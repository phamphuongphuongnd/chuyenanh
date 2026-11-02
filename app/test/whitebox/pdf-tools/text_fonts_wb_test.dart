// Kiểm thử hộp trắng (A03) cho lib/features/pdf_tools/logic/text_fonts.dart.
// Thiết kế: test-output/whitebox/pdf-tools/text_fonts/buoc-5-du-lieu-thu.md — expected chép từ Bước 5.
// Hàm private _isHangul/_isKana/_isHan kiểm qua dominantScript với chuỗi 1 ký tự.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/text_fonts.dart';

TextScript ch(int c) => dominantScript(String.fromCharCode(c));

void main() {
  group('U1 _isHangul', () {
    test('U1.1 H1Đ H2Đ: U+AC00, biên U+D7AF ⇒ hangul', () {
      expect(ch(0xAC00), TextScript.hangul);
      expect(ch(0xD7AF), TextScript.hangul);
    });
    test('U1.2 H2S: U+E000 ⇒ latin', () => expect(ch(0xE000), TextScript.latin));
    test('U1.3 H1S H3Đ H4Đ: U+1100, biên U+11FF ⇒ hangul', () {
      expect(ch(0x1100), TextScript.hangul);
      expect(ch(0x11FF), TextScript.hangul);
    });
    test('U1.4 H4S H5S: U+2000 ⇒ latin', () => expect(ch(0x2000), TextScript.latin));
    test('U1.5 H5Đ H6Đ: U+3131, biên U+318F ⇒ hangul', () {
      expect(ch(0x3131), TextScript.hangul);
      expect(ch(0x318F), TextScript.hangul);
    });
    test('U1.6 H3S H5S: A ⇒ latin', () => expect(ch(0x41), TextScript.latin));
    test('U1.7 H6S: U+3190 ⇒ latin', () => expect(ch(0x3190), TextScript.latin));
  });

  group('U2 _isKana', () {
    test('U2.1 K1Đ K2Đ: U+3042, biên U+30FF ⇒ kana', () {
      expect(ch(0x3042), TextScript.kana);
      expect(ch(0x30FF), TextScript.kana);
    });
    test('U2.2 K1S K3S: A ⇒ latin', () => expect(ch(0x41), TextScript.latin));
    test('U2.3 K2S K3S: U+3105 ⇒ latin', () => expect(ch(0x3105), TextScript.latin));
    test('U2.4 K3Đ K4Đ: U+31F0, biên U+31FF ⇒ kana', () {
      expect(ch(0x31F0), TextScript.kana);
      expect(ch(0x31FF), TextScript.kana);
    });
    test('U2.5 K4S: U+3250 ⇒ latin', () => expect(ch(0x3250), TextScript.latin));
  });

  group('U3 _isHan', () {
    test('U3.1 N1Đ N2Đ: U+4E00, biên U+9FFF ⇒ han', () {
      expect(ch(0x4E00), TextScript.han);
      expect(ch(0x9FFF), TextScript.han);
    });
    test('U3.2 N2S: U+A000 ⇒ latin', () => expect(ch(0xA000), TextScript.latin));
    test('U3.3 N3Đ N4Đ: U+3400, biên U+4DBF ⇒ han', () {
      expect(ch(0x3400), TextScript.han);
      expect(ch(0x4DBF), TextScript.han);
    });
    test('U3.4 N4S: U+4DC0 ⇒ latin', () => expect(ch(0x4DC0), TextScript.latin));
    test('U3.5 N3S N5S N7S: A ⇒ latin', () => expect(ch(0x41), TextScript.latin));
    test('U3.6 N5Đ N6Đ: U+20000, biên U+2A6DF ⇒ han', () {
      expect(ch(0x20000), TextScript.han);
      expect(ch(0x2A6DF), TextScript.han);
    });
    test('U3.7 N6S N8S: U+2A6E0 ⇒ latin', () => expect(ch(0x2A6E0), TextScript.latin));
    test('U3.8 N7Đ N8Đ: U+F900, biên U+FAFF ⇒ han', () {
      expect(ch(0xF900), TextScript.han);
      expect(ch(0xFAFF), TextScript.han);
    });
    test('U3.9 N8S: U+FB00 ⇒ latin', () => expect(ch(0xFB00), TextScript.latin));
  });

  group('U4 dominantScript', () {
    test('U4.1 a ⇒ latin', () => expect(dominantScript('a'), TextScript.latin));
    test('U4.2 rỗng ⇒ latin', () => expect(dominantScript(''), TextScript.latin));
    test('U4.3 기 ⇒ hangul', () => expect(dominantScript('기'), TextScript.hangul));
    test('U4.4 ひ ⇒ kana', () => expect(dominantScript('ひ'), TextScript.kana));
    test('U4.5 机 ⇒ han', () => expect(dominantScript('机'), TextScript.han));
    test('U4.6 机ひ ⇒ kana (kana thắng Hán)', () {
      expect(dominantScript('机ひ'), TextScript.kana);
    });
    test('U4.7 ひ기 / dòng trộn ⇒ hangul', () {
      expect(dominantScript('ひ기'), TextScript.hangul);
      expect(dominantScript('Hà Nội 河内 하노이 ハノイ'), TextScript.hangul);
    });
  });

  group('U5 fontAssetCandidates', () {
    test('U5.1 Hàn ⇒ KR', () {
      expect(fontAssetCandidates('기밀'), ['assets/fonts/NotoSansKR-Regular.ttf']);
    });
    test('U5.2 kana ⇒ JP', () {
      expect(fontAssetCandidates('ひみつ'), ['assets/fonts/NotoSansJP-Regular.ttf']);
    });
    test('U5.3 Hán ⇒ SC', () {
      expect(fontAssetCandidates('机密'), ['assets/fonts/NotoSansSC-Regular.ttf']);
    });
    test('U5.4 Latin/Việt ⇒ NotoSans .ttf đầu tiên', () {
      expect(fontAssetCandidates('Hà Nội').first, 'assets/fonts/NotoSans-Regular.ttf');
    });
  });
}
