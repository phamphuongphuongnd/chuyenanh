// Kiểm thử hộp trắng (A18) — lib/src/options.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

void main() {
  test('U1-P1 DocxWriteOptions mặc định: A4 dọc, lề 2,54 cm, Arial 11, Noto Sans', () {
    const o = DocxWriteOptions();
    expect(o.pageWidthPt, closeTo(210 / 25.4 * 72, 0.1));
    expect(o.pageHeightPt, closeTo(297 / 25.4 * 72, 0.1));
    expect(o.pageWidthPt < o.pageHeightPt, isTrue);
    expect(o.marginPt, closeTo(2.54 / 2.54 * 72, 0.01));
    expect(o.fontFamily, 'Arial');
    expect(o.fallbackFontFamily, 'Noto Sans');
    expect(o.fontSizePt, 11);
    expect(o.created, isNull);
  });

  test('U1-P1b RebuildOptions mặc định: chèn ngắt trang, dò cột, dò bảng', () {
    const o = RebuildOptions();
    expect(o.insertPageBreaks, isTrue);
    expect(o.detectColumns, isTrue);
    expect(o.detectTables, isTrue);
  });
}
