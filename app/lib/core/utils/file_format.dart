import 'package:intl/intl.dart';

/// Dung lượng theo locale: `vi` → `4,35 MB`, `en` → `4.35 MB`. Đơn vị 1024.
/// < 1 KB hiện số byte nguyên (`512 B`); còn lại 2 chữ số thập phân, bỏ số 0 thừa không làm.
String formatFileSize(int bytes, String locale) {
  if (bytes < 1024) return '${bytes < 0 ? 0 : bytes} B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final nf = NumberFormat('0.00', _safeLocale(locale));
  return '${nf.format(value)} ${units[unit]}';
}

/// Dòng thông tin file: `4,35 MB • 07:23 • Download`.
/// Cùng ngày với [now] → giờ `HH:mm`; khác ngày → ngày dạng ngắn theo locale (`yMd`).
String formatFileInfoLine(
  int size,
  DateTime modified,
  String folder,
  String locale, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final sameDay =
      n.year == modified.year &&
      n.month == modified.month &&
      n.day == modified.day;
  final loc = _safeLocale(locale);
  final time = sameDay
      ? DateFormat('HH:mm', loc).format(modified)
      : DateFormat.yMd(loc).format(modified);
  final parts = [formatFileSize(size, locale), time];
  if (folder.isNotEmpty) parts.add(folder);
  return parts.join(' • ');
}

/// Ngày giờ đầy đủ (hộp thoại Thông tin file).
String formatDateTime(DateTime dt, String locale) =>
    DateFormat.yMd(_safeLocale(locale)).add_Hm().format(dt);

String _safeLocale(String locale) {
  final l = locale.replaceAll('-', '_');
  return DateFormat.localeExists(l) ? l : 'en';
}
