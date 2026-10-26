import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/syncfusion_pdf_tools.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Tạo PDF mẫu: trang i có chữ "<tag> page <i+1>", khổ lấy từ [sizes] (xoay vòng).
Future<String> makePdf(
  String dir,
  String name,
  int pages, {
  String tag = 'Doc',
  List<Size> sizes = const [Size(595, 842)],
  String? password,
}) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.margins.all = 0;
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add()!;
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = sizes[i % sizes.length];
    section.pages.add().graphics.drawString(
      '$tag page ${i + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(20, 20, 250, 30),
    );
  }
  if (password != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  final path = p.join(dir, name);
  await File(path).writeAsBytes(await doc.save());
  doc.dispose();
  return path;
}

sf.PdfDocument open(String path, {String? password}) => sf.PdfDocument(
  inputBytes: File(path).readAsBytesSync(),
  password: password,
);

String textOf(sf.PdfDocument d, int page) => sf.PdfTextExtractor(
  d,
).extractText(startPageIndex: page, endPageIndex: page);

void main() {
  late Directory tmp;
  // Không nạp font từ assets trong test (rootBundle không có).
  const engine = SyncfusionPdfTools(fontLoader: null);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pdf_tools_test');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('merge', () {
    test('gộp đúng thứ tự, giữ khổ và hướng từng trang', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 2, tag: 'A');
      final b = await makePdf(
        tmp.path,
        'b.pdf',
        3,
        tag: 'B',
        sizes: const [Size(612, 792), Size(792, 612)],
      );
      final out = p.join(tmp.path, 'a & b.pdf');
      final progress = <double>[];
      final r = await engine.merge([a, b], out, onProgress: progress.add);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 5);
      expect(textOf(d, 0), contains('A page 1'));
      expect(textOf(d, 2), contains('B page 1'));
      expect(textOf(d, 4), contains('B page 3'));
      expect(d.pages[0].size.width, closeTo(595, 0.5));
      expect(d.pages[2].size.width, closeTo(612, 0.5));
      expect(d.pages[3].size.width, closeTo(792, 0.5));
      expect(d.pages[3].size.height, closeTo(612, 0.5));
      d.dispose();
      expect(progress.last, 1.0);
      expect(File('$out.tmp').existsSync(), isFalse);
      // file gốc nguyên vẹn
      expect(open(a).pages.count, 2);
    });

    test('không ghi đè file gốc', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      expect(() => engine.merge([a], a), throwsArgumentError);
    });

    test('file có mật khẩu: thiếu → PasswordRequired, sai → WrongPassword, đúng → gộp', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final b = await makePdf(tmp.path, 'b.pdf', 2, password: 'pw1');
      final out = p.join(tmp.path, 'out.pdf');
      await expectLater(
        engine.merge([a, b], out),
        throwsA(isA<PasswordRequired>()),
      );
      await expectLater(
        engine.merge([a, b], out, passwords: {b: 'bad'}),
        throwsA(isA<WrongPassword>()),
      );
      expect(File(out).existsSync(), isFalse);
      await engine.merge([a, b], out, passwords: {b: 'pw1'});
      final d = open(out);
      expect(d.pages.count, 3); // kết quả không còn mật khẩu
      d.dispose();
    });

    test('file hỏng → CorruptFile', () async {
      final bad = p.join(tmp.path, 'bad.pdf');
      await File(bad).writeAsString('not a pdf');
      await expectLater(
        engine.merge([bad], p.join(tmp.path, 'o.pdf')),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('huỷ trước khi chạy → Cancelled, không tạo file', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final token = CancelToken()..cancel();
      final out = p.join(tmp.path, 'o.pdf');
      await expectLater(
        engine.merge([a], out, cancelToken: token),
        throwsA(isA<Cancelled>()),
      );
      expect(File(out).existsSync(), isFalse);
    });

    test('huỷ giữa chừng → Cancelled, không để file dở', () async {
      final big = await makePdf(tmp.path, 'big.pdf', 150);
      final out = p.join(tmp.path, 'o.pdf');
      final token = CancelToken();
      final fut = engine.merge(
        [big, big, big],
        out,
        cancelToken: token,
        onProgress: (v) {
          if (v > 0) token.cancel();
        },
      );
      await expectLater(fut, throwsA(isA<Cancelled>()));
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });
  });

  group('split', () {
    test('mỗi trang một file', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final files = await engine.split(src, const SplitEveryPage(), outDir, 'src');
      expect(files.map(p.basename), ['src (1).pdf', 'src (2).pdf', 'src (3).pdf']);
      for (var i = 0; i < 3; i++) {
        final d = open(files[i]);
        expect(d.pages.count, 1);
        expect(textOf(d, 0), contains('Doc page ${i + 1}'));
        d.dispose();
      }
    });

    test('theo khoảng, tên không trùng file có sẵn', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 6);
      final outDir = p.join(tmp.path, 'out')..toString();
      await Directory(outDir).create();
      await File(p.join(outDir, 'src (1-3).pdf')).writeAsString('x');
      final files = await engine.split(
        src,
        const SplitByRanges([PageRange(1, 3), PageRange(4, 4), PageRange(5, 6)]),
        outDir,
        'src',
      );
      expect(files.map(p.basename), [
        'src (1-3) (1).pdf',
        'src (4).pdf',
        'src (5-6).pdf',
      ]);
      expect(open(files[0]).pages.count, 3);
      expect(open(files[2]).pages.count, 2);
      // file có sẵn không bị đụng
      expect(File(p.join(outDir, 'src (1-3).pdf')).readAsStringSync(), 'x');
    });

    test('mỗi N trang', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 5);
      final files = await engine.split(
        src,
        const SplitEveryN(2),
        p.join(tmp.path, 'o'),
        'src',
      );
      expect(files.length, 3);
      expect(open(files.last).pages.count, 1);
    });

    test('khoảng ngoài phạm vi → FormatException', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      await expectLater(
        engine.split(
          src,
          const SplitByRanges([PageRange(2, 9)]),
          p.join(tmp.path, 'o'),
          'src',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('organize', () {
    test('đổi thứ tự, xoá, nhân đôi và xoay trang', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 4);
      final out = p.join(tmp.path, 'org.pdf');
      await engine.organize(src, const [
        PageOp(2),
        PageOp(0, rotation: 90),
        PageOp(2, rotation: 180),
      ], out);
      final d = open(out);
      expect(d.pages.count, 3);
      expect(textOf(d, 0), contains('Doc page 3'));
      expect(textOf(d, 1), contains('Doc page 1'));
      expect(textOf(d, 2), contains('Doc page 3'));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      expect(d.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(d.pages[2].rotation, sf.PdfPageRotateAngle.rotateAngle180);
      d.dispose();
    });

    test('cộng dồn góc xoay với trang đã xoay sẵn', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final pre = open(src);
      pre.pages[0].rotation = sf.PdfPageRotateAngle.rotateAngle90;
      final rotated = p.join(tmp.path, 'rot.pdf');
      await File(rotated).writeAsBytes(await pre.save());
      pre.dispose();
      final out = p.join(tmp.path, 'org.pdf');
      await engine.organize(rotated, const [PageOp(0, rotation: 270)], out);
      final d = open(out);
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      d.dispose();
    });

    test('chỉ số sai / rỗng / góc lạ → lỗi tham số', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      await expectLater(
        engine.organize(src, const [PageOp(5)], out),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        engine.organize(src, const [], out),
        throwsArgumentError,
      );
      await expectLater(
        engine.organize(src, const [PageOp(0, rotation: 45)], out),
        throwsArgumentError,
      );
      expect(File(out).existsSync(), isFalse);
    });
  });

  group('watermark', () {
    test('chữ nằm trên mọi trang, chữ gốc vẫn còn', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final out = p.join(tmp.path, 'wm.pdf');
      await engine.watermark(src, const WatermarkSpec.text('CONFIDENTIAL'), out);
      final d = open(out);
      expect(d.pages.count, 3);
      for (var i = 0; i < 3; i++) {
        final t = textOf(d, i);
        expect(t, contains('CONFIDENTIAL'), reason: 'trang ${i + 1}');
        expect(t, contains('Doc page ${i + 1}'));
      }
      d.dispose();
    });

    test('watermark ảnh PNG: mở lại được và có thêm đối tượng ảnh', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2);
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 40, height: 20)..clear(img.ColorRgb8(200, 0, 0))),
      );
      final out = p.join(tmp.path, 'wm.pdf');
      await engine.watermark(src, WatermarkSpec.image(png, opacity: 0.4), out);
      final d = open(out);
      expect(d.pages.count, 2);
      d.dispose();
      expect(File(out).lengthSync(), greaterThan(File(src).lengthSync()));
    });

    test('file có mật khẩu cần mật khẩu; chữ rỗng → lỗi tham số', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'wm.pdf');
      await expectLater(
        engine.watermark(src, const WatermarkSpec.text('X'), out),
        throwsA(isA<PasswordRequired>()),
      );
      await engine.watermark(
        src,
        const WatermarkSpec.text('SECRET'),
        out,
        password: 'pw',
      );
      final d = open(out);
      expect(textOf(d, 0), contains('SECRET'));
      d.dispose();
      await expectLater(
        engine.watermark(src, const WatermarkSpec.text('  '), out, password: 'pw'),
        throwsArgumentError,
      );
    });

    test('không ghi đè file gốc', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      expect(
        () => engine.watermark(src, const WatermarkSpec.text('X'), src),
        throwsArgumentError,
      );
    });
  });

  group('createBlank', () {
    test('số trang, khổ A4 dọc/ngang, Letter, metadata', () async {
      final out = p.join(tmp.path, 'blank.pdf');
      await engine.createBlank(
        const BlankDocSpec(pageCount: 3, title: 'My Notes', category: 'Work'),
        out,
      );
      var d = open(out);
      expect(d.pages.count, 3);
      expect(d.pages[0].size.width, closeTo(595.28, 0.5));
      expect(d.pages[0].size.height, closeTo(841.89, 0.5));
      expect(d.documentInformation.title, 'My Notes');
      expect(d.documentInformation.subject, 'Work');
      expect(textOf(d, 0), contains('My Notes'));
      expect(textOf(d, 1), isNot(contains('My Notes')));
      d.dispose();

      final out2 = p.join(tmp.path, 'land.pdf');
      await engine.createBlank(
        const BlankDocSpec(pageSize: PageSizeOption.letter, landscape: true),
        out2,
      );
      d = open(out2);
      expect(d.pages[0].size.width, closeTo(792, 0.5));
      expect(d.pages[0].size.height, closeTo(612, 0.5));
      d.dispose();
    });

    test('mẫu kẻ dòng / kẻ ô / màu nền làm nội dung trang lớn hơn trang trắng', () async {
      Future<int> size(BlankDocSpec s, String n) async {
        final path = p.join(tmp.path, n);
        await engine.createBlank(s, path);
        return File(path).lengthSync();
      }

      final blank = await size(const BlankDocSpec(), 'a.pdf');
      final lined = await size(
        const BlankDocSpec(template: BlankTemplate.lined),
        'b.pdf',
      );
      final grid = await size(
        const BlankDocSpec(template: BlankTemplate.grid),
        'c.pdf',
      );
      final colored = await size(
        const BlankDocSpec(backgroundArgb: 0xFFFFF59D),
        'd.pdf',
      );
      expect(lined, greaterThan(blank));
      expect(grid, greaterThan(lined));
      expect(colored, greaterThan(blank));
    });

    test('1000 trang được, 1001 hoặc 0 → lỗi', () async {
      final out = p.join(tmp.path, 'big.pdf');
      await engine.createBlank(const BlankDocSpec(pageCount: 1000), out);
      final d = open(out);
      expect(d.pages.count, 1000);
      d.dispose();
      // BlankDocSpec có assert; kiểm đường ném của job qua spec hợp lệ ở biên.
      expect(() => BlankDocSpec(pageCount: 1001), throwsA(isA<AssertionError>()));
      expect(() => BlankDocSpec(pageCount: 0), throwsA(isA<AssertionError>()));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  test('pageCount', () async {
    final a = await makePdf(tmp.path, 'a.pdf', 4);
    expect(await engine.pageCount(a), 4);
    final b = await makePdf(tmp.path, 'b.pdf', 2, password: 'pw');
    await expectLater(engine.pageCount(b), throwsA(isA<PasswordRequired>()));
    expect(await engine.pageCount(b, password: 'pw'), 2);
  });
}
