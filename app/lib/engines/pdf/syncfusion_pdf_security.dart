import 'dart:isolate';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/errors/app_error.dart';
import 'pdf_security.dart';

/// [PdfSecurityEngine] dùng Syncfusion PDF. Phân tích/ghi PDF chạy trong isolate nền
/// để PDF lớn không làm đơ giao diện (parse và `save()` đều đồng bộ, tốn CPU/RAM).
class SyncfusionPdfSecurity implements PdfSecurityEngine {
  const SyncfusionPdfSecurity();

  @override
  Future<bool> isEncrypted(Uint8List bytes) =>
      Isolate.run(() => _isEncrypted(bytes));

  @override
  Future<Uint8List> decrypt(Uint8List bytes, String password) =>
      Isolate.run(() => _decrypt(bytes, password));

  @override
  Future<Uint8List> encrypt(
    Uint8List bytes,
    String userPassword, {
    String? ownerPassword,
  }) => Isolate.run(() => _encrypt(bytes, userPassword, ownerPassword));
}

bool _isEncrypted(Uint8List bytes) {
  try {
    _open(bytes).dispose();
    return false;
  } on PasswordRequired {
    return true;
  }
}

Future<Uint8List> _decrypt(Uint8List bytes, String password) async {
  final doc = _open(bytes, password: password);
  try {
    final security = doc.security;
    security.userPassword = '';
    security.ownerPassword = '';
    security.permissions.clear();
    return Uint8List.fromList(await doc.save());
  } finally {
    doc.dispose();
  }
}

Future<Uint8List> _encrypt(
  Uint8List bytes,
  String userPassword,
  String? ownerPassword,
) async {
  final doc = _open(bytes);
  try {
    final security = doc.security;
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    security.userPassword = userPassword;
    security.ownerPassword = ownerPassword ?? userPassword;
    return Uint8List.fromList(await doc.save());
  } finally {
    doc.dispose();
  }
}

/// Mở tài liệu; đổi exception Syncfusion thành [AppError].
sf.PdfDocument _open(Uint8List bytes, {String? password}) {
  try {
    return sf.PdfDocument(inputBytes: bytes, password: password);
  } on ArgumentError catch (e) {
    if (e.name == 'password' ||
        (e.message?.toString().toLowerCase().contains('password') ?? false)) {
      throw password == null || password.isEmpty
          ? const PasswordRequired()
          : const WrongPassword();
    }
    throw CorruptFile(e.toString());
  } catch (e) {
    throw CorruptFile(e.toString());
  }
}
