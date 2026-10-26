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

/// Đường dẫn asset font (theo thứ tự thử) cho [text]. Font Noto tải sau
/// (`assets/fonts/`, xem hợp đồng mục 5); thiếu file thì engine rơi về Helvetica.
List<String> fontAssetCandidates(String text) => switch (dominantScript(text)) {
  TextScript.hangul => const ['assets/fonts/NotoSansKR-Regular.ttf'],
  TextScript.kana => const ['assets/fonts/NotoSansJP-Regular.ttf'],
  TextScript.han => const ['assets/fonts/NotoSansSC-Regular.ttf'],
  TextScript.latin => const [
    'assets/fonts/NotoSans-Regular.ttf',
    'assets/fonts/NotoSans-Regular.otf',
  ],
};
