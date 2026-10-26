// Gộp dấu tiếng Việt dạng NFD (chữ + dấu rời) thành NFC (ký tự dựng sẵn) bằng bảng tra.
// Dart không có normalize() sẵn; Syncfusion vẽ NFD bị lệch dấu (xem lmm-wiki/concepts/xuat-chu-ra-pdf.md).
// Bản này sao từ app/test/spikes/vi_nfc.dart; khi T6 đưa bản chung vào app/lib/core/utils/ thì
// thay bằng bản đó.

const _tones = <int>[0x0300, 0x0301, 0x0303, 0x0309, 0x0323]; // huyền sắc ngã hỏi nặng

// Nguyên âm (đã có dấu mũ/trăng/râu) -> 5 dấu theo thứ tự _tones.
const _toneTable = <String, String>{
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
const _shape = <String, String>{
  'a\u0302': 'â',
  'a\u0306': 'ă',
  'e\u0302': 'ê',
  'o\u0302': 'ô',
  'o\u031b': 'ơ',
  'u\u031b': 'ư',
  'A\u0302': 'Â',
  'A\u0306': 'Ă',
  'E\u0302': 'Ê',
  'O\u0302': 'Ô',
  'O\u031b': 'Ơ',
  'U\u031b': 'Ư',
};

bool _isShape(int c) => c == 0x0302 || c == 0x0306 || c == 0x031B;
bool _isTone(int c) => _tones.contains(c);

/// Gộp chuỗi NFD → NFC cho tiếng Việt (nhận dấu thanh / dấu hình theo thứ tự bất kỳ).
/// Chuỗi đã NFC giữ nguyên.
String composeVietnamese(String s) {
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
        // không ghép được: giữ nguyên chữ gốc và dấu rời
        out.write(base);
        out.writeCharCode(tone);
        continue;
      }
      base = row[_tones.indexOf(tone)];
    }
    out.write(base);
  }
  return out.toString();
}
