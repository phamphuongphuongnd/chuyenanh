import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/syncfusion_pdf_security.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF một trang có chữ, tạo bằng Syncfusion.
Future<Uint8List> _samplePdf({String? userPassword}) async {
  final doc = sf.PdfDocument();
  doc.pages.add().graphics.drawString(
    'Hello PDF Office',
    sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
  );
  if (userPassword != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword = userPassword;
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

void main() {
  const engine = SyncfusionPdfSecurity();

  test('PDF thường → isEncrypted false', () async {
    expect(await engine.isEncrypted(await _samplePdf()), isFalse);
  });

  test('encrypt → isEncrypted true, decrypt đúng mật khẩu → mở được', () async {
    final locked = await engine.encrypt(await _samplePdf(), 'secret');
    expect(await engine.isEncrypted(locked), isTrue);

    final unlocked = await engine.decrypt(locked, 'secret');
    expect(await engine.isEncrypted(unlocked), isFalse);
    final doc = sf.PdfDocument(inputBytes: unlocked);
    expect(doc.pages.count, 1);
    expect(sf.PdfTextExtractor(doc).extractText(), contains('Hello'));
    doc.dispose();
  });

  test('decrypt sai mật khẩu → WrongPassword', () async {
    final locked = await _samplePdf(userPassword: 'right');
    await expectLater(
      engine.decrypt(locked, 'wrong'),
      throwsA(isA<WrongPassword>()),
    );
  });

  test('encrypt file đang khoá → PasswordRequired', () async {
    final locked = await _samplePdf(userPassword: 'x');
    await expectLater(
      engine.encrypt(locked, 'y'),
      throwsA(isA<PasswordRequired>()),
    );
  });

  test('bytes rác → CorruptFile', () async {
    final junk = Uint8List.fromList(List.generate(64, (i) => i));
    await expectLater(engine.isEncrypted(junk), throwsA(isA<CorruptFile>()));
  });
}
