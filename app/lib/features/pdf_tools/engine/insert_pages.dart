// Chèn trang vào PDF có sẵn: trang trắng, ảnh, hoặc trang lấy từ PDF khác.
// Phần lập kế hoạch là hàm thuần (có unit test); phần ghép trang chạy TRONG isolate
// (hàm top-level, tham số/kết quả sendable). Không import Flutter widget.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import 'isolate_job.dart';
import 'page_ranges.dart';
import 'pdf_ops.dart';

/// Số trang trắng tối đa mỗi lần chèn.
const int maxInsertBlankPages = 50;

/// Cạnh dài tối đa (px) của ảnh nhúng — như Ảnh→PDF.
const int maxInsertImageLongSide = 3000;

/// Lề quanh ảnh trên trang chèn (point).
const double insertImageMargin = 18;

/// Khổ A4 dọc (point).
const Size a4Portrait = Size(595.28, 841.89);

// --------------------------------------------------------------------------
// Vị trí chèn

/// Người dùng chọn chèn ở đâu.
enum InsertWhere { start, afterPage, end }

/// Đổi lựa chọn vị trí thành `insertAfter` = số trang gốc đứng TRƯỚC khối trang chèn
/// (0 = đầu tài liệu, [pageCount] = cuối). [afterPage] (1-based) chỉ dùng với
/// [InsertWhere.afterPage]; ngoài `1..pageCount` → [RangeError].
int resolveInsertAfter(InsertWhere where, int afterPage, int pageCount) {
  if (pageCount < 1) throw ArgumentError('pageCount must be >= 1');
  return switch (where) {
    InsertWhere.start => 0,
    InsertWhere.end => pageCount,
    InsertWhere.afterPage => RangeError.checkValueInInterval(
      afterPage,
      1,
      pageCount,
      'afterPage',
    ),
  };
}

/// Chỉ số (0-based) trang gốc "kề bên" chỗ chèn — lấy khổ cho trang trắng / ảnh:
/// trang ngay trước chỗ chèn, hoặc trang đầu nếu chèn ở đầu.
int neighborPageIndex(int insertAfter) => insertAfter == 0 ? 0 : insertAfter - 1;

/// Một trang của tài liệu kết quả.
sealed class ResultPage {
  const ResultPage(this.index);

  /// 0-based: trong file gốc ([OriginalPage]) hoặc trong khối trang chèn ([InsertedPage]).
  final int index;
}

/// Trang thứ [index] của file gốc.
final class OriginalPage extends ResultPage {
  const OriginalPage(super.index);

  @override
  bool operator ==(Object other) => other is OriginalPage && other.index == index;

  @override
  int get hashCode => Object.hash('o', index);

  @override
  String toString() => 'O$index';
}

/// Trang chèn thứ [index].
final class InsertedPage extends ResultPage {
  const InsertedPage(super.index);

  @override
  bool operator ==(Object other) => other is InsertedPage && other.index == index;

  @override
  int get hashCode => Object.hash('i', index);

  @override
  String toString() => 'I$index';
}

/// Thứ tự trang của tài liệu kết quả: [insertAfter] trang gốc đầu, rồi [insertedCount] trang
/// chèn, rồi phần còn lại của file gốc. Tham số sai → [ArgumentError] / [RangeError].
List<ResultPage> planInsertion({
  required int sourcePageCount,
  required int insertAfter,
  required int insertedCount,
}) {
  if (sourcePageCount < 1) throw ArgumentError('sourcePageCount must be >= 1');
  if (insertedCount < 1) throw ArgumentError('insertedCount must be >= 1');
  RangeError.checkValueInInterval(insertAfter, 0, sourcePageCount, 'insertAfter');
  return [
    for (var i = 0; i < insertAfter; i++) OriginalPage(i),
    for (var i = 0; i < insertedCount; i++) InsertedPage(i),
    for (var i = insertAfter; i < sourcePageCount; i++) OriginalPage(i),
  ];
}

/// Các trang (0-based, theo thứ tự) lấy từ PDF khác: [ranges] `null` = tất cả.
/// Khoảng ngoài `1..pageCount` → [FormatException]; list rỗng → [ArgumentError].
List<int> pagesFromRanges(List<PageRange>? ranges, int pageCount) {
  if (pageCount < 1) throw const CorruptFile('no pages');
  if (ranges == null) return [for (var i = 0; i < pageCount; i++) i];
  validateRanges(ranges, pageCount);
  return [
    for (final r in ranges)
      for (var pg = r.start; pg <= r.end; pg++) pg - 1,
  ];
}

