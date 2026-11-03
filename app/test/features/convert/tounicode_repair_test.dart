// CMap ToUnicode lệch chuẩn (đích bfrange 5 chữ số hex, kiểu PDF do MuPDF / PyMuPDF tạo) làm
// Syncfusion ném RangeError khi trích chữ → cả tài liệu thành CorruptFile. Fixture
// test/fixtures/pdf/tounicode_5digit_bfrange.pdf (≈ 31 KB, 2 trang) tạo bằng PyMuPDF:
// `page.insert_font(fontfile=assets/fonts/NotoSans-Regular.ttf)` + `insert_text` (chữ Việt) +
// `doc.subset_fonts()` — CMap vẫn giữ đủ bảng của font gốc, có 7 dòng kiểu `<0f0d> <0f1a> <1df00>`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/engine/pdf_extract.dart';
import 'package:pdf_office/features/convert/engine/tounicode_repair.dart';
import 'package:pdf_office/features/convert/text/vietnamese_nfc.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const fixturePath = 'test/fixtures/pdf/tounicode_5digit_bfrange.pdf';

const expectedLines = [
  'Xin chào thế giới',
  'Tiếng Việt có dấu: ắ ằ ẳ ẵ ặ ệ ữ ỹ',
  'Đọc to và dàn chữ',
];

String _cmap(String body) => '/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n'
    '1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n$body\nendcmap\n'
    'CMapName currentdict /CMap defineresource pop\nend\nend\n';

/// Bọc extractor thật: lần gọi đầu ném [error], các lần sau trích thật.
class _FailOnce implements sf.PdfTextExtractor {
  _FailOnce(this.inner, this.error);
  final sf.PdfTextExtractor inner;
  final Object error;
  int calls = 0;

  @override
  List<sf.TextLine> extractTextLines({int? startPageIndex, int? endPageIndex}) {
    calls++;
    if (calls == 1) throw error;
    return inner.extractTextLines(startPageIndex: startPageIndex, endPageIndex: endPageIndex);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Uint8List fixture;
  setUpAll(() => fixture = File(fixturePath).readAsBytesSync());

  group('repairToUnicodeCMap', () {
    test('CMap chuẩn → null (không đụng)', () {
      expect(
        repairToUnicodeCMap(_cmap('2 beginbfrange\n<0003> <0061> <0020>\n<0062> <0063> <00a0>\n'
            'endbfrange\n1 beginbfchar\n<0064> <00660069>\nendbfchar')),
        isNull,
      );
    });

    test('bfrange đích 5 chữ số → bfchar cặp surrogate; dòng chuẩn giữ nguyên', () {
      final out = repairToUnicodeCMap(_cmap(
        '2 beginbfrange\n<0003> <0004> <0041>\n<0f0d> <0f0f> <1df00>\nendbfrange',
      ))!;
      expect(out, contains('1 beginbfrange\n<0003> <0004> <0041>\nendbfrange'));
      expect(out, isNot(contains('<1df00>')));
      // U+1DF00 = D837 DF00; mã sau tăng code point.
      expect(out, contains('3 beginbfchar\n<0f0d> <d837df00>\n<0f0e> <d837df01>\n<0f0f> <d837df02>\nendbfchar'));
      expect(out.indexOf('beginbfchar'), lessThan(out.indexOf('endcmap')));
    });

    test('bfchar đích 5 chữ số và mảng bfrange lệch chuẩn được chuẩn hoá', () {
      final out = repairToUnicodeCMap(_cmap(
        '1 beginbfchar\n<0010> <10780>\nendbfchar\n'
        '1 beginbfrange\n<0020> <0023> [<41> <1f600>]\nendbfrange',
      ))!;
      expect(out, contains('<0010> <d801df80>'));
      // Mảng: phần tử đệm 4 chữ số / UTF-16; khoảng thu lại theo số phần tử.
      expect(out, contains('<0020> <0021> [<0041> <d83dde00>]'));
    });
  });

  group('PDF có CMap đích 5 chữ số (fixture PyMuPDF)', () {
    test('tiền đề: Syncfusion trích thẳng thì lỗi (đúng lỗi cần sửa)', () {
      final doc = sf.PdfDocument(inputBytes: fixture);
      addTearDown(doc.dispose);
      expect(
        () => sf.PdfTextExtractor(doc).extractTextLines(startPageIndex: 0, endPageIndex: 0),
        throwsA(isA<RangeError>()),
        reason: 'nếu Syncfusion đã tự sửa lỗi này thì tiền đề test không còn đúng',
      );
    });

    test('extractLayoutPages trả đúng chữ Việt mọi trang', () {
      final pages = extractLayoutPages(fixture);
      expect(pages, hasLength(2));
      for (var p = 0; p < 2; p++) {
        final text = composeVietnamese(pages[p].lines.map((l) => l.text).join('\n'));
        for (final l in expectedLines) {
          expect(text, contains('$l ${p + 1}'), reason: 'trang ${p + 1}');
        }
      }
      expect(layoutPagesToText(pages), contains('Đọc to và dàn chữ 2'));
    });

    test('extractPageTextLines: lỗi lần đầu + có CMap để sửa → sửa và thử lại', () {
      final doc = sf.PdfDocument(inputBytes: fixture);
      addTearDown(doc.dispose);
      final ex = _FailOnce(sf.PdfTextExtractor(doc), RangeError('giả lập'));
      final lines = extractPageTextLines(doc, ex, 1);
      expect(ex.calls, 2);
      expect(composeVietnamese(lines.map((l) => l.text).join('\n')), contains('Xin chào thế giới 2'));
    });
  });

  test('extractPageTextLines: không có gì để sửa → ném lại đúng lỗi gốc, không thử lại', () async {
    final src = sf.PdfDocument();
    src.pages.add().graphics.drawString('Hello', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14));
    final bytes = Uint8List.fromList(await src.save());
    src.dispose();
    final doc = sf.PdfDocument(inputBytes: bytes);
    addTearDown(doc.dispose);
    final err = StateError('lỗi khác');
    final ex = _FailOnce(sf.PdfTextExtractor(doc), err);
    expect(() => extractPageTextLines(doc, ex, 0), throwsA(same(err)));
    expect(ex.calls, 1);
  });
}
