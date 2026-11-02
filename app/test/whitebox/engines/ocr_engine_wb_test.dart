// Kiểm thử hộp trắng A11 — lib/engines/ocr/ocr_engine.dart.
// Mã bộ = mã ở test-output/whitebox/engines/ocr_engine/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';

void main() {
  group('U1 ocrScriptForLanguage', () {
    test('OC-1 zh ⇒ chinese (D1 Đ)', () {
      expect(ocrScriptForLanguage('zh'), OcrScript.chinese);
    });
    test('OC-2 ja ⇒ japanese (D1 S, D2 Đ)', () {
      expect(ocrScriptForLanguage('ja'), OcrScript.japanese);
    });
    test('OC-3 ko ⇒ korean (D2 S, D3 Đ)', () {
      expect(ocrScriptForLanguage('ko'), OcrScript.korean);
    });
    test('OC-4 vi / en / id / mã lạ ⇒ latin (D3 S)', () {
      for (final code in ['vi', 'en', 'id', 'fr', '']) {
        expect(ocrScriptForLanguage(code), OcrScript.latin, reason: code);
      }
    });
  });
}
