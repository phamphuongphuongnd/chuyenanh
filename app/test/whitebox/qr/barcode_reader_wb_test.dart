// Kiểm thử hộp trắng A13 — app/lib/features/qr/barcode_reader.dart
// Thiết kế: test-output/whitebox/qr/barcode_reader/buoc-1..5. Expected chép từ Bước 5.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/qr/barcode_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const perm = MethodChannel('flutter.baseflow.com/permissions/methods');
  const picker = MethodChannel('plugins.flutter.io/image_picker');

  late int permRequests;
  late List<int> sources;

  void setup({int status = 1, String? picked}) {
    permRequests = 0;
    sources = [];
    m.setMockMethodCallHandler(perm, (c) async {
      if (c.method == 'requestPermissions') {
        permRequests++;
        return {1: status};
      }
      return null;
    });
    m.setMockMethodCallHandler(picker, (c) async {
      if (c.method == 'pickImage') {
        sources.add((c.arguments as Map)['source'] as int);
        return picked;
      }
      return null;
    });
  }

  tearDown(() {
    m.setMockMethodCallHandler(perm, null);
    m.setMockMethodCallHandler(picker, null);
  });

  Future<Object?> pick(QrImageSource s) =>
      const ImagePickerQrPicker().pick(s).then((v) => v as Object?, onError: (Object e) => e);

  test('1-1 thư viện, huỷ ⇒ null, không xin quyền', () async {
    setup(picked: null);
    final r = await pick(QrImageSource.gallery);
    expect(permRequests, 0);
    expect(sources, [1]);
    expect(r, isNull);
  });
  test('1-2 thư viện chọn ảnh ⇒ path', () async {
    setup(picked: '/p/x.jpg');
    final r = await pick(QrImageSource.gallery);
    expect(sources, [1]);
    expect(r, '/p/x.jpg');
  });
  test('1-3 camera có quyền ⇒ path', () async {
    setup(status: 1, picked: '/p/c.jpg');
    final r = await pick(QrImageSource.camera);
    expect(permRequests, 1);
    expect(sources, [0]);
    expect(r, '/p/c.jpg');
  });
  test('1-4 camera bị từ chối ⇒ PermissionDenied, không mở picker', () async {
    setup(status: 0, picked: '/p/c.jpg');
    final r = await pick(QrImageSource.camera);
    expect(permRequests, 1);
    expect(sources, isEmpty);
    expect(r, isA<PermissionDenied>());
  });
}
