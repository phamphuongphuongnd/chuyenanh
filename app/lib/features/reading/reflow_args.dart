import 'package:flutter/foundation.dart';

import '../../core/navigation/open_file_args.dart';

/// Màn đọc dàn chữ mở ở chế độ nào (từ menu ⋮ của trình đọc PDF).
enum ReflowMode {
  /// Chỉ đọc.
  read,

  /// Mở sẵn thanh đọc to.
  readAloud,

  /// Mở sẵn bảng dịch cho trang đang đọc.
  translate,
}

/// `extra` của `Routes.reflow`: file cần mở + chế độ. Route vẫn nhận [OpenFileArgs] trơn (= [ReflowMode.read]).
@immutable
class ReflowArgs {
  const ReflowArgs(this.file, {this.mode = ReflowMode.read});

  final OpenFileArgs file;
  final ReflowMode mode;

  @override
  bool operator ==(Object other) =>
      other is ReflowArgs && other.file == file && other.mode == mode;

  @override
  int get hashCode => Object.hash(file, mode);
}
