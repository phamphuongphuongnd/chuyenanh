// Kiểm thử hộp trắng (Bước 6) cho lib/features/pdf_tools/engine/page_numbers.dart.
// Mã bộ = mã ở test-output/whitebox/pdf-tools/page_numbers/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 — không chỉnh cho khớp code; FAIL thật giữ nguyên.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_numbers.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF A4, nội dung không có chữ số.
Future<String> _makePdf(
  String dir,
  String name,
  int pages, {
  String? password,
  Map<int, sf.PdfPageRotateAngle> rotations = const {},
}) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.margins.all = 0;
  doc.pageSettings.size = const Size(595, 842);
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawString(
      'Body text',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(40, 300, 250, 30),
    );
  }
  var bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  if (rotations.isNotEmpty || password != null) {
    final loaded = sf.PdfDocument(inputBytes: bytes);
    rotations.forEach((i, a) => loaded.pages[i].rotation = a);
    if (password != null) {
      loaded.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
      loaded.security.userPassword = password;
      loaded.security.ownerPassword = password;
    }
    bytes = Uint8List.fromList(await loaded.save());
    loaded.dispose();
  }
  final path = p.join(dir, name);
  await File(path).writeAsBytes(bytes);
  return path;
}

String _text(String path, int page) {
  final d = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  final t = sf.PdfTextExtractor(d).extractText(startPageIndex: page, endPageIndex: page);
  d.dispose();
  return t;
}

Future<Object?> _catch(Future<Object?> f) => f.then((v) => v, onError: (Object e) => e);

