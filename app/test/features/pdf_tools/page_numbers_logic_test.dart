import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_numbers.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  group('formatPageLabel', () {
    test('bốn kiểu nhãn', () {
      expect(formatPageLabel(PageNumberStyle.plain, 3, 10), '3');
      expect(formatPageLabel(PageNumberStyle.ofTotal, 3, 10), '3 / 10');
      expect(formatPageLabel(PageNumberStyle.pageWord, 3, 10), 'Page 3');
      expect(formatPageLabel(PageNumberStyle.dashed, 3, 10), '- 3 -');
    });

    test('chữ "Trang" theo mẫu của ngôn ngữ', () {
      expect(
        formatPageLabel(
          PageNumberStyle.pageWord,
          7,
          9,
          pageWordTemplate: 'Trang {n}',
        ),
        'Trang 7',
      );
      expect(
        formatPageLabel(
          PageNumberStyle.pageWord,
          12,
          20,
          pageWordTemplate: '第 {n} 页',
        ),
        '第 12 页',
      );
      expect(
        formatPageLabel(
          PageNumberStyle.pageWord,
          2,
          2,
          pageWordTemplate: '{n} ページ',
        ),
        '2 ページ',
      );
    });

    test('mẫu thiếu {n} → nối số vào sau; mẫu rỗng → chỉ số', () {
      expect(
        formatPageLabel(PageNumberStyle.pageWord, 4, 4, pageWordTemplate: 'Hal'),
        'Hal 4',
      );
      expect(
        formatPageLabel(PageNumberStyle.pageWord, 4, 4, pageWordTemplate: '  '),
        '4',
      );
    });
  });

  group('selectNumberedPages', () {
    test('mặc định: mọi trang', () {
      expect(selectNumberedPages(3), [0, 1, 2]);
      expect(selectNumberedPages(0), isEmpty);
    });

    test('khoảng trang: gộp trùng, sắp tăng dần', () {
      expect(
        selectNumberedPages(
          10,
          ranges: const [PageRange(5, 6), PageRange(2, 3), PageRange(3, 5)],
        ),
        [1, 2, 3, 4, 5],
      );
    });

    test('bỏ trang bìa (cả khi nằm trong khoảng)', () {
      expect(selectNumberedPages(3, skipFirst: true), [1, 2]);
      expect(
        selectNumberedPages(
          5,
          ranges: const [PageRange(1, 2)],
          skipFirst: true,
        ),
        [1],
      );
      expect(selectNumberedPages(1, skipFirst: true), isEmpty);
    });

    test('khoảng ngoài số trang → FormatException', () {
      expect(
        () => selectNumberedPages(3, ranges: const [PageRange(2, 4)]),
        throwsFormatException,
      );
    });
  });

  group('vị trí & góc xoay', () {
    const raw = Size(595, 842);

    test('pageRotationDegrees', () {
      expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle0), 0);
      expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle90), 90);
      expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle180), 180);
      expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle270), 270);
    });

    test('visualPageSize đổi rộng/cao khi xoay 90/270', () {
      expect(visualPageSize(raw, 0), raw);
      expect(visualPageSize(raw, 180), raw);
      expect(visualPageSize(raw, 90), const Size(842, 595));
      expect(visualPageSize(raw, 270), const Size(842, 595));
      expect(visualPageSize(raw, -90), const Size(842, 595));
    });

    test('visualToRawPoint theo /Rotate xoay chiều kim đồng hồ', () {
      // 0°: giữ nguyên
      expect(visualToRawPoint(10, 20, raw, 0), const Offset(10, 20));
      // 90°: góc trên trái khi xem = góc dưới trái trang gốc
      expect(visualToRawPoint(0, 0, raw, 90), const Offset(0, 842));
      // 90°: giữa mép dưới khi xem = giữa mép phải trang gốc
      expect(visualToRawPoint(421, 595, raw, 90), const Offset(595, 421));
      // 180°: lật cả hai trục
      expect(visualToRawPoint(0, 0, raw, 180), const Offset(595, 842));
      expect(visualToRawPoint(100, 30, raw, 180), const Offset(495, 812));
      // 270°: góc trên trái khi xem = góc trên phải trang gốc
      expect(visualToRawPoint(0, 0, raw, 270), const Offset(595, 0));
      // 270°: giữa mép dưới khi xem = giữa mép trái trang gốc
      expect(visualToRawPoint(421, 595, raw, 270), const Offset(0, 421));
    });

    test('pageNumberRect: 6 vị trí cách mép đúng lề', () {
      Rect at(PageNumberVAlign v, PageNumberHAlign h) => pageNumberRect(
        pageW: 595,
        pageH: 842,
        textW: 20,
        textH: 12,
        vAlign: v,
        hAlign: h,
        margin: 24,
      );
      expect(
        at(PageNumberVAlign.bottom, PageNumberHAlign.center),
        const Rect.fromLTWH(287.5, 806, 20, 12),
      );
      expect(
        at(PageNumberVAlign.top, PageNumberHAlign.left),
        const Rect.fromLTWH(24, 24, 20, 12),
      );
      expect(
        at(PageNumberVAlign.top, PageNumberHAlign.right),
        const Rect.fromLTWH(551, 24, 20, 12),
      );
      expect(
        at(PageNumberVAlign.bottom, PageNumberHAlign.left),
        const Rect.fromLTWH(24, 806, 20, 12),
      );
      expect(
        at(PageNumberVAlign.bottom, PageNumberHAlign.right),
        const Rect.fromLTWH(551, 806, 20, 12),
      );
      expect(
        at(PageNumberVAlign.top, PageNumberHAlign.center),
        const Rect.fromLTWH(287.5, 24, 20, 12),
      );
    });

    test('pageNumberRect kẹp trong trang khi lề / chữ quá lớn', () {
      final big = pageNumberRect(
        pageW: 100,
        pageH: 50,
        textW: 150,
        textH: 10,
        vAlign: PageNumberVAlign.bottom,
        hAlign: PageNumberHAlign.right,
        margin: 500,
      );
      expect(big.left, 0);
      expect(big.top, 0);
      final negMargin = pageNumberRect(
        pageW: 100,
        pageH: 50,
        textW: 10,
        textH: 10,
        vAlign: PageNumberVAlign.top,
        hAlign: PageNumberHAlign.left,
        margin: -5,
      );
      expect(negMargin.topLeft, Offset.zero);
    });
  });

  test('PageNumberSpec mặc định: dưới giữa, cỡ 11, lề 24, từ số 1', () {
    const s = PageNumberSpec();
    expect(s.style, PageNumberStyle.plain);
    expect(s.vAlign, PageNumberVAlign.bottom);
    expect(s.hAlign, PageNumberHAlign.center);
    expect(s.fontSize, 11);
    expect(s.margin, 24);
    expect(s.startNumber, 1);
    expect(s.ranges, isNull);
    expect(s.skipFirstPage, isFalse);
  });
}
