// Kiểm thử hộp trắng (A15) — tts_logic.dart. Mã bộ theo
// test-output/whitebox/tts/tts_logic/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

List<String> _names(List<TtsVoice> v) => [for (final x in v) x.name];

void main() {
  group('U1 ttsLocaleFor', () {
    test('1-1 vi ⇒ vi-VN', () => expect(ttsLocaleFor('vi'), 'vi-VN'));
    test('1-2 en_GB ⇒ en-GB', () => expect(ttsLocaleFor('en_GB'), 'en-GB'));
    test('1-3 zh-Hans ⇒ zh-CN', () => expect(ttsLocaleFor('zh-Hans'), 'zh-CN'));
    test('1-4 fr ⇒ fr', () => expect(ttsLocaleFor('fr'), 'fr'));
  });

  group('U2 ttsSpeedLabel', () {
    test('2-1 1.0 ⇒ 1×', () => expect(ttsSpeedLabel(1.0), '1×'));
    test('2-2 0.75 ⇒ 0.75×', () => expect(ttsSpeedLabel(0.75), '0.75×'));
  });

  group('U3 splitForTts', () {
    test('3-1 đoạn ngắn ⇒ giữ nguyên', () => expect(splitForTts('A.'), ['A.']));
    test('3-2 maxLength 0 ⇒ AssertionError', () {
      expect(() => splitForTts('A.', maxLength: 0), throwsA(isA<AssertionError>()));
    });
    test('3-3 chỉ khoảng trắng ⇒ rỗng', () => expect(splitForTts('   '), isEmpty));
    test('3-4 ba câu, max 6 ⇒ mỗi câu một phần', () {
      expect(splitForTts('Một. Hai. Ba.', maxLength: 6), ['Một.', 'Hai.', 'Ba.']);
    });
    test('3-5 không dấu câu, max 5 ⇒ cắt ở khoảng trắng', () {
      expect(splitForTts('aaaa bbbb', maxLength: 5), ['aaaa', 'bbbb']);
    });
    test('3-6 câu CJK hết ở 。 ⇒ chia theo 。', () {
      expect(splitForTts('今天。明天。', maxLength: 3), ['今天。', '明天。']);
    });
    test('3-7 câu ngắn gộp chung một phần', () {
      expect(splitForTts('A. B. C.', maxLength: 7), ['A. B.', 'C.']);
    });
    test('3-8 câu dài sau câu ngắn ⇒ câu ngắn riêng, câu dài cắt cứng', () {
      expect(splitForTts('A. xxxxxxxx', maxLength: 5), ['A.', 'xxxxx', 'xxx']);
    });
    test('3-9 câu dài ở giữa ⇒ thứ tự giữ nguyên', () {
      expect(
        splitForTts('A. xxxxxxxx. B.', maxLength: 5),
        ['A.', 'xxxxx', 'xxx.', 'B.'],
      );
    });
  });

  group('U4 flush (qua splitForTts)', () {
    test('4-1 bộ đệm rỗng ⇒ không thêm phần rỗng', () {
      final r = splitForTts('aaaa bbbb', maxLength: 5);
      expect(r.every((p) => p.isNotEmpty), isTrue);
      expect(r, ['aaaa', 'bbbb']);
    });
    test('4-2 bộ đệm có chữ ⇒ thêm phần', () {
      expect(splitForTts('Một. Hai.', maxLength: 6), ['Một.', 'Hai.']);
    });
  });

  group('U5 _splitLong (qua splitForTts)', () {
    test('5-1 câu dài vì khoảng trắng đuôi ⇒ trim rồi giữ nguyên', () {
      expect(splitForTts('abcd.  efg', maxLength: 5), ['abcd.', 'efg']);
    });
    test('5-2 chuỗi liền ⇒ cắt cứng', () {
      expect(splitForTts('x' * 12, maxLength: 5), ['xxxxx', 'xxxxx', 'xx']);
    });
    test('5-3 có khoảng trắng ⇒ cắt ở khoảng trắng', () {
      expect(splitForTts('aaa bbb ccc', maxLength: 5), ['aaa', 'bbb', 'ccc']);
    });
  });

  group('U6 TtsSegment ==', () {
    const s = TtsSegment(1, 'a');
    test('6-1 khác kiểu ⇒ false', () => expect(s == ('x' as Object), isFalse));
    test('6-2 giống ⇒ true', () => expect(s == const TtsSegment(1, 'a'), isTrue));
    test('6-3 khác đoạn ⇒ false', () => expect(s == const TtsSegment(2, 'a'), isFalse));
    test('6-4 khác chữ ⇒ false', () => expect(s == const TtsSegment(1, 'b'), isFalse));
  });

  group('U7 TtsVoice.toMap', () {
    test('7-1 không identifier ⇒ không có khoá identifier', () {
      expect(
        const TtsVoice(name: 'A', locale: 'vi-VN').toMap(),
        {'name': 'A', 'locale': 'vi-VN'},
      );
    });
    test('7-2 có identifier ⇒ có khoá', () {
      expect(
        const TtsVoice(name: 'A', locale: 'vi-VN', identifier: 'id1').toMap(),
        {'name': 'A', 'locale': 'vi-VN', 'identifier': 'id1'},
      );
    });
  });

  group('U8 TtsVoice ==', () {
    const v = TtsVoice(name: 'A', locale: 'vi-VN', identifier: 'i');
    test('8-1 khác kiểu ⇒ false', () => expect(v == ('A' as Object), isFalse));
    test('8-2 khác tên ⇒ false', () {
      expect(v == const TtsVoice(name: 'B', locale: 'vi-VN', identifier: 'i'), isFalse);
    });
    test('8-3 khác locale ⇒ false', () {
      expect(v == const TtsVoice(name: 'A', locale: 'en-US', identifier: 'i'), isFalse);
    });
    test('8-4 khác identifier ⇒ false', () {
      expect(v == const TtsVoice(name: 'A', locale: 'vi-VN'), isFalse);
    });
    test('8-5 giống hệt ⇒ true', () {
      expect(v == const TtsVoice(name: 'A', locale: 'vi-VN', identifier: 'i'), isTrue);
    });
  });

  group('U9 filterVoices', () {
    const a = {'name': 'A', 'locale': 'vi-VN'};
    test('9-1 1 giọng đúng vùng ⇒ [A]', () => expect(_names(filterVoices([a], 'vi-VN')), ['A']));
    test('9-2 raw null ⇒ []', () => expect(filterVoices(null, 'vi-VN'), isEmpty));
    test('9-3 list rỗng ⇒ []', () => expect(filterVoices(const [], 'vi-VN'), isEmpty));
    test('9-4 phần tử không phải Map ⇒ bỏ', () {
      expect(filterVoices(['rác'], 'vi-VN'), isEmpty);
    });
    test('9-5 thiếu name ⇒ bỏ', () {
      expect(filterVoices([{'locale': 'vi-VN'}], 'vi-VN'), isEmpty);
    });
    test('9-6 name không phải chuỗi ⇒ dùng toString', () {
      expect(_names(filterVoices([{'name': 7, 'locale': 'vi-VN'}], 'vi-VN')), ['7']);
    });
    test('9-7 thiếu locale ⇒ bỏ', () {
      expect(filterVoices([{'name': 'A'}], 'vi-VN'), isEmpty);
    });
    test('9-8 name rỗng ⇒ bỏ', () {
      expect(filterVoices([{'name': '', 'locale': 'vi-VN'}], 'vi-VN'), isEmpty);
    });
    test('9-9 locale rỗng ⇒ bỏ', () {
      expect(filterVoices([{'name': 'A', 'locale': ''}], 'vi-VN'), isEmpty);
    });
    test('9-10 giọng cần mạng ⇒ bỏ', () {
      expect(
        filterVoices([{'name': 'A', 'locale': 'vi-VN', 'network_required': '1'}], 'vi-VN'),
        isEmpty,
      );
    });
    test('9-11 giọng offline (network_required 0) ⇒ giữ', () {
      expect(
        _names(filterVoices([{'name': 'A', 'locale': 'vi-VN', 'network_required': '0'}], 'vi-VN')),
        ['A'],
      );
    });
    test('9-12 giọng chưa tải (notInstalled) ⇒ bỏ', () {
      expect(
        filterVoices([{'name': 'A', 'locale': 'vi-VN', 'features': 'notInstalled'}], 'vi-VN'),
        isEmpty,
      );
    });
    test('9-13 có features khác ⇒ giữ', () {
      expect(
        _names(filterVoices([{'name': 'A', 'locale': 'vi-VN', 'features': 'embeddedTts'}], 'vi-VN')),
        ['A'],
      );
    });
    test('9-14 khác ngôn ngữ ⇒ bỏ', () {
      expect(filterVoices([{'name': 'E', 'locale': 'en-US'}], 'vi-VN'), isEmpty);
    });
    test('9-15 trùng name|locale ⇒ giữ 1', () {
      expect(_names(filterVoices([a, a], 'vi-VN')), ['A']);
    });
    test('9-16 có identifier ⇒ giữ identifier', () {
      final v = filterVoices([{'name': 'Linh', 'locale': 'vi-VN', 'identifier': 'com.apple.linh'}], 'vi-VN');
      expect(v.single.identifier, 'com.apple.linh');
    });
    test('9-17 locale chỉ ngôn ngữ (vi) ⇒ giọng vi-VN tính là đúng', () {
      expect(_names(filterVoices([a], 'vi')), ['A']);
    });
    test('9-18 không có đúng vùng ⇒ lấy cùng ngôn ngữ', () {
      expect(_names(filterVoices([{'name': 'G', 'locale': 'en-GB'}], 'en-US')), ['G']);
    });
    test('9-19 có cả đúng vùng và cùng ngôn ngữ ⇒ chỉ đúng vùng', () {
      expect(
        _names(filterVoices([
          {'name': 'G', 'locale': 'en-GB'},
          {'name': 'U', 'locale': 'en-US'},
        ], 'en-US')),
        ['U'],
      );
    });
    test('9-20 rác rồi giọng hợp lệ ⇒ giọng hợp lệ', () {
      expect(_names(filterVoices(['rác', a], 'vi-VN')), ['A']);
    });
    test('9-21 locale dạng vi_VN ⇒ chuẩn hoá vi-VN, giữ', () {
      final v = filterVoices([{'name': 'A', 'locale': 'vi_VN'}], 'vi-VN');
      expect(v.single.locale, 'vi-VN');
    });
  });

  group('U10 ttsVoiceDisplayName', () {
    test('10-1 tên người ⇒ giữ', () {
      expect(ttsVoiceDisplayName(const TtsVoice(name: 'Linh', locale: 'vi-VN')), 'Linh');
    });
    test('10-2 tên mã Android ⇒ null', () {
      expect(ttsVoiceDisplayName(const TtsVoice(name: 'vi-vn-x-gft-local', locale: 'vi-VN')), isNull);
    });
    test('10-3 có # ⇒ null', () {
      expect(ttsVoiceDisplayName(const TtsVoice(name: 'Linh#1', locale: 'vi-VN')), isNull);
    });
    test('10-4 có -x- ⇒ null', () {
      expect(ttsVoiceDisplayName(const TtsVoice(name: 'Voice-x-1', locale: 'vi-VN')), isNull);
    });
  });
}