// --------------------------------------------------------------------------
// Khổ trang + vị trí ảnh

/// Khổ trang A4 cho ảnh [imageWidth]×[imageHeight]: ảnh ngang → A4 ngang.
Size a4PageForImage(int imageWidth, int imageHeight) =>
    imageWidth > imageHeight ? a4Portrait.flipped : a4Portrait;

/// Ô vẽ ảnh: co/giãn giữ tỉ lệ cho vừa trang trừ [margin], căn giữa.
Rect fitImageRect({
  required int imageWidth,
  required int imageHeight,
  required Size page,
  double margin = insertImageMargin,
}) {
  final boxW = math.max(1.0, page.width - 2 * margin);
  final boxH = math.max(1.0, page.height - 2 * margin);
  final iw = math.max(1, imageWidth).toDouble();
  final ih = math.max(1, imageHeight).toDouble();
  final scale = math.min(boxW / iw, boxH / ih);
  final w = iw * scale;
  final h = ih * scale;
  return Rect.fromLTWH((page.width - w) / 2, (page.height - h) / 2, w, h);
}

// --------------------------------------------------------------------------
// Nội dung chèn

/// Cách đặt khổ trang cho ảnh chèn.
enum InsertImageFit {
  /// Trang A4 (dọc/ngang theo ảnh), ảnh vừa trang.
  a4,

  /// Trang cùng khổ trang kề bên, ảnh vừa trang.
  neighbor,
}

/// Nội dung sẽ chèn (đúng một loại).
sealed class InsertContent {
  const InsertContent();
}

/// [count] trang trắng (1–[maxInsertBlankPages]) cùng khổ trang kề bên.
final class InsertBlank extends InsertContent {
  const InsertBlank(this.count);
  final int count;
}

/// Mỗi ảnh (bytes PNG/JPG) một trang, theo thứ tự.
final class InsertImages extends InsertContent {
  const InsertImages(this.images, {this.fit = InsertImageFit.a4});
  final List<Uint8List> images;
  final InsertImageFit fit;
}

/// Trang của PDF [path]; [ranges] `null` = tất cả trang. [password] nếu file khoá.
final class InsertPdfPages extends InsertContent {
  const InsertPdfPages(this.path, {this.password, this.ranges});
  final String path;
  final String? password;
  final List<PageRange>? ranges;
}

/// Số trang sẽ chèn với [content]; [otherPageCount] = số trang PDF nguồn (chỉ cho
/// [InsertPdfPages]). Ranges sai → [FormatException].
int insertedPageCount(InsertContent content, {int otherPageCount = 0}) =>
    switch (content) {
      InsertBlank(:final count) => count,
      InsertImages(:final images) => images.length,
      InsertPdfPages(:final ranges) => pagesFromRanges(ranges, otherPageCount).length,
    };

// --------------------------------------------------------------------------
// Engine

/// Chèn trang vào [inputPath] sau [insertAfter] trang gốc (0 = đầu, số trang = cuối), ghi
/// file mới [outputPath] (không ghi đè gốc, không giữ mật khẩu, mất annotation/form/link).
abstract interface class InsertPagesEngine {
  Future<String> insertPages(
    String inputPath,
    int insertAfter,
    InsertContent content,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}

/// Impl Syncfusion, chạy trong isolate riêng (huỷ được, báo tiến độ).
class SyncfusionInsertPages implements InsertPagesEngine {
  const SyncfusionInsertPages();

