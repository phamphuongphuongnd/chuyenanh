// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/pdf_convert_engine.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/pdf_convert_engine/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as office;
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/convert/convert_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/engine/pdf_convert_engine.dart';
import 'package:pdf_office/features/convert/engine/pdf_extract.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _direct = PdfConvertEngine(fontSource: NoFontSource(), useIsolate: false);
const _iso = PdfConvertEngine(fontSource: NoFontSource());

String _pdfText(String path) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return sf.PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

Future<Object?> _capture<T>(Future<T> f) => f.then<Object?>((v) => v, onError: (Object e) => e);

LayoutPage _page(String text) => LayoutPage(index: 0, width: 595, height: 842, lines: [
      LayoutLine(
          pageIndex: 0,
          text: text,
          bounds: const LayoutRect(left: 40, top: 40, width: 200, height: 12),
          fontSize: 12),
    ]);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_pce_'));
  tearDown(() => tmp.deleteSync(recursive: true));
  String path(String n) => p.join(tmp.path, n);

  String textPdf(String name, String text) {
    final doc = sf.PdfDocument();
    doc.pages.add().graphics.drawString(text, sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(40, 40, 400, 20));
    File(path(name)).writeAsBytesSync(doc.saveSync());
    doc.dispose();
    return path(name);
  }

  String blankPdf() {
    final doc = sf.PdfDocument()..pages.add();
    File(path('blank.pdf')).writeAsBytesSync(doc.saveSync());
    doc.dispose();
    return path('blank.pdf');
  }

  String garbage(String name) {
    File(path(name)).writeAsBytesSync([1, 2, 3, 4]);
    return path(name);
  }

  String docx() {
    File(path('in.docx')).writeAsBytesSync(writeDocx(const [
      DocParagraph(spans: [DocSpan('Docx body')]),
    ]));
    return path('in.docx');
  }

  String xlsx() {
    File(path('in.xlsx')).writeAsBytesSync(sheetGridsToXlsx(const [
      SheetGrid(name: 'Sheet A', rows: [
        ['Cell X']
      ])
    ]).bytes);
    return path('in.xlsx');
  }

  group('U1 isNoTextError', () {
    test('U1-P1 Unknown(NoTextFoundException) ⇒ true', () {
      expect(isNoTextError(const Unknown(NoTextFoundException())), isTrue);
    });
    test('U1-P2 không phải Unknown ⇒ false', () {
      expect(isNoTextError(const CorruptFile()), isFalse);
    });
    test('U1-P3 Unknown nguyên nhân khác ⇒ false', () {
      expect(isNoTextError(const Unknown('x')), isFalse);
    });
  });

  group('U2 _run / U3 closure tiến độ (qua API công khai)', () {
    test('U2-P1 / U3-P2 không isolate, không token ⇒ kết quả, tiến độ tới 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.textToPdf('Hello', path('a.pdf'), onProgress: progress.add));
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      expect(r, path('a.pdf'));
      expect(_pdfText(path('a.pdf')), contains('Hello'));
    });

    test('U2-P2 chạy trong isolate ⇒ cùng kết quả', () async {
      final r = await _capture(_iso.textToPdf('Hello iso', path('b.pdf')));
      expect(r, path('b.pdf'));
      expect(_pdfText(path('b.pdf')), contains('Hello iso'));
    });

    test('U2-P3 token chưa huỷ ⇒ kết quả', () async {
      final r = await _capture(_direct.docxToPdf(docx(), path('c.pdf'), cancelToken: CancelToken()));
      expect(r, path('c.pdf'));
    });

    test('U2-P4 docxToPdf với token đã huỷ ⇒ Cancelled ngay ở bước đọc, không ra file', () async {
      final progress = <double>[];
      final r = await _capture(
          _direct.docxToPdf(docx(), path('d.pdf'), cancelToken: CancelToken()..cancel(), onProgress: progress.add));
      expect(progress, isEmpty); // chưa tới onProgress(0.15)
      expect(r, isA<Cancelled>());
      expect(File(path('d.pdf')).existsSync(), isFalse);
    });

    test('U2-P5 job ném AppError (DOCX hỏng) ⇒ CorruptFile nguyên loại', () async {
      final r = await _capture(_direct.docxToPdf(garbage('bad.docx'), path('e.pdf')));
      expect(r, isA<CorruptFile>());
    });

    test('U2-P6 job ném lỗi thường (onProgress ném StateError) ⇒ AppError (Unknown)', () async {
      final r = await _capture(_direct.textToPdf('x', path('f.pdf'), onProgress: (_) => throw StateError('ui')));
      expect(r, isA<Unknown>());
      expect(File(path('f.pdf')).existsSync(), isFalse);
    });

    test('U3-P1 không onProgress ⇒ vẫn ra file', () async {
      final r = await _capture(_direct.textToPdf('NoProgress', path('g.pdf')));
      expect(r, path('g.pdf'));
    });
  });

  group('U4 _readInput / U6 txtFileToPdf', () {
    test('U4-P1 / U6-P2 file không có ⇒ CorruptFile', () async {
      final r = await _capture(_direct.txtFileToPdf(path('none.txt'), path('x.pdf')));
      expect(r, isA<CorruptFile>());
      expect(File(path('x.pdf')).existsSync(), isFalse);
    });

    test('U4-P2 / U6-P1 file có ⇒ đọc và ra PDF chứa chữ', () async {
      File(path('in.txt')).writeAsStringSync('Txt content');
      final r = await _capture(_direct.txtFileToPdf(path('in.txt'), path('t.pdf')));
      expect(r, path('t.pdf'));
      expect(_pdfText(path('t.pdf')), contains('Txt content'));
    });

    test('U6-P3 textToPdf ném (token đã huỷ) ⇒ Cancelled', () async {
      File(path('in.txt')).writeAsStringSync('x');
      final r = await _capture(_direct.txtFileToPdf(path('in.txt'), path('t2.pdf'), cancelToken: CancelToken()..cancel()));
      expect(r, isA<Cancelled>());
      expect(File(path('t2.pdf')).existsSync(), isFalse);
    });
  });

  group('U5 textToPdf', () {
    test('U5-P1 không token, có onProgress ⇒ file, tiến độ kết thúc 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.textToPdf('Line', path('p1.pdf'), onProgress: progress.add));
      expect(progress.last, 1);
      expect(r, path('p1.pdf'));
    });

    test('U5-P2 token chưa huỷ ⇒ file', () async {
      final r = await _capture(_direct.textToPdf('Line', path('p2.pdf'), cancelToken: CancelToken()));
      expect(r, path('p2.pdf'));
    });

    test('U5-P3 token đã huỷ ⇒ Cancelled, không chạy dựng PDF, không file', () async {
      final progress = <double>[];
      final r = await _capture(
          _direct.textToPdf('Line', path('p3.pdf'), cancelToken: CancelToken()..cancel(), onProgress: progress.add));
      expect(progress, isEmpty);
      expect(r, isA<Cancelled>());
      expect(File(path('p3.pdf')).existsSync(), isFalse);
    });

    test('U5-P4 huỷ khi đang dựng trong isolate ⇒ Cancelled, không file', () async {
      final token = CancelToken();
      final text = List.generate(40000, (i) => 'Line number $i of a long document').join('\n');
      final r = await _capture(_iso
          .textToPdf(text, path('p4.pdf'), cancelToken: token, onProgress: (_) => token.cancel())
          .timeout(const Duration(seconds: 60)));
      expect(token.isCancelled, isTrue);
      expect(r, isA<Cancelled>());
      expect(File(path('p4.pdf')).existsSync(), isFalse);
    });

    test('U5-P5 không onProgress ⇒ file', () async {
      final r = await _capture(_direct.textToPdf('Line', path('p5.pdf')));
      expect(r, path('p5.pdf'));
    });
  });

  group('U7 docxToPdf / U8 closure đọc DOCX', () {
    test('U7-P1 / U8-P1 DOCX hợp lệ, có onProgress ⇒ PDF chứa chữ, tiến độ có 0.15', () async {
      final progress = <double>[];
      final r = await _capture(_direct.docxToPdf(docx(), path('d1.pdf'), onProgress: progress.add));
      expect(progress, contains(closeTo(0.15, 1e-9)));
      expect(r, path('d1.pdf'));
      expect(_pdfText(path('d1.pdf')), contains('Docx body'));
    });

    test('U7-P2 file không có ⇒ CorruptFile', () async {
      final r = await _capture(_direct.docxToPdf(path('none.docx'), path('d2.pdf')));
      expect(r, isA<CorruptFile>());
    });

    test('U7-P3 / U8-P2 DOCX hỏng ⇒ CorruptFile, không báo 0.15', () async {
      final progress = <double>[];
      final r = await _capture(_direct.docxToPdf(garbage('b.docx'), path('d3.pdf'), onProgress: progress.add));
      expect(progress, isEmpty);
      expect(r, isA<CorruptFile>());
    });

    test('U7-P4 không onProgress ⇒ file', () async {
      final r = await _capture(_direct.docxToPdf(docx(), path('d4.pdf')));
      expect(r, path('d4.pdf'));
    });

    test('U7-P5 huỷ sau bước đọc (lúc báo 0.15) ⇒ Cancelled, không file', () async {
      final token = CancelToken();
      final r = await _capture(_direct.docxToPdf(docx(), path('d5.pdf'), cancelToken: token, onProgress: (v) {
        if ((v - 0.15).abs() < 1e-9) token.cancel();
      }));
      expect(r, isA<Cancelled>());
      expect(File(path('d5.pdf')).existsSync(), isFalse);
    });
  });

  group('U9 xlsxToPdf / U10 closure đọc XLSX', () {
    test('U9-P1 / U10-P1 XLSX hợp lệ, có onProgress ⇒ PDF chứa tên sheet + ô, có 0.15', () async {
      final progress = <double>[];
      final r = await _capture(_direct.xlsxToPdf(xlsx(), path('x1.pdf'), onProgress: progress.add));
      expect(progress, contains(closeTo(0.15, 1e-9)));
      expect(r, path('x1.pdf'));
      final t = _pdfText(path('x1.pdf'));
      expect(t, contains('Sheet A'));
      expect(t, contains('Cell X'));
    });

    test('U9-P2 file không có ⇒ CorruptFile', () async {
      expect(await _capture(_direct.xlsxToPdf(path('none.xlsx'), path('x2.pdf'))), isA<CorruptFile>());
    });

    test('U9-P3 / U10-P2 XLSX hỏng ⇒ CorruptFile', () async {
      expect(await _capture(_direct.xlsxToPdf(garbage('b.xlsx'), path('x3.pdf'))), isA<CorruptFile>());
    });

    test('U9-P4 không onProgress ⇒ file', () async {
      expect(await _capture(_direct.xlsxToPdf(xlsx(), path('x4.pdf'))), path('x4.pdf'));
    });

    test('U9-P5 huỷ sau bước đọc ⇒ Cancelled, không file', () async {
      final token = CancelToken();
      final r = await _capture(_direct.xlsxToPdf(xlsx(), path('x5.pdf'), cancelToken: token, onProgress: (v) {
        if ((v - 0.15).abs() < 1e-9) token.cancel();
      }));
      expect(r, isA<Cancelled>());
      expect(File(path('x5.pdf')).existsSync(), isFalse);
    });
  });

  group('U11 extractPages', () {
    test('U11-P1 PDF có chữ ⇒ trang có dòng, tiến độ ≤ 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.extractPages(textPdf('s.pdf', 'Extract me'), onProgress: progress.add));
      expect(progress.last, lessThanOrEqualTo(1 + 1e-9));
      expect((r as List<LayoutPage>).single.lines.single.text, contains('Extract me'));
    });

    test('U11-P2 file không có ⇒ CorruptFile', () async {
      expect(await _capture(_direct.extractPages(path('none.pdf'))), isA<CorruptFile>());
    });

    test('U11-P3 byte hỏng ⇒ CorruptFile', () async {
      expect(await _capture(_direct.extractPages(garbage('g.pdf'))), isA<CorruptFile>());
    });
  });

  group('U12 writePages / U13 closure target', () {
    test('U12-P1 / U13-P1 có chữ, target text, onProgress ⇒ TXT UTF-8, tiến độ 1', () async {
      final progress = <double>[];
      final r = await _capture(
          _direct.writePages(PdfTextTarget.text, [_page('Xin chào')], path('w.txt'), onProgress: progress.add));
      expect(progress.last, 1);
      expect(r, path('w.txt'));
      expect(File(path('w.txt')).readAsStringSync(), 'Xin chào');
    });

    test('U12-P2 không có dòng chữ ⇒ NoTextFound (isNoTextError), không file', () async {
      final r = await _capture(_direct.writePages(
          PdfTextTarget.docx, const [LayoutPage(index: 0, width: 1, height: 1, lines: [])], path('w.docx')));
      expect(r, predicate(isNoTextError));
      expect(File(path('w.docx')).existsSync(), isFalse);
    });

    test('U12-P3 token đã huỷ ⇒ Cancelled', () async {
      final r = await _capture(_direct.writePages(PdfTextTarget.text, [_page('x')], path('w3.txt'),
          cancelToken: CancelToken()..cancel()));
      expect(r, isA<Cancelled>());
    });

    test('U12-P4 / U13-P2 target docx, không onProgress ⇒ DOCX đọc lại có chữ', () async {
      final r = await _capture(_direct.writePages(PdfTextTarget.docx, [_page('Docx out')], path('w.docx')));
      expect(r, path('w.docx'));
      final doc = office.readDocx(File(path('w.docx')).readAsBytesSync());
      expect(doc.blocks.whereType<office.DocxParagraph>().map((e) => e.plainText).join(), contains('Docx out'));
    });

    test('U13-P3 target xlsx ⇒ XLSX đọc lại có ô', () async {
      final r = await _capture(_direct.writePages(PdfTextTarget.xlsx, [_page('Xlsx out')], path('w.xlsx')));
      expect(r, path('w.xlsx'));
      final wb = office.readXlsx(File(path('w.xlsx')).readAsBytesSync());
      expect(wb.sheets.first.cells.values.map((c) => c.display), contains('Xlsx out'));
    });
  });

  group('U14 pdfToText', () {
    test('U14-P1 PDF có chữ, có onProgress ⇒ TXT, tiến độ 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.pdfToText(textPdf('t.pdf', 'Plain text'), path('o.txt'), onProgress: progress.add));
      expect(progress.last, 1);
      expect(r, path('o.txt'));
      expect(File(path('o.txt')).readAsStringSync(), contains('Plain text'));
    });
    test('U14-P2 file không có ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToText(path('none.pdf'), path('o.txt'))), isA<CorruptFile>());
    });
    test('U14-P3 byte hỏng ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToText(garbage('g.pdf'), path('o.txt'))), isA<CorruptFile>());
    });
    test('U14-P4 PDF không có chữ ⇒ NoTextFound, không file', () async {
      final r = await _capture(_direct.pdfToText(blankPdf(), path('o4.txt')));
      expect(r, predicate(isNoTextError));
      expect(File(path('o4.txt')).existsSync(), isFalse);
    });
    test('U14-P5 không onProgress ⇒ TXT', () async {
      expect(await _capture(_direct.pdfToText(textPdf('t.pdf', 'Plain'), path('o5.txt'))), path('o5.txt'));
    });
  });

  group('U15 pdfToDocx / U16 closure', () {
    test('U15-P1 / U16-P1 PDF có chữ, onProgress ⇒ DOCX có chữ, tiến độ 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.pdfToDocx(textPdf('t.pdf', 'Word text'), path('o.docx'), onProgress: progress.add));
      expect(progress.last, 1);
      expect(r, path('o.docx'));
      final doc = office.readDocx(File(path('o.docx')).readAsBytesSync());
      expect(doc.blocks.whereType<office.DocxParagraph>().map((e) => e.plainText).join(), contains('Word text'));
    });
    test('U15-P2 file không có ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToDocx(path('none.pdf'), path('o.docx'))), isA<CorruptFile>());
    });
    test('U15-P3 byte hỏng ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToDocx(garbage('g.pdf'), path('o.docx'))), isA<CorruptFile>());
    });
    test('U15-P4 / U16-P2 PDF không chữ ⇒ NoTextFound, không file', () async {
      final r = await _capture(_direct.pdfToDocx(blankPdf(), path('o4.docx')));
      expect(r, predicate(isNoTextError));
      expect(File(path('o4.docx')).existsSync(), isFalse);
    });
    test('U15-P5 không onProgress ⇒ DOCX', () async {
      expect(await _capture(_direct.pdfToDocx(textPdf('t.pdf', 'W'), path('o5.docx'))), path('o5.docx'));
    });
  });

  group('U17 pdfToXlsx / U18 closure', () {
    test('U17-P1 / U18-P1 PDF có chữ, onProgress ⇒ XLSX có ô, tiến độ 1', () async {
      final progress = <double>[];
      final r = await _capture(_direct.pdfToXlsx(textPdf('t.pdf', 'Excel text'), path('o.xlsx'), onProgress: progress.add));
      expect(progress.last, 1);
      expect(r, path('o.xlsx'));
      final wb = office.readXlsx(File(path('o.xlsx')).readAsBytesSync());
      expect(wb.sheets.first.cells.values.map((c) => c.display).join(), contains('Excel text'));
    });
    test('U17-P2 file không có ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToXlsx(path('none.pdf'), path('o.xlsx'))), isA<CorruptFile>());
    });
    test('U17-P3 byte hỏng ⇒ CorruptFile', () async {
      expect(await _capture(_direct.pdfToXlsx(garbage('g.pdf'), path('o.xlsx'))), isA<CorruptFile>());
    });
    test('U17-P4 / U18-P2 PDF không chữ ⇒ NoTextFound, không file', () async {
      final r = await _capture(_direct.pdfToXlsx(blankPdf(), path('o4.xlsx')));
      expect(r, predicate(isNoTextError));
      expect(File(path('o4.xlsx')).existsSync(), isFalse);
    });
    test('U17-P5 không onProgress ⇒ XLSX', () async {
      expect(await _capture(_direct.pdfToXlsx(textPdf('t.pdf', 'E'), path('o5.xlsx'))), path('o5.xlsx'));
    });
  });
}
