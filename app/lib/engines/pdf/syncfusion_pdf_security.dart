import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/errors/app_error.dart';
import 'pdf_security.dart';

/// [PdfSecurityEngine] dùng Syncfusion PDF.
class SyncfusionPdfSecurity implements PdfSecurityEngine {
  const SyncfusionPdfSecurity();

  @override
  Future<bool> isEncrypted(Uint8List bytes) async {
    try {
      _open(bytes).dispose();
      return false;
    } on PasswordRequired {
      return true;
    }
  }

  @override
  Future<Uint8List> decrypt(Uint8List bytes, String password) async {
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

  @override
  Future<Uint8List> encrypt(
    Uint8List bytes,
    String userPassword, {
    String? ownerPassword,
  }) async {
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
}
