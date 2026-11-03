/// Hệ chữ chiếm ưu thế trong một chuỗi (để chọn font nhúng).
enum TextScript { latin, han, kana, hangul }

bool _isHangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7AF) ||
    (c >= 0x1100 && c <= 0x11FF) ||
    (c >= 0x3130 && c <= 0x318F);

bool _isKana(int c) => (c >= 0x3040 && c <= 0x30FF) || (c >= 0x31F0 && c <= 0x31FF);

bool _isHan(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0x20000 && c <= 0x2A6DF) ||
    (c >= 0xF900 && c <= 0xFAFF);

/// Hệ chữ để chọn font cho [text]: có Hangul → hangul; có kana → kana; có Hán → han;
/// còn lại → latin (Latin/Việt/Indonesia).
TextScript dominantScript(String text) {
  var han = false;
  var kana = false;
  for (final c in text.runes) {
    if (_isHangul(c)) return TextScript.hangul;
    if (_isKana(c)) kana = true;
    if (_isHan(c)) han = true;
  }
  if (kana) return TextScript.kana;
  if (han) return TextScript.han;
  return TextScript.latin;
}

/// Ký tự Hán/kana/Hangul (kể cả dấu câu CJK) — app không đóng gói font CJK nên không vẽ được.
bool isCjkChar(int c) =>
    _isHangul(c) || _isKana(c) || _isHan(c) || (c >= 0x3000 && c <= 0x303F) || (c >= 0xFF00 && c <= 0xFFEF);

/// Thay mỗi ký tự CJK bằng `?` (người dùng biết có chữ bị mất); Việt/Anh giữ nguyên.
String replaceCjk(String text) {
  if (!text.runes.any(isCjkChar)) return text;
  final b = StringBuffer();
  for (final c in text.runes) {
    b.write(isCjkChar(c) ? '?' : String.fromCharCode(c));
  }
  return b.toString();
}

/// Đường dẫn asset font (theo thứ tự thử) cho [text]. Chỉ có Noto Sans (Latin/Việt); không còn
/// font CJK, chữ Hán/Nhật/Hàn khi vẽ được đổi thành `?` qua [replaceCjk].
List<String> fontAssetCandidates(String text) => const [
  'assets/fonts/NotoSans-Regular.ttf',
  'assets/fonts/NotoSans-Regular.otf',
];
