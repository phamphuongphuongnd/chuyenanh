import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/errors/app_error.dart';

/// Chụp một ảnh bằng camera. Tách interface để test.
abstract interface class CameraService {
  /// Đường dẫn ảnh vừa chụp; `null` nếu người dùng bỏ qua.
  /// Ném [PermissionDenied] nếu bị từ chối quyền camera.
  Future<String?> capture();
}

class ImagePickerCameraService implements CameraService {
  const ImagePickerCameraService();

  @override
  Future<String?> capture() async {
    // Manifest khai quyền CAMERA nên phải xin lúc chạy, nếu không hệ thống chặn intent chụp.
    final status = await Permission.camera.request();
    if (!status.isGranted) throw const PermissionDenied();
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}
