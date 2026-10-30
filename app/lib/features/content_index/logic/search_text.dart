// Chuẩn hoá chữ cho tìm theo nội dung + cắt đoạn trích. Hàm thuần, dùng được trong isolate.
//
// Luật: `normalized` = chữ thường + bỏ dấu (`đ→d`) + mọi khoảng trắng → dấu cách, đổi TỪNG ký tự
// 1:1 (cùng độ dài với chữ gốc) để vị trí khớp trong bản chuẩn hoá cũng là vị trí trong bản gốc
// (dùng cắt đoạn trích + tô đậm). Gộp NFC (`composeVietnamese`) làm TRƯỚC, ở bước chuẩn bị chữ.
import '../../convert/text/vietnamese_nfc.dart';

/// Số ký tự tối đa của chữ lưu cho một file.
const int maxContentChars = 200000;

/// Chữ có dấu (chữ thường) → chữ không dấu. Tiếng Việt + vài chữ Latin-1 hay gặp.
const Map<String, String> _foldGroups = {
  'a': 'àáãảạăằắẵẳặâầấẫẩậäåāą',
  'c': 'çćč',
  'd': 'đď',
  'e': 'èéẽẻẹêềếễểệëēęě',
  'i': 'ìíĩỉịîïī',
  'n': 'ñńň',
  'o': 'òóõỏọôồốỗổộơờớỡởợöøō',
  'r': 'ř',
  's': 'śš',
  'u': 'ùúũủụưừứữửựûüūů',
  'y': 'ỳýỹỷỵÿ',
  'z': 'źżž',
};

final Map<int, int> _foldTable = {
  for (final e in _foldGroups.entries)
    for (final c in e.value.codeUnits) c: e.key.codeUnitAt(0),
};

/// Bộ nhớ đệm cho ký tự ngoài ASCII (gọi `toLowerCase` từng ký tự tốn).
final Map<int, int> _foldCache = {};

