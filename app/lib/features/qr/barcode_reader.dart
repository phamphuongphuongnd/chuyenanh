import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/app_error.dart';
import 'ml_kit_barcode_reader.dart';
import 'qr_content.dart';

/// Giải mã QR / mã vạch từ một file ảnh. Tách interface để test thay bằng bản giả.
abstract interface class BarcodeReader {
  /// Mọi mã tìm được trong ảnh (rỗng nếu không có). Ném [AppError] khi ảnh lỗi.
  Future<List<ScannedCode>> read(String imagePath);
}

/// Nguồn ảnh để quét.
enum QrImageSource { camera, gallery }

/// Lấy một ảnh từ camera / thư viện. Tách interface để test.
abstract interface class QrImagePicker {
  /// Đường dẫn ảnh; `null` nếu người dùng bỏ qua. Ném [PermissionDenied] nếu bị từ chối quyền camera.
  Future<String?> pick(QrImageSource source);
}

/// Cạnh dài tối đa (px) của ảnh đưa vào bộ đọc mã — xem ghi chú ANR ở [ImagePickerQrPicker.pick].
const double kQrMaxImageSide = 2000;

class ImagePickerQrPicker implements QrImagePicker {
  const ImagePickerQrPicker();

  @override
  Future<String?> pick(QrImageSource source) async {
    if (source == QrImageSource.camera) {
      // Manifest khai quyền CAMERA nên phải xin lúc chạy, nếu không hệ thống chặn intent chụp.
      // UI đã giải thích + xin trước (`ensureCameraPermission`) → đây chỉ chốt lại, không hiện hộp nữa.
      final status = await Permission.camera.request();
      if (!status.isGranted) throw const PermissionDenied();
    }
    final file = await ImagePicker().pickImage(
      source: source == QrImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Plugin ML Kit giải mã + xoay ảnh trên luồng UI của Android: ảnh camera 50 MP (Galaxy A13)
      // làm app treo > 10 s (ANR). image_picker thu nhỏ ở luồng nền; QR đọc tốt ở 2000 px.
      maxWidth: kQrMaxImageSide,
      maxHeight: kQrMaxImageSide,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

/// Bộ giải mã dùng chung; test override bằng bản giả.
final barcodeReaderProvider = Provider<BarcodeReader>(
  (ref) => const MlKitBarcodeReader(),
);

final qrImagePickerProvider = Provider<QrImagePicker>(
  (ref) => const ImagePickerQrPicker(),
);
