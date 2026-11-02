// Kiểm thử hộp trắng (A05, Bước 6) cho lib/features/convert/ocr/ocr_to_layout.dart.
// Expected chép từ test-output/whitebox/convert/ocr_to_layout/buoc-5-du-lieu-thu.md — không chỉnh cho khớp code.
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_layout/pdf_layout.dart' show LayoutLine;
import 'package:pdf_office/features/convert/ocr/ocr_to_layout.dart';

const _e = 1e-9;

OcrResult _r(List<OcrBlock> blocks, {int? w = 1000, int? h = 1400}) =>
    OcrResult(text: '', blocks: blocks, imageWidth: w, imageHeight: h);

OcrBlock _blk(List<(String, Rect)> lines) =>
    OcrBlock(lines.map((e) => e.$1).join('\n'), Rect.zero, [for (final l in lines) OcrLine(l.$1, l.$2)]);

const _xin = ('Xin chào', Rect.fromLTWH(100, 200, 500, 70));

void main() {
  group('U1 ocrRenderDpi', () {
    test('OL-U1-B1 dọc 595x842 → 200 dpi (D1 S, D2 S, D3 S)', () {
      expect(ocrRenderDpi(595, 842), closeTo(200, _e));
    });
    test('OL-U1-B2 ngang 842x595 → 200 dpi (D1 Đ)', () {
      expect(ocrRenderDpi(842, 595), closeTo(200, _e));
    });
    test('OL-U1-B3 kích thước 0 → trả targetDpi, không chia 0 (D2 Đ)', () {
      final v = ocrRenderDpi(0, 0);
      expect(v.isFinite, isTrue);
      expect(v, 200);
    });
    test('OL-U1-B4 2000x3000 → dpi giảm để cạnh dài = 2560 px (D3 Đ)', () {
      final v = ocrRenderDpi(2000, 3000);
      expect(v, lessThan(200));
      expect(v, closeTo(61.44, 1e-9));
      expect(3000 / 72 * v, closeTo(2560, 1e-6));
    });
  });

  group('U2 ocrResultToLayoutPage', () {
    test('OL-U2-B1 không có khối → trang rỗng giữ index/kích thước (D9 S ngay)', () {
      final p = ocrResultToLayoutPage(_r([]), pageIndex: 2, pageWidth: 500, pageHeight: 700);
      expect(p.lines, isEmpty);
      expect((p.index, p.width, p.height), (2, 500.0, 700.0));
    });
    test('OL-U2-B2 1 khối 1 dòng, có cỡ ảnh → đổi px sang point theo tỉ lệ', () {
      final p = ocrResultToLayoutPage(_r([_blk([_xin])]), pageIndex: 3, pageWidth: 500, pageHeight: 700);
      final l = p.lines.single;
      expect(l.pageIndex, 3);
      expect(l.text, 'Xin chào');
      expect(l.bounds.left, closeTo(50, _e));
      expect(l.bounds.top, closeTo(100, _e));
      expect(l.bounds.width, closeTo(250, _e));
      expect(l.bounds.height, closeTo(35, _e));
      expect(l.fontSize, closeTo(28, _e));
    });
    test('OL-U2-B3 khối không có dòng → dùng chữ khối, xuống dòng thành dấu cách (D10 Đ)', () {
      final r = _r([const OcrBlock('a\nb', Rect.fromLTWH(200, 200, 400, 100), [])]);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700).lines.single;
      expect(l.text, 'a b');
      expect(l.bounds.left, closeTo(100, _e));
      expect(l.bounds.top, closeTo(100, _e));
      expect(l.bounds.width, closeTo(200, _e));
      expect(l.bounds.height, closeTo(50, _e));
    });
    test('OL-U2-B4 1 khối 2 dòng → 2 dòng, trên xuống (D11 lặp 2 lần)', () {
      final r = _r([
        _blk([('trên', const Rect.fromLTWH(0, 0, 100, 40)), ('dưới', const Rect.fromLTWH(0, 300, 100, 40))])
      ]);
      final p = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 1000, pageHeight: 1400);
      expect(p.lines.map((l) => l.text), ['trên', 'dưới']);
    });
    test('OL-U2-B5 imageWidth null, pixelWidth 1000 → dùng pixelWidth (D1 Đ)', () {
      final r = _r([_blk([_xin])], w: null);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700, pixelWidth: 1000)
          .lines
          .single;
      expect(l.bounds.left, closeTo(50, _e));
      expect(l.bounds.width, closeTo(250, _e));
    });
    test('OL-U2-B6 cả imageWidth lẫn pixelWidth null → 200 dpi cho trục x (D2 Đ, D5 S)', () {
      final r = _r([_blk([_xin])], w: null);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700).lines.single;
      expect(l.bounds.left, closeTo(36, _e));
      expect(l.bounds.width, closeTo(180, _e));
      expect(l.bounds.top, closeTo(100, _e)); // trục y vẫn theo imageHeight
    });
    test('OL-U2-B8 imageWidth = 0 → 200 dpi cho trục x (D6 S)', () {
      final r = _r([_blk([_xin])], w: 0);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700).lines.single;
      expect(l.bounds.left, closeTo(36, _e));
    });
    test('OL-U2-B9 imageHeight null, pixelHeight 1400 → dùng pixelHeight (D3 Đ)', () {
      final r = _r([_blk([_xin])], h: null);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700, pixelHeight: 1400)
          .lines
          .single;
      expect(l.bounds.top, closeTo(100, _e));
      expect(l.bounds.height, closeTo(35, _e));
    });
    test('OL-U2-B10 cả imageHeight lẫn pixelHeight null → 200 dpi cho trục y (D4 Đ, D7 S)', () {
      final r = _r([_blk([_xin])], h: null);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700).lines.single;
      expect(l.bounds.top, closeTo(72, _e));
      expect(l.bounds.height, closeTo(25.2, _e));
      expect(l.fontSize, closeTo(20.16, _e));
      expect(l.bounds.left, closeTo(50, _e)); // trục x vẫn theo imageWidth
    });
    test('OL-U2-B12 imageHeight = 0 → 200 dpi cho trục y (D8 S)', () {
      final r = _r([_blk([_xin])], h: 0);
      final l = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 500, pageHeight: 700).lines.single;
      expect(l.bounds.top, closeTo(72, _e));
    });
  });

  group('U3 add (qua ocrResultToLayoutPage, tỉ lệ 1:1)', () {
    List<LayoutLine> run(String t, Rect b) =>
        ocrResultToLayoutPage(_r([_blk([(t, b)])]), pageIndex: 0, pageWidth: 1000, pageHeight: 1400).lines;

    test('OL-U3-B1 chữ NFD có khoảng trắng hai đầu → trim + NFC, thêm dòng (D1 S, D2 S, D3 S)', () {
      final ls = run('  Việt  ', const Rect.fromLTWH(0, 0, 100, 40));
      expect(ls.single.text, 'Việt');
    });
    test('OL-U3-B2 chỉ khoảng trắng → bỏ dòng (D1 Đ)', () {
      expect(run('   ', const Rect.fromLTWH(0, 0, 100, 40)), isEmpty);
    });
    test('OL-U3-B3 hộp rộng 0 → bỏ dòng (D2 Đ)', () {
      expect(run('abc', const Rect.fromLTWH(0, 0, 0, 40)), isEmpty);
    });
    test('OL-U3-B4 hộp cao 0 → bỏ dòng (D3 Đ)', () {
      expect(run('abc', const Rect.fromLTWH(0, 0, 100, 0)), isEmpty);
    });
  });

  group('U4 _readingOrder (qua ocrResultToLayoutPage)', () {
    List<String> order(List<(String, Rect)> ls) =>
        ocrResultToLayoutPage(_r(ls.isEmpty ? [] : [_blk(ls)]), pageIndex: 0, pageWidth: 1000, pageHeight: 1400)
            .lines
            .map((l) => l.text)
            .toList();

    test('OL-U4-B1 không dòng → [] (D1 S)', () {
      expect(order([]), isEmpty);
    });
    test('OL-U4-B2 1 dòng (D1 Đ, D2 S)', () {
      expect(order([('một', const Rect.fromLTWH(0, 0, 100, 40))]), ['một']);
    });
    test('OL-U4-B3 2 dòng khác hàng, đưa vào ngược → trên xuống (D2 Đ, D3 S)', () {
      expect(
        order([('dưới', const Rect.fromLTWH(0, 300, 100, 40)), ('trên', const Rect.fromLTWH(0, 0, 100, 40))]),
        ['trên', 'dưới'],
      );
    });
    test('OL-U4-B4 2 dòng cùng hàng, đưa vào phải trước → trái sang phải (D3 Đ)', () {
      expect(
        order([('phải', const Rect.fromLTWH(500, 102, 100, 40)), ('trái', const Rect.fromLTWH(0, 100, 100, 40))]),
        ['trái', 'phải'],
      );
    });
  });
}
