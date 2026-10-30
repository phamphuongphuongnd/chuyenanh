import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:pdf_office/features/translate/translate_languages.dart';

void main() {
  group('guessLanguageCode', () {
    test('chữ Hán → zh', () {
      expect(guessLanguageCode('今天天气很好，我们去公园散步吧。'), 'zh');
    });

    test('Hán + Kana → ja', () {
      expect(guessLanguageCode('今日はいい天気ですね。公園に行きましょう。'), 'ja');
      expect(guessLanguageCode('カタカナだけのテキスト'), 'ja');
    });

    test('Hangul → ko', () {
      expect(guessLanguageCode('오늘은 날씨가 좋네요. 공원에 갑시다.'), 'ko');
    });

    test('dấu tiếng Việt (dựng sẵn và NFD) → vi', () {
      expect(guessLanguageCode('Hôm nay trời đẹp, chúng ta đi dạo nhé.'), 'vi');
      expect(guessLanguageCode('Xin chào'), 'vi');
      // "Việt" viết dạng NFD: e + dấu mũ + dấu nặng.
      expect(guessLanguageCode('Tiệng Việt'), 'vi');
    });

    test('Latin không dấu (Anh, Indonesia) → en', () {
      expect(guessLanguageCode('The weather is nice today.'), 'en');
      expect(guessLanguageCode('Selamat pagi, apa kabar?'), 'en');
    });

    test('vài chữ có dấu lẻ trong văn bản tiếng Anh dài → vẫn en', () {
      expect(
        guessLanguageCode(
          'We met at a small café near the station and talked about the '
          'project plan for the next quarter in great detail.',
        ),
        'en',
      );
    });

    test('vài chữ Hán lẻ trong văn bản tiếng Anh dài → vẫn en', () {
      expect(
        guessLanguageCode(
          'The word 中 means middle and it appears in many place names '
          'across the whole region of eastern Asia.',
        ),
        'en',
      );
    });

    test('rỗng / chỉ số và ký hiệu → en', () {
      expect(guessLanguageCode(''), 'en');
      expect(guessLanguageCode('123 - 456 !!!'), 'en');
    });
  });

  group('translateLanguageFor', () {
    test('6 mã app → TranslateLanguage có bcpCode trùng', () {
      const expected = {
        'vi': TranslateLanguage.vietnamese,
        'en': TranslateLanguage.english,
        'zh': TranslateLanguage.chinese,
        'ja': TranslateLanguage.japanese,
        'ko': TranslateLanguage.korean,
        'id': TranslateLanguage.indonesian,
      };
      expect(kTranslateLanguageCodes.toSet(), expected.keys.toSet());
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(translateLanguageFor(key), value);
        expect(translateLanguageFor(key)!.bcpCode, key);
      }
    });

    test('mã lạ → null', () {
      expect(translateLanguageFor('fr'), isNull);
      expect(translateLanguageFor(''), isNull);
    });

    test('normalizeLanguageCode bỏ vùng/chữ viết', () {
      expect(normalizeLanguageCode('zh-Hans'), 'zh');
      expect(normalizeLanguageCode('en_US'), 'en');
      expect(normalizeLanguageCode('VI'), 'vi');
      expect(normalizeLanguageCode('fr'), isNull);
      expect(normalizeLanguageCode(null), isNull);
    });
  });

  group('defaultTargetCode', () {
    test('mặc định là ngôn ngữ app', () {
      expect(defaultTargetCode(appCode: 'vi', sourceCode: 'en'), 'vi');
    });

    test('trùng nguồn → tiếng Anh; nguồn đã là Anh → tiếng Việt', () {
      expect(defaultTargetCode(appCode: 'ja', sourceCode: 'ja'), 'en');
      expect(defaultTargetCode(appCode: 'en', sourceCode: 'en'), 'vi');
    });

    test('ngôn ngữ app ngoài 6 ngôn ngữ → en', () {
      expect(defaultTargetCode(appCode: 'fr', sourceCode: 'vi'), 'en');
    });
  });

  group('splitIntoBatches', () {
    test('chia đều và lô cuối ngắn hơn', () {
      final items = List.generate(7, (i) => i);
      expect(splitIntoBatches(items, 3), [
        [0, 1, 2],
        [3, 4, 5],
        [6],
      ]);
    });

    test('vừa khít, ít hơn một lô, rỗng', () {
      expect(splitIntoBatches([1, 2, 3, 4], 2), [
        [1, 2],
        [3, 4],
      ]);
      expect(splitIntoBatches([1, 2], 300), [
        [1, 2],
      ]);
      expect(splitIntoBatches(<int>[], 300), isEmpty);
    });

    test('650 đoạn với lô 300 → 300 + 300 + 50', () {
      final batches = splitIntoBatches(
        List.generate(650, (i) => 'p$i'),
        kTranslateBatchSize,
      );
      expect(batches.map((b) => b.length), [300, 300, 50]);
      expect(batches.last.first, 'p600');
    });

    test('size <= 0 → lỗi', () {
      expect(() => splitIntoBatches([1], 0), throwsArgumentError);
    });
  });

  test('cleanParagraphs bỏ đoạn rỗng và khoảng trắng hai đầu', () {
    expect(cleanParagraphs(['  a ', '', '   ', '\nb\n']), ['a', 'b']);
  });

  test('sampleForGuess chỉ lấy các đoạn đầu', () {
    final sample = sampleForGuess(['abc', 'def', 'ghi'], maxChars: 5);
    expect(sample, contains('abc'));
    expect(sample, contains('def'));
    expect(sample, isNot(contains('ghi')));
  });
}
