// Giữ liên kết / chú thích khi nén PDF mức Vừa / Mạnh (trang đã thành ảnh).
// Đọc `PdfPage.annotations` của PDF gốc trong isolate, đổi thành dữ liệu sendable, rồi dựng lại
// trên trang ảnh với toạ độ nhân theo tỉ lệ (khổ trang ảnh / khổ trang gốc).
// Dựng lại được: liên kết URI, liên kết nội bộ (có /Dest), highlight / underline / squiggly /
// strikeout, ghi chú (popup). Không dựng lại được (đếm vào "mất"): ô biểu mẫu, hình vẽ (line,
// rect, ellipse, polygon), liên kết nội bộ dạng action, và mọi chú thích ở trang xoay. Loại mà
// thư viện Syncfusion không đọc được (FreeText, Ink, Stamp…) không đếm được.
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'isolate_job.dart';
import 'pdf_ops.dart' show openPdfFile;

/// Một chú thích đã chuẩn hoá (sendable): `[kind, left, top, width, height, ...riêng từng loại]`.
///  - `uri`:  `[.., uri]`
///  - `goto`: `[.., destPageIndex, x, y]`
///  - `mark`: `[.., typeIndex, r, g, b, text, author, opacity, [l, t, w, h, …]]`
///  - `note`: `[.., text, author, r, g, b]`
typedef AnnotData = List<Object>;

/// Chú thích đọc được của từng trang + khổ trang gốc + số chú thích không dựng lại được.
class PageAnnotations {
  const PageAnnotations({
    required this.width,
    required this.height,
    required this.items,
    required this.lost,
  });

  final double width;
  final double height;
  final List<AnnotData> items;
  final int lost;

  Map<String, Object> toMap() => {
    'w': width,
    'h': height,
    'items': items,
    'lost': lost,
  };

  static PageAnnotations fromMap(Map<Object?, Object?> m) => PageAnnotations(
    width: (m['w'] as num).toDouble(),
    height: (m['h'] as num).toDouble(),
    items: [for (final i in (m['items'] as List)) (i as List).cast<Object>()],
    lost: m['lost'] as int,
  );
}

/// Job (isolate): đọc chú thích từng trang của PDF gốc → `List<Map>` (xem [PageAnnotations]).
Future<Object?> compressExtractAnnotationsJob(
  Map<String, Object?> args,
  JobPort port,
) async {
  final doc = await openPdfFile(
    args['input'] as String,
    password: args['password'] as String?,
  );
  try {
    final n = doc.pages.count;
    final out = <Map<String, Object>>[];
    for (var i = 0; i < n; i++) {
      out.add(_readPage(doc, i).toMap());
      port.progress((i + 1) / n);
    }
    return out;
  } finally {
    doc.dispose();
  }
}

PageAnnotations _readPage(sf.PdfDocument doc, int index) {
  final page = doc.pages[index];
  final size = page.size;
  final items = <AnnotData>[];
  var lost = 0;
  int count;
  try {
    count = page.annotations.count;
  } catch (_) {
    return PageAnnotations(
      width: size.width,
      height: size.height,
      items: items,
      lost: 0,
    );
  }
  final rotated = page.rotation != sf.PdfPageRotateAngle.rotateAngle0;
  for (var j = 0; j < count; j++) {
    try {
      final a = page.annotations[j];
      final data = rotated ? null : _encode(doc, a);
      if (data == null) {
        lost++;
      } else {
        items.add(data);
      }
    } catch (_) {
      lost++;
    }
  }
  return PageAnnotations(
    width: size.width,
    height: size.height,
    items: items,
    lost: lost,
  );
}

List<Object> _box(Rect b) => <Object>[b.left, b.top, b.width, b.height];

