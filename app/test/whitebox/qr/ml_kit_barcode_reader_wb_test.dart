// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng A13 — app/lib/features/qr/ml_kit_barcode_reader.dart
// Thiết kế: test-output/whitebox/qr/ml_kit_barcode_reader/buoc-1..5. Expected chép từ Bước 5.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/qr/ml_kit_barcode_reader.dart';
import 'package:pdf_office/features/qr/qr_content.dart';

mlkit.Barcode _b(mlkit.BarcodeFormat f, {String? raw, String? display}) => mlkit.Barcode(
  type: mlkit.BarcodeType.text,
  format: f,
  displayValue: display,
  rawValue: raw,
  rawBytes: null,
  boundingBox: Rect.zero,
  cornerPoints: const [],
  value: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const ch = MethodChannel('google_mlkit_barcode_scanning');
  tearDown(() => m.setMockMethodCallHandler(ch, null));

  group('U1 codeFormatFromMlKit', () {
    final same = {
      mlkit.BarcodeFormat.qrCode: CodeFormat.qrCode,
      mlkit.BarcodeFormat.aztec: CodeFormat.aztec,
      mlkit.BarcodeFormat.dataMatrix: CodeFormat.dataMatrix,
      mlkit.BarcodeFormat.pdf417: CodeFormat.pdf417,
      mlkit.BarcodeFormat.ean13: CodeFormat.ean13,
      mlkit.BarcodeFormat.ean8: CodeFormat.ean8,
      mlkit.BarcodeFormat.upca: CodeFormat.upca,
      mlkit.BarcodeFormat.upce: CodeFormat.upce,
      mlkit.BarcodeFormat.code128: CodeFormat.code128,
      mlkit.BarcodeFormat.code39: CodeFormat.code39,
      mlkit.BarcodeFormat.code93: CodeFormat.code93,
      mlkit.BarcodeFormat.codabar: CodeFormat.codabar,
      mlkit.BarcodeFormat.itf: CodeFormat.itf,
    };
    var i = 1;
    for (final e in same.entries) {
      test('1-${i++} ${e.key.name} ⇒ ${e.value.name}', () => expect(codeFormatFromMlKit(e.key), e.value));
    }
    test('1-14 all ⇒ unknown', () => expect(codeFormatFromMlKit(mlkit.BarcodeFormat.all), CodeFormat.unknown));
    test('1-15 unknown ⇒ unknown', () => expect(codeFormatFromMlKit(mlkit.BarcodeFormat.unknown), CodeFormat.unknown));
  });

  group('U2 scannedCodesFromMlKit', () {
    const qr = mlkit.BarcodeFormat.qrCode;
    test('2-1 rỗng ⇒ rỗng', () => expect(scannedCodesFromMlKit(const []), isEmpty));
    test('2-2 1 mã raw ⇒ 1 ScannedCode', () {
      expect(scannedCodesFromMlKit([_b(qr, raw: 'https://a.b')]), [
        const ScannedCode(format: CodeFormat.qrCode, raw: 'https://a.b'),
      ]);
    });
    test('2-3 raw null ⇒ dùng displayValue', () {
      expect(scannedCodesFromMlKit([_b(qr, display: 'ABC')]), [const ScannedCode(format: CodeFormat.qrCode, raw: 'ABC')]);
    });
    test('2-4 không nội dung ⇒ bỏ', () => expect(scannedCodesFromMlKit([_b(qr)]), isEmpty));
    test('2-5 raw rỗng ⇒ bỏ', () => expect(scannedCodesFromMlKit([_b(qr, raw: '')]), isEmpty));
    test('2-6 bỏ trùng, giữ thứ tự', () {
      expect(
        scannedCodesFromMlKit([
          _b(qr, raw: 'X'),
          _b(mlkit.BarcodeFormat.ean13, raw: 'X'),
          _b(qr, raw: 'X'),
          _b(qr, raw: 'Y'),
        ]),
        [
          const ScannedCode(format: CodeFormat.qrCode, raw: 'X'),
          const ScannedCode(format: CodeFormat.ean13, raw: 'X'),
          const ScannedCode(format: CodeFormat.qrCode, raw: 'Y'),
        ],
      );
    });
  });

  group('U3 MlKitBarcodeReader.read', () {
    late Directory tmp;
    late String img;
    late List<String> calls;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('wb_mlkit_');
      img = p.join(tmp.path, 'a.jpg');
      File(img).writeAsBytesSync([1, 2, 3]);
      calls = [];
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    void mock({bool scanThrows = false, bool closeThrows = false}) {
      m.setMockMethodCallHandler(ch, (c) async {
        calls.add(c.method);
        if (c.method == 'vision#startBarcodeScanner') {
          if (scanThrows) throw PlatformException(code: 'scan');
          return <Object>[];
        }
        if (c.method == 'vision#closeBarcodeScanner' && closeThrows) {
          throw PlatformException(code: 'close');
        }
        return null;
      });
    }

    Future<Object?> read(String path) =>
        const MlKitBarcodeReader().read(path).then((v) => v as Object?, onError: (Object e) => e);

    test('3-1 ảnh có thật ⇒ danh sách, đóng scanner', () async {
      mock();
      final r = await read(img);
      expect(calls, ['vision#startBarcodeScanner', 'vision#closeBarcodeScanner']);
      expect(r, isEmpty);
    });
    test('3-2 ảnh không tồn tại ⇒ CorruptFile, không gọi plugin', () async {
      mock();
      final r = await read(p.join(tmp.path, 'none.jpg'));
      expect(calls, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('3-3 plugin ném ⇒ AppError, vẫn đóng', () async {
      mock(scanThrows: true);
      final r = await read(img);
      expect(calls, ['vision#startBarcodeScanner', 'vision#closeBarcodeScanner']);
      expect(r, isA<AppError>());
    });
    test('3-4 close ném ⇒ vẫn trả kết quả', () async {
      mock(closeThrows: true);
      final r = await read(img);
      expect(calls.last, 'vision#closeBarcodeScanner');
      expect(r, isEmpty);
    });
  });
}
