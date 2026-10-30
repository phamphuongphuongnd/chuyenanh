import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Mã 6 ngôn ngữ dịch được (trùng 6 ngôn ngữ của app), theo thứ tự hiển thị.
const List<String> kTranslateLanguageCodes = [
  'vi',
  'en',
  'zh',
  'ja',
  'ko',
  'id',
];

/// Số đoạn dịch mỗi lô; tài liệu dài hơn thì hỏi người dùng có dịch tiếp không.
const int kTranslateBatchSize = 300;

/// Kích thước ước lượng một gói dịch (MB) — chỉ để hiện cho người dùng.
const int kTranslateModelSizeMb = 30;

/// Gói tiếng Anh luôn có sẵn trong ML Kit (không tải, không xoá được).
const String kBuiltInModelCode = 'en';

/// Ánh xạ mã ngôn ngữ app → [TranslateLanguage] của ML Kit. `null` nếu không thuộc 6 ngôn ngữ.
TranslateLanguage? translateLanguageFor(String code) => switch (code) {
  'vi' => TranslateLanguage.vietnamese,
  'en' => TranslateLanguage.english,
  'zh' => TranslateLanguage.chinese,
  'ja' => TranslateLanguage.japanese,
  'ko' => TranslateLanguage.korean,
  'id' => TranslateLanguage.indonesian,
  _ => null,
};

/// Mã ngôn ngữ app (vi, en…) của [code] bất kỳ (vd. `zh-Hans`, `en_US`); không thuộc 6 ngôn ngữ → `null`.
String? normalizeLanguageCode(String? code) {
  if (code == null) return null;
  final base = code.split(RegExp('[-_]')).first.toLowerCase();
  return kTranslateLanguageCodes.contains(base) ? base : null;
}

/// Đoán ngôn ngữ theo ký tự (không cần gói nhận diện ngôn ngữ):
/// có chữ Hán / Kana / Hangul đáng kể → zh / ja / ko; có dấu tiếng Việt → vi; còn lại → en.
String guessLanguageCode(String text, {int maxChars = 4000}) {
  var hangul = 0, kana = 0, han = 0, latin = 0, viMarks = 0;
  var seen = 0;
  for (final r in text.runes) {
    if (++seen > maxChars) break;
    if (_isHangul(r)) {
      hangul++;
    } else if (_isKana(r)) {
      kana++;
    } else if (_isHan(r)) {
      han++;
    } else if (_isVietnameseMark(r)) {
      viMarks++;
      // Dấu kết hợp (NFD) không phải chữ; chữ có dấu dựng sẵn vẫn tính là chữ Latin.
      if (r < 0x0300 || r > 0x036F) latin++;
    } else if (_isLatinLetter(r)) {
      latin++;
    }
  }
  final cjk = hangul + kana + han;
  final letters = cjk + latin;
  if (letters == 0) return 'en';
  // Chữ CJK chiếm ≥ 20% số chữ (mỗi chữ CJK ~ một từ nên ngưỡng thấp hơn chữ Latin).
  if (cjk > 0 && cjk * 5 >= letters) {
    if (kana * 10 >= cjk) return 'ja'; // Tiếng Nhật luôn xen Kana giữa chữ Hán.
    if (hangul * 2 >= cjk) return 'ko';
    return 'zh';
  }
  // Tiếng Việt: hầu như từ nào cũng có dấu → ≥ 5% số chữ Latin có dấu.
  if (viMarks > 0 && viMarks * 20 >= latin) return 'vi';
  return 'en';
}

/// Ngôn ngữ đích mặc định: ngôn ngữ app; nếu trùng nguồn thì sang tiếng Anh
/// (nguồn đã là tiếng Anh thì sang tiếng Việt).
String defaultTargetCode({
  required String appCode,
  required String sourceCode,
}) {
  final app = normalizeLanguageCode(appCode) ?? 'en';
  if (app != sourceCode) return app;
  return sourceCode == 'en' ? 'vi' : 'en';
}

/// Bỏ khoảng trắng hai đầu và đoạn rỗng.
List<String> cleanParagraphs(Iterable<String> paragraphs) => [
  for (final p in paragraphs)
    if (p.trim().isNotEmpty) p.trim(),
];

/// Chia [items] thành các lô liên tiếp, mỗi lô tối đa [size] phần tử (lô cuối có thể ngắn hơn).
List<List<T>> splitIntoBatches<T>(List<T> items, int size) {
  if (size <= 0) throw ArgumentError.value(size, 'size', 'phải > 0');
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

/// Mẫu chữ để đoán ngôn ngữ: ghép các đoạn đầu cho đủ ~[maxChars] ký tự.
String sampleForGuess(List<String> paragraphs, {int maxChars = 4000}) {
  final buf = StringBuffer();
  for (final p in paragraphs) {
    if (buf.length >= maxChars) break;
    buf
      ..write(p)
      ..write(' ');
  }
  return buf.toString();
}

bool _isHangul(int r) =>
    (r >= 0xAC00 && r <= 0xD7AF) || // Âm tiết Hangul
    (r >= 0x1100 && r <= 0x11FF) || // Jamo
    (r >= 0x3130 && r <= 0x318F); // Jamo tương thích

bool _isKana(int r) =>
    (r >= 0x3040 && r <= 0x309F) || // Hiragana
    (r >= 0x30A0 && r <= 0x30FF) || // Katakana
    (r >= 0x31F0 && r <= 0x31FF) || // Katakana mở rộng
    (r >= 0xFF66 && r <= 0xFF9F); // Katakana nửa độ rộng

bool _isHan(int r) =>
    (r >= 0x4E00 && r <= 0x9FFF) || // CJK thống nhất
    (r >= 0x3400 && r <= 0x4DBF) || // Mở rộng A
    (r >= 0xF900 && r <= 0xFAFF) || // Tương thích
    (r >= 0x20000 && r <= 0x2A6DF); // Mở rộng B

bool _isLatinLetter(int r) =>
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7);

/// Chữ có dấu kiểu tiếng Việt (dựng sẵn) hoặc dấu kết hợp của tiếng Việt (văn bản NFD).
bool _isVietnameseMark(int r) {
  if (r >= 0x1EA0 && r <= 0x1EF9) return true; // ạ ả ấ … ỹ
  if (_viLatin1.contains(r)) return true;
  // Dấu kết hợp: huyền, sắc, ngã, hỏi, nặng, mũ, trăng, móc.
  return r == 0x0300 ||
      r == 0x0301 ||
      r == 0x0303 ||
      r == 0x0309 ||
      r == 0x0323 ||
      r == 0x0302 ||
      r == 0x0306 ||
      r == 0x031B;
}

/// à á â ã è é ê ì í ò ó ô õ ù ú ý ă đ ĩ ũ ơ ư (thường + hoa).
final Set<int> _viLatin1 = {
  ...'àáâãèéêìíòóôõùúýăđĩũơưÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂĐĨŨƠƯ'.runes,
};
