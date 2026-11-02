// Kiểm thử hộp trắng A13 — app/lib/features/system/app_authenticator.dart
// Thiết kế: test-output/whitebox/system/app_authenticator/buoc-1..5. Expected chép từ Bước 5.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf_office/features/system/app_authenticator.dart';

/// LocalAuthentication giả: trả [supported]/[ok] hoặc ném [error]; ghi tham số gọi.
class _FakeLocalAuth implements LocalAuthentication {
  Object? error;
  bool supported = true;
  bool ok = true;
  int supportedCalls = 0;
  int authCalls = 0;
  Map<Symbol, dynamic> lastArgs = {};

  @override
  Future<bool> isDeviceSupported() async {
    supportedCalls++;
    if (error != null) throw error!;
    return supported;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      authCalls++;
      lastArgs = invocation.namedArguments;
      final e = error;
      if (e != null) return Future<bool>.error(e);
      return Future<bool>.value(ok);
    }
    return super.noSuchMethod(invocation);
  }
}

class _Engine implements AppAuthenticator {
  Completer<AppAuthResult>? pending;
  Object? error;
  int calls = 0;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<AppAuthResult> authenticate(String reason) {
    calls++;
    if (error != null) return Future.error(error!);
    return pending!.future;
  }
}

LocalAuthException _lae(LocalAuthExceptionCode c) => LocalAuthException(code: c);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U1 hàm tạo', () {
    test('1-1 không truyền auth ⇒ tạo được, không ném', () {
      final r = (() {
        try {
          LocalAppAuthenticator();
          return 'ok';
        } catch (e) {
          return e;
        }
      })();
      expect(r, 'ok');
    });
    test('1-2 truyền bản giả ⇒ isSupported dùng bản giả', () async {
      final f = _FakeLocalAuth()..supported = true;
      final r = await LocalAppAuthenticator(f).isSupported();
      expect(f.supportedCalls, 1);
      expect(r, isTrue);
    });
  });

  group('U2 isSupported', () {
    Future<(int, Object?)> run(_FakeLocalAuth f) async {
      final r = await LocalAppAuthenticator(f).isSupported().then((v) => v as Object?, onError: (Object e) => e);
      return (f.supportedCalls, r);
    }

    test('2-1 máy trả false ⇒ false', () async {
      final (calls, r) = await run(_FakeLocalAuth()..supported = false);
      expect(calls, 1);
      expect(r, isFalse);
    });
    test('2-2 PlatformException ⇒ ném lên (không đổi thành false)', () async {
      final (calls, r) = await run(_FakeLocalAuth()..error = PlatformException(code: 'x'));
      expect(calls, 1);
      expect(r, isA<PlatformException>());
    });
    test('2-3 LocalAuthException ⇒ ném lên', () async {
      final (calls, r) = await run(_FakeLocalAuth()..error = _lae(LocalAuthExceptionCode.deviceError));
      expect(calls, 1);
      expect(r, isA<LocalAuthException>());
    });
    test('2-4 MissingPluginException ⇒ ném lên', () async {
      final (calls, r) = await run(_FakeLocalAuth()..error = MissingPluginException());
      expect(calls, 1);
      expect(r, isA<MissingPluginException>());
    });
  });

  group('U3 authenticate', () {
    Future<Object?> run(_FakeLocalAuth f) =>
        LocalAppAuthenticator(f).authenticate('Mở khoá').then((v) => v as Object?, onError: (Object e) => e);

    test('3-1 xác thực đúng ⇒ success, cho phép PIN, hỏi lại sau nền', () async {
      final f = _FakeLocalAuth()..ok = true;
      final r = await run(f);
      expect(f.authCalls, 1);
      expect(f.lastArgs[#localizedReason], 'Mở khoá');
      expect(f.lastArgs[#biometricOnly], isFalse);
      expect(f.lastArgs[#persistAcrossBackgrounding], isTrue);
      expect(r, AppAuthResult.success);
    });
    test('3-2 trả false ⇒ failed', () async {
      final f = _FakeLocalAuth()..ok = false;
      final r = await run(f);
      expect(f.authCalls, 1);
      expect(r, AppAuthResult.failed);
    });
    test('3-3 MissingPluginException ⇒ unavailable', () async {
      final f = _FakeLocalAuth()..error = MissingPluginException();
      expect(await run(f), AppAuthResult.unavailable);
      expect(f.authCalls, 1);
    });
    test('3-4 PlatformException ⇒ unavailable', () async {
      final f = _FakeLocalAuth()..error = PlatformException(code: 'x');
      expect(await run(f), AppAuthResult.unavailable);
    });
    for (final (id, code) in [
      ('3-5', LocalAuthExceptionCode.noCredentialsSet),
      ('3-6', LocalAuthExceptionCode.noBiometricHardware),
      ('3-7', LocalAuthExceptionCode.noBiometricsEnrolled),
      ('3-8', LocalAuthExceptionCode.deviceError),
      ('3-9', LocalAuthExceptionCode.unknownError),
    ]) {
      test('$id LocalAuthException(${code.name}) ⇒ unavailable', () async {
        final f = _FakeLocalAuth()..error = _lae(code);
        final r = await run(f);
        expect(f.authCalls, 1);
        expect(r, AppAuthResult.unavailable);
      });
    }
    test('3-10 userCanceled ⇒ failed', () async {
      final f = _FakeLocalAuth()..error = _lae(LocalAuthExceptionCode.userCanceled);
      expect(await run(f), AppAuthResult.failed);
    });
    test('3-10b timeout/systemCanceled/temporaryLockout/biometricLockout ⇒ failed', () async {
      for (final c in [
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout,
      ]) {
        expect(await run(_FakeLocalAuth()..error = _lae(c)), AppAuthResult.failed, reason: c.name);
      }
    });
  });

  group('U4 AppAuthService.authenticate', () {
    test('4-1 engine trả success; đang chờ ⇒ isAuthenticating', () async {
      final e = _Engine()..pending = Completer();
      final s = AppAuthService(e);
      final fut = s.authenticate('r');
      expect(s.isAuthenticating, isTrue);
      e.pending!.complete(AppAuthResult.success);
      final r = await fut;
      expect(e.calls, 1);
      expect(s.isAuthenticating, isFalse);
      expect(r, AppAuthResult.success);
    });
    test('4-2 engine ném ⇒ unavailable, bộ đếm về 0', () async {
      final e = _Engine()..error = StateError('boom');
      final s = AppAuthService(e);
      final r = await s.authenticate('r').then((v) => v as Object?, onError: (Object x) => x);
      expect(e.calls, 1);
      expect(s.isAuthenticating, isFalse);
      expect(r, AppAuthResult.unavailable);
    });
  });

  group('U5 AppAuthService.isSupported / isDefinitelyUnsupported', () {
    test('5-1 máy báo không hỗ trợ ⇒ isDefinitelyUnsupported true', () async {
      final s = AppAuthService(_SupportEngine(supported: false));
      expect(await s.isSupported(), isFalse);
      expect(await s.isDefinitelyUnsupported(), isTrue);
    });
    test('5-2 máy hỗ trợ ⇒ isDefinitelyUnsupported false', () async {
      final s = AppAuthService(_SupportEngine(supported: true));
      expect(await s.isSupported(), isTrue);
      expect(await s.isDefinitelyUnsupported(), isFalse);
    });
    test('5-3 engine ném ⇒ isSupported false nhưng KHÔNG coi là chắc chắn không có khoá', () async {
      final s = AppAuthService(_SupportEngine(error: PlatformException(code: 'x')));
      expect(await s.isSupported(), isFalse);
      expect(await s.isDefinitelyUnsupported(), isFalse);
    });
  });
}

class _SupportEngine implements AppAuthenticator {
  _SupportEngine({this.supported = true, this.error});
  final bool supported;
  final Object? error;
  @override
  Future<bool> isSupported() async {
    if (error != null) throw error!;
    return supported;
  }

  @override
  Future<AppAuthResult> authenticate(String reason) async => AppAuthResult.failed;
}
