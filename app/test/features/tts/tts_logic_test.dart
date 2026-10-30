import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

void main() {
  group('ttsLocaleFor', () {
    test('6 ngôn ngữ app → locale giọng đọc', () {
      expect(ttsLocaleFor('vi'), 'vi-VN');
      expect(ttsLocaleFor('en'), 'en-US');
      expect(ttsLocaleFor('zh'), 'zh-CN');
      expect(ttsLocaleFor('ja'), 'ja-JP');
      expect(ttsLocaleFor('ko'), 'ko-KR');
      expect(ttsLocaleFor('id'), 'id-ID');
    });

    test('không phân biệt hoa thường, bỏ khoảng trắng', () {
      expect(ttsLocaleFor(' VI '), 'vi-VN');
    });

    test('mã đã có vùng giữ nguyên, đổi _ thành -', () {
      expect(ttsLocaleFor('en_GB'), 'en-GB');
      expect(ttsLocaleFor('pt-br'), 'pt-BR');
    });

    test('mã lạ trả lại như cũ', () {
      expect(ttsLocaleFor('fr'), 'fr');
      expect(ttsLocaleFor('zh_Hant'), 'zh-CN');
    });
  });

  group('splitForTts', () {
    test('đoạn ngắn giữ nguyên (đã trim), đoạn rỗng → rỗng', () {
      expect(splitForTts('  Xin chào.  '), ['Xin chào.']);
      expect(splitForTts('   \n '), isEmpty);
    });

    test('đoạn dài chia theo câu, mỗi phần ≤ giới hạn, không mất chữ', () {
      final sentences = List.generate(10, (i) => 'Câu số $i rất là dài.');
      final text = sentences.join(' ');
      final parts = splitForTts(text, maxLength: 50);
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(50));
        // Cắt ở cuối câu.
        expect(p.endsWith('.'), isTrue, reason: p);
      }
      expect(parts.join(' '), text);
    });

    test('mặc định giới hạn 3500 ký tự', () {
      final sentence = '${'a' * 99}. ';
      final text = sentence * 80; // ~8000 ký tự
      final parts = splitForTts(text);
      expect(parts.length, 3);
      expect(parts.every((p) => p.length <= kTtsMaxChunkLength), isTrue);
    });

    test('câu không có dấu chấm thì cắt ở khoảng trắng', () {
      final text = List.filled(30, 'chữ').join(' '); // 119 ký tự
      final parts = splitForTts(text, maxLength: 40);
      expect(parts.every((p) => p.length <= 40), isTrue);
      expect(parts.every((p) => !p.startsWith(' ') && !p.endsWith(' ')), isTrue);
      expect(parts.join(' '), text);
    });

    test('chuỗi liền không khoảng trắng thì cắt cứng', () {
      final parts = splitForTts('x' * 95, maxLength: 40);
      expect(parts.map((p) => p.length), [40, 40, 15]);
    });

    test('câu CJK chia ở 。 không cần khoảng trắng', () {
      final text = '今天天气很好。' * 10; // 70 ký tự
      final parts = splitForTts(text, maxLength: 20);
      expect(parts.every((p) => p.length <= 20 && p.endsWith('。')), isTrue);
      expect(parts.join(), text);
    });
  });

  test('buildTtsQueue bỏ đoạn rỗng, giữ chỉ số đoạn gốc', () {
    final q = buildTtsQueue(['A.', '  ', 'B. C.'], maxLength: 3);
    expect(q, const [
      TtsSegment(0, 'A.'),
      TtsSegment(2, 'B.'),
      TtsSegment(2, 'C.'),
    ]);
  });

  test('filterVoices: đúng ngôn ngữ, bỏ giọng cần mạng / chưa cài', () {
    final raw = [
      {'name': 'vi-vn-x-gft-local', 'locale': 'vi-VN', 'network_required': '0'},
      {'name': 'vi-vn-x-gft-network', 'locale': 'vi-VN', 'network_required': '1'},
      {
        'name': 'vi-vn-x-vic-local',
        'locale': 'vi-VN',
        'network_required': '0',
        'features': 'notInstalled',
      },
      {'name': 'Linh', 'locale': 'vi-VN', 'identifier': 'com.apple.linh'},
      {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
      'rác',
    ];
    final v = filterVoices(raw, 'vi-VN');
    expect(v.map((e) => e.name), ['vi-vn-x-gft-local', 'Linh']);
    expect(v.last.toMap()['identifier'], 'com.apple.linh');
    expect(filterVoices(null, 'vi-VN'), isEmpty);
    // Không có đúng vùng → lấy cùng ngôn ngữ.
    expect(filterVoices([
      {'name': 'en-gb-x-1', 'locale': 'en-GB'},
    ], 'en-US').length, 1);
  });

  test('ttsVoiceDisplayName ẩn tên mã Android', () {
    expect(
      ttsVoiceDisplayName(const TtsVoice(name: 'vi-vn-x-gft-local', locale: 'vi-VN')),
      isNull,
    );
    expect(
      ttsVoiceDisplayName(const TtsVoice(name: 'Linh', locale: 'vi-VN')),
      'Linh',
    );
  });

  test('nhãn tốc độ và quy đổi tốc độ engine', () {
    expect(kTtsSpeeds.map(ttsSpeedLabel), [
      '0.5×',
      '0.75×',
      '1×',
      '1.25×',
      '1.5×',
      '2×',
    ]);
    expect(ttsEngineRate(1.0), 0.5);
    expect(ttsEngineRate(0.5), 0.25);
    expect(ttsEngineRate(2.0), 1.0);
  });
}