void main() {
  group('P1 formatPageLabel', () {
    test('P1-1 plain ⇒ "7"', () => expect(formatPageLabel(PageNumberStyle.plain, 7, 12), '7'));
    test('P1-2 ofTotal ⇒ "7 / 12"', () => expect(formatPageLabel(PageNumberStyle.ofTotal, 7, 12), '7 / 12'));
    test('P1-3 pageWord có {n} ⇒ thay số (bỏ khoảng trắng đầu/cuối)', () {
      expect(formatPageLabel(PageNumberStyle.pageWord, 7, 12, pageWordTemplate: 'Trang {n}'), 'Trang 7');
      expect(formatPageLabel(PageNumberStyle.pageWord, 7, 12, pageWordTemplate: '  Trang {n} '), 'Trang 7');
    });
    test('P1-4 pageWord thiếu {n} ⇒ nối số vào sau', () {
      expect(formatPageLabel(PageNumberStyle.pageWord, 7, 12, pageWordTemplate: 'Trang'), 'Trang 7');
    });
    test('P1-5 pageWord rỗng ⇒ chỉ số', () {
      expect(formatPageLabel(PageNumberStyle.pageWord, 7, 12, pageWordTemplate: ''), '7');
      expect(formatPageLabel(PageNumberStyle.pageWord, 7, 12, pageWordTemplate: '   '), '7');
    });
    test('P1-6 dashed ⇒ "- 7 -"', () => expect(formatPageLabel(PageNumberStyle.dashed, 7, 12), '- 7 -'));
  });

  group('P2 selectNumberedPages', () {
    test('P2-1 mặc định ⇒ mọi trang', () => expect(selectNumberedPages(3), [0, 1, 2]));
    test('P2-2 không có trang ⇒ rỗng', () => expect(selectNumberedPages(0), isEmpty));
    test('P2-3 khoảng trang ⇒ tăng dần, không trùng', () {
      expect(selectNumberedPages(3, ranges: const [PageRange(3, 3), PageRange(1, 2)]), [0, 1, 2]);
      expect(selectNumberedPages(3, ranges: const [PageRange(1, 2), PageRange(2, 3)]), [0, 1, 2]);
    });
    test('P2-4 khoảng ngoài 1..pageCount ⇒ FormatException', () {
      expect(() => selectNumberedPages(3, ranges: const [PageRange(1, 5)]), throwsFormatException);
    });
    test('P2-8 bỏ trang 1, kể cả khi nằm trong khoảng', () {
      expect(selectNumberedPages(3, skipFirst: true), [1, 2]);
      expect(selectNumberedPages(3, ranges: const [PageRange(1, 2)], skipFirst: true), [1]);
    });
  });

  group('P3 pageRotationDegrees', () {
    test('P3-1 0°', () => expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle0), 0));
    test('P3-2 90°', () => expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle90), 90));
    test('P3-3 180°', () => expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle180), 180));
    test('P3-4 270°', () => expect(pageRotationDegrees(sf.PdfPageRotateAngle.rotateAngle270), 270));
  });

  group('P4 visualPageSize', () {
    const raw = Size(595, 842);
    test('P4-1 xoay 90 (và 450) ⇒ đổi rộng/cao', () {
      expect(visualPageSize(raw, 90), const Size(842, 595));
      expect(visualPageSize(raw, 450), const Size(842, 595));
    });
    test('P4-2 xoay 270 (và -90) ⇒ đổi rộng/cao', () {
      expect(visualPageSize(raw, 270), const Size(842, 595));
      expect(visualPageSize(raw, -90), const Size(842, 595));
    });
    test('P4-3 xoay 0 / 180 ⇒ giữ nguyên', () {
      expect(visualPageSize(raw, 0), raw);
      expect(visualPageSize(raw, 180), raw);
    });
  });

  group('P5 visualToRawPoint (raw 600×800, điểm đang xem (10,20))', () {
    const raw = Size(600, 800);
    test('P5-1 90° (theo chiều kim đồng hồ) ⇒ (20, 790)', () {
      expect(visualToRawPoint(10, 20, raw, 90), const Offset(20, 790));
    });
    test('P5-2 180° ⇒ (590, 780)', () {
      expect(visualToRawPoint(10, 20, raw, 180), const Offset(590, 780));
    });
    test('P5-3 270° (và -90) ⇒ (580, 10)', () {
      expect(visualToRawPoint(10, 20, raw, 270), const Offset(580, 10));
      expect(visualToRawPoint(10, 20, raw, -90), const Offset(580, 10));
    });
    test('P5-4 0° (và 360) ⇒ giữ nguyên', () {
      expect(visualToRawPoint(10, 20, raw, 0), const Offset(10, 20));
      expect(visualToRawPoint(10, 20, raw, 360), const Offset(10, 20));
    });
  });

  group('P6 pageNumberRect (trang 600×800, chữ 100×20, lề 24)', () {
    Rect r(PageNumberHAlign h, PageNumberVAlign v, {double textW = 100, double margin = 24}) =>
        pageNumberRect(pageW: 600, pageH: 800, textW: textW, textH: 20, vAlign: v, hAlign: h, margin: margin);
    test('P6-1 trái / trên ⇒ (24, 24)', () {
      expect(r(PageNumberHAlign.left, PageNumberVAlign.top), const Rect.fromLTWH(24, 24, 100, 20));
    });
    test('P6-2 giữa / trên ⇒ (250, 24)', () {
      expect(r(PageNumberHAlign.center, PageNumberVAlign.top), const Rect.fromLTWH(250, 24, 100, 20));
    });
    test('P6-3 phải / trên ⇒ (476, 24)', () {
      expect(r(PageNumberHAlign.right, PageNumberVAlign.top), const Rect.fromLTWH(476, 24, 100, 20));
    });
    test('P6-4 trái / dưới ⇒ (24, 756)', () {
      expect(r(PageNumberHAlign.left, PageNumberVAlign.bottom), const Rect.fromLTWH(24, 756, 100, 20));
    });
    test('P6-5 khung lớn hơn chỗ trống ⇒ kẹp trong trang, không âm', () {
      expect(r(PageNumberHAlign.right, PageNumberVAlign.top, textW: 700).left, 0);
      expect(r(PageNumberHAlign.left, PageNumberVAlign.bottom, margin: 1000).top, 0);
    });
  });

  group('P7 / P8 engine', () {
    late Directory tmp;
    const engine = SyncfusionPageNumbers(fontLoader: null);
    setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_pagenum'));
    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } on FileSystemException {
        // bỏ qua
      }
    });

    test('P8-1 / P7-1 mặc định, nhãn Latin-1 ⇒ không nạp font, mỗi trang có số', () async {
      final asked = <String>[];
      final e = SyncfusionPageNumbers(fontLoader: (t) {
        asked.add(t);
        return null;
      });
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'a_n.pdf');
      final r = await _catch(e.addPageNumbers(src, const PageNumberSpec(), out));
      expect(asked, isEmpty);
      expect(r, out);
      expect(_text(out, 0), contains('1'));
      expect(_text(out, 1), contains('2'));
      expect(_text(out, 1), contains('Body text'));
    });

    test('P8-2 cỡ chữ < 8 ⇒ ArgumentError; 8 được', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(fontSize: 7.9), out)), isA<ArgumentError>());
      expect(File(out).existsSync(), isFalse);
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(fontSize: 8), out)), out);
    });

    test('P8-3 cỡ chữ > 24 ⇒ ArgumentError; 24 được', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(fontSize: 24.1), out)), isA<ArgumentError>());
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(fontSize: 24), out)), out);
    });

    test('P8-4 số bắt đầu < 1 ⇒ RangeError', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      expect(
        await _catch(engine.addPageNumbers(src, const PageNumberSpec(startNumber: 0), p.join(tmp.path, 'o.pdf'))),
        isA<RangeError>(),
      );
    });

    test('P8-5 số bắt đầu > 99999 ⇒ RangeError; 99999 được', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(startNumber: 100000), out)), isA<RangeError>());
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(startNumber: 99999), out)), out);
      expect(_text(out, 0), contains('99999'));
    });

    test('P8-6 lề âm ⇒ ArgumentError; lề 0 được', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(margin: -1), out));
      expect(r, isA<ArgumentError>());
      expect(r, isNot(isA<RangeError>()));
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(margin: 0), out)), out);
    });

    test('P8-7 output trùng input (kể cả khác cách viết) ⇒ ArgumentError, gốc không đổi', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final before = File(src).readAsBytesSync();
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(), src)), isA<ArgumentError>());
      expect(
        await _catch(engine.addPageNumbers(src, const PageNumberSpec(), p.join(tmp.path, '.', 'a.pdf'))),
        isA<ArgumentError>(),
      );
      expect(File(src).readAsBytesSync(), before);
    });

    test('P8-8 token chưa huỷ ⇒ chạy bình thường', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      expect(await _catch(engine.addPageNumbers(src, const PageNumberSpec(), out, cancelToken: CancelToken())), out);
    });

    test('P8-9 token đã huỷ ⇒ Cancelled, không tạo file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(), out, cancelToken: CancelToken()..cancel()));
      expect(r, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('P8-10 nhãn ngoài Latin-1, không có fontLoader ⇒ vẫn ra file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(
        src,
        const PageNumberSpec(style: PageNumberStyle.pageWord, pageWordTemplate: '第 {n} 页'),
        out,
      ));
      expect(r, out);
      expect(File(out).existsSync(), isTrue);
    });

    test('P8-11 nhãn ngoài Latin-1, có fontLoader ⇒ nạp font đúng 1 lần với nhãn mẫu', () async {
      final asked = <String>[];
      final e = SyncfusionPageNumbers(fontLoader: (t) {
        asked.add(t);
        return null;
      });
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(e.addPageNumbers(
        src,
        const PageNumberSpec(style: PageNumberStyle.pageWord, pageWordTemplate: '第 {n} 页'),
        out,
      ));
      expect(asked, ['第 1 页']);
      expect(r, out);
    });

    test('P8-12 / P7-2 sai mật khẩu ⇒ WrongPassword, không tạo file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(), out, password: 'nope'));
      expect(r, isA<WrongPassword>());
      expect(File(out).existsSync(), isFalse);
    });

    test('P7-3 khoảng trang vượt số trang ⇒ FormatException, không tạo file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(ranges: [PageRange(1, 5)]), out));
      expect(r, isA<FormatException>());
      expect(File(out).existsSync(), isFalse);
    });

    test('P7-4 bỏ bìa trên PDF 1 trang ⇒ ArgumentError, không tạo file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(skipFirstPage: true), out));
      expect(r, isA<ArgumentError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('P7-6 trang xoay 90° ⇒ có số, giữ góc xoay', () async {
      final src = await _makePdf(tmp.path, 'r.pdf', 2, rotations: {1: sf.PdfPageRotateAngle.rotateAngle90});
      final out = p.join(tmp.path, 'o.pdf');
      final r = await _catch(engine.addPageNumbers(src, const PageNumberSpec(style: PageNumberStyle.dashed), out));
      expect(r, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      d.dispose();
      expect(_text(out, 1), matches(RegExp(r'-\s*2\s*-')));
    });
  });
}
