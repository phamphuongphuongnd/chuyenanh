// Kiểm thử hộp trắng (Bước 6) cho lib/features/pdf_tools/engine/insert_pages.dart.
// Mã bộ = mã ở test-output/whitebox/pdf-tools/insert_pages/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 — không chỉnh cho khớp code; FAIL thật giữ nguyên.
import 'dart:convert' show latin1;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/insert_pages.dart';
import 'package:pdf_office/features/pdf_tools/engine/isolate_job.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF mẫu: trang i có chữ `<tag> page <i+1>`, khổ [size]; [rotations] đặt sau khi nạp.
Future<String> _makePdf(
  String dir,
  String name,
  int pages, {
  String tag = 'Doc',
  Size size = const Size(595, 842),
  String? password,
  Map<int, sf.PdfPageRotateAngle> rotations = const {},
}) async {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.orientation = size.width > size.height
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    section.pages.add().graphics.drawString(
      '$tag page ${i + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(20, 20, 250, 30),
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

/// PDF hợp lệ về cú pháp nhưng cây trang rỗng (/Count 0).
Uint8List _zeroPagePdf() {
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [] /Count 0 >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offs = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offs.add(b.length);
    b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offs) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(b.toString()));
}

sf.PdfDocument _open(String path) => sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

List<String> _labels(sf.PdfDocument d) => [
  for (var i = 0; i < d.pages.count; i++)
    RegExp(r'\w+ page \d+')
            .firstMatch(sf.PdfTextExtractor(d).extractText(startPageIndex: i, endPageIndex: i))
            ?.group(0) ??
        '-',
];

Uint8List _png(int w, int h) => Uint8List.fromList(
  img.encodePng(img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 30, 30))),
);

Future<Object?> _catch(Future<Object?> f) => f.then((v) => v, onError: (Object e) => e);

