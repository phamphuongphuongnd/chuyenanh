// Kiểm thử hộp trắng A11 — lib/engines/pdf/syncfusion_pdf_security.dart.
// Mã bộ = mã ở test-output/whitebox/engines/syncfusion_pdf_security/buoc-5-du-lieu-thu.md.
// _open/_isEncrypted/_decrypt/_encrypt là hàm private ⇒ đi qua API công khai với PDF thật;
// nhánh trong _open được xác định bằng cách dò kiểu lỗi Syncfusion ném cho cùng dữ liệu.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/syncfusion_pdf_security.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<Uint8List> _samplePdf({String? userPassword, String? ownerPassword}) async {
  final doc = sf.PdfDocument();
  doc.pages.add().graphics.drawString(
    'Hello PDF Office',
    sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
  );
  if (userPassword != null || ownerPassword != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = userPassword ?? '';
    doc.security.ownerPassword = ownerPassword ?? userPassword ?? '';
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

Future<Object?> _capture(Future<Object?> f) =>
    f.then((v) => v, onError: (Object e) => e);

/// Mở thử bằng Syncfusion: null = mở được, ngược lại là lỗi gốc.
Object? _rawOpen(Uint8List bytes, {String? password}) {
  try {
    sf.PdfDocument(inputBytes: bytes, password: password).dispose();
    return null;
  } catch (e) {
    return e;
  }
}

String _text(Uint8List bytes, {String? password}) {
  final d = sf.PdfDocument(inputBytes: bytes, password: password);
  final t = sf.PdfTextExtractor(d).extractText();
  d.dispose();
  return t;
}

void main() {
  const engine = SyncfusionPdfSecurity();

  group('U1 _isEncrypted (qua isEncrypted)', () {
    test('IE-1 PDF thường ⇒ false (O1 S)', () async {
      expect(await engine.isEncrypted(await _samplePdf()), isFalse);
    });
    test('IE-1b PDF chỉ có owner-password ⇒ false (O1 S)', () async {
      final ownerOnly = await _samplePdf(ownerPassword: 'own');
      expect(_rawOpen(ownerOnly), isNull, reason: 'Syncfusion mở được không cần mật khẩu');
      expect(await engine.isEncrypted(ownerOnly), isFalse);
    });
    test('IE-2 PDF có user-password ⇒ true (O1 Đ, O2 Đ)', () async {
      final locked = await _samplePdf(userPassword: 'u');
      expect(_rawOpen(locked), isA<ArgumentError>());
      expect(await engine.isEncrypted(locked), isTrue);
    });
    test('IE-3 bytes rác ⇒ CorruptFile (O2 S)', () async {
      final junk = Uint8List.fromList(List.generate(64, (i) => i));
      final r = await _capture(engine.isEncrypted(junk));
      expect(r, isA<CorruptFile>());
    });
  });

  group('U2 _decrypt (qua decrypt)', () {
    test('DE-1 đúng mật khẩu ⇒ bytes không còn mật khẩu, giữ nội dung (O1 S)', () async {
      final locked = await _samplePdf(userPassword: 'secret');
      final r = await _capture(engine.decrypt(locked, 'secret'));
      expect(r, isA<Uint8List>());
      final plain = r as Uint8List;
      expect(_rawOpen(plain), isNull);
      expect(await engine.isEncrypted(plain), isFalse);
      expect(_text(plain), contains('Hello'));
    });
    test('DE-1b file không mật khẩu + mật khẩu bất kỳ ⇒ trả bản lưu lại bình thường (O1 S)', () async {
      final r = await _capture(engine.decrypt(await _samplePdf(), 'any'));
      expect(r, isA<Uint8List>());
      expect(_text(r as Uint8List), contains('Hello'));
    });
    test('DE-2 sai mật khẩu ⇒ WrongPassword (O1 Đ)', () async {
      final locked = await _samplePdf(userPassword: 'right');
      final r = await _capture(engine.decrypt(locked, 'wrong'));
      expect(r, isA<WrongPassword>());
    });
  });

  group('U3 _encrypt (qua encrypt)', () {
    test('EN-1 ownerPassword null ⇒ owner = user, AES-256 (O1 S, Q1 Đ)', () async {
      final r = await _capture(engine.encrypt(await _samplePdf(), 'user1'));
      expect(r, isA<Uint8List>());
      final locked = r as Uint8List;
      expect(latin1.decode(locked), contains('AESV3'), reason: 'AES-256 (/CFM /AESV3)');
      expect(await engine.isEncrypted(locked), isTrue);
      expect(_rawOpen(locked, password: 'user1'), isNull);
      expect(_rawOpen(locked, password: 'own'), isA<ArgumentError>());
    });
    test('EN-2 ownerPassword riêng ⇒ mở được bằng cả hai mật khẩu (Q1 S)', () async {
      final r = await _capture(
        engine.encrypt(await _samplePdf(), 'user1', ownerPassword: 'own'),
      );
      final locked = r as Uint8List;
      expect(_rawOpen(locked, password: 'user1'), isNull);
      expect(_rawOpen(locked, password: 'own'), isNull);
    });
    test('EN-3 file vào đang có mật khẩu ⇒ PasswordRequired (O1 Đ)', () async {
      final locked = await _samplePdf(userPassword: 'x');
      final r = await _capture(engine.encrypt(locked, 'y'));
      expect(r, isA<PasswordRequired>());
    });
  });

  group('U4 _open', () {
    test('OP-1 PDF hợp lệ ⇒ mở được (T1 S)', () async {
      final pdf = await _samplePdf();
      expect(_rawOpen(pdf), isNull);
      expect(await engine.isEncrypted(pdf), isFalse);
    });
    test('OP-3 lỗi name=password, không truyền mật khẩu ⇒ PasswordRequired (A Đ, PN Đ)', () async {
      final locked = await _samplePdf(userPassword: 'x');
      final raw = _rawOpen(locked);
      expect(raw, isA<ArgumentError>());
      expect((raw as ArgumentError).name, 'password');
      final r = await _capture(engine.encrypt(locked, 'y'));
      expect(r, isA<PasswordRequired>());
    });
    test('OP-4 lỗi name=password, mật khẩu rỗng ⇒ PasswordRequired (PN S, PE Đ)', () async {
      final locked = await _samplePdf(userPassword: 'x');
      expect((_rawOpen(locked, password: '') as ArgumentError).name, 'password');
      final r = await _capture(engine.decrypt(locked, ''));
      expect(r, isA<PasswordRequired>());
    });
    test('OP-5 lỗi name=password, mật khẩu sai ⇒ WrongPassword (PE S)', () async {
      final locked = await _samplePdf(userPassword: 'x');
      expect((_rawOpen(locked, password: 'z') as ArgumentError).name, 'password');
      final r = await _capture(engine.decrypt(locked, 'z'));
      expect(r, isA<WrongPassword>());
    });
    test('OP-6 ArgumentError không nói password, message null ⇒ CorruptFile (A S, B Đ, C Đ)', () async {
      final pdf = await _samplePdf();
      final cut = Uint8List.sublistView(pdf, 0, pdf.length - 10); // mất bảng xref
      final raw = _rawOpen(cut);
      expect(raw, isA<ArgumentError>());
      expect((raw as ArgumentError).name, isNot('password'));
      expect(raw.message, isNull);
      final r = await _capture(engine.isEncrypted(cut));
      expect(r, isA<CorruptFile>());
    });
    test('OP-8 ArgumentError có message không chứa password ⇒ CorruptFile (B S, C S, DD S)', () async {
      final junk = Uint8List.fromList(List.generate(64, (i) => i));
      final raw = _rawOpen(junk);
      expect(raw, isA<ArgumentError>());
      expect((raw as ArgumentError).name, isNot('password'));
      expect(raw.message, isNotNull);
      expect(raw.message.toString().toLowerCase(), isNot(contains('password')));
      final r = await _capture(engine.isEncrypted(junk));
      expect(r, isA<CorruptFile>());
    });
  });
}
