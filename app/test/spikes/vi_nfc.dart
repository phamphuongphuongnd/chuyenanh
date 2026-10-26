// Spike S1: gop dau tieng Viet dang NFD (ky tu to hop) thanh NFC bang bang tra.
// Dart khong co normalize() san; day la ban toi thieu cho tieng Viet.

const _tones = <int>[0x0300, 0x0301, 0x0303, 0x0309, 0x0323]; // huyen sac nga hoi nang

// Nguyen am (da co dau mu/trang/rau) -> 5 dau theo thu tu _tones, [khong dau] dau tien.
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

// (goc, dau hinh) -> chu co dau hinh. 0x0302 mu, 0x0306 trang, 0x031B rau.
const _shape = <String, String>{
  'â': 'â', 'ă': 'ă', 'ê': 'ê', 'ô': 'ô',
  'ơ': 'ơ', 'ư': 'ư',
  'Â': 'Â', 'Ă': 'Ă', 'Ê': 'Ê', 'Ô': 'Ô',
  'Ơ': 'Ơ', 'Ư': 'Ư',
};

bool _isShape(int c) => c == 0x0302 || c == 0x0306 || c == 0x031B;
bool _isTone(int c) => _tones.contains(c);

/// Gop chuoi NFD -> NFC cho tieng Viet (chap nhan dau thanh/dau hinh theo bat ky thu tu).
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
      base = row == null ? base : row[_tones.indexOf(tone)];
      if (row == null) out.write(base); // khong ghep duoc: giu nguyen, rieng dau
      if (row == null) {
        out.writeCharCode(tone);
        continue;
      }
    }
    out.write(base);
  }
  return out.toString();
}
