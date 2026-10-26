import 'dart:convert';
import 'dart:typed_data';

/// Giải mã nội dung file .txt: nhận BOM UTF-8 / UTF-16 LE / UTF-16 BE; không BOM thì đoán UTF-16
/// theo tỉ lệ byte 0, còn lại UTF-8 (byte lỗi thành U+FFFD, không ném).
String decodeTextBytes(Uint8List bytes) {
  if (bytes.isEmpty) return '';
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes, 2, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes, 2, littleEndian: false);
  }
  // Không BOM: văn bản Latin UTF-16 có rất nhiều byte 0 ở vị trí chẵn/lẻ.
  if (bytes.length >= 4) {
    var even = 0;
    var odd = 0;
    final n = bytes.length < 4096 ? bytes.length : 4096;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) {
        if (i.isEven) {
          even++;
        } else {
          odd++;
        }
      }
    }
    final half = n / 2;
    if (odd > half * 0.3 && even == 0) return _utf16(bytes, 0, littleEndian: true);
    if (even > half * 0.3 && odd == 0) return _utf16(bytes, 0, littleEndian: false);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _utf16(Uint8List bytes, int start, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}
