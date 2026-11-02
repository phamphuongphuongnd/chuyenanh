// Kiểm thử hộp trắng (A15) — translate_languages.dart. Mã bộ = <đơn vị>-<đường> theo
// test-output/whitebox/translate/translate_languages/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:pdf_office/features/translate/translate_languages.dart';

String _c(int rune) => String.fromCharCode(rune);

void main() {
  group('U1 translateLanguageFor', () {
    const cases = <String, TranslateLanguage?>{
      '1-1': TranslateLanguage.vietnamese,
      '1-2': TranslateLanguage.english,
      '1-3': TranslateLanguage.chinese,
      '1-4': TranslateLanguage.japanese,
      '1-5': TranslateLanguage.korean,
      '1-6': TranslateLanguage.indonesian,
      '1-7': null,
    };
    const input = {
      '1-1': 'vi',
      '1-2': 'en',
      '1-3': 'zh',
      '1-4': 'ja',
      '1-5': 'ko',
      '1-6': 'id',
      '1-7': 'fr',
    };
    for (final e in cases.entries) {
      test('${e.key} ${input[e.key]} ⇒ ${e.value}', () {
        expect(translateLanguageFor(input[e.key]!), e.value);
      });
    }
  });

  group('U2 normalizeLanguageCode', () {
    test('2-1 null ⇒ null', () => expect(normalizeLanguageCode(null), isNull));
    test('2-2 zh-Hans ⇒ zh', () => expect(normalizeLanguageCode('zh-Hans'), 'zh'));
    test('2-3 fr ⇒ null (ngoài 6 ngôn ngữ)', () => expect(normalizeLanguageCode('fr'), isNull));
  });

  group('U3 guessLanguageCode', () {
    final cases = <String, (String, int, String)>{
      '3-1 a': ('a', 4000, 'en'),
      '3-2 rỗng': ('', 4000, 'en'),
      '3-3 chữ số': ('1', 4000, 'en'),
      '3-4 maxChars 1, a中': ('a中', 1, 'en'),
      '3-5 Hangul': ('가', 4000, 'ko'),
      '3-6 Kana': ('カ', 4000, 'ja'),
      '3-7 Hán': ('中', 4000, 'zh'),
      '3-8 Hán < 20%': ('中aaaaa', 4000, 'en'),
      '3-9 ạ dựng sẵn': ('ạ', 4000, 'vi'),
      '3-10 dấu kết hợp đứng riêng': ('́', 4000, 'en'),
      '3-11 à': ('à', 4000, 'vi'),
      '3-12 café trong câu Anh dài': (
        'We met at a small café near the station and talked a lot',
        4000,
        'en',
      ),
      '3-13 aa': ('aa', 4000, 'en'),
      '3-14 가a': ('가a', 4000, 'ko'),
      '3-15 カa': ('カa', 4000, 'ja'),
      '3-16 中a': ('中a', 4000, 'zh'),
      '3-17 a + dấu sắc NFD': ('á', 4000, 'vi'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$3}', () {
        expect(guessLanguageCode(e.value.$1, maxChars: e.value.$2), e.value.$3);
      });
    }
  });

  group('U4 defaultTargetCode', () {
    test('4-1 app vi, nguồn en ⇒ vi', () {
      expect(defaultTargetCode(appCode: 'vi', sourceCode: 'en'), 'vi');
    });
    test('4-2 app fr (ngoài 6), nguồn vi ⇒ en', () {
      expect(defaultTargetCode(appCode: 'fr', sourceCode: 'vi'), 'en');
    });
    test('4-3 app ja trùng nguồn ja ⇒ en', () {
      expect(defaultTargetCode(appCode: 'ja', sourceCode: 'ja'), 'en');
    });
    test('4-4 app en trùng nguồn en ⇒ vi', () {
      expect(defaultTargetCode(appCode: 'en', sourceCode: 'en'), 'vi');
    });
  });

  group('U5 splitIntoBatches', () {
    test('5-1 size 0 ⇒ ArgumentError', () {
      expect(() => splitIntoBatches([1], 0), throwsArgumentError);
    });
    test('5-2 [1,2], 300 ⇒ một lô ngắn', () {
      expect(splitIntoBatches([1, 2], 300), [
        [1, 2],
      ]);
    });
    test('5-3 [1,2,3,4], 2 ⇒ hai lô đủ', () {
      expect(splitIntoBatches([1, 2, 3, 4], 2), [
        [1, 2],
        [3, 4],
      ]);
    });
  });

  group('U6 sampleForGuess', () {
    test('6-1 [] ⇒ rỗng', () => expect(sampleForGuess(const []), ''));
    test('6-2 [abc], 5 ⇒ có abc', () {
      expect(sampleForGuess(['abc'], maxChars: 5), contains('abc'));
    });
    test('6-3 [abc,def,ghi], 5 ⇒ abc, def; không ghi', () {
      final s = sampleForGuess(['abc', 'def', 'ghi'], maxChars: 5);
      expect(s, contains('abc'));
      expect(s, contains('def'));
      expect(s, isNot(contains('ghi')));
    });
  });

  // Hàm private: kiểm qua guessLanguageCode (1 ký tự). Đ ⇒ ngôn ngữ tương ứng, S ⇒ 'en'.
  group('U7 _isHangul (qua guessLanguageCode)', () {
    final cases = <String, (int, String)>{
      '7-1 U+AC00': (0xAC00, 'ko'),
      '7-2 U+E000': (0xE000, 'en'),
      '7-3 A': (0x41, 'en'),
      '7-4 U+1100': (0x1100, 'ko'),
      '7-5 U+1200': (0x1200, 'en'),
      '7-6 U+3130': (0x3130, 'ko'),
      '7-7 U+3190': (0x3190, 'en'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$2}', () {
        expect(guessLanguageCode(_c(e.value.$1)), e.value.$2);
      });
    }
  });

  group('U8 _isKana (qua guessLanguageCode)', () {
    final cases = <String, (int, String)>{
      '8-1 U+3040': (0x3040, 'ja'),
      '8-2 U+30A0': (0x30A0, 'ja'),
      '8-3 U+3100': (0x3100, 'en'),
      '8-4 U+31F0': (0x31F0, 'ja'),
      '8-5 U+3200': (0x3200, 'en'),
      '8-6 U+FF66': (0xFF66, 'ja'),
      '8-7 U+FFA0': (0xFFA0, 'en'),
      '8-8 A': (0x41, 'en'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$2}', () {
        expect(guessLanguageCode(_c(e.value.$1)), e.value.$2);
      });
    }
  });

  group('U9 _isHan (qua guessLanguageCode)', () {
    final cases = <String, (int, String)>{
      '9-1 U+4E00': (0x4E00, 'zh'),
      '9-2 U+A000': (0xA000, 'en'),
      '9-3 U+F900': (0xF900, 'zh'),
      '9-4 U+FB00': (0xFB00, 'en'),
      '9-5 U+20000': (0x20000, 'zh'),
      '9-6 U+2A6E0': (0x2A6E0, 'en'),
      '9-7 U+3000': (0x3000, 'en'),
      '9-8 U+3400': (0x3400, 'zh'),
      '9-9 U+4DC0': (0x4DC0, 'en'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$2}', () {
        expect(guessLanguageCode(_c(e.value.$1)), e.value.$2);
      });
    }
  });

  // '中' + c×5: c là chữ Latin ⇒ CJK 1/6 < 20% ⇒ 'en'; c không phải chữ ⇒ 'zh'.
  group('U10 _isLatinLetter (qua guessLanguageCode)', () {
    final cases = <String, (int, String)>{
      '10-1 A': (0x41, 'en'),
      '10-2 a': (0x61, 'en'),
      '10-3 [': (0x5B, 'zh'),
      '10-4 {': (0x7B, 'zh'),
      '10-5 Ä': (0xC4, 'en'),
      '10-6 ×': (0xD7, 'zh'),
      '10-7 ÷': (0xF7, 'zh'),
      '10-8 U+0250': (0x250, 'zh'),
      '10-9 1': (0x31, 'zh'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$2}', () {
        expect(guessLanguageCode('中${_c(e.value.$1) * 5}'), e.value.$2);
      });
    }
  });

  // 'a' + c: c là dấu tiếng Việt ⇒ 'vi'; không ⇒ 'en'.
  group('U11 _isVietnameseMark (qua guessLanguageCode)', () {
    final cases = <String, (int, String)>{
      '11-1 ạ': (0x1EA1, 'vi'),
      '11-2 U+1F00': (0x1F00, 'en'),
      '11-3 à': (0xE0, 'vi'),
      '11-4 U+0300': (0x300, 'vi'),
      '11-5 U+0301': (0x301, 'vi'),
      '11-6 U+0303': (0x303, 'vi'),
      '11-7 U+0309': (0x309, 'vi'),
      '11-8 U+0323': (0x323, 'vi'),
      '11-9 U+0302': (0x302, 'vi'),
      '11-10 U+0306': (0x306, 'vi'),
      '11-11 U+031B': (0x31B, 'vi'),
      '11-12 b': (0x62, 'en'),
    };
    for (final e in cases.entries) {
      test('${e.key} ⇒ ${e.value.$2}', () {
        expect(guessLanguageCode('a${_c(e.value.$1)}'), e.value.$2);
      });
    }
  });
}