  @override
  Future<String> insertPages(
    String inputPath,
    int insertAfter,
    InsertContent content,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    _validateContent(content);
    final out = p.normalize(p.absolute(outputPath));
    for (final i in [inputPath, if (content is InsertPdfPages) content.path]) {
      if (p.normalize(p.absolute(i)) == out) {
        throw ArgumentError('output must differ from input: $outputPath');
      }
    }
    final r = await runIsolateJob(
      insertPagesJob,
      {
        'input': inputPath,
        'password': password,
        'insertAfter': insertAfter,
        'content': content,
        'output': outputPath,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }
}

void _validateContent(InsertContent content) {
  switch (content) {
    case InsertBlank(:final count):
      RangeError.checkValueInInterval(count, 1, maxInsertBlankPages, 'count');
    case InsertImages(:final images):
      if (images.isEmpty) throw ArgumentError('images must not be empty');
    case InsertPdfPages(:final ranges):
      if (ranges != null && ranges.isEmpty) {
        throw ArgumentError('ranges must not be empty');
      }
  }
}

/// Ảnh đã chuẩn hoá (xoay theo EXIF, thu nhỏ) để nhúng.
class _PreparedImage {
  const _PreparedImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

_PreparedImage _prepareImage(Uint8List raw) {
  try {
    final bytes = ops.applyEdit(
      raw,
      const ops.ImageEdit(maxLongSide: maxInsertImageLongSide),
    );
    final info = ops.probe(bytes);
    return _PreparedImage(bytes, info.width, info.height);
  } catch (e) {
    throw CorruptFile('image: $e');
  }
}

/// Khổ trang đang HIỂN THỊ (đã tính hướng xoay) của [page].
Size _displayedSize(sf.PdfPage page) {
  final s = page.size;
  final r = page.rotation;
  final swap =
      r == sf.PdfPageRotateAngle.rotateAngle90 ||
      r == sf.PdfPageRotateAngle.rotateAngle270;
  return swap ? Size(s.height, s.width) : Size(s.width, s.height);
}

/// Thêm một trang khổ [size] (lề 0) vào [out] — mỗi trang một section để đặt khổ riêng.
sf.PdfPage _addPage(sf.PdfDocument out, Size size) {
  final section = out.sections!.add();
  final settings = section.pageSettings;
  settings.margins.all = 0;
  // Đặt orientation trước size (Syncfusion chuẩn hoá size theo orientation).
  settings.orientation = size.width > size.height
      ? sf.PdfPageOrientation.landscape
      : sf.PdfPageOrientation.portrait;
  settings.size = size;
  return section.pages.add();
}

/// Job isolate: args `input`, `password`, `insertAfter`, `content` ([InsertContent]), `output`.
Future<Object?> insertPagesJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final insertAfter = args['insertAfter'] as int;
  final content = args['content'] as InsertContent;
  final output = args['output'] as String;
  _validateContent(content);

  final src = await openPdfFile(input, password: password);
  sf.PdfDocument? other;
  final out = sf.PdfDocument();
  var saved = false;
  try {
    final count = src.pages.count;
    if (count == 0) throw const CorruptFile('no pages');
    RangeError.checkValueInInterval(insertAfter, 0, count, 'insertAfter');
    final neighbor = _displayedSize(src.pages[neighborPageIndex(insertAfter)]);

    // Chuẩn bị trang chèn: hàm vẽ trang chèn thứ i.
    final int insertedCount;
    final void Function(int i) addInserted;
    var base = 0.0; // phần tiến độ đã dùng cho bước chuẩn bị
    switch (content) {
      case InsertBlank(count: final n):
        insertedCount = n;
        addInserted = (_) => _addPage(out, neighbor);
      case InsertImages(:final images, :final fit):
        final prepared = <_PreparedImage>[];
        for (var i = 0; i < images.length; i++) {
          prepared.add(_prepareImage(images[i]));
          port.progress((i + 1) / images.length * 0.4);
        }
        base = 0.4;
        insertedCount = prepared.length;
        addInserted = (i) {
          final img = prepared[i];
          final size = fit == InsertImageFit.a4
              ? a4PageForImage(img.width, img.height)
              : neighbor;
          final page = _addPage(out, size);
          page.graphics.drawImage(
            sf.PdfBitmap(img.bytes),
            fitImageRect(imageWidth: img.width, imageHeight: img.height, page: size),
          );
        };
      case InsertPdfPages(path: final otherPath, password: final pw, :final ranges):
        final doc = await openPdfFile(otherPath, password: pw);
        other = doc;
        final indices = pagesFromRanges(ranges, doc.pages.count);
        insertedCount = indices.length;
        addInserted = (i) => copyPage(out, doc.pages[indices[i]]);
    }

    final plan = planInsertion(
      sourcePageCount: count,
      insertAfter: insertAfter,
      insertedCount: insertedCount,
    );
    for (var i = 0; i < plan.length; i++) {
      switch (plan[i]) {
        case OriginalPage(:final index):
          copyPage(out, src.pages[index]);
        case InsertedPage(:final index):
          addInserted(index);
      }
      port.progress(base + (i + 1) / plan.length * (0.9 - base));
    }
    final bytes = await out.save();
    out.dispose();
    saved = true;
    await writeAtomically(output, bytes);
    port.fileWritten(output);
    return output;
  } finally {
    if (!saved) out.dispose();
    other?.dispose();
    src.dispose();
  }
}
