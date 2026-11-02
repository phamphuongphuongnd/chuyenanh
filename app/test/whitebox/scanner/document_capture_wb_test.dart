// Kiểm thử hộp trắng A07 — scanner/capture/document_capture.dart (Bước 6).
// Plugin (cunning_document_scanner, image_picker, path_provider) thay bằng mock MethodChannel.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/scanner/capture/document_capture.dart';

const _scanner = MethodChannel('cunning_document_scanner');
const _picker = MethodChannel('plugins.flutter.io/image_picker');
const _paths = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir, appTmp;
  late String src;
  late int pathCalls;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wb_capture_');
    appTmp = Directory(p.join(dir.path, 'apptmp'))..createSync();
    src = p.join(dir.path, 'plugin_cache_page.jpg');
    File(src).writeAsStringSync('JPEGDATA');
    pathCalls = 0;
    m.setMockMethodCallHandler(_paths, (c) async {
      pathCalls++;
      return appTmp.path;
    });
  });
  tearDown(() {
    for (final c in [_scanner, _picker, _paths]) {
      m.setMockMethodCallHandler(c, null);
    }
    dir.deleteSync(recursive: true);
  });

  const cap = PluginDocumentCapture();

  group('U1 scanPages', () {
    test('U1-B1 quét xong ⇒ trả đường dẫn đã chép sang thư mục tạm của app', () async {
      MethodCall? call;
      m.setMockMethodCallHandler(_scanner, (c) async {
        call = c;
        return [src];
      });
      final r = await cap.scanPages(maxPages: 7);
      expect((call!.arguments as Map)['noOfPages'], 7);
      expect(pathCalls, 1);
      expect(r, hasLength(1));
      expect(p.isWithin(p.join(appTmp.path, 'scan_pages'), r!.single), isTrue);
      expect(File(r.single).readAsStringSync(), 'JPEGDATA');
    });
    test('U1-B2 người dùng huỷ ⇒ null, không chép', () async {
      m.setMockMethodCallHandler(_scanner, (c) async => null);
      final r = await cap.scanPages();
      expect(pathCalls, 0);
      expect(r, isNull);
    });
    test('U1-B3 thiếu quyền camera ⇒ PermissionDenied', () async {
      m.setMockMethodCallHandler(_scanner, (c) async => throw PlatformException(code: 'permission_denied'));
      final r = await cap.scanPages().then<Object?>((v) => v, onError: (Object e) => e);
      expect(pathCalls, 0);
      expect(r, isA<PermissionDenied>());
    });
    test('U1-B4 trình quét lỗi khác ⇒ ScannerUnavailable', () async {
      m.setMockMethodCallHandler(_scanner, (c) async => throw PlatformException(code: 'gms_unavailable'));
      final r = await cap.scanPages().then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isA<ScannerUnavailable>());
    });
    test('U1-B5 không có plugin ⇒ ScannerUnavailable', () async {
      final r = await cap.scanPages().then<Object?>((v) => v, onError: (Object e) => e);
      expect(pathCalls, 0);
      expect(r, isA<ScannerUnavailable>());
    });
    test('U1-B6 chép ảnh lỗi nền tảng (path_provider PlatformException) ⇒ ScannerUnavailable', () async {
      m.setMockMethodCallHandler(_scanner, (c) async => [src]);
      m.setMockMethodCallHandler(_paths, (c) async {
        pathCalls++;
        throw PlatformException(code: 'no_dir');
      });
      final r = await cap.scanPages().then<Object?>((v) => v, onError: (Object e) => e);
      expect(pathCalls, 1);
      expect(r, isA<ScannerUnavailable>());
    });
  });

  group('U2 takePhoto', () {
    test('U2-B1 chụp xong ⇒ trả đường dẫn đã chép', () async {
      m.setMockMethodCallHandler(_picker, (c) async => src);
      final r = await cap.takePhoto();
      expect(pathCalls, 1);
      expect(p.isWithin(appTmp.path, r!), isTrue);
      expect(r, endsWith('.jpg'));
    });
    test('U2-B2 huỷ ⇒ null', () async {
      m.setMockMethodCallHandler(_picker, (c) async => null);
      final r = await cap.takePhoto();
      expect(pathCalls, 0);
      expect(r, isNull);
    });
    test('U2-B3 từ chối quyền camera ⇒ PermissionDenied', () async {
      m.setMockMethodCallHandler(_picker, (c) async => throw PlatformException(code: 'camera_access_denied'));
      final r = await cap.takePhoto().then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isA<PermissionDenied>());
    });
    test('U2-B4 lỗi nền tảng khác ⇒ AppError (không phải PermissionDenied)', () async {
      m.setMockMethodCallHandler(_picker, (c) async => throw PlatformException(code: 'no_available_camera'));
      final r = await cap.takePhoto().then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isA<AppError>());
      expect(r, isNot(isA<PermissionDenied>()));
    });
  });

  group('U3 _keep', () {
    test('U3-B3 file không có đuôi ⇒ bản chép đuôi .jpg', () async {
      final noExt = p.join(dir.path, 'scanpage');
      File(noExt).writeAsStringSync('X');
      m.setMockMethodCallHandler(_scanner, (c) async => [noExt]);
      final r = await cap.scanPages();
      expect(r!.single, endsWith('_0.jpg'));
      expect(File(r.single).existsSync(), isTrue);
    });
  });
}
