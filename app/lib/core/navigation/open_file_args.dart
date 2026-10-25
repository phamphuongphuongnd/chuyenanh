import 'package:flutter/foundation.dart';

/// Tham số mở trình đọc PDF (`Routes.pdfReader`, `extra: OpenFileArgs`).
@immutable
class OpenFileArgs {
  const OpenFileArgs(this.path, {this.password, this.initialPage});

  final String path;

  /// Mật khẩu đã biết (vd. vừa nhập ở màn khác); null = reader tự hỏi nếu cần.
  final String? password;

  /// Trang mở đầu, 0-based (vd. mở từ bookmark).
  final int? initialPage;

  @override
  bool operator ==(Object other) =>
      other is OpenFileArgs &&
      other.path == path &&
      other.password == password &&
      other.initialPage == initialPage;

  @override
  int get hashCode => Object.hash(path, password, initialPage);
}