void main() {
  group('I1 resolveInsertAfter', () {
    test('I1-1 đầu tài liệu ⇒ 0', () => expect(resolveInsertAfter(InsertWhere.start, 1, 3), 0));
    test('I1-2 pageCount < 1 ⇒ ArgumentError', () {
      expect(() => resolveInsertAfter(InsertWhere.start, 1, 0), throwsArgumentError);
    });
    test('I1-3 cuối tài liệu ⇒ pageCount', () => expect(resolveInsertAfter(InsertWhere.end, 1, 3), 3));
    test('I1-4 sau trang N trong 1..pageCount ⇒ N', () {
      expect(resolveInsertAfter(InsertWhere.afterPage, 1, 3), 1);
      expect(resolveInsertAfter(InsertWhere.afterPage, 2, 3), 2);
      expect(resolveInsertAfter(InsertWhere.afterPage, 3, 3), 3);
    });
    test('I1-5 sau trang ngoài 1..pageCount ⇒ RangeError', () {
      expect(() => resolveInsertAfter(InsertWhere.afterPage, 0, 3), throwsRangeError);
      expect(() => resolveInsertAfter(InsertWhere.afterPage, 4, 3), throwsRangeError);
    });
  });

  group('I2 neighborPageIndex', () {
    test('I2-1 chèn đầu ⇒ trang đầu (0)', () => expect(neighborPageIndex(0), 0));
    test('I2-2 chèn sau trang 3 ⇒ trang ngay trước (2)', () => expect(neighborPageIndex(3), 2));
  });

  group('I3/I4 == của ResultPage', () {
    test('I3-1 OriginalPage so với InsertedPage ⇒ khác', () {
      expect(const OriginalPage(1) == const InsertedPage(1), isFalse);
    });
    test('I3-2 OriginalPage khác index ⇒ khác', () {
      expect(const OriginalPage(1) == const OriginalPage(2), isFalse);
    });
    test('I3-3 OriginalPage cùng index ⇒ bằng', () {
      // ignore: prefer_const_constructors
      expect(OriginalPage(1) == OriginalPage(1), isTrue);
    });
    test('I4-1 InsertedPage so với OriginalPage ⇒ khác', () {
      expect(const InsertedPage(1) == const OriginalPage(1), isFalse);
    });
    test('I4-2 InsertedPage khác index ⇒ khác', () {
      expect(const InsertedPage(1) == const InsertedPage(2), isFalse);
    });
    test('I4-3 InsertedPage cùng index ⇒ bằng', () {
      // ignore: prefer_const_constructors
      expect(InsertedPage(1) == InsertedPage(1), isTrue);
    });
  });

  group('I5 planInsertion', () {
    test('I5-1 hợp lệ ⇒ trang gốc trước, khối chèn, phần còn lại', () {
      expect(planInsertion(sourcePageCount: 3, insertAfter: 1, insertedCount: 2), const [
        OriginalPage(0), InsertedPage(0), InsertedPage(1), OriginalPage(1), OriginalPage(2),
      ]);
      expect(planInsertion(sourcePageCount: 3, insertAfter: 0, insertedCount: 1), const [
        InsertedPage(0), OriginalPage(0), OriginalPage(1), OriginalPage(2),
      ]);
      expect(planInsertion(sourcePageCount: 3, insertAfter: 3, insertedCount: 1), const [
        OriginalPage(0), OriginalPage(1), OriginalPage(2), InsertedPage(0),
      ]);
    });
    test('I5-2 sourcePageCount < 1 ⇒ ArgumentError', () {
      expect(() => planInsertion(sourcePageCount: 0, insertAfter: 0, insertedCount: 1), throwsArgumentError);
    });
    test('I5-3 insertedCount < 1 ⇒ ArgumentError', () {
      expect(() => planInsertion(sourcePageCount: 3, insertAfter: 0, insertedCount: 0), throwsArgumentError);
    });
    test('I5-4 insertAfter ngoài 0..n ⇒ RangeError', () {
      expect(() => planInsertion(sourcePageCount: 3, insertAfter: 4, insertedCount: 1), throwsRangeError);
      expect(() => planInsertion(sourcePageCount: 3, insertAfter: -1, insertedCount: 1), throwsRangeError);
    });
  });

  group('I6 pagesFromRanges', () {
    test('I6-1 pageCount < 1 ⇒ CorruptFile', () {
      expect(() => pagesFromRanges(null, 0), throwsA(isA<CorruptFile>()));
    });
    test('I6-2 ranges null ⇒ tất cả trang', () => expect(pagesFromRanges(null, 3), [0, 1, 2]));
    test('I6-3 khoảng ngoài 1..pageCount ⇒ FormatException; list rỗng ⇒ ArgumentError', () {
      expect(() => pagesFromRanges(const [PageRange(1, 5)], 3), throwsFormatException);
      expect(() => pagesFromRanges(const [], 3), throwsArgumentError);
    });
    test('I6-4 theo khoảng, giữ thứ tự gõ (0-based)', () {
      expect(pagesFromRanges(const [PageRange(3, 3), PageRange(1, 2)], 3), [2, 0, 1]);
    });
  });

  group('I7 a4PageForImage', () {
    test('I7-1 ảnh ngang ⇒ A4 ngang', () {
      final s = a4PageForImage(40, 20);
      expect(s.width, closeTo(841.89, 0.01));
      expect(s.height, closeTo(595.28, 0.01));
    });
    test('I7-2 ảnh dọc / vuông ⇒ A4 dọc', () {
      expect(a4PageForImage(20, 40).width, closeTo(595.28, 0.01));
      expect(a4PageForImage(30, 30).width, closeTo(595.28, 0.01));
    });
  });

  group('I8 insertedPageCount', () {
    test('I8-1 trang trắng ⇒ count', () => expect(insertedPageCount(const InsertBlank(3)), 3));
    test('I8-2 ảnh ⇒ số ảnh', () {
      expect(insertedPageCount(InsertImages([_png(2, 2), _png(2, 2)])), 2);
    });
    test('I8-3 PDF khác ⇒ số trang theo khoảng (null = tất cả)', () {
      expect(insertedPageCount(const InsertPdfPages('x.pdf'), otherPageCount: 4), 4);
      expect(
        insertedPageCount(const InsertPdfPages('x.pdf', ranges: [PageRange(2, 3)]), otherPageCount: 4),
        2,
      );
    });
    test('I8-4 khoảng sai ⇒ FormatException', () {
      expect(
        () => insertedPageCount(const InsertPdfPages('x.pdf', ranges: [PageRange(1, 9)]), otherPageCount: 4),
        throwsFormatException,
      );
    });
  });

  group('engine / job', () {
    late Directory tmp;
    const engine = SyncfusionInsertPages();
    setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_insert'));
    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } on FileSystemException {
        // Windows: isolate vừa kill có thể chưa nhả file.
      }
    });

    // ---- I9 insertPages ----
    test('I9-1 / I15-1 chèn 2 trang trắng sau trang 1 của 3 trang ⇒ 5 trang đúng thứ tự, gốc không đổi', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 3);
      final before = File(src).readAsBytesSync();
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 1, const InsertBlank(2), out));
      expect(r, out);
      final d = _open(out);
      expect(_labels(d), ['Doc page 1', '-', '-', 'Doc page 2', 'Doc page 3']);
      d.dispose();
      expect(File(src).readAsBytesSync(), before);
    });

    test('I9-2 nội dung sai (0 trang trắng) ⇒ RangeError, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 1, const InsertBlank(0), out));
      expect(r, isA<RangeError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I9-3 output trùng input (khác cách viết) ⇒ ArgumentError, gốc không đổi', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final before = File(src).readAsBytesSync();
      final alias = p.join(tmp.path, '.', 'doc.pdf');
      final r = await _catch(engine.insertPages(src, 1, const InsertBlank(1), alias));
      expect(r, isA<ArgumentError>());
      expect(r, isNot(isA<RangeError>()));
      expect(File(src).readAsBytesSync(), before);
    });

    test('I9-3b output trùng PDF nguồn trang ⇒ ArgumentError, file nguồn trang không đổi', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final other = await _makePdf(tmp.path, 'b.pdf', 1, tag: 'B');
      final before = File(other).readAsBytesSync();
      final r = await _catch(engine.insertPages(src, 1, InsertPdfPages(other), other));
      expect(r, isA<ArgumentError>());
      expect(File(other).readAsBytesSync(), before);
    });

    test('I9-5 / I15-3 sai mật khẩu file gốc ⇒ WrongPassword, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 1, const InsertBlank(1), out, password: 'nope'));
      expect(r, isA<WrongPassword>());
      expect(File(out).existsSync(), isFalse);
    });

    // ---- I10 _validateContent (qua insertPages; output = input để dừng ngay sau bước kiểm) ----
    Future<Object?> validate(String src, InsertContent c) => _catch(engine.insertPages(src, 1, c, src));
    Matcher passed() => isA<ArgumentError>()
        .having((e) => e is RangeError, 'là RangeError', isFalse)
        .having((e) => '${e.message}', 'message', contains('output must differ'));

    test('I10-1 trang trắng 1 và 50 ⇒ hợp lệ', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(await validate(src, const InsertBlank(1)), passed());
      expect(await validate(src, const InsertBlank(50)), passed());
    });
    test('I10-2 trang trắng 0 / 51 ⇒ RangeError', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(await validate(src, const InsertBlank(0)), isA<RangeError>());
      expect(await validate(src, const InsertBlank(51)), isA<RangeError>());
    });
    test('I10-3 ảnh không rỗng ⇒ hợp lệ', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(await validate(src, InsertImages([_png(4, 4)])), passed());
    });
    test('I10-4 danh sách ảnh rỗng ⇒ ArgumentError(images)', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(
        await validate(src, const InsertImages([])),
        isA<ArgumentError>().having((e) => '${e.message}', 'message', contains('images')),
      );
    });
    test('I10-5 PDF khác, ranges null ⇒ hợp lệ', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(await validate(src, const InsertPdfPages('b.pdf')), passed());
    });
    test('I10-6 PDF khác, ranges có phần tử ⇒ hợp lệ', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(await validate(src, const InsertPdfPages('b.pdf', ranges: [PageRange(2, 3)])), passed());
    });
    test('I10-7 PDF khác, ranges rỗng ⇒ ArgumentError(ranges)', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      expect(
        await validate(src, const InsertPdfPages('b.pdf', ranges: [])),
        isA<ArgumentError>().having((e) => '${e.message}', 'message', contains('ranges')),
      );
    });

    // ---- I11 / I12 / I13 / I14 ----
    test('I11-2 / I15-7 ảnh hỏng (ảnh thứ 2) ⇒ CorruptFile, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(
        src, 1, InsertImages([_png(4, 4), Uint8List.fromList([1, 2, 3])]), out,
      ));
      expect(r, isA<CorruptFile>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I12-1 trang kề bên xoay 90° ⇒ trang trắng lấy khổ đang hiển thị (ngang)', () async {
      final src = await _makePdf(tmp.path, 'r.pdf', 1, rotations: {0: sf.PdfPageRotateAngle.rotateAngle90});
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 1, const InsertBlank(1), out)), out);
      final d = _open(out);
      expect(d.pages.count, 2);
      expect(d.pages[1].size.width, closeTo(842, 1));
      expect(d.pages[1].size.height, closeTo(595, 1));
      d.dispose();
    });

    test('I12-2 trang kề bên xoay 270° ⇒ trang trắng ngang', () async {
      final src = await _makePdf(tmp.path, 'r.pdf', 1, rotations: {0: sf.PdfPageRotateAngle.rotateAngle270});
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 1, const InsertBlank(1), out)), out);
      final d = _open(out);
      expect(d.pages[1].size.width, closeTo(842, 1));
      d.dispose();
    });

    test('I12-3 / I13-2 trang kề bên không xoay (dọc) ⇒ trang trắng dọc cùng khổ', () async {
      final src = await _makePdf(tmp.path, 'r.pdf', 1);
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 0, const InsertBlank(1), out)), out);
      final d = _open(out);
      expect(d.pages[0].size.width, closeTo(595, 1));
      expect(d.pages[0].size.height, closeTo(842, 1));
      d.dispose();
    });

    test('I13-1 trang kề bên ngang (không xoay) ⇒ trang trắng ngang', () async {
      final src = await _makePdf(tmp.path, 'l.pdf', 1, size: const Size(842, 595));
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 1, const InsertBlank(1), out)), out);
      final d = _open(out);
      expect(d.pages[1].size.width, closeTo(842, 1));
      d.dispose();
    });

    test('I14-1 / I15-6 ảnh ngang, khổ A4 ⇒ trang A4 ngang chen giữa', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 2, size: const Size(400, 600));
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 1, InsertImages([_png(40, 20)]), out)), out);
      final d = _open(out);
      expect(_labels(d), ['Doc page 1', '-', 'Doc page 2']);
      expect(d.pages[1].size.width, closeTo(841.89, 1));
      d.dispose();
    });

    test('I14-2 ảnh, khổ kề bên ⇒ trang cùng khổ trang kề bên', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 2, size: const Size(400, 600));
      final out = p.join(tmp.path, 'out.pdf');
      expect(
        await _catch(engine.insertPages(src, 2, InsertImages([_png(40, 20)], fit: InsertImageFit.neighbor), out)),
        out,
      );
      final d = _open(out);
      expect(d.pages[2].size.width, closeTo(400, 1));
      expect(d.pages[2].size.height, closeTo(600, 1));
      d.dispose();
    });

    // ---- I15 insertPagesJob ----
    test('I15-2 gọi job trực tiếp với nội dung sai ⇒ RangeError', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(runIsolateJob(insertPagesJob, {
        'input': src,
        'password': null,
        'insertAfter': 1,
        'content': const InsertBlank(0),
        'output': out,
      }));
      expect(r, isA<RangeError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I15-4 PDF gốc 0 trang ⇒ CorruptFile, không có file ra', () async {
      final src = p.join(tmp.path, 'zero.pdf');
      File(src).writeAsBytesSync(_zeroPagePdf());
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 0, const InsertBlank(1), out));
      printOnFailure('kết quả: $r');
      expect(r, isA<CorruptFile>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I15-5 insertAfter vượt số trang ⇒ RangeError, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 3);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 4, const InsertBlank(1), out));
      expect(r, isA<RangeError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I15-9 tất cả trang PDF khác chèn cuối ⇒ đúng thứ tự', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final other = await _makePdf(tmp.path, 'b.pdf', 2, tag: 'B');
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 1, InsertPdfPages(other), out)), out);
      final d = _open(out);
      expect(_labels(d), ['Doc page 1', 'B page 1', 'B page 2']);
      d.dispose();
    });

    test('I15-10 sai mật khẩu PDF nguồn trang ⇒ WrongPassword, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final other = await _makePdf(tmp.path, 'b.pdf', 2, tag: 'B', password: 'pw');
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(src, 1, InsertPdfPages(other, password: 'nope'), out));
      expect(r, isA<WrongPassword>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I15-11 khoảng trang vượt số trang PDF nguồn ⇒ FormatException, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 1);
      final other = await _makePdf(tmp.path, 'b.pdf', 2, tag: 'B');
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _catch(engine.insertPages(
        src, 1, InsertPdfPages(other, ranges: const [PageRange(1, 9)]), out,
      ));
      expect(r, isA<FormatException>());
      expect(File(out).existsSync(), isFalse);
    });

    test('I15-13 chèn đầu tài liệu ⇒ trang chèn đứng đầu', () async {
      final src = await _makePdf(tmp.path, 'doc.pdf', 3);
      final out = p.join(tmp.path, 'out.pdf');
      expect(await _catch(engine.insertPages(src, 0, const InsertBlank(1), out)), out);
      final d = _open(out);
      expect(_labels(d), ['-', 'Doc page 1', 'Doc page 2', 'Doc page 3']);
      d.dispose();
    });
  });
}
