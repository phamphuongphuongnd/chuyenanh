// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A02) — lib/features/pdf_tools/engine/syncfusion_pdf_tools.dart
// Mã bộ & kết quả mong đợi chép từ test-output/whitebox/pdf-tools/syncfusion_pdf_tools/buoc-5-du-lieu-thu.md
// Mật khẩu trong file này chỉ là mật khẩu của PDF mẫu tự sinh trong test.
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/syncfusion_pdf_tools.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _pw = 'pw-fixture';

Future<String> makePdf(String dir, String name, int pages, {String tag = 'Doc', String? password}) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.margins.all = 0;
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = const Size(595, 842);
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

sf.PdfDocument open(String path) => sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

String textOf(sf.PdfDocument d, int page) =>
    sf.PdfTextExtractor(d).extractText(startPageIndex: page, endPageIndex: page);

Future<Object?> capture(Future<Object?> Function() f) => f().then((v) => v, onError: (Object e) => e);

/// Spec giả không có cả chữ lẫn ảnh (constructor thật không cho tạo).
class _NoContentSpec implements WatermarkSpec {
  const _NoContentSpec();
  @override
  String? get text => null;
  @override
  Uint8List? get imageBytes => null;
  @override
  double get fontSize => 48;
  @override
  int get colorArgb => 0xFFE5393B;
  @override
  double get imageScale => 1;
  @override
  double get opacity => 0.3;
  @override
  double get angle => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  const engine = SyncfusionPdfTools(fontLoader: null);
  final noto = File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync();

  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_a02_sf'));
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('LF loadBundledFont', () {
    final requested = <String>[];
    void mockAssets(Set<String> available) {
      requested.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? msg) async {
          final key = Uri.decodeFull(
            String.fromCharCodes(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes)),
          );
          requested.add(key);
          return available.contains(key) ? ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4])) : null;
        },
      );
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    test('LF-1 chữ Latin, có NotoSans-Regular.ttf ⇒ trả bytes font đó', () async {
      mockAssets({'assets/fonts/NotoSans-Regular.ttf'});
      final r = await capture(() => loadBundledFont('ABC'));
      expect(requested, ['assets/fonts/NotoSans-Regular.ttf']);
      expect(r, [1, 2, 3, 4]);
    });
    test('LF-2 thiếu .ttf, có .otf ⇒ thử tiếp và trả bytes .otf', () async {
      mockAssets({'assets/fonts/NotoSans-Regular.otf'});
      final r = await capture(() => loadBundledFont('ABC'));
      expect(requested, ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Regular.otf']);
      expect(r, [1, 2, 3, 4]);
    });
    test('LF-3 không có font nào ⇒ null (rơi về Helvetica)', () async {
      mockAssets({});
      final r = await capture(() => loadBundledFont('ABC'));
      expect(requested.length, 2);
      expect(r, isNull);
    });
  });

  group('ME merge', () {
    test('ME-1 [a(1), b(2)] ⇒ 3 trang', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1, tag: 'A');
      final b = await makePdf(tmp.path, 'b.pdf', 2, tag: 'B');
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.merge([a, b], out));
      expect(r, out);
      expect(open(out).pages.count, 3);
    });
    test('ME-2 danh sách rỗng ⇒ ArgumentError, không tạo file', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.merge([], out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<ArgumentError>());
    });
    test('ME-3 output trùng input ⇒ ArgumentError, file gốc không đổi', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final before = File(a).readAsBytesSync();
      final r = await capture(() => engine.merge([a], a));
      expect(File(a).readAsBytesSync(), before);
      expect(r, isA<ArgumentError>());
    });
    test('ME-4 [a, b có mật khẩu] không nhập ⇒ PasswordRequired', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final b = await makePdf(tmp.path, 'b.pdf', 1, password: _pw);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.merge([a, b], out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
  });

  group('SP split', () {
    List<String> names(Object? r) => (r! as List).cast<String>().map(p.basename).toList();

    test('SP-1 không token, mỗi trang ⇒ 3 file src (1..3).pdf', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(() => engine.split(src, const SplitEveryPage(), outDir, 'src'));
      expect(names(r), ['src (1).pdf', 'src (2).pdf', 'src (3).pdf']);
    });
    test('SP-2 token chưa huỷ ⇒ như SP-1', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(
        () => engine.split(src, const SplitEveryPage(), outDir, 'src', cancelToken: CancelToken()),
      );
      expect(names(r), ['src (1).pdf', 'src (2).pdf', 'src (3).pdf']);
    });
    test('SP-3 token đã huỷ (file có mật khẩu) ⇒ Cancelled trước khi mở file', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3, password: _pw);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(
        () => engine.split(src, const SplitEveryPage(), outDir, 'src', cancelToken: CancelToken()..cancel()),
      );
      expect(Directory(outDir).existsSync(), isFalse);
      expect(r, isA<Cancelled>());
    });
    test('SP-4 file có mật khẩu, không nhập ⇒ PasswordRequired, không tạo thư mục', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3, password: _pw);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(() => engine.split(src, const SplitEveryPage(), outDir, 'src'));
      expect(Directory(outDir).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
    test('SP-5 khoảng 2-9 trên 3 trang ⇒ FormatException, không tạo thư mục', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(
        () => engine.split(src, const SplitByRanges([PageRange(2, 9)]), outDir, 'src'),
      );
      expect(Directory(outDir).existsSync(), isFalse);
      expect(r, isA<FormatException>());
    });
    test('SP-7 hai khoảng trùng 1-2, 1-2 ⇒ tên thứ hai đánh số (1)', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(
        () => engine.split(src, const SplitByRanges([PageRange(1, 2), PageRange(1, 2)]), outDir, 'src'),
      );
      expect(names(r), ['src (1-2).pdf', 'src (1-2) (1).pdf']);
      for (final f in (r! as List).cast<String>()) {
        expect(open(f).pages.count, 2);
      }
    });
    test('SP-8 trùng khoảng + đã có "src (1-2) (1).pdf" ⇒ đánh số (2), file có sẵn giữ nguyên', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      await Directory(outDir).create();
      final existing = File(p.join(outDir, 'src (1-2) (1).pdf'))..writeAsStringSync('x');
      final r = await capture(
        () => engine.split(src, const SplitByRanges([PageRange(1, 2), PageRange(1, 2)]), outDir, 'src'),
      );
      expect(names(r), ['src (1-2).pdf', 'src (1-2) (2).pdf']);
      expect(existing.readAsStringSync(), 'x');
    });
    test('PH-SP-7b tên gốc rất dài + hai khoảng trùng ⇒ mọi tên ≤ 150 byte (không kể đuôi)', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final r = await capture(
        () => engine.split(src, const SplitByRanges([PageRange(1, 2), PageRange(1, 2)]), outDir, 'ệ' * 100),
      );
      final list = (r! as List).cast<String>();
      expect(list, hasLength(2));
      for (final f in list) {
        expect(File(f).existsSync(), isTrue);
        expect(utf8.encode(p.basename(f)).length, lessThan(255));
      }
    });
    test('SP-9 huỷ ngay sau khi gọi ⇒ Cancelled ở bước chạy job, không có file kết quả', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 3);
      final outDir = p.join(tmp.path, 'out');
      final token = CancelToken();
      final fut = capture(() => engine.split(src, const SplitEveryPage(), outDir, 'src', cancelToken: token));
      token.cancel();
      final r = await fut;
      expect(Directory(outDir).existsSync(), isTrue); // đã qua vòng đặt tên + tạo thư mục
      expect(Directory(outDir).listSync(), isEmpty);
      expect(r, isA<Cancelled>());
    });
  });

  group('OR organize', () {
    test('OR-1 [trang 2] ⇒ 1 trang', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.organize(src, const [PageOp(1)], out));
      expect(r, out);
      expect(textOf(open(out), 0), contains('Doc page 2'));
    });
    test('OR-2 danh sách rỗng ⇒ ArgumentError', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.organize(src, const [], out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<ArgumentError>());
    });
    test('OR-3 output trùng input ⇒ ArgumentError, file gốc không đổi', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2);
      final before = File(src).readAsBytesSync();
      final r = await capture(() => engine.organize(src, const [PageOp(0)], src));
      expect(File(src).readAsBytesSync(), before);
      expect(r, isA<ArgumentError>());
    });
    test('OR-4 file có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 2, password: _pw);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.organize(src, const [PageOp(0)], out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
  });

  group('WM watermark', () {
    Uint8List png() => Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 20)..clear(img.ColorRgb8(200, 0, 0))),
    );

    test('WM-1 chữ CONFIDENTIAL ⇒ có chữ trên trang', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, const WatermarkSpec.text('CONFIDENTIAL'), out));
      expect(r, out);
      expect(textOf(open(out), 0), contains('CONFIDENTIAL'));
    });
    test('WM-2 ảnh PNG ⇒ có file kết quả', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, WatermarkSpec.image(png()), out));
      expect(r, out);
      expect(File(out).lengthSync(), greaterThan(File(src).lengthSync()));
    });
    test('WM-3 spec không chữ không ảnh ⇒ ArgumentError', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, const _NoContentSpec(), out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<ArgumentError>());
      expect('$r', contains('needs text or image'));
    });
    test('WM-5 chữ toàn dấu cách ⇒ ArgumentError', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, const WatermarkSpec.text('  '), out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<ArgumentError>());
      expect('$r', contains('must not be empty'));
    });
    test('WM-6 output trùng input ⇒ ArgumentError, file gốc không đổi', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final before = File(src).readAsBytesSync();
      final r = await capture(() => engine.watermark(src, const WatermarkSpec.text('X'), src));
      expect(File(src).readAsBytesSync(), before);
      expect(r, isA<ArgumentError>());
      expect('$r', contains('output must differ'));
    });
    test('WM-9 chữ Việt, không có bộ nạp font ⇒ vẫn tạo file', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, const WatermarkSpec.text('Tiếng Việt'), out));
      expect(r, out);
      expect(File(out).existsSync(), isTrue);
    });
    test('WM-10 chữ Việt NFD + bộ nạp font ⇒ bộ nạp nhận chữ NFC, chữ hiện đúng', () async {
      final calls = <String>[];
      final spyEngine = SyncfusionPdfTools(
        fontLoader: (t) async {
          calls.add(t);
          return noto;
        },
      );
      final src = await makePdf(tmp.path, 'src.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(
        () => spyEngine.watermark(src, const WatermarkSpec.text('Tiếng Việt'), out),
      );
      expect(calls, ['Tiếng Việt']);
      expect(r, out);
      expect(textOf(open(out), 0), contains('Tiếng Việt'));
    });
    test('WM-11 file có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final src = await makePdf(tmp.path, 'src.pdf', 1, password: _pw);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await capture(() => engine.watermark(src, const WatermarkSpec.text('X'), out));
      expect(File(out).existsSync(), isFalse);
      expect(r, isA<PasswordRequired>());
    });
  });

  group('CB createBlank', () {
    test('CB-1 tiêu đề Latin + bộ nạp ⇒ không gọi bộ nạp', () async {
      final calls = <String>[];
      final spyEngine = SyncfusionPdfTools(fontLoader: (t) async {
        calls.add(t);
        return noto;
      });
      final out = p.join(tmp.path, 'b.pdf');
      final r = await capture(() => spyEngine.createBlank(const BlankDocSpec(title: 'My Notes'), out));
      expect(calls, isEmpty);
      expect(r, out);
      expect(textOf(open(out), 0), contains('My Notes'));
    });
    test('CB-2 tiêu đề Việt, không có bộ nạp ⇒ vẫn tạo file, metadata đúng', () async {
      final out = p.join(tmp.path, 'b.pdf');
      final r = await capture(() => engine.createBlank(const BlankDocSpec(title: 'Tiêu đề'), out));
      expect(r, out);
      expect(open(out).documentInformation.title, 'Tiêu đề');
    });
    test('CB-3 tiêu đề Việt + bộ nạp ⇒ gọi bộ nạp với tiêu đề, chữ hiện đúng', () async {
      final calls = <String>[];
      final spyEngine = SyncfusionPdfTools(fontLoader: (t) async {
        calls.add(t);
        return noto;
      });
      final out = p.join(tmp.path, 'b.pdf');
      final r = await capture(() => spyEngine.createBlank(const BlankDocSpec(title: 'Tiêu đề'), out));
      expect(calls, ['Tiêu đề']);
      expect(r, out);
      expect(textOf(open(out), 0), contains('Tiêu đề'));
    });
    test('CB-4 huỷ giữa chừng ⇒ Cancelled, không để file', () async {
      final out = p.join(tmp.path, 'b.pdf');
      final token = CancelToken();
      final r = await capture(
        () => engine.createBlank(
          const BlankDocSpec(pageCount: 300),
          out,
          cancelToken: token,
          onProgress: (v) {
            if (v > 0) token.cancel();
          },
        ),
      );
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
      expect(r, isA<Cancelled>());
    });
  });

  group('PG pageCount', () {
    test('PG-1 4 trang ⇒ 4', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 4);
      expect(await capture(() => engine.pageCount(a)), 4);
    });
    test('PG-2 có mật khẩu, không nhập ⇒ PasswordRequired', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1, password: _pw);
      expect(await capture(() => engine.pageCount(a)), isA<PasswordRequired>());
    });
  });

  group('EO _ensureOutputIsNotInput (qua merge)', () {
    test('EO-1 [a, b] → c ⇒ cho qua', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final b = await makePdf(tmp.path, 'b.pdf', 1);
      final out = p.join(tmp.path, 'c.pdf');
      expect(await capture(() => engine.merge([a, b], out)), out);
    });
    test('EO-2 output = "<dir>/./a.pdf" (cùng file sau normalize) ⇒ ArgumentError', () async {
      final a = await makePdf(tmp.path, 'a.pdf', 1);
      final before = File(a).readAsBytesSync();
      final r = await capture(() => engine.merge([a], p.join(tmp.path, '.', 'a.pdf')));
      expect(File(a).readAsBytesSync(), before);
      expect(r, isA<ArgumentError>());
    });
    test('EO-B1 (bổ sung) output khác hoa/thường cùng file trên ổ không phân biệt hoa/thường ⇒ ArgumentError', () async {
      final a = await makePdf(tmp.path, 'Src.pdf', 1);
      final before = File(a).readAsBytesSync();
      final out = p.join(tmp.path, 'src.pdf');
      final sameFile = FileSystemEntity.identicalSync(a, out);
      expect(sameFile, isTrue, reason: 'tiền điều kiện: hệ file không phân biệt hoa/thường (Windows)');
      final r = await capture(() => engine.merge([a], out));
      final after = File(a).readAsBytesSync();
      expect(r, isA<ArgumentError>());
      expect(after, before);
    });
  });
}
