// Chuẩn hoá chữ trước khi vẽ vào PDF.
//
// Syncfusion không áp dụng GPOS/mark positioning nên chữ Việt dạng NFD (chữ + dấu rời) vẽ SAI dấu.
// Dart không có `normalize`, nên gộp NFD → NFC cho tiếng Việt bằng bảng tra (kết quả spike S1,
// xem lmm-wiki/concepts/xuat-chu-ra-pdf.md).

const List<int> _tones = <int>[0x0300, 0x0301, 0x0303, 0x0309, 0x0323]; // huyền sắc ngã hỏi nặng

// Nguyên âm (đã có dấu mũ/trăng/râu) -> 5 dấu thanh theo thứ tự [_tones].
const Map<String, String> _toneTable = <String, String>{
  'a': 'àáãảạ',
  'ă': 'ằắẵẳặ',
  'â': 'ầấẫẩậ',
  'e': 'èéẽẻẹ',
  'ê': 'ềếễểệ',
  'i': 'ìíĩỉị',
  'o': 'òóõỏọ',
  'ô': 'ồốỗổộ',
  'ơ': 'ờớỡởợ',
  'u': 'ùúũủụ',
  'ư': 'ừứữửự',
  'y': 'ỳýỹỷỵ',
  'A': 'ÀÁÃẢẠ',
  'Ă': 'ẰẮẴẲẶ',
  'Â': 'ẦẤẪẨẬ',
  'E': 'ÈÉẼẺẸ',
  'Ê': 'ỀẾỄỂỆ',
  'I': 'ÌÍĨỈỊ',
  'O': 'ÒÓÕỎỌ',
  'Ô': 'ỒỐỖỔỘ',
  'Ơ': 'ỜỚỠỞỢ',
  'U': 'ÙÚŨỦỤ',
  'Ư': 'ỪỨỮỬỰ',
  'Y': 'ỲÝỸỶỴ',
};

// (gốc + dấu hình) -> chữ có dấu hình. 0x0302 mũ, 0x0306 trăng, 0x031B râu.
const Map<String, String> _shape = <String, String>{
  'â': 'â',
  'ă': 'ă',
  'ê': 'ê',
  'ô': 'ô',
  'ơ': 'ơ',
  'ư': 'ư',
  'Â': 'Â',
  'Ă': 'Ă',
  'Ê': 'Ê',
  'Ô': 'Ô',
  'Ơ': 'Ơ',
  'Ư': 'Ư',
};

bool _isShape(int c) => c == 0x0302 || c == 0x0306 || c == 0x031B;
bool _isTone(int c) => _tones.contains(c);

/// Gộp chuỗi NFD → NFC cho tiếng Việt (dấu thanh/dấu hình theo thứ tự bất kỳ).
/// Ký tự không phải tiếng Việt giữ nguyên.
String composeVietnamese(String s) {
  // Đường nhanh: không có dấu rời nào thì trả nguyên.
  var hasMark = false;
  for (final c in s.codeUnits) {
    if (_isShape(c) || _isTone(c)) {
      hasMark = true;
      break;
    }
  }
  if (!hasMark) return s;

  final r = s.runes.toList();
  final out = StringBuffer();
  var i = 0;
  while (i < r.length) {
    var base = String.fromCharCode(r[i]);
    i++;
    int? tone;
    while (i < r.length && (_isShape(r[i]) || _isTone(r[i]))) {
      final m = r[i];
      if (_isShape(m)) {
        final k = _shape['$base${String.fromCharCode(m)}'];
        if (k == null) break;
        base = k;
      } else {
        tone = m;
      }
      i++;
    }
    if (tone != null) {
      final row = _toneTable[base];
      if (row == null) {
        // Không ghép được: giữ nguyên chữ gốc, dấu thanh đứng riêng.
        out
          ..write(base)
          ..writeCharCode(tone);
        continue;
      }
      base = row[_tones.indexOf(tone)];
    }
    out.write(base);
  }
  return out.toString();
}

/// Chuẩn bị chuỗi đưa vào PDF: NFC tiếng Việt, đổi `\r\n`/`\r` thành `\n`, tab thành 4 dấu cách,
/// bỏ BOM / ký tự zero-width / ký tự điều khiển (trừ `\n`).
String normalizeForPdf(String text) {
  final buf = StringBuffer();
  final src = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final c in src.runes) {
    if (c == 0x0A) {
      buf.writeCharCode(c);
    } else if (c == 0x09) {
      buf.write('    ');
    } else if (c < 0x20 || c == 0x7F || (c >= 0x80 && c < 0xA0)) {
      continue;
    } else if (c == 0x2028 || c == 0x2029) {
      buf.write('\n');
    } else if (c == 0xFEFF || (c >= 0x200B && c <= 0x200F)) {
      continue;
    } else {
      buf.writeCharCode(c);
    }
  }
  return composeVietnamese(buf.toString());
}
