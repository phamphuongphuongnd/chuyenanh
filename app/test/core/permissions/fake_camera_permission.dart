import 'package:pdf_office/core/permissions/camera_permission.dart';
import 'package:permission_handler/permission_handler.dart';

/// Quyền camera giả cho widget test (plugin permission_handler không chạy trong test).
/// Mặc định đã có quyền → không hiện hộp giải thích.
class FakeCameraPermission implements CameraPermissionApi {
  FakeCameraPermission({
    this.current = PermissionStatus.granted,
    this.afterRequest = PermissionStatus.granted,
  });

  PermissionStatus current;

  /// Kết quả hộp xin quyền hệ thống.
  PermissionStatus afterRequest;
  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<PermissionStatus> status() async {
    statusCalls++;
    return current;
  }

  @override
  Future<PermissionStatus> request() async {
    requestCalls++;
    return current = afterRequest;
  }
}
