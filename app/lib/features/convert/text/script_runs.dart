// Tách chuỗi thành các đoạn liền nhau cùng hệ chữ để vẽ mỗi đoạn bằng một font riêng
// (không có font nào đủ Việt + CJK — xem lmm-wiki/concepts/xuat-chu-ra-pdf.md).

/// Hệ chữ quyết định font.
enum ScriptFace {
  /// Latin / Việt / số / dấu câu ASCII → Noto Sans.
  latin,

  /// Hán tự (mặc định, giản thể) → Noto Sans SC.
  chinese,

  /// Kana (và Hán tự trong chuỗi có kana) → Noto Sans JP.
  japanese,

  /// Hangul → Noto Sans KR.
  korean,
}

/// Một đoạn liên tiếp cùng [face].
class ScriptRun {
  const ScriptRun(this.face, this.text);

  final ScriptFace face;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ScriptRun && other.face == face && other.text == text;

  @override
  int get hashCode => Object.hash(face, text);

  @override
  String toString() => 'ScriptRun($face, "$text")';
}

bool _isHangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7AF) ||
    (c >= 0x1100 && c <= 0x11FF) ||
    (c >= 0x3130 && c <= 0x318F) ||
    (c >= 0xA960 && c <= 0xA97F) ||
    (c >= 0xD7B0 && c <= 0xD7FF);

bool _isKana(int c) =>
    (c >= 0x3040 && c <= 0x30FF) ||
    (c >= 0x31F0 && c <= 0x31FF) ||
    (c >= 0xFF66 && c <= 0xFF9F);

bool _isHan(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    (c >= 0x20000 && c <= 0x2FA1F);

/// Dấu câu / ký tự toàn chiều rộng của CJK (kana, 0x3040-0x30FF, xét riêng ở [_isKana]).
bool _isCjkPunct(int c) =>
    (c >= 0x3000 && c <= 0x303F) ||
    (c >= 0xFF00 && c <= 0xFF65) ||
    (c >= 0xFFA0 && c <= 0xFFEF);

/// Ký tự trung tính: theo hệ chữ của ký tự đứng trước (dấu cách, số, dấu câu ASCII).
bool _isNeutral(int c) =>
    c <= 0x40 || (c >= 0x5B && c <= 0x60) || (c >= 0x7B && c <= 0x7F) || c == 0xA0;

/// Các hệ chữ có mặt trong [text] (để chỉ nạp font CJK nặng khi thật sự cần).
/// Luôn gồm [ScriptFace.latin] khi có ký tự Latin hoặc chuỗi rỗng.
Set<ScriptFace> scriptsIn(String text) {
  final found = <ScriptFace>{};
  var kana = false;
  var han = false;
  for (final c in text.runes) {
    if (_isHangul(c)) {
      found.add(ScriptFace.korean);
    } else if (_isKana(c)) {
      kana = true;
    } else if (_isHan(c) || _isCjkPunct(c)) {
      han = true;
    } else {
      found.add(ScriptFace.latin);
    }
  }
  if (kana) found.add(ScriptFace.japanese);
  if (han) found.add(kana ? ScriptFace.japanese : ScriptFace.chinese);
  if (found.isEmpty) found.add(ScriptFace.latin);
  return found;
}

/// Cắt [text] thành các [ScriptRun]. Ký tự trung tính theo đoạn đứng trước (đầu chuỗi → latin).
/// Hán tự dùng font Nhật nếu cả chuỗi có kana, ngược lại font Trung.
List<ScriptRun> splitScriptRuns(String text) {
  final hasKana = text.runes.any(_isKana);
  final hanFace = hasKana ? ScriptFace.japanese : ScriptFace.chinese;
  final runs = <(ScriptFace, StringBuffer)>[];
  for (final c in text.runes) {
    ScriptFace f;
    if (_isHangul(c)) {
      f = ScriptFace.korean;
    } else if (_isKana(c)) {
      f = ScriptFace.japanese;
    } else if (_isHan(c) || _isCjkPunct(c)) {
      f = hanFace;
    } else if (_isNeutral(c) && runs.isNotEmpty) {
      f = runs.last.$1;
    } else {
      f = ScriptFace.latin;
    }
    if (runs.isEmpty || runs.last.$1 != f) runs.add((f, StringBuffer()));
    runs.last.$2.writeCharCode(c);
  }
  return [for (final r in runs) ScriptRun(r.$1, r.$2.toString())];
}

/// Có thể ngắt dòng giữa hai ký tự CJK bất kỳ (không cần dấu cách).
bool isBreakableCjk(int codePoint) =>
    _isHan(codePoint) || _isKana(codePoint) || _isCjkPunct(codePoint);
