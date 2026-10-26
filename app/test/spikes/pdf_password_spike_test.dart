// Spike S1 (phan 3): mat khau PDF voi Syncfusion — loai exception, go mat khau.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/syncfusion_pdf_security.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

final _outDir = Directory('../spikes/pdf_text/out');

Uint8List _plain() {
  final d = sf.PdfDocument();
  d.pages.add().graphics.drawString(
      'secret page', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18));
  final b = Uint8List.fromList(d.saveSync());
  d.dispose();
  return b;
}

Uint8List _encrypted(String user, {String? owner}) {
  final d = sf.PdfDocument();
  d.pages.add().graphics.drawString(
      'secret page', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18));
  d.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
  d.security.userPassword = user;
  d.security.ownerPassword = owner ?? user;
  final b = Uint8List.fromList(d.saveSync());
  d.dispose();
  return b;
}

void main() {
  final log = StringBuffer();
  tearDownAll(() {
    _outDir.createSync(recursive: true);
    File('${_outDir.path}/password_report.txt')
        .writeAsStringSync(log.toString());
  });

  test('syncfusion tho: loai exception khi thieu / sai mat khau', () {
    final enc = _encrypted('abc');
    // 1. khong mat khau
    try {
      sf.PdfDocument(inputBytes: enc).dispose();
      log.writeln('khong mat khau: KHONG nem loi');
    } catch (e) {
      log.writeln('khong mat khau: ${e.runtimeType} | $e');
      if (e is ArgumentError) {
        log.writeln('  ArgumentError.name=${e.name} message=${e.message}');
      }
    }
    // 2. sai mat khau
    try {
      sf.PdfDocument(inputBytes: enc, password: 'sai').dispose();
      log.writeln('sai mat khau: KHONG nem loi');
    } catch (e) {
      log.writeln('sai mat khau: ${e.runtimeType} | $e');
    }
    // 3. mat khau rong chuoi
    try {
      sf.PdfDocument(inputBytes: enc, password: '').dispose();
      log.writeln('password="" : KHONG nem loi');
    } catch (e) {
      log.writeln('password="" : ${e.runtimeType} | $e');
    }
    // 4. dung -> go -> luu -> mo lai
    final doc = sf.PdfDocument(inputBytes: enc, password: 'abc');
    log.writeln('mo voi abc: OK, pages=${doc.pages.count}');
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final out = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    final re = sf.PdfDocument(inputBytes: out);
    log.writeln('mo lai khong mat khau sau go: OK, pages=${re.pages.count}');
    re.dispose();
    expect(true, isTrue);
  });

  test('SyncfusionPdfSecurity: isEncrypted/decrypt/encrypt', () async {
    const eng = SyncfusionPdfSecurity();
    final enc = _encrypted('abc');
    expect(await eng.isEncrypted(enc), isTrue);
    expect(await eng.isEncrypted(_plain()), isFalse);

    await expectLater(eng.decrypt(enc, 'sai'), throwsA(isA<WrongPassword>()));
    await expectLater(eng.decrypt(enc, ''), throwsA(isA<PasswordRequired>()));

    final dec = await eng.decrypt(enc, 'abc');
    expect(await eng.isEncrypted(dec), isFalse);
    final d = sf.PdfDocument(inputBytes: dec);
    expect(d.pages.count, 1);
    d.dispose();

    // encrypt roi decrypt (vong day du); file da co mat khau -> PasswordRequired.
    final enc2 = await eng.encrypt(_plain(), 'xyz');
    expect(await eng.isEncrypted(enc2), isTrue);
    await expectLater(
        eng.encrypt(enc2, 'q'), throwsA(isA<PasswordRequired>()));
    final dec2 = await eng.decrypt(enc2, 'xyz');
    expect(await eng.isEncrypted(dec2), isFalse);

    // owner-only password (user rong): mo duoc khong can mat khau?
    final ownerOnly = _encrypted('', owner: 'own');
    log.writeln('owner-only: isEncrypted=${await eng.isEncrypted(ownerOnly)}');
    final pdecOwner = await eng.decrypt(ownerOnly, '');
    log.writeln('owner-only decrypt(""): OK ${pdecOwner.length} bytes');
  });
}
