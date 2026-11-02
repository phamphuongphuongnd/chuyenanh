// ignore_for_file: depend_on_referenced_packages
// Kiểm thử hộp trắng (A06) — services/camera_service.dart. Mã bộ = buoc-5-du-lieu-thu.md của camera_service.
// Plugin permission_handler + image_picker được thay bằng bản giả qua `Platform.instance`
// (cùng cách test/core/ios_simulation_test.dart giả path_provider).
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/image_to_pdf/services/camera_service.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePermissions extends Fake
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  _FakePermissions(this.status);
  final PermissionStatus status;
  final List<List<Permission>> requested = [];

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requested.add(permissions);
    return {for (final p in permissions) p: status};
  }
}

class _FakePicker extends Fake
    with MockPlatformInterfaceMixin
    implements ImagePickerPlatform {
  _FakePicker(this.result);
  final String? result;
  final List<(ImageSource, ImagePickerOptions)> calls = [];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls.add((source, options));
    return result == null ? null : XFile(result!);
  }
}

void main() {
  late PermissionHandlerPlatform savedPerm;
  late ImagePickerPlatform savedPicker;
  setUp(() {
    savedPerm = PermissionHandlerPlatform.instance;
    savedPicker = ImagePickerPlatform.instance;
  });
  tearDown(() {
    PermissionHandlerPlatform.instance = savedPerm;
    ImagePickerPlatform.instance = savedPicker;
  });

  const svc = ImagePickerCameraService();

  group('U1 capture', () {
    test('1-1 bị từ chối quyền camera ⇒ ném PermissionDenied, không mở camera', () async {
      final perm = _FakePermissions(PermissionStatus.denied);
      final picker = _FakePicker('/x.jpg');
      PermissionHandlerPlatform.instance = perm;
      ImagePickerPlatform.instance = picker;
      final r = await svc.capture().then<Object?>((v) => v, onError: (Object e) => e);
      expect(perm.requested.single, [Permission.camera]);
      expect(picker.calls, isEmpty, reason: 'đi nhánh !isGranted ⇒ dừng');
      expect(r, isA<PermissionDenied>());
    });
    test('1-2 có quyền, chụp xong ⇒ trả đường dẫn ảnh', () async {
      final picker = _FakePicker('/shot.jpg');
      PermissionHandlerPlatform.instance = _FakePermissions(PermissionStatus.granted);
      ImagePickerPlatform.instance = picker;
      final r = await svc.capture().then<Object?>((v) => v, onError: (Object e) => e);
      expect(picker.calls.single.$1, ImageSource.camera);
      expect(r, '/shot.jpg');
    });
    test('1-3 có quyền, người dùng bỏ qua ⇒ null', () async {
      final picker = _FakePicker(null);
      PermissionHandlerPlatform.instance = _FakePermissions(PermissionStatus.granted);
      ImagePickerPlatform.instance = picker;
      final r = await svc.capture().then<Object?>((v) => v, onError: (Object e) => e);
      expect(picker.calls, hasLength(1));
      expect(r, isNull);
    });
    test('1-4 (dữ liệu bổ sung) từ chối vĩnh viễn ⇒ PermissionDenied', () async {
      final picker = _FakePicker('/x.jpg');
      PermissionHandlerPlatform.instance =
          _FakePermissions(PermissionStatus.permanentlyDenied);
      ImagePickerPlatform.instance = picker;
      final r = await svc.capture().then<Object?>((v) => v, onError: (Object e) => e);
      expect(picker.calls, isEmpty);
      expect(r, isA<PermissionDenied>());
    });
  });
}