AnnotData? _encode(sf.PdfDocument doc, sf.PdfAnnotation a) {
  final b = a.bounds;
  if (b.width <= 0 || b.height <= 0) return null;
  if (a is sf.PdfUriAnnotation) {
    final uri = a.uri;
    return uri.isEmpty ? null : <Object>['uri', ..._box(b), uri];
  }
  if (a is sf.PdfTextWebLink) {
    final uri = a.url;
    return uri.isEmpty ? null : <Object>['uri', ..._box(b), uri];
  }
  if (a is sf.PdfDocumentLinkAnnotation) {
    final d = a.destination;
    if (d == null) return null;
    final target = _pageIndexOf(doc, d.page);
    if (target < 0) return null;
    return <Object>['goto', ..._box(b), target, d.location.dx, d.location.dy];
  }
  if (a is sf.PdfTextMarkupAnnotation) {
    final c = a.color;
    final rects = a.boundsCollection;
    return <Object>[
      'mark',
      ..._box(b),
      a.textMarkupAnnotationType.index,
      c.r,
      c.g,
      c.b,
      a.text,
      a.author,
      a.opacity,
      <Object>[for (final r in (rects.isEmpty ? [b] : rects)) ..._box(r)],
    ];
  }
  if (a is sf.PdfPopupAnnotation) {
    final c = a.color;
    return <Object>['note', ..._box(b), a.text, a.author, c.r, c.g, c.b];
  }
  return null;
}

int _pageIndexOf(sf.PdfDocument doc, sf.PdfPage page) {
  for (var i = 0; i < doc.pages.count; i++) {
    if (identical(doc.pages[i], page)) return i;
  }
  return -1;
}

/// Dựng lại [pages] lên [doc] (trang i của [doc] là trang ảnh i). Trang ảnh khổ khác trang gốc
/// → nhân toạ độ theo tỉ lệ. Trả số chú thích không dựng được (gồm cả [PageAnnotations.lost]).
/// Gọi SAU khi đã thêm đủ trang (liên kết nội bộ cần trang đích).
int restoreAnnotations(sf.PdfDocument doc, List<PageAnnotations> pages) {
  var lost = 0;
  final n = doc.pages.count;
  for (var i = 0; i < pages.length && i < n; i++) {
    final src = pages[i];
    lost += src.lost;
    final page = doc.pages[i];
    final sx = src.width > 0 ? page.size.width / src.width : 1.0;
    final sy = src.height > 0 ? page.size.height / src.height : 1.0;
    Rect r(List<Object> a, int o) => Rect.fromLTWH(
      (a[o] as num).toDouble() * sx,
      (a[o + 1] as num).toDouble() * sy,
      (a[o + 2] as num).toDouble() * sx,
      (a[o + 3] as num).toDouble() * sy,
    );
    for (final a in src.items) {
      try {
        switch (a[0] as String) {
          case 'uri':
            page.annotations.add(
              sf.PdfUriAnnotation(bounds: r(a, 1), uri: a[5] as String)
                ..border = sf.PdfAnnotationBorder(0),
            );
          case 'goto':
            final t = (a[5] as int);
            if (t < 0 || t >= n) {
              lost++;
              continue;
            }
            final tp = doc.pages[t];
            final tsx = pages[t].width > 0 ? tp.size.width / pages[t].width : 1.0;
            final tsy = pages[t].height > 0 ? tp.size.height / pages[t].height : 1.0;
            page.annotations.add(
              sf.PdfDocumentLinkAnnotation(
                r(a, 1),
                sf.PdfDestination(
                  tp,
                  Offset(
                    (a[6] as num).toDouble() * tsx,
                    (a[7] as num).toDouble() * tsy,
                  ),
                ),
              )..border = sf.PdfAnnotationBorder(0),
            );
          case 'mark':
            final flat = (a[12] as List).cast<Object>();
            final rects = [
              for (var k = 0; k + 3 < flat.length; k += 4) r(flat, k),
            ];
            page.annotations.add(
              sf.PdfTextMarkupAnnotation(
                r(a, 1),
                a[9] as String,
                sf.PdfColor(a[6] as int, a[7] as int, a[8] as int),
                author: a[10] as String,
                opacity: (a[11] as num).toDouble(),
                boundsCollection: rects,
                textMarkupAnnotationType:
                    sf.PdfTextMarkupAnnotationType.values[a[5] as int],
              ),
            );
          case 'note':
            page.annotations.add(
              sf.PdfPopupAnnotation(
                r(a, 1),
                a[5] as String,
                author: a[6] as String,
                color: sf.PdfColor(a[7] as int, a[8] as int, a[9] as int),
              ),
            );
          default:
            lost++;
        }
      } catch (e) {
        debugPrint('compress: không dựng lại được chú thích ${a[0]} ($e)');
        lost++;
      }
    }
  }
  return lost;
}
