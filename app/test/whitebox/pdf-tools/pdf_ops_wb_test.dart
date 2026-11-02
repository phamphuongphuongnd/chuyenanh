// Kiểm thử hộp trắng (A02) — lib/features/pdf_tools/engine/pdf_ops.dart
// Mã bộ & kết quả mong đợi chép từ test-output/whitebox/pdf-tools/pdf_ops/buoc-5-du-lieu-thu.md
// Mật khẩu trong file này chỉ là mật khẩu của PDF mẫu tự sinh trong test.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/isolate_job.dart';
import 'package:pdf_office/features/pdf_tools/engine/pdf_ops.dart';
import 'package:pdf_office/features/pdf_tools/engine/watermark_layout.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _pw = 'pw-fixture';

Future<Uint8List> pdfBytes(
  int pages, {
  String tag = 'Doc',
  List<Size> sizes = const [Size(595, 842)],
  String? password,
  sf.PdfPageRotateAngle? rotation,
  bool withText = true,
}) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.margins.all = 0;
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    final size = sizes[i % sizes.length];
    section.pageSettings.orientation = size.width > size.height
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    final page = section.pages.add();
    if (withText) {
      page.graphics.drawString(
        '$tag page ${i + 1}',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
        bounds: const Rect.fromLTWH(20, 20, 250, 30),
      );
    }
  }
  if (password != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  var bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  if (rotation != null) {
    final d = sf.PdfDocument(inputBytes: bytes);
    for (var i = 0; i < d.pages.count; i++) {
      d.pages[i].rotation = rotation;
    }
    bytes = Uint8List.fromList(await d.save());
    d.dispose();
  }
  return bytes;
}

/// PDF một trang 'hello' như lúc dò thư viện; [mutate] sửa vài byte để ra file hỏng có dạng cố định.
Future<Uint8List> helloBytes() async {
  final d = sf.PdfDocument();
  d.pages.add().graphics.drawString('hello', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12));
  final b = Uint8List.fromList(await d.save());
  d.dispose();
  return b;
}

/// Mở được nhưng 0 trang (byte 48..53 = '{').
Future<Uint8List> zeroPageBytes() async {
  final m = await helloBytes();
  for (var j = 0; j < 6; j++) {
    m[48 + j] = 0x7B;
  }
  return m;
}

/// File hỏng làm Syncfusion ném lỗi KHÔNG phải ArgumentError (lúc dò: TypeError khi đè '0123' vào
/// vùng đối tượng đầu). Byte lưu ra không cố định giữa các lần chạy ⇒ dò vị trí đè đầu tiên cho kết quả đó.
Future<Uint8List> typeErrorBytes() async {
  final base = await helloBytes();
  for (var pos = 9; pos < 400; pos++) {
    final m = Uint8List.fromList(base);
    for (var j = 0; j < 4 && pos + j < m.length; j++) {
      m[pos + j] = 0x30 + j;
    }
    try {
      sf.PdfDocument(inputBytes: m).dispose();
    } on ArgumentError {
      continue;
    } catch (_) {
      return m;
    }
  }
  throw StateError('không dò được file hỏng ném lỗi khác ArgumentError');
}

Future<String> write(String dir, String name, List<int> bytes) async {
  final path = p.join(dir, name);
  await File(path).writeAsBytes(bytes);
  return path;
}

sf.PdfDocument open(String path, {String? password}) =>
    sf.PdfDocument(inputBytes: File(path).readAsBytesSync(), password: password);

String textOf(sf.PdfDocument d, int page) =>
    sf.PdfTextExtractor(d).extractText(startPageIndex: page, endPageIndex: page);

Future<Object?> capture(Future<Object?> Function() f) => f().then((v) => v, onError: (Object e) => e);

