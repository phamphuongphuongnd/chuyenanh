// ignore_for_file: depend_on_referenced_packages, unnecessary_import
// Kiểm thử hộp trắng A13 — app/lib/features/id_card/id_card_services.dart
// Thiết kế: test-output/whitebox/id-card/id_card_services/buoc-1..5. Expected chép từ Bước 5.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/id_card/id_card_services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _SelfDeletingEngine implements ImageToPdfEngine {
  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    await File(imagePaths.single).delete();
    await File(outputPath).writeAsString('%PDF');
    return ImageToPdfResult(outputPath: outputPath, pageCount: 1);
  }
}

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.temp);
  final String temp;
  int calls = 0;
  @override
  Future<String?> getTemporaryPath() async {
    calls++;
    return temp;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const picker = MethodChannel('plugins.flutter.io/image_picker');

  late Directory tmp;
  late PathProviderPlatform saved;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_idcard_');
    saved = PathProviderPlatform.instance;
  });
  tearDown(() {
    PathProviderPlatform.instance = saved;
    m.setMockMethodCallHandler(picker, null);
    if (Platform.isWindows) Process.runSync('attrib', ['-R', '${tmp.path}\\*', '/S', '/D']);
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // còn handle
    }
  });

  Future<Object?> settle(Future<Object?> f) => f.then((v) => v, onError: (Object e) => e);

  group('U1 layout', () {
    const side = IdCardSide('a.jpg');
    test('1-1 bản in ⇒ 2480×3508, 92', () {
      final l = const IdCardRequest(front: side, back: side).layout;
      expect([l.pageWidthPx, l.pageHeightPx, l.jpegQuality], [2480, 3508, 92]);
    });
    test('1-2 xem trước ⇒ 1240×1754, 80', () {
      final l = const IdCardRequest(front: side, back: side, preview: true).layout;
      expect([l.pageWidthPx, l.pageHeightPx, l.jpegQuality], [1240, 1754, 80]);
    });
  });

  group('U2 pickImage', () {
    late Map<dynamic, dynamic> args;
    void mock({String? path, String? errorCode}) {
      m.setMockMethodCallHandler(picker, (c) async {
        if (c.method != 'pickImage') return null;
        args = c.arguments as Map;
        if (errorCode != null) throw PlatformException(code: errorCode);
        return path;
      });
    }

    test('2-1 chọn ảnh ⇒ path, tham số nén', () async {
      mock(path: '/p/a.jpg');
      final r = await settle(const ImagePickerIdCardGalleryPicker().pickImage());
      expect(args['source'], 1);
      expect(args['imageQuality'], 95);
      expect(args['maxWidth'], 3000);
      expect(args['maxHeight'], 3000);
      expect(r, '/p/a.jpg');
    });
    test('2-2 huỷ ⇒ null', () async {
      mock(path: null);
      expect(await settle(const ImagePickerIdCardGalleryPicker().pickImage()), isNull);
    });
    test('2-3 lỗi nền tảng khác ⇒ AppError', () async {
      mock(errorCode: 'x');
      final r = await settle(const ImagePickerIdCardGalleryPicker().pickImage());
      expect(r, isA<AppError>());
      expect(r, isNot(isA<PermissionDenied>()));
    });
    test('2-4 photo_access_denied ⇒ PermissionDenied', () async {
      mock(errorCode: 'photo_access_denied');
      expect(await settle(const ImagePickerIdCardGalleryPicker().pickImage()), isA<PermissionDenied>());
    });
  });

  group('U3 compose', () {
    String file(String n, List<int> b) => (File(p.join(tmp.path, n))..writeAsBytesSync(b)).path;
    Future<Object?> compose(String f, String b) => settle(
      const IsolateIdCardComposer().compose(IdCardRequest(front: IdCardSide(f), back: IdCardSide(b), preview: true)),
    );

    test('3-1 2 ảnh hợp lệ ⇒ JPEG', () async {
      final png = base64Decode(_png1x1);
      final r = await compose(file('f.png', png), file('b.png', png));
      expect(r, isA<Uint8List>());
      expect((r as Uint8List).sublist(0, 2), [0xFF, 0xD8]);
    });
    test('3-2 ảnh hỏng ⇒ CorruptFile', () async {
      expect(await compose(file('f.jpg', [1, 2, 3]), file('b.jpg', [1, 2, 3])), isA<CorruptFile>());
    });
    test('3-3 file mất ⇒ CorruptFile', () async {
      final png = base64Decode(_png1x1);
      expect(await compose(p.join(tmp.path, 'none.png'), file('b.png', png)), isA<CorruptFile>());
    });
    test('3-4 không đọc được (là thư mục) ⇒ CorruptFile', () async {
      final png = base64Decode(_png1x1);
      final dir = Directory(p.join(tmp.path, 'dir.png'))..createSync();
      expect(await compose(dir.path, file('b.png', png)), isA<CorruptFile>());
    });
  });

  group('U4 export', () {
    test('4-3 xoá ảnh tạm lỗi ⇒ không ném, trả outputPath', () async {
      final work = Directory(p.join(tmp.path, 'work'))..createSync();
      final ex = DefaultIdCardExporter(_SelfDeletingEngine(), () async => work);
      final r = await settle(
        ex.export(page: Uint8List.fromList([1, 2]), format: IdCardFormat.pdf, outputDir: tmp.path, baseName: 'IDCard_z'),
      );
      expect(r, p.join(tmp.path, 'IDCard_z.pdf'));
      expect(work.listSync(), isEmpty);
    });
  });

  group('U5 deleteIdCardTempFiles', () {
    test('5-1 rỗng ⇒ không gọi path_provider', () async {
      final f = _FakePathProvider(tmp.path);
      PathProviderPlatform.instance = f;
      final r = await settle(deleteIdCardTempFiles(const []).then((_) => 'ok'));
      expect(f.calls, 0);
      expect(r, 'ok');
    });
    test('5-2 chỉ xoá file trong temp', () async {
      final t = Directory(p.join(tmp.path, 'T'))..createSync();
      final outDir = Directory.systemTemp.createTempSync('wb_idcard_out_');
      addTearDown(() => outDir.deleteSync(recursive: true));
      final a = File(p.join(t.path, 'a.jpg'))..writeAsBytesSync([1]);
      final b = File(p.join(outDir.path, 'b.jpg'))..writeAsBytesSync([1]);
      PathProviderPlatform.instance = _FakePathProvider(t.path);
      await deleteIdCardTempFiles([a.path, b.path]);
      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isTrue);
    });
    test('5-3 không lấy được temp ⇒ không ném, không xoá', () async {
      final b = File(p.join(tmp.path, 'b.jpg'))..writeAsBytesSync([1]);
      final r = await settle(deleteIdCardTempFiles([b.path]).then((_) => 'ok'));
      expect(b.existsSync(), isTrue);
      expect(r, 'ok');
    });
  });

  group('U6 deleteFilesUnder', () {
    late String root;
    setUp(() => root = (Directory(p.join(tmp.path, 'root'))..createSync()).path);
    test('6-1 rỗng ⇒ 0', () async => expect(await deleteFilesUnder(root, const []), 0));
    test('6-2 file trong root ⇒ xoá, 1', () async {
      final a = File(p.join(root, 'a.jpg'))..writeAsBytesSync([1]);
      expect(await deleteFilesUnder(root, [a.path]), 1);
      expect(a.existsSync(), isFalse);
    });
    test('6-3 ngoài root và ../ ⇒ không xoá', () async {
      final b = File(p.join(tmp.path, 'b.jpg'))..writeAsBytesSync([1]);
      final b2 = File(p.join(tmp.path, 'b2.jpg'))..writeAsBytesSync([1]);
      expect(await deleteFilesUnder(root, [b.path, p.join(root, '..', 'b2.jpg')]), 0);
      expect(b.existsSync(), isTrue);
      expect(b2.existsSync(), isTrue);
    });
    test('6-4 không tồn tại ⇒ 0', () async => expect(await deleteFilesUnder(root, [p.join(root, 'missing.jpg')]), 0));
    test('6-5 xoá lỗi (chỉ-đọc) ⇒ 0, không ném', () async {
      final ro = File(p.join(root, 'ro.jpg'))..writeAsBytesSync([1]);
      Process.runSync('attrib', ['+R', ro.path]);
      final r = await settle(deleteFilesUnder(root, [ro.path]));
      expect(ro.existsSync(), isTrue);
      expect(r, 0);
    }, testOn: 'windows');
  });

  group('U7 renderIdCardWatermark', () {
    test('7-1 ⇒ PNG 1012×638', () async {
      final r = await settle(renderIdCardWatermark('MẪU'));
      expect(r, isA<Uint8List>());
      final b = r as Uint8List;
      expect(b.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final bd = ByteData.sublistView(b);
      expect(bd.getUint32(16), 1012);
      expect(bd.getUint32(20), 638);
    });
  });
}
