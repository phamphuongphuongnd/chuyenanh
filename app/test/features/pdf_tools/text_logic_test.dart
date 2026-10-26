import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/text_fonts.dart';
import 'package:pdf_office/features/pdf_tools/logic/vi_nfc.dart';

void main() {
  group('composeVietnamese', () {
    test('NFD -> NFC: dấu thanh, dấu mũ, dấu chồng', () {
      expect(composeVietnamese('Ha\u0300 No\u0323\u0302i'), 'Hà Nội');
      expect(composeVietnamese('e\u0323\u0302'), 'ệ');
      expect(composeVietnamese('e\u0302\u0323'), 'ệ'); // thứ tự dấu bất kỳ
      expect(composeVietnamese('u\u031b\u0323'), 'ự');
      expect(composeVietnamese('A\u0306\u0301'), 'Ắ');
      expect(composeVietnamese('Cafe\u0301'), 'Café');
    });
    test('đã NFC / không phải tiếng Việt thì giữ nguyên', () {
      expect(composeVietnamese('Hà Nội 河内 hello'), 'Hà Nội 河内 hello');
      expect(composeVietnamese(''), '');
    });
    test('dấu rời không có chữ gốc ghép được thì giữ nguyên', () {
      expect(composeVietnamese('b\u0301'), 'b\u0301');
      expect(composeVietnamese('\u0301'), '\u0301');
    });
  });

  group('dominantScript / fontAssetCandidates', () {
    test('nhận hệ chữ', () {
      expect(dominantScript('Hello Hà Nội'), TextScript.latin);
      expect(dominantScript('机密'), TextScript.han);
      expect(dominantScript('社外秘 ひみつ'), TextScript.kana);
      expect(dominantScript('기밀 CONFIDENTIAL'), TextScript.hangul);
      expect(dominantScript(''), TextScript.latin);
    });
    test('đường dẫn font theo hệ chữ', () {
      expect(fontAssetCandidates('abc').first, endsWith('NotoSans-Regular.ttf'));
      expect(fontAssetCandidates('机密').single, endsWith('NotoSansSC-Regular.ttf'));
      expect(fontAssetCandidates('ひ').single, endsWith('NotoSansJP-Regular.ttf'));
      expect(fontAssetCandidates('기').single, endsWith('NotoSansKR-Regular.ttf'));
    });
  });
}
