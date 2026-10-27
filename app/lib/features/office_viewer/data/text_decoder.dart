import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'office_io.dart';

/// Bảng mã nhận được của file TXT.
enum TextEncoding {
  utf8('UTF-8'),
  utf8Bom('UTF-8 BOM'),
  utf16le('UTF-16 LE'),
  utf16be('UTF-16 BE'),

  /// Dự phòng cho file ANSI cũ (Latin-1 / Windows-1252).
  windows1252('Windows-1252');

  const TextEncoding(this.label);
  final String label;
}

/// Kết quả đọc file chữ.
class DecodedText {
  const DecodedText(this.text, this.encoding, {this.truncated = false});

  final String text;
  final TextEncoding encoding;

  /// File lớn hơn [maxTextBytes] nên chỉ đọc phần đầu.
  final bool truncated;
}

/// Giới hạn đọc một file TXT (byte).
const int maxTextBytes = 20 * 1024 * 1024;

/// Nhận bảng mã (BOM trước, rồi UTF-16 không BOM theo tỉ lệ byte 0, rồi UTF-8 chặt,
/// cuối cùng Windows-1252) và giải mã [bytes]. [truncated]: dữ liệu bị cắt giữa chừng
/// nên cho phép bỏ tối đa 3 byte UTF-8 dở dang ở cuối.
DecodedText decodeText(Uint8List bytes, {bool truncated = false}) {
  final n = bytes.length;
  if (n >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return DecodedText(
      utf8.decode(bytes.sublist(3), allowMalformed: true),
      TextEncoding.utf8Bom,
      truncated: truncated,
    );
  }
  if (n >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return DecodedText(
      _utf16(bytes, 2, littleEndian: true),
      TextEncoding.utf16le,
      truncated: truncated,
    );
  }
  if (n >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return DecodedText(
      _utf16(bytes, 2, littleEndian: false),
      TextEncoding.utf16be,
      truncated: truncated,
    );
  }
  final guess = _guessUtf16WithoutBom(bytes);
  if (guess != null) {
    return DecodedText(
      _utf16(bytes, 0, littleEndian: guess),
      guess ? TextEncoding.utf16le : TextEncoding.utf16be,
      truncated: truncated,
    );
  }
  for (var cut = 0; cut <= (truncated ? 3 : 0) && cut <= n; cut++) {
    try {
      final s = utf8.decode(bytes.sublist(0, n - cut));
      return DecodedText(s, TextEncoding.utf8, truncated: truncated);
    } on FormatException {
      // thử cắt thêm byte cuối
    }
  }
  final lenient = _lenientUtf8(bytes, truncated: truncated);
  if (lenient != null) {
    return DecodedText(lenient, TextEncoding.utf8, truncated: truncated);
  }
  return DecodedText(
    _windows1252(bytes),
    TextEncoding.windows1252,
    truncated: truncated,
  );
}

/// UTF-8 có vài byte rác (log, file ghép): vẫn coi là UTF-8 nếu chuỗi hợp lệ nhiều gấp
/// 10 lần chỗ lỗi. File Windows-1252 thật không có chuỗi hợp lệ nào nên vẫn rơi xuống 1252.
String? _lenientUtf8(Uint8List bytes, {required bool truncated}) {
  final s = utf8.decode(bytes, allowMalformed: true);
  var valid = 0, bad = 0;
  for (final r in s.runes) {
    if (r == 0xFFFD) {
      bad++;
    } else if (r > 0x7F) {
      valid++;
    }
  }
  if (valid == 0 || valid < bad * 10) return null;
  return s;
}

/// `true` = UTF-16 LE, `false` = BE, `null` = không phải UTF-16.
bool? _guessUtf16WithoutBom(Uint8List b) {
  final len = (b.length < 4096 ? b.length : 4096) & ~1;
  if (len < 4) return null;
  var zeroEven = 0, zeroOdd = 0;
  for (var i = 0; i < len; i += 2) {
    if (b[i] == 0) zeroEven++;
    if (b[i + 1] == 0) zeroOdd++;
  }
  final pairs = len / 2;
  if (zeroOdd / pairs > 0.3 && zeroEven / pairs < 0.05) return true;
  if (zeroEven / pairs > 0.3 && zeroOdd / pairs < 0.05) return false;
  return null;
}

String _utf16(Uint8List b, int start, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = start; i + 1 < b.length; i += 2) {
    units.add(littleEndian ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
  }
  return String.fromCharCodes(units);
}

const List<int> _cp1252High = [
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
];

String _windows1252(Uint8List b) {
  final units = List<int>.generate(b.length, (i) {
    final v = b[i];
    return (v >= 0x80 && v <= 0x9F) ? _cp1252High[v - 0x80] : v;
  });
  return String.fromCharCodes(units);
}

/// Tách dòng theo `\r\n`, `\n` hoặc `\r` đơn. Chuỗi rỗng → `['']`.
List<String> splitLines(String text) => text.split(RegExp(r'\r\n|\n|\r'));

/// Đọc tối đa [maxTextBytes] byte đầu của file rồi nhận mã + giải mã (trong isolate).
Future<DecodedText> readTextFile(String path) => runParsing(() {
  final raf = File(path).openSync();
  try {
    final length = raf.lengthSync();
    final isTruncated = length > maxTextBytes;
    final bytes = raf.readSync(isTruncated ? maxTextBytes : length);
    return decodeText(bytes, truncated: isTruncated);
  } finally {
    raf.closeSync();
  }
});
