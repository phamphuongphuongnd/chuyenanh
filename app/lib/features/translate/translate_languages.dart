import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Mã 2 ngôn ngữ dịch được (trùng 2 ngôn ngữ của app), theo thứ tự hiển thị.
const List<String> kTranslateLanguageCodes = ['vi', 'en'];

/// Số đoạn dịch mỗi lô; tài liệu dài hơn thì hỏi người dùng có dịch tiếp không.
const int kTranslateBatchSize = 300;

/// Kích thước ước lượng một gói dịch (MB) — chỉ để hiện cho người dùng.
const int kTranslateModelSizeMb = 30;

/// Gói tiếng Anh luôn có sẵn trong ML Kit (không tải, không xoá được).
const String kBuiltInModelCode = 'en';

/// Ánh xạ mã ngôn ngữ app → [TranslateLanguage] của ML Kit. `null` nếu không thuộc 2 ngôn ngữ.
TranslateLanguage? translateLanguageFor(String code) => switch (code) {
  'vi' => TranslateLanguage.vietnamese,
  'en' => TranslateLanguage.english,
  _ => null,
};

/// Mã ngôn ngữ app (vi, en…) của [code] bất kỳ (vd. `vi-VN`, `en_US`); không thuộc 2 ngôn ngữ → `null`.
String? normalizeLanguageCode(String? code) {
  if (code == null) return null;
  final base = code.split(RegExp('[-_]')).first.toLowerCase();
  return kTranslateLanguageCodes.contains(base) ? base : null;
}

/// Đoán ngôn ngữ theo ký tự (không cần gói nhận diện ngôn ngữ): có dấu tiếng Việt đáng kể → vi; còn lại → en.
String guessLanguageCode(String text, {int maxChars = 4000}) {
  var latin = 0, viMarks = 0;
  var seen = 0;
  for (final r in text.runes) {
    if (++seen > maxChars) break;
    if (_isVietnameseMark(r)) {
      viMarks++;
      // Dấu kết hợp (NFD) không phải chữ; chữ có dấu dựng sẵn vẫn tính là chữ Latin.
      if (r < 0x0300 || r > 0x036F) latin++;
    } else if (_isLatinLetter(r)) {
      latin++;
    }
  }
  if (latin == 0) return 'en';
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
