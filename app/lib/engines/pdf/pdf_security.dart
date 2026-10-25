import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'syncfusion_pdf_security.dart';

/// Mật khẩu PDF (đặt / gỡ / phát hiện). Impl: [SyncfusionPdfSecurity].
///
/// Lỗi ném ra luôn là `AppError`: [WrongPassword], [PasswordRequired], [CorruptFile].
abstract interface class PdfSecurityEngine {
  /// `true` nếu PDF cần mật khẩu người dùng để mở (mở không mật khẩu bị từ chối).
  /// File hỏng → ném `CorruptFile`.
  Future<bool> isEncrypted(Uint8List bytes);

  /// Mở bằng [password] và trả về bytes PDF **không** còn mật khẩu.
  /// Sai mật khẩu → `WrongPassword`. File không có mật khẩu → trả lại bản lưu lại bình thường.
  Future<Uint8List> decrypt(Uint8List bytes, String password);

  /// Đặt mật khẩu AES-256. [ownerPassword] null → dùng [userPassword].
  /// File vào đang có mật khẩu → `PasswordRequired` (gỡ trước bằng [decrypt]).
  Future<Uint8List> encrypt(
    Uint8List bytes,
    String userPassword, {
    String? ownerPassword,
  });
}

final pdfSecurityProvider = Provider<PdfSecurityEngine>(
  (ref) => const SyncfusionPdfSecurity(),
);
