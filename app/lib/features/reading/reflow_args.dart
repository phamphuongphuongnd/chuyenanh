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
  const ReflowArgs(
    this.file, {
    this.mode = ReflowMode.read,
    this.autoStartReadAloud = false,
  });

  final OpenFileArgs file;
  final ReflowMode mode;

  /// Chỉ có nghĩa với [ReflowMode.readAloud]: dàn chữ xong thì tự bắt đầu đọc (một chạm từ menu).
  final bool autoStartReadAloud;

  @override
  bool operator ==(Object other) =>
      other is ReflowArgs && other.file == file &&
      other.mode == mode &&
      other.autoStartReadAloud == autoStartReadAloud;

  @override
  int get hashCode => Object.hash(file, mode, autoStartReadAloud);
}
