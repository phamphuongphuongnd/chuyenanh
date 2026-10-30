import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;

import '../../core/errors/app_error.dart';
import 'barcode_reader.dart';
import 'qr_content.dart';

/// Loại mã ML Kit → loại mã của app. Hàm thuần.
CodeFormat codeFormatFromMlKit(mlkit.BarcodeFormat f) => switch (f) {
  mlkit.BarcodeFormat.qrCode => CodeFormat.qrCode,
  mlkit.BarcodeFormat.aztec => CodeFormat.aztec,
  mlkit.BarcodeFormat.dataMatrix => CodeFormat.dataMatrix,
  mlkit.BarcodeFormat.pdf417 => CodeFormat.pdf417,
  mlkit.BarcodeFormat.ean13 => CodeFormat.ean13,
  mlkit.BarcodeFormat.ean8 => CodeFormat.ean8,
  mlkit.BarcodeFormat.upca => CodeFormat.upca,
  mlkit.BarcodeFormat.upce => CodeFormat.upce,
  mlkit.BarcodeFormat.code128 => CodeFormat.code128,
  mlkit.BarcodeFormat.code39 => CodeFormat.code39,
  mlkit.BarcodeFormat.code93 => CodeFormat.code93,
  mlkit.BarcodeFormat.codabar => CodeFormat.codabar,
  mlkit.BarcodeFormat.itf => CodeFormat.itf,
  mlkit.BarcodeFormat.all || mlkit.BarcodeFormat.unknown => CodeFormat.unknown,
};

/// Đổi kết quả ML Kit sang model của app: bỏ mã không có nội dung, bỏ mã trùng
/// (cùng loại + cùng nội dung), giữ thứ tự. Hàm thuần.
List<ScannedCode> scannedCodesFromMlKit(Iterable<mlkit.Barcode> barcodes) {
  final out = <ScannedCode>[];
  for (final b in barcodes) {
    final raw = b.rawValue ?? b.displayValue;
    if (raw == null || raw.isEmpty) continue;
    final code = ScannedCode(format: codeFormatFromMlKit(b.format), raw: raw);
    if (!out.contains(code)) out.add(code);
  }
  return out;
}

/// Giải mã offline bằng ML Kit (model đóng sẵn trong APK). Mỗi lần đọc tạo một
/// `BarcodeScanner` rồi đóng ngay (quét thưa, không cần giữ tài nguyên native).
///
/// Chỉ chạy được trên máy thật — logic ngoài plugin tách ở [codeFormatFromMlKit]
/// và [scannedCodesFromMlKit].
class MlKitBarcodeReader implements BarcodeReader {
  const MlKitBarcodeReader();

  @override
  Future<List<ScannedCode>> read(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw const CorruptFile('image not found');
    }
    final scanner = mlkit.BarcodeScanner(
      formats: const [mlkit.BarcodeFormat.all],
    );
    try {
      final barcodes = await scanner.processImage(
        mlkit.InputImage.fromFilePath(imagePath),
      );
      return scannedCodesFromMlKit(barcodes);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    } finally {
      try {
        await scanner.close();
      } catch (_) {
        // Đóng lỗi không ảnh hưởng kết quả đã có.
      }
    }
  }
}