Object? captureSync(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

/// Chép 1 trang của [src] sang tài liệu mới, lưu rồi mở lại (rotation chỉ đọc được sau khi lưu).
Future<sf.PdfDocument> copyOne(Uint8List src, {int extra = 0}) async {
  final s = sf.PdfDocument(inputBytes: src);
  final out = sf.PdfDocument();
  copyPage(out, s.pages[0], extraRotation: extra);
  final b = Uint8List.fromList(await out.save());
  out.dispose();
  s.dispose();
  return sf.PdfDocument(inputBytes: b);
}

class _FakeBlank implements BlankDocSpec {
  const _FakeBlank(this.pageCount);
  @override
  final int pageCount;
  @override
  BlankTemplate get template => BlankTemplate.blank;
  @override
  String get title => '';
  @override
  PageSizeOption get pageSize => PageSizeOption.a4;
  @override
  bool get landscape => false;
  @override
  int get backgroundArgb => 0xFFFFFFFF;
  @override
  String? get category => null;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_a02_ops'));
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('OF openPdfFile', () {
    test('OF-1 file PDF hợp lệ ⇒ mở được', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(2));
      final r = await capture(() => openPdfFile(a));
      expect(r, isA<sf.PdfDocument>());
      expect((r! as sf.PdfDocument).pages.count, 2);
    });
    test('OF-2 file không tồn tại ⇒ CorruptFile', () async {
      final r = await capture(() => openPdfFile(p.join(tmp.path, 'nope.pdf')));
      expect(r, isA<CorruptFile>());
    });
    test('OF-3 đọc bị từ chối quyền (thư mục trên Windows, errno 5) ⇒ PermissionDenied', () async {
      final r = await capture(() => openPdfFile(tmp.path));
      expect(r, isA<PermissionDenied>());
    });
    test('OF-4 file không phải PDF ⇒ CorruptFile', () async {
      final bad = await write(tmp.path, 'bad.pdf', utf8.encode('not a pdf'));
      final r = await capture(() => openPdfFile(bad));
      expect(r, isA<CorruptFile>());
      expect((r! as CorruptFile).detail, contains('Invalid argument')); // lỗi đến từ openPdfBytes
    });
  });

  group('OB openPdfBytes', () {
    late Uint8List plain;
    late Uint8List enc;
    setUp(() async {
      plain = await pdfBytes(1);
      enc = await pdfBytes(1, password: _pw);
    });
    test('OB-1 PDF thường, không mật khẩu ⇒ mở được', () {
      expect(captureSync(() => openPdfBytes(plain)), isA<sf.PdfDocument>());
    });
    test('OB-2 PDF có mật khẩu, mật khẩu đúng ⇒ mở được', () {
      expect(captureSync(() => openPdfBytes(enc, password: _pw)), isA<sf.PdfDocument>());
    });
    test('OB-3 PDF thường, mật khẩu rỗng ⇒ mở được', () {
      expect(captureSync(() => openPdfBytes(plain, password: '')), isA<sf.PdfDocument>());
    });
    test('OB-4 PDF có mật khẩu, không nhập ⇒ PasswordRequired', () {
      expect(captureSync(() => openPdfBytes(enc)), isA<PasswordRequired>());
    });
    test('OB-5 file hỏng làm thư viện ném TypeError ⇒ CorruptFile', () async {
      final b = await typeErrorBytes();
      final pre = captureSync(() => sf.PdfDocument(inputBytes: b));
      expect(pre, isA<Error>(), reason: 'tiền điều kiện: thư viện ném lỗi không phải ArgumentError');
      expect(pre, isNot(isA<ArgumentError>()));
      final r = captureSync(() => openPdfBytes(b));
      expect(r, isA<CorruptFile>());
      expect((r! as CorruptFile).detail, isNot(contains('Invalid argument'))); // nhánh catch (e) L43
    });
    test('OB-6 "not a pdf" (ArgumentError có message, không chứa password) ⇒ CorruptFile', () {
      final r = captureSync(() => openPdfBytes(Uint8List.fromList(utf8.encode('not a pdf'))));
      expect(r, isA<CorruptFile>());
      expect((r! as CorruptFile).detail, contains('Invalid position'));
    });
    test('OB-7 ArgumentError không có message ⇒ CorruptFile', () {
      final b = Uint8List.fromList(utf8.encode('%PDF-1.4\ntrailer\n<<>>\nstartxref\n0\n%%EOF'));
      final r = captureSync(() => openPdfBytes(b));
      expect(r, isA<CorruptFile>());
      expect((r! as CorruptFile).detail, contains('Invalid cross reference table.'));
    });
    test('OB-10 PDF có mật khẩu, mật khẩu rỗng ⇒ PasswordRequired', () {
      expect(captureSync(() => openPdfBytes(enc, password: '')), isA<PasswordRequired>());
    });
    test('OB-11 PDF có mật khẩu, mật khẩu sai ⇒ WrongPassword', () {
      expect(captureSync(() => openPdfBytes(enc, password: 'bad')), isA<WrongPassword>());
    });
  });

  group('CP copyPage / RD _rotationDegrees / AD _angleFromDegrees', () {
    test('CP-1 trang dọc, không xoay ⇒ giữ khổ dọc, xoay 0', () async {
      final d = await copyOne(await pdfBytes(1));
      expect(d.pages[0].size.width, closeTo(595, 0.5));
      expect(d.pages[0].size.height, closeTo(842, 0.5));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
    });
    test('CP-2 trang ngang ⇒ giữ khổ ngang', () async {
      final d = await copyOne(await pdfBytes(1, sizes: const [Size(842, 595)]));
      expect(d.pages[0].size.width, closeTo(842, 0.5));
      expect(d.pages[0].size.height, closeTo(595, 0.5));
    });
    test('CP-3 / AD-1 xoay thêm 90 ⇒ xoay 90', () async {
      final d = await copyOne(await pdfBytes(1), extra: 90);
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle90);
    });
    test('RD-1 trang gốc xoay 0 ⇒ giữ 0', () async {
      final d = await copyOne(await pdfBytes(1, rotation: sf.PdfPageRotateAngle.rotateAngle0));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
    });
    test('RD-2 trang gốc xoay 90 ⇒ giữ 90', () async {
      final d = await copyOne(await pdfBytes(1, rotation: sf.PdfPageRotateAngle.rotateAngle90));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle90);
    });
    test('RD-3 trang gốc xoay 180 ⇒ giữ 180', () async {
      final d = await copyOne(await pdfBytes(1, rotation: sf.PdfPageRotateAngle.rotateAngle180));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle180);
    });
    test('RD-4 trang gốc xoay 270 ⇒ giữ 270', () async {
      final d = await copyOne(await pdfBytes(1, rotation: sf.PdfPageRotateAngle.rotateAngle270));
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle270);
    });
    test('AD-2 xoay thêm 180 ⇒ xoay 180', () async {
      final d = await copyOne(await pdfBytes(1), extra: 180);
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle180);
    });
    test('AD-3 xoay thêm 270 ⇒ xoay 270', () async {
      final d = await copyOne(await pdfBytes(1), extra: 270);
      expect(d.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle270);
    });
    test('AD-4 xoay thêm 45 (ngoài hợp đồng) ⇒ không ném, vẫn chép 1 trang giữ khổ (*)', () async {
      final src = await pdfBytes(1);
      final r = await capture(() => copyOne(src, extra: 45));
      expect(r, isA<sf.PdfDocument>());
      final d = r! as sf.PdfDocument;
      expect(d.pages.count, 1);
      expect(d.pages[0].size.width, closeTo(595, 0.5));
    });
  });

  group('MJ mergeJob', () {
    Future<Object?> merge(List<String> inputs, String out, {List<double>? prog}) => capture(
      () => runIsolateJob(
        mergeJob,
        {'inputs': inputs, 'passwords': <String, String>{}, 'output': out},
        onProgress: prog?.add,
        plannedOutputs: [out],
      ),
    );

    test('MJ-1 [a(2 trang)] ⇒ file 2 trang, 2 lần báo tiến độ trang', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(2, tag: 'A'));
      final out = p.join(tmp.path, 'o.pdf');
      final prog = <double>[];
      final r = await merge([a], out, prog: prog);
      expect(prog.where((v) => v < 1).length, 2);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 2);
      expect(textOf(d, 1), contains('A page 2'));
      d.dispose();
    });
    test('MJ-2 inputs rỗng ⇒ CorruptFile, không tạo file', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await merge([], out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<CorruptFile>());
    });
    test('MJ-3 [a, b có mật khẩu] không nhập mật khẩu ⇒ PasswordRequired, không tạo file', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(1));
      final b = await write(tmp.path, 'b.pdf', await pdfBytes(1, password: _pw));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await merge([a, b], out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
    test('MJ-4 [PDF 0 trang] ⇒ CorruptFile, không tạo file (*)', () async {
      final z = await write(tmp.path, 'z.pdf', await zeroPageBytes());
      expect(open(z).pages.count, 0, reason: 'tiền điều kiện: file mở được, 0 trang');
      final out = p.join(tmp.path, 'o.pdf');
      final r = await merge([z], out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<CorruptFile>());
    });
    test('MJ-5 [a(1), b(2)] ⇒ 3 trang đúng thứ tự', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(1, tag: 'A'));
      final b = await write(tmp.path, 'b.pdf', await pdfBytes(2, tag: 'B'));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await merge([a, b], out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 3);
      expect(textOf(d, 0), contains('A page 1'));
      expect(textOf(d, 2), contains('B page 2'));
      d.dispose();
    });
    test('MJ-6 [PDF 0 trang, a(2)] ⇒ 2 trang của a (*)', () async {
      final z = await write(tmp.path, 'z.pdf', await zeroPageBytes());
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(2, tag: 'A'));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await merge([z, a], out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 2);
      expect(textOf(d, 0), contains('A page 1'));
      d.dispose();
    });
  });

  group('SJ splitJob', () {
    Future<Object?> split(String input, List<PageRange> ranges, List<String> outs, {String? pw}) =>
        capture(
          () => runIsolateJob(
            splitJob,
            {'input': input, 'password': pw, 'ranges': ranges, 'outputs': outs},
            plannedOutputs: outs,
          ),
        );

    test('SJ-1 3 trang, [1-2] ⇒ 1 file 2 trang', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(3));
      final o1 = p.join(tmp.path, 'o1.pdf');
      final r = await split(src, const [PageRange(1, 2)], [o1]);
      expect(r, [o1]);
      expect(open(o1).pages.count, 2);
    });
    test('SJ-2 file có mật khẩu, không nhập ⇒ PasswordRequired, không tạo file', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(3, password: _pw));
      final o1 = p.join(tmp.path, 'o1.pdf');
      final r = await split(src, const [PageRange(1, 2)], [o1]);
      expect(File(o1).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
    test('SJ-3 [2-9] trên 3 trang ⇒ FormatException, không tạo file', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(3));
      final o1 = p.join(tmp.path, 'o1.pdf');
      final r = await split(src, const [PageRange(2, 9)], [o1]);
      expect(File(o1).existsSync(), isFalse);
      expect(r, isA<FormatException>());
    });
    test('SJ-4 [1-1, 2-3] ⇒ 2 file: 1 trang và 2 trang', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(3));
      final o1 = p.join(tmp.path, 'o1.pdf');
      final o2 = p.join(tmp.path, 'o2.pdf');
      final r = await split(src, const [PageRange(1, 1), PageRange(2, 3)], [o1, o2]);
      expect(r, [o1, o2]);
      expect(open(o1).pages.count, 1);
      final d2 = open(o2);
      expect(d2.pages.count, 2);
      expect(textOf(d2, 0), contains('Doc page 2'));
    });
    test('SJ-5 [1-1] ⇒ 1 file 1 trang', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(3));
      final o1 = p.join(tmp.path, 'o1.pdf');
      final r = await split(src, const [PageRange(1, 1)], [o1]);
      expect(r, [o1]);
      expect(open(o1).pages.count, 1);
    });
  });

  group('OJ organizeJob', () {
    Future<Object?> organize(String input, List<PageOp> ops, String out) => capture(
      () => runIsolateJob(
        organizeJob,
        {'input': input, 'password': null, 'ops': ops, 'output': out},
        plannedOutputs: [out],
      ),
    );

    test('OJ-1 [trang 2] ⇒ 1 trang là trang 2', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(2));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await organize(src, const [PageOp(1)], out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 1);
      expect(textOf(d, 0), contains('Doc page 2'));
    });
    test('OJ-2 file có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(2, password: _pw));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await organize(src, const [PageOp(0)], out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
    test('OJ-3 [trang 6] trên 2 trang ⇒ RangeError', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(2));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await organize(src, const [PageOp(5)], out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<RangeError>());
    });
    test('OJ-4 [trang 2, trang 1 xoay 90] ⇒ 2 trang, trang sau xoay 90', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(2));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await organize(src, const [PageOp(1), PageOp(0, rotation: 90)], out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 2);
      expect(textOf(d, 0), contains('Doc page 2'));
      expect(textOf(d, 1), contains('Doc page 1'));
      expect(d.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
    });
  });

  group('WJ watermarkJob', () {
    Future<Object?> wm(String input, WatermarkSpec spec, String out, {String? pw}) => capture(
      () => runIsolateJob(
        watermarkJob,
        {'input': input, 'password': pw, 'spec': spec, 'fontBytes': null, 'output': out},
        plannedOutputs: [out],
      ),
    );
    Uint8List png() => Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 20)..clear(img.ColorRgb8(200, 0, 0))),
    );

    test('WJ-1 chữ CONFIDENTIAL ⇒ chữ trên trang, chữ gốc còn', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(1));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await wm(src, const WatermarkSpec.text('CONFIDENTIAL'), out);
      expect(r, out);
      final t = textOf(open(out), 0);
      expect(t, contains('CONFIDENTIAL'));
      expect(t, contains('Doc page 1'));
    });
    test('WJ-2 file có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(1, password: _pw));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await wm(src, const WatermarkSpec.text('X'), out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
    test('WJ-3 ảnh PNG ⇒ có file, lớn hơn file gốc, không thêm chữ', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(2));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await wm(src, WatermarkSpec.image(png()), out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 2);
      expect(textOf(d, 0).trim(), 'Doc page 1');
      expect(File(out).lengthSync(), greaterThan(File(src).lengthSync()));
    });
    test('WJ-5 ảnh không phải PNG/JPG ⇒ lỗi, không tạo file (*)', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(1));
      final before = File(src).readAsBytesSync();
      final out = p.join(tmp.path, 'o.pdf');
      final r = await wm(src, WatermarkSpec.image(Uint8List.fromList([1, 2, 3])), out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isNot(out));
      expect(r, isA<Exception>());
      expect(File(src).readAsBytesSync(), before);
    });
    test('WJ-6 PDF 0 trang ⇒ không lỗi, có file kết quả (*)', () async {
      final src = await write(tmp.path, 'z.pdf', await zeroPageBytes());
      final out = p.join(tmp.path, 'o.pdf');
      final prog = <double>[];
      final r = await capture(
        () => runIsolateJob(
          watermarkJob,
          {
            'input': src,
            'password': null,
            'spec': const WatermarkSpec.text('X'),
            'fontBytes': null,
            'output': out,
          },
          onProgress: prog.add,
          plannedOutputs: [out],
        ),
      );
      expect(prog.where((v) => v < 1), isEmpty); // không vào vòng trang
      expect(r, out);
      expect(File(out).existsSync(), isTrue);
    });
    test('WJ-8 PlacedWatermarkSpec góc trên trái ⇒ chữ nằm góc trên trái', () async {
      final src = await write(tmp.path, 's.pdf', await pdfBytes(1, withText: false));
      final out = p.join(tmp.path, 'o.pdf');
      final r = await wm(
        src,
        const PlacedWatermarkSpec.text('TOPLEFT', alignX: -1, alignY: -1, angle: 0),
        out,
      );
      expect(r, out);
      final lines = sf.PdfTextExtractor(open(out)).extractTextLines(startPageIndex: 0, endPageIndex: 0);
      final line = lines.firstWhere((l) => l.text.contains('TOPLEFT'));
      expect(line.bounds.left, lessThan(595 / 4));
      expect(line.bounds.top, lessThan(842 / 4));
    });
  });

  group('BJ blankJob', () {
    Future<Object?> blank(BlankDocSpec spec, String out) => capture(
      () => runIsolateJob(
        blankJob,
        {'spec': spec, 'fontBytes': null, 'output': out},
        plannedOutputs: [out],
      ),
    );
    Future<int> sizeOf(BlankDocSpec s, String name) async {
      final out = p.join(tmp.path, name);
      final r = await blank(s, out);
      expect(r, out);
      return File(out).lengthSync();
    }

    test('BJ-1 mặc định ⇒ 1 trang A4 dọc', () async {
      final out = p.join(tmp.path, 'b.pdf');
      final r = await blank(const BlankDocSpec(), out);
      expect(r, out);
      final d = open(out);
      expect(d.pages.count, 1);
      expect(d.pages[0].size.width, closeTo(595.28, 0.5));
      expect(d.pages[0].size.height, closeTo(841.89, 0.5));
      expect(textOf(d, 0).trim(), isEmpty);
    });
    test('BJ-2 số trang 0 ⇒ RangeError, không tạo file', () async {
      final out = p.join(tmp.path, 'b.pdf');
      final r = await blank(const _FakeBlank(0), out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<RangeError>());
    });
    test('BJ-3 số trang 1001 ⇒ RangeError, không tạo file', () async {
      final out = p.join(tmp.path, 'b.pdf');
      final r = await blank(const _FakeBlank(1001), out);
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<RangeError>());
    });
    test('BJ-4 ngang ⇒ khổ A4 ngang', () async {
      final out = p.join(tmp.path, 'b.pdf');
      await blank(const BlankDocSpec(landscape: true), out);
      final d = open(out);
      expect(d.pages[0].size.width, closeTo(841.89, 0.5));
      expect(d.pages[0].size.height, closeTo(595.28, 0.5));
    });
    test('BJ-6 danh mục Work ⇒ metadata subject = Work', () async {
      final out = p.join(tmp.path, 'b.pdf');
      await blank(const BlankDocSpec(category: 'Work'), out);
      expect(open(out).documentInformation.subject, 'Work');
    });
    test('BJ-7 tiêu đề My Notes ⇒ chữ trên trang 1 + metadata title', () async {
      final out = p.join(tmp.path, 'b.pdf');
      await blank(const BlankDocSpec(title: 'My Notes'), out);
      final d = open(out);
      expect(textOf(d, 0), contains('My Notes'));
      expect(d.documentInformation.title, 'My Notes');
    });
    test('BJ-9 2 trang, tiêu đề ⇒ 2 trang, tiêu đề chỉ ở trang 1', () async {
      final out = p.join(tmp.path, 'b.pdf');
      await blank(const BlankDocSpec(pageCount: 2, title: 'T1'), out);
      final d = open(out);
      expect(d.pages.count, 2);
      expect(textOf(d, 0), contains('T1'));
      expect(textOf(d, 1), isNot(contains('T1')));
    });
    test('BJ-10 nền vàng nhạt ⇒ nội dung lớn hơn nền trắng', () async {
      final white = await sizeOf(const BlankDocSpec(), 'w.pdf');
      final yellow = await sizeOf(const BlankDocSpec(backgroundArgb: 0xFFFFF59D), 'y.pdf');
      expect(yellow, greaterThan(white));
    });
    test('BJ-14 kẻ dòng ⇒ lớn hơn trang trắng', () async {
      final blankSize = await sizeOf(const BlankDocSpec(), 'w.pdf');
      final lined = await sizeOf(const BlankDocSpec(template: BlankTemplate.lined), 'l.pdf');
      expect(lined, greaterThan(blankSize));
    });
    test('BJ-15 kẻ ô ⇒ lớn hơn kẻ dòng', () async {
      final lined = await sizeOf(const BlankDocSpec(template: BlankTemplate.lined), 'l.pdf');
      final grid = await sizeOf(const BlankDocSpec(template: BlankTemplate.grid), 'g.pdf');
      expect(grid, greaterThan(lined));
    });
  });

  group('PC pageCountJob', () {
    test('PC-1 4 trang ⇒ 4', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(4));
      expect(await capture(() => runIsolateJob(pageCountJob, {'input': a, 'password': null})), 4);
    });
    test('PC-2 có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final a = await write(tmp.path, 'a.pdf', await pdfBytes(1, password: _pw));
      expect(
        await capture(() => runIsolateJob(pageCountJob, {'input': a, 'password': null})),
        isA<PasswordRequired>(),
      );
    });
  });

  group('MF makeFont / IL isLatin1', () {
    final noto = File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync();
    test('MF-1 chữ Latin, không đậm ⇒ Helvetica thường', () {
      final f = makeFont('ABC', 12, null);
      expect(f, isA<sf.PdfStandardFont>());
      expect((f as sf.PdfStandardFont).fontFamily, sf.PdfFontFamily.helvetica);
      expect(f.style, sf.PdfFontStyle.regular);
    });
    test('MF-2 chữ Việt + có font ⇒ TrueType nhúng', () {
      expect(makeFont('Tiếng Việt', 12, noto), isA<sf.PdfTrueTypeFont>());
    });
    test('MF-3 chữ Việt + thiếu font ⇒ rơi về Helvetica', () {
      final f = makeFont('Tiếng Việt', 12, null);
      expect(f, isA<sf.PdfStandardFont>());
      expect((f as sf.PdfStandardFont).fontFamily, sf.PdfFontFamily.helvetica);
    });
    test('MF-4 chữ Latin, đậm ⇒ Helvetica đậm', () {
      final f = makeFont('ABC', 12, null, bold: true);
      expect(f, isA<sf.PdfStandardFont>());
      expect(f.style, sf.PdfFontStyle.bold);
    });
    test('IL-1 Latin-1 / ngoài Latin-1', () {
      expect(isLatin1('Café'), isTrue);
      expect(isLatin1('Việt'), isFalse);
    });
  });
}
