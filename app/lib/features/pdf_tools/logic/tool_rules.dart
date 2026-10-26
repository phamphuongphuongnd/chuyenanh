import 'package:path/path.dart' as p;

/// Tên gợi ý khi gộp: `A & B`; từ 3 file trở lên `A & B (+N)`. Cắt tối đa 80 ký tự.
String mergedDefaultName(List<String> inputPaths) {
  final names = [
    for (final path in inputPaths) p.basenameWithoutExtension(path),
  ];
  if (names.isEmpty) return 'merged';
  var text = names.length == 1 ? names.first : '${names[0]} & ${names[1]}';
  if (names.length > 2) text = '$text (+${names.length - 2})';
  if (text.length > 80) text = '${text.substring(0, 77)}...';
  return text;
}

/// Tên cơ sở kết quả: `<tên gốc>_<hậu tố>` (vd. `report_locked`).
String suffixedName(String inputPath, String suffix) =>
    '${p.basenameWithoutExtension(inputPath)}_$suffix';

/// Lỗi nhập mật khẩu mới.
enum PasswordIssue { empty, mismatch }

/// Kiểm mật khẩu khoá file: không rỗng, nhập lại khớp. `null` = hợp lệ.
PasswordIssue? validateNewPassword(String password, String confirm) {
  if (password.isEmpty) return PasswordIssue.empty;
  if (password != confirm) return PasswordIssue.mismatch;
  return null;
}

/// Số trang tài liệu trắng từ chuỗi người dùng gõ; ngoài 1..1000 hoặc không phải số → `null`.
int? parseBlankPageCount(String text) {
  final n = int.tryParse(text.trim());
  if (n == null || n < 1 || n > 1000) return null;
  return n;
}

/// Số file sẽ tạo khi tách mỗi [n] trang từ [pageCount] trang (n < 1 → 0).
int splitEveryNFileCount(int pageCount, int n) =>
    n < 1 || pageCount < 1 ? 0 : (pageCount + n - 1) ~/ n;
