import 'dart:io';

import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Lỗi thống nhất của app. Engine/feature ném các lớp con này; UI đổi thành câu
/// thông báo bằng [appErrorMessage].
sealed class AppError implements Exception {
  const AppError();

  /// Chuyển exception bất kỳ thành [AppError] (đã là AppError thì giữ nguyên).
  static AppError from(Object error) {
    if (error is AppError) return error;
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      // ENOSPC (28) trên Android/Linux, ERROR_DISK_FULL (112) trên Windows.
      if (code == 28 || code == 112) return const NoSpace();
      // EACCES (13), EPERM (1), ERROR_ACCESS_DENIED (5).
      if (code == 13 || code == 1 || code == 5) return const PermissionDenied();
    }
    return Unknown(error);
  }
}

/// Mật khẩu sai.
final class WrongPassword extends AppError {
  const WrongPassword();
}

/// File có mật khẩu nhưng chưa nhập.
final class PasswordRequired extends AppError {
  const PasswordRequired();
}

/// File hỏng / không đọc được.
final class CorruptFile extends AppError {
  const CorruptFile([this.detail]);
  final String? detail;
}

/// Định dạng không hỗ trợ.
final class UnsupportedFormat extends AppError {
  const UnsupportedFormat([this.extension]);
  final String? extension;
}

/// Hết dung lượng lưu trữ.
final class NoSpace extends AppError {
  const NoSpace();
}

/// Thiếu quyền truy cập file / camera / ảnh.
final class PermissionDenied extends AppError {
  const PermissionDenied();
}

/// Người dùng huỷ (qua `CancelToken`).
final class Cancelled extends AppError {
  const Cancelled();
}

/// Lỗi khác, giữ nguyên nguyên nhân để log.
final class Unknown extends AppError {
  const Unknown(this.cause);
  final Object cause;

  @override
  String toString() => 'Unknown($cause)';
}

/// Câu thông báo theo ngôn ngữ hiện tại.
String appErrorMessage(BuildContext context, AppError error) {
  final l = context.l10n;
  return switch (error) {
    WrongPassword() => l.core_errorWrongPassword,
    PasswordRequired() => l.core_errorPasswordRequired,
    CorruptFile() => l.core_errorCorruptFile,
    UnsupportedFormat() => l.core_errorUnsupportedFormat,
    NoSpace() => l.core_errorNoSpace,
    PermissionDenied() => l.core_errorPermissionDenied,
    Cancelled() => l.core_errorCancelled,
    Unknown() => l.core_errorUnknown,
  };
}
