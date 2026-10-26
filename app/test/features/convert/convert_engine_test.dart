import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as office;
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';
import 'package:pdf_office/engines/convert/convert_engine.dart';
import 'package:pdf_office/features/convert/engine/flow_writer.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/engine/pdf_builders.dart';
import 'package:pdf_office/features/convert/engine/pdf_convert_engine.dart';
import 'package:pdf_office/features/convert/engine/pdf_extract.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _fontDir = r'C:\Windows\Fonts\';
final _hasFonts = File('${_fontDir}arial.ttf').existsSync();
final _skipNoFonts = _hasFonts ? null : r'cần font ở C:\Windows\Fonts (chỉ có trên Windows)';

const _winFonts = FileFontSource({
  FontSlot.regular: '${_fontDir}arial.ttf',
  FontSlot.bold: '${_fontDir}arialbd.ttf',
  FontSlot.chinese: '${_fontDir}msyh.ttc',
  FontSlot.japanese: '${_fontDir}msyh.ttc',
  FontSlot.korean: '${_fontDir}malgun.ttf',
});

String _pdfText(String path) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return sf.PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

int _pdfPages(String path) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('convert_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String out(String name) => p.join(tmp.path, name);

  group('textToPdf (font chuẩn, không cần Noto)', () {
    const engine = PdfConvertEngine(fontSource: NoFontSource());

    test('đủ số trang khi paginate và giữ chữ', () async {
      final text = List.generate(300, (i) => 'Line number $i of the document').join('\n');
      final progress = <double>[];
      final path = await engine.textToPdf(text, out('a.pdf'), onProgress: progress.add);
      expect(File(path).existsSync(), isTrue);
      // A4, lề 40, cỡ 12 → khoảng 50-60 dòng/trang → 300 dòng cần ≥ 5 trang
      expect(_pdfPages(path), inInclusiveRange(5, 8));
      final t = _pdfText(path);
      expect(t, contains('Line number 0 of the document'));
      expect(t, contains('Line number 299 of the document'));
      expect(progress.last, 1);
    });

    test('dòng dài tự xuống dòng, khổ Letter ngang', () async {
      final text = List.filled(200, 'word').join(' ');
      final path = await engine.textToPdf(
        text,
        out('b.pdf'),
        options: const ToPdfOptions(pageSize: PageSizeOption.letter, landscape: true),
      );
      final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
      expect(doc.pages[0].size.width, closeTo(792, 0.5));
      expect(doc.pages[0].size.height, closeTo(612, 0.5));
      doc.dispose();
      expect(_pdfText(path).replaceAll(RegExp(r'\s+'), ' ').trim(), List.filled(200, 'word').join(' '));
    });

    test('huỷ trước khi chạy → Cancelled, không để file', () async {
      final token = CancelToken()..cancel();
      await expectLater(
        engine.textToPdf('x', out('c.pdf'), cancelToken: token),
        throwsA(isA<Cancelled>()),
      );
      expect(File(out('c.pdf')).existsSync(), isFalse);
    });

    test('txtFileToPdf nhận UTF-16 BOM', () async {
      final bytes = <int>[0xFF, 0xFE];
      for (final u in 'Hello UTF16'.codeUnits) {
        bytes.addAll([u & 0xFF, u >> 8]);
      }
      File(out('u16.txt')).writeAsBytesSync(bytes);
      final path = await engine.txtFileToPdf(out('u16.txt'), out('u16.pdf'));
      expect(_pdfText(path), contains('Hello UTF16'));
    });

    test('file không tồn tại → CorruptFile', () async {
      await expectLater(
        engine.txtFileToPdf(out('none.txt'), out('x.pdf')),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('không cần isolate cũng cho kết quả giống', () async {
      const direct = PdfConvertEngine(fontSource: NoFontSource(), useIsolate: false);
      final path = await direct.textToPdf('Hello direct', out('d.pdf'));
      expect(_pdfText(path), contains('Hello direct'));
    });
  });

  group('PDF → TXT / DOCX / XLSX', () {
    const engine = PdfConvertEngine(fontSource: NoFontSource());

    Future<String> sourcePdf() => engine.textToPdf(
          'Annual Report\n\nThis is the first paragraph of the report.\nSecond line here.',
          out('src.pdf'),
        );

    test('pdfToText', () async {
      final pdf = await sourcePdf();
      final txt = await engine.pdfToText(pdf, out('o.txt'));
      final s = File(txt).readAsStringSync();
      expect(s, contains('Annual Report'));
      expect(s, contains('Second line here.'));
    });

    test('pdfToDocx ra zip hợp lệ mở lại được bằng office_reader', () async {
      final pdf = await sourcePdf();
      final docx = await engine.pdfToDocx(pdf, out('o.docx'));
      final bytes = File(docx).readAsBytesSync();
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(zip.files.map((f) => f.name), contains('word/document.xml'));
      final doc = office.readDocx(bytes);
      final text = doc.blocks.whereType<office.DocxParagraph>().map((e) => e.plainText).join('\n');
      expect(text, contains('Annual Report'));
      expect(text, contains('first paragraph'));
    });

    test('pdfToXlsx: bảng thành ô', () async {
      // PDF có bảng 3x3 vẽ bằng writer.
      final fonts = PdfFontSet(const {});
      final w = PdfFlowWriter(fonts, pageWidth: 595, pageHeight: 842, margin: 40);
      w.paragraph(const [StyledSpan('Price list')], fontSize: 16, spaceAfter: 10);
      w.table(
        colWidths: const [150, 150, 150],
        rows: [
          for (var r = 0; r < 3; r++)
            [for (var c = 0; c < 3; c++) GridCell([StyledSpan('R${r}C$c')])],
        ],
        fontSize: 12,
      );
      File(out('tbl.pdf')).writeAsBytesSync(w.finish());
      final xlsx = await engine.pdfToXlsx(out('tbl.pdf'), out('o.xlsx'));
      final wb = office.readXlsx(File(xlsx).readAsBytesSync());
      expect(wb.sheets, isNotEmpty);
      final texts = wb.sheets.first.cells.values.map((c) => c.display).toSet();
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(texts, contains('R${r}C$c'));
        }
      }
    });

    test('PDF không có chữ → NoTextFound', () async {
      final doc = sf.PdfDocument()..pages.add();
      File(out('blank.pdf')).writeAsBytesSync(doc.saveSync());
      doc.dispose();
      await expectLater(
        engine.pdfToText(out('blank.pdf'), out('b.txt')),
        throwsA(predicate(isNoTextError)),
      );
    });

    test('PDF có mật khẩu: thiếu → PasswordRequired, sai → WrongPassword, đúng → chạy', () async {
      final pdf = await sourcePdf();
      final doc = sf.PdfDocument(inputBytes: File(pdf).readAsBytesSync());
      doc.security.userPassword = 'secret';
      doc.security.ownerPassword = 'secret';
      File(out('enc.pdf')).writeAsBytesSync(doc.saveSync());
      doc.dispose();
      await expectLater(engine.pdfToText(out('enc.pdf'), out('e.txt')), throwsA(isA<PasswordRequired>()));
      await expectLater(
        engine.pdfToText(out('enc.pdf'), out('e.txt'), password: 'nope'),
        throwsA(isA<WrongPassword>()),
      );
      final txt = await engine.pdfToText(out('enc.pdf'), out('e.txt'), password: 'secret');
      expect(File(txt).readAsStringSync(), contains('Annual Report'));
    });

    test('extractLayoutPages: TextLine → LayoutPage (khổ trang, toạ độ, thứ tự)', () async {
      final pdf = await sourcePdf();
      final pages = extractLayoutPages(File(pdf).readAsBytesSync());
      expect(pages, hasLength(1));
      expect(pages.single.width, closeTo(595.28, 0.5));
      expect(pages.single.height, closeTo(841.89, 0.5));
      final lines = pages.single.lines;
      expect(lines.first.text, contains('Annual Report'));
      expect(lines.first.fontSize, closeTo(12, 0.5));
      expect(lines.first.bounds.left, closeTo(40, 1));
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i].bounds.top, greaterThan(lines[i - 1].bounds.top));
      }
    });

    test('sheetGridsToXlsx: số ô, số được ghi thành số, tên sheet hợp lệ', () {
      final r = sheetGridsToXlsx([
        const SheetGrid(name: 'A/B:C', rows: [
          ['Name', 'Qty'],
          ['x', '12'],
          ['y', '007'],
        ]),
        const SheetGrid(name: 'A/B:C', rows: [
          ['only']
        ]),
      ]);
      expect(r.cellCount, 7);
      final wb = office.readXlsx(r.bytes);
      expect(wb.sheets.map((s) => s.name), ['A_B_C', 'A_B_C (2)']);
      expect(wb.sheets.first.cell(1, 1)!.type, office.XlsxCellType.number);
      expect(wb.sheets.first.cell(2, 1)!.display, '007'); // giữ số 0 đầu
    });
  });

  group('DOCX / XLSX → PDF', () {
    const engine = PdfConvertEngine(fontSource: NoFontSource());

    test('docxToPdf: heading, đoạn, danh sách, bảng, ngắt trang', () async {
      final docx = writeDocx(const [
        DocHeading(level: 1, spans: [DocSpan('Main Title')]),
        DocParagraph(spans: [DocSpan('Body paragraph text.'), DocSpan(' Bold part', bold: true)]),
        DocListItem(ordered: false, marker: '•', spans: [DocSpan('first item')]),
        DocTable(cells: [
          ['H1', 'H2'],
          ['a', 'b'],
        ]),
        DocPageBreak(),
        DocParagraph(spans: [DocSpan('On second page.')]),
      ]);
      File(out('in.docx')).writeAsBytesSync(docx);
      final path = await engine.docxToPdf(out('in.docx'), out('d.pdf'));
      expect(_pdfPages(path), 2);
      final t = _pdfText(path);
      for (final s in ['Main Title', 'Body paragraph text.', 'first item', 'H1', 'H2', 'On second page.']) {
        expect(t, contains(s));
      }
    });

    test('docxToPdf: file hỏng → CorruptFile', () async {
      File(out('bad.docx')).writeAsBytesSync([1, 2, 3, 4]);
      await expectLater(engine.docxToPdf(out('bad.docx'), out('x.pdf')), throwsA(isA<CorruptFile>()));
    });

    test('xlsxToPdf: mỗi sheet ít nhất một trang, có chữ các ô', () async {
      final xlsx = sheetGridsToXlsx([
        const SheetGrid(name: 'Sheet One', rows: [
          ['Item', 'Price'],
          ['Apple', '12'],
        ]),
        const SheetGrid(name: 'Sheet Two', rows: [
          ['Other', 'x']
        ]),
      ]).bytes;
      File(out('in.xlsx')).writeAsBytesSync(xlsx);
      final path = await engine.xlsxToPdf(out('in.xlsx'), out('x.pdf'));
      expect(_pdfPages(path), greaterThanOrEqualTo(2));
      final t = _pdfText(path);
      for (final s in ['Sheet One', 'Apple', 'Sheet Two', 'Other']) {
        expect(t, contains(s));
      }
    });

    test('xlsxToPdf: file hỏng → CorruptFile', () async {
      File(out('bad.xlsx')).writeAsBytesSync([1, 2, 3, 4]);
      await expectLater(engine.xlsxToPdf(out('bad.xlsx'), out('x.pdf')), throwsA(isA<CorruptFile>()));
    });
  });

  test('partitionColumns chia dải theo chiều rộng trang', () {
    expect(partitionColumns([100, 100, 100, 100], 250), [
      [0, 1],
      [2, 3],
    ]);
    expect(partitionColumns([300, 50], 200), [
      [0],
      [1],
    ]);
    expect(partitionColumns([], 200), isEmpty);
  });

  group('chữ Việt / CJK với font Windows', () {
    const engine = PdfConvertEngine(fontSource: _winFonts);

    test('Việt NFD được chuẩn hoá NFC khi vẽ', skip: _skipNoFonts, () async {
      final path = await engine.textToPdf(
        'Nguye\u0302\u0303n Thi\u0323 Phu\u031Bo\u031B\u0323ng\nTiê\u0301ng Việt',
        out('vi.pdf'),
      );
      final t = _pdfText(path);
      expect(t, contains('Nguyễn Thị Phượng'));
      expect(t, contains('Tiếng Việt'));
    });

    test('dòng trộn Việt + Hán + Hangul', skip: _skipNoFonts, () async {
      final path = await engine.textToPdf('Hà Nội 河内 하노이', out('mix.pdf'));
      expect(File(path).lengthSync(), lessThan(1500000)); // font được subset
      final t = _pdfText(path);
      expect(t, contains('Hà Nội'));
    });
  });
}
