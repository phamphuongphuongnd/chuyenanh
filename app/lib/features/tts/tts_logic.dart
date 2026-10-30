import 'package:flutter/foundation.dart';

/// Giới hạn ký tự một lần đọc. Android cho tối đa ~4000
/// (`TextToSpeech.getMaxSpeechInputLength`), chừa biên cho an toàn.
const int kTtsMaxChunkLength = 3500;

/// Các mức tốc độ trong bảng chọn (1.0 = bình thường).
const List<double> kTtsSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

const Map<String, String> _ttsLocales = {
  'vi': 'vi-VN',
  'en': 'en-US',
  'zh': 'zh-CN',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'id': 'id-ID',
};

/// Mã ngôn ngữ app (vi, en, zh, ja, ko, id) → locale giọng đọc (vi-VN, en-US…).
/// Mã đã có vùng (`en_GB`, `pt-BR`) giữ nguyên (đổi `_` thành `-`); mã lạ trả lại như cũ.
String ttsLocaleFor(String languageCode) {
  final code = languageCode.trim().replaceAll('_', '-');
  final parts = code.split('-');
  if (parts.length >= 2 && parts[1].length == 2) {
    return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
  }
  final lang = parts.first.toLowerCase();
  return _ttsLocales[lang] ?? lang;
}

/// Nhãn tốc độ: 0.5×, 0.75×, 1×, 1.25×, 1.5×, 2×.
String ttsSpeedLabel(double speed) {
  final s = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$s×';
}

/// Tốc độ người dùng (0.5–2, 1 = bình thường) → giá trị `setSpeechRate` của flutter_tts.
/// Cả Android (plugin nhân 2 trước khi gửi máy) lẫn iOS (`AVSpeechUtteranceDefaultSpeechRate`)
/// đều coi 0.5 là bình thường; iOS tối đa 1.0.
double ttsEngineRate(double speed) => (0.5 * speed).clamp(0.05, 1.0);

// Dấu kết câu: Latin + CJK. Câu Latin cần khoảng trắng sau dấu; CJK thì không.
final RegExp _sentenceEnd = RegExp(r'[.!?…]+["”’)\]]*\s+|[。！？]+["”’」』）]*\s*');

/// Chia một đoạn văn thành các phần ≤ [maxLength] ký tự để engine đọc được.
/// Ưu tiên cắt ở cuối câu; câu quá dài thì cắt ở khoảng trắng; không có khoảng trắng
/// (chuỗi CJK dài) thì cắt cứng. Đoạn rỗng/chỉ khoảng trắng → danh sách rỗng.
List<String> splitForTts(String text, {int maxLength = kTtsMaxChunkLength}) {
  assert(maxLength > 0);
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.length <= maxLength) return [trimmed];

  // Tách câu (giữ dấu câu ở cuối câu).
  final sentences = <String>[];
  var start = 0;
  for (final m in _sentenceEnd.allMatches(trimmed)) {
    sentences.add(trimmed.substring(start, m.end));
    start = m.end;
  }
  if (start < trimmed.length) sentences.add(trimmed.substring(start));

  final chunks = <String>[];
  final buf = StringBuffer();
  void flush() {
    final s = buf.toString().trim();
    if (s.isNotEmpty) chunks.add(s);
    buf.clear();
  }

  for (final sentence in sentences) {
    if (sentence.length > maxLength) {
      flush();
      chunks.addAll(_splitLong(sentence, maxLength));
      continue;
    }
    if (buf.length + sentence.length > maxLength) flush();
    buf.write(sentence);
  }
  flush();
  return chunks;
}

/// Cắt một câu dài theo khoảng trắng gần nhất trước giới hạn, hoặc cắt cứng.
List<String> _splitLong(String sentence, int maxLength) {
  final out = <String>[];
  var rest = sentence.trim();
  while (rest.length > maxLength) {
    var cut = rest.lastIndexOf(RegExp(r'\s'), maxLength);
    if (cut <= 0) cut = maxLength;
    final head = rest.substring(0, cut).trim();
    if (head.isNotEmpty) out.add(head);
    rest = rest.substring(cut).trim();
  }
  if (rest.isNotEmpty) out.add(rest);
  return out;
}

/// Một lần đọc: phần [text] thuộc đoạn [paragraph] (chỉ số trong danh sách gốc).
@immutable
class TtsSegment {
  const TtsSegment(this.paragraph, this.text);

  final int paragraph;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is TtsSegment && other.paragraph == paragraph && other.text == text;

  @override
  int get hashCode => Object.hash(paragraph, text);

  @override
  String toString() => 'TtsSegment($paragraph, ${text.length} ký tự)';
}

/// Dựng hàng đợi đọc từ danh sách đoạn; đoạn rỗng bị bỏ qua.
List<TtsSegment> buildTtsQueue(
  List<String> paragraphs, {
  int maxLength = kTtsMaxChunkLength,
}) => [
  for (var i = 0; i < paragraphs.length; i++)
    for (final part in splitForTts(paragraphs[i], maxLength: maxLength))
      TtsSegment(i, part),
];

/// Một giọng đọc của máy.
@immutable
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.identifier});

  final String name;

  /// Dạng BCP-47 (`vi-VN`).
  final String locale;

  /// iOS: mã định danh giọng.
  final String? identifier;

  /// Map gửi cho `FlutterTts.setVoice`.
  Map<String, String> toMap() => {
    'name': name,
    'locale': locale,
    'identifier': ?identifier,
  };

  @override
  bool operator ==(Object other) =>
      other is TtsVoice &&
      other.name == name &&
      other.locale == locale &&
      other.identifier == identifier;

  @override
  int get hashCode => Object.hash(name, locale, identifier);
}

/// Lọc giọng hợp [locale]: cùng ngôn ngữ, ưu tiên đúng vùng; bỏ giọng cần mạng hoặc
/// chưa tải (Android báo `network_required` = 1 / feature `notInstalled`).
/// [raw] là kết quả thô `FlutterTts.getVoices` (List<Map>).
List<TtsVoice> filterVoices(Object? raw, String locale) {
  if (raw is! List) return const [];
  final want = locale.toLowerCase().replaceAll('_', '-');
  final lang = want.split('-').first;
  final exact = <TtsVoice>[];
  final sameLang = <TtsVoice>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final name = item['name']?.toString() ?? '';
    final loc = (item['locale']?.toString() ?? '').replaceAll('_', '-');
    if (name.isEmpty || loc.isEmpty) continue;
    if (item['network_required']?.toString() == '1') continue;
    final features = item['features']?.toString() ?? '';
    if (features.contains('notInstalled')) continue;
    final l = loc.toLowerCase();
    if (l.split('-').first != lang) continue;
    if (!seen.add('$name|$loc')) continue;
    final voice = TtsVoice(
      name: name,
      locale: loc,
      identifier: item['identifier']?.toString(),
    );
    (l == want || l.startsWith('$want-') ? exact : sameLang).add(voice);
  }
  return exact.isNotEmpty ? exact : sameLang;
}

/// Tên giọng dễ đọc: tên Android kiểu `vi-vn-x-gft-local` → null (UI hiện "Giọng n").
String? ttsVoiceDisplayName(TtsVoice voice) {
  final n = voice.name;
  if (RegExp(r'^[a-z]{2,3}[-_][a-z]{2}', caseSensitive: false).hasMatch(n) ||
      n.contains('#') ||
      n.contains('-x-')) {
    return null;
  }
  return n;
}