bool _isSpace(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000;

int _foldUnit(int c) {
  if (c < 0x80) {
    if (c >= 0x41 && c <= 0x5A) return c + 0x20; // A-Z
    if (c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0B || c == 0x0C) {
      return 0x20;
    }
    return c;
  }
  final cached = _foldCache[c];
  if (cached != null) return cached;
  int out;
  if (_isSpace(c)) {
    out = 0x20;
  } else if (c >= 0xD800 && c <= 0xDFFF) {
    out = c; // nửa cặp surrogate: giữ nguyên để không đổi độ dài
  } else {
    final lower = String.fromCharCode(c).toLowerCase();
    // Vài chữ khi viết thường thành 2 ký tự (vd `İ`) → giữ chữ gốc để giữ 1:1.
    final lc = lower.length == 1 ? lower.codeUnitAt(0) : c;
    out = _foldTable[lc] ?? lc;
  }
  _foldCache[c] = out;
  return out;
}

/// Đổi 1:1 từng ký tự (UTF-16): chữ thường, bỏ dấu, khoảng trắng → dấu cách.
/// Kết quả dài đúng bằng [s]. Không gộp NFC — gọi trên chữ đã qua [prepareContent].
String foldForSearch(String s) {
  final units = s.codeUnits;
  final out = List<int>.filled(units.length, 0);
  for (var i = 0; i < units.length; i++) {
    out[i] = _foldUnit(units[i]);
  }
  return String.fromCharCodes(out);
}

/// Chuẩn hoá chuỗi bất kỳ (tên file…) để so khớp: NFC rồi [foldForSearch].
String normalizeForSearch(String s) => foldForSearch(composeVietnamese(s));

/// Chuẩn hoá từ khoá người dùng gõ: như [normalizeForSearch] + gộp khoảng trắng liên tiếp,
/// bỏ khoảng trắng hai đầu. `"  Hợp   ĐỒNG "` → `"hop dong"`.
String normalizeQuery(String q) =>
    normalizeForSearch(q).replaceAll(RegExp(' {2,}'), ' ').trim();

/// Chữ đã chuẩn bị để lưu: `content` (gốc, gọn) + `normalized` (cùng độ dài).
typedef PreparedText = ({String content, String normalized});

/// Chuẩn bị chữ trích từ file: NFC tiếng Việt, bỏ ký tự điều khiển / zero-width, mỗi cụm khoảng
/// trắng còn một ký tự (`\n` nếu cụm có xuống dòng, ngược lại dấu cách), cắt ở
/// [maxContentChars] ký tự; rồi tạo bản chuẩn hoá.
PreparedText prepareContent(String raw, {int maxChars = maxContentChars}) {
  final src = composeVietnamese(raw);
  final buf = StringBuffer();
  var pendingSpace = 0; // 0: không; 1: dấu cách; 2: xuống dòng
  var written = 0;
  for (final c in src.runes) {
    if (_isSpace(c)) {
      final nl = c == 0x0A || c == 0x0D || c == 0x2028 || c == 0x2029;
      if (nl) {
        pendingSpace = 2;
      } else if (pendingSpace == 0) {
        pendingSpace = 1;
      }
      continue;
    }
    if (c < 0x20 ||
        c == 0x7F ||
        (c >= 0x80 && c < 0xA0) ||
        c == 0xFEFF ||
        (c >= 0x200B && c <= 0x200F)) {
      continue;
    }
    final width = c > 0xFFFF ? 2 : 1;
    final spaceWidth = (pendingSpace != 0 && written > 0) ? 1 : 0;
    if (written + spaceWidth + width > maxChars) break;
    if (spaceWidth == 1) buf.write(pendingSpace == 2 ? '\n' : ' ');
    pendingSpace = 0;
    buf.writeCharCode(c);
    written += spaceWidth + width;
  }
  final content = buf.toString();
  return (content: content, normalized: foldForSearch(content));
}

/// Đoạn trích hiển thị dưới tên file; [matchStart] = -1 khi không có chỗ khớp để tô.
class Excerpt {
  const Excerpt(this.text, this.matchStart, this.matchLength);

  final String text;
  final int matchStart;
  final int matchLength;

  bool get hasMatch => matchStart >= 0 && matchLength > 0;
  String get before => hasMatch ? text.substring(0, matchStart) : text;
  String get match =>
      hasMatch ? text.substring(matchStart, matchStart + matchLength) : '';
  String get after => hasMatch ? text.substring(matchStart + matchLength) : '';
}

bool _isWs(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D;
bool _isHigh(int c) => c >= 0xD800 && c <= 0xDBFF;
bool _isLow(int c) => c >= 0xDC00 && c <= 0xDFFF;

/// Cắt [window] (chữ gốc quanh chỗ khớp) thành đoạn ~[maxLength] ký tự, chỗ khớp
/// [normalizedQuery] ở giữa, bám ranh giới từ, thêm `…` ở phía còn chữ.
/// [atStart] / [atEnd]: [window] đã là đầu / cuối nội dung (không thêm `…` phía đó).
Excerpt buildExcerpt(
  String window,
  String normalizedQuery, {
  int maxLength = 80,
  bool atStart = true,
  bool atEnd = true,
}) {
  final len = window.length;
  final q = normalizedQuery;
  final idx = q.isEmpty ? -1 : foldForSearch(window).indexOf(q);
  final qLen = idx < 0 ? 0 : q.length;
  int start;
  int end;
  if (idx < 0) {
    start = 0;
    end = len < maxLength ? len : maxLength;
  } else {
    final room = maxLength - qLen > 0 ? maxLength - qLen : 0;
    start = idx - room ~/ 2;
    end = idx + qLen + (room - room ~/ 2);
    if (start < 0) {
      end -= start;
      start = 0;
    }
    if (end > len) {
      start -= end - len;
      end = len;
      if (start < 0) start = 0;
    }
    // Bám ranh giới từ (không cắt giữa chữ) nếu chỉ mất ít ký tự.
    const slack = 15;
    if (start > 0 && !_isWs(window.codeUnitAt(start - 1))) {
      for (var i = start; i < idx && i - start <= slack; i++) {
        if (_isWs(window.codeUnitAt(i))) {
          start = i + 1;
          break;
        }
      }
    }
    if (end < len && !_isWs(window.codeUnitAt(end))) {
      for (var i = end - 1; i >= idx + qLen && end - i <= slack; i--) {
        if (_isWs(window.codeUnitAt(i))) {
          end = i;
          break;
        }
      }
    }
  }
  // Không cắt đôi cặp surrogate.
  if (start > 0 && start < len && _isLow(window.codeUnitAt(start))) start++;
  if (end > 0 && end < len && _isHigh(window.codeUnitAt(end - 1))) end--;
  // Bỏ khoảng trắng hai đầu (không lấn vào chỗ khớp).
  final keepFrom = idx < 0 ? end : idx;
  while (start < keepFrom && _isWs(window.codeUnitAt(start))) {
    start++;
  }
  final keepTo = idx < 0 ? start : idx + qLen;
  while (end > keepTo && _isWs(window.codeUnitAt(end - 1))) {
    end--;
  }
  final prefix = (start > 0 || !atStart) ? '…' : '';
  final suffix = (end < len || !atEnd) ? '…' : '';
  final body = window.substring(start, end).replaceAll(RegExp('[\n\r\t]'), ' ');
  return Excerpt(
    '$prefix$body$suffix',
    idx < 0 ? -1 : prefix.length + idx - start,
    qLen,
  );
}
