import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Kết quả một lần xác thực bằng khoá của máy.
enum AppAuthResult {
  /// Người dùng đã xác thực đúng (vân tay / khuôn mặt / PIN / hình vẽ / mật khẩu máy).
  success,

  /// Huỷ, sai, hết giờ, bị hệ thống ngắt… — thử lại được.
  failed,

  /// Máy không có khoá màn hình / không hỗ trợ / lỗi nền tảng — không xác thực được.
  unavailable,
}

/// Engine xác thực bằng khoá của máy. Test thay bằng fake qua [appAuthenticatorProvider].
abstract interface class AppAuthenticator {
  /// Máy có cách xác thực nào dùng được không (sinh trắc học hoặc khoá màn hình).
  Future<bool> isSupported();

  /// Hiện hộp thoại xác thực của hệ thống với lời nhắc [reason].
  /// Cho phép PIN / hình vẽ / mật khẩu máy, không chỉ sinh trắc học.
  Future<AppAuthResult> authenticate(String reason);
}

/// Cài đặt thật bằng gói `local_auth`.
class LocalAppAuthenticator implements AppAuthenticator {
  LocalAppAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<AppAuthResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Cho phép rơi về PIN / hình vẽ / mật khẩu máy.
        biometricOnly: false,
        // Không hiện bước "xác nhận" thêm sau khi nhận diện khuôn mặt.
        sensitiveTransaction: false,
        // Lỡ bị đẩy xuống nền giữa chừng thì hỏi lại khi quay về thay vì báo lỗi.
        persistAcrossBackgrounding: true,
      );
      return ok ? AppAuthResult.success : AppAuthResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError => AppAuthResult.unavailable,
        _ => AppAuthResult.failed,
      };
    } on PlatformException {
      return AppAuthResult.unavailable;
    } on MissingPluginException {
      return AppAuthResult.unavailable;
    }
  }
}

/// Engine thật; test override bằng fake.
final appAuthenticatorProvider = Provider<AppAuthenticator>(
  (ref) => LocalAppAuthenticator(),
);

/// Bọc [AppAuthenticator] và đếm số phiên xác thực đang chạy. Màn PIN / sinh trắc của
/// hệ thống có thể đẩy app xuống nền (Android mở Activity riêng cho PIN) — trong lúc đó
/// [AppLockGate] không tính là "rời app", nên xác thực xong không bị khoá lại.
class AppAuthService {
  AppAuthService(this._engine);

  final AppAuthenticator _engine;
  int _running = 0;

  /// Đang có hộp thoại xác thực của hệ thống.
  bool get isAuthenticating => _running > 0;

  Future<bool> isSupported() => _engine.isSupported();

  Future<AppAuthResult> authenticate(String reason) async {
    _running++;
    try {
      return await _engine.authenticate(reason);
    } catch (_) {
      return AppAuthResult.unavailable;
    } finally {
      _running--;
    }
  }
}

final appAuthServiceProvider = Provider<AppAuthService>(
  (ref) => AppAuthService(ref.watch(appAuthenticatorProvider)),
);

/// Đồng hồ cho [AppLockGate] (test thay để giả lập thời gian ở nền).
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
