import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/system/app_authenticator.dart';
import 'package:pdf_office/features/system/app_lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine xác thực giả: trả [result] (hoặc chờ [pending] nếu có), đếm số lần gọi.
class _FakeAuth implements AppAuthenticator {
  _FakeAuth({this.result = AppAuthResult.failed});

  AppAuthResult result;
  bool supported = true;
  Completer<AppAuthResult>? pending;
  int calls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<AppAuthResult> authenticate(String reason) {
    calls++;
    return pending?.future ?? Future.value(result);
  }
}

const _content = 'NOI_DUNG_APP';
final _lockScreen = find.byKey(const ValueKey('app_lock_screen'));

/// Đồng hồ giả cho cổng khoá; tăng bằng [_Clock.advance].
class _Clock {
  DateTime now = DateTime(2026, 10, 30, 9);
  void advance(Duration d) => now = now.add(d);
}

Future<void> _pump(
  WidgetTester tester, {
  required bool appLock,
  required _FakeAuth auth,
  required _Clock clock,
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsRepository.kLocale: 'en',
    SettingsRepository.kAppLock: appLock,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appAuthenticatorProvider.overrideWithValue(auth),
        appLockClockProvider.overrideWithValue(() => clock.now),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            AppLockGate(child: child ?? const SizedBox()),
        home: const Scaffold(body: Text(_content)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Giả lập rời app [away] rồi quay lại (đủ chuỗi trạng thái như máy thật).
Future<void> _leaveAndReturn(
  WidgetTester tester,
  _Clock clock,
  Duration away,
) async {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  clock.advance(away);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  late _Clock clock;
  setUp(() => clock = _Clock());
  tearDown(
    () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  testWidgets('tắt khoá: hiện nội dung, không hỏi xác thực', (tester) async {
    final auth = _FakeAuth();
    await _pump(tester, appLock: false, auth: auth, clock: clock);
    expect(find.text(_content), findsOneWidget);
    expect(_lockScreen, findsNothing);
    expect(auth.calls, 0);

    // Tắt khoá thì rời app lâu cũng không khoá.
    await _leaveAndReturn(tester, clock, const Duration(minutes: 5));
    expect(_lockScreen, findsNothing);
    expect(auth.calls, 0);
  });

  testWidgets('bật khoá + xác thực thất bại: màn khoá che nội dung', (
    tester,
  ) async {
    final auth = _FakeAuth(result: AppAuthResult.failed);
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(_lockScreen, findsOneWidget);
    expect(find.text('Phiotron PDF is locked'), findsOneWidget);
    // Tự hỏi đúng một lần khi màn khoá hiện.
    expect(auth.calls, 1);
    // Nội dung bên dưới không chạm được.
    expect(find.text(_content).hitTestable(), findsNothing);

    // Bấm "Mở khoá" vẫn thất bại → vẫn khoá.
    await tester.tap(find.byKey(const ValueKey('app_lock_unlock')));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(_lockScreen, findsOneWidget);

    // Lần sau thành công → mở.
    auth.result = AppAuthResult.success;
    await tester.tap(find.byKey(const ValueKey('app_lock_unlock')));
    await tester.pumpAndSettle();
    expect(_lockScreen, findsNothing);
    expect(find.text(_content).hitTestable(), findsOneWidget);
  });

  testWidgets('bật khoá + xác thực thành công: hiện nội dung', (tester) async {
    final auth = _FakeAuth(result: AppAuthResult.success);
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(auth.calls, 1);
    expect(_lockScreen, findsNothing);
    expect(find.text(_content).hitTestable(), findsOneWidget);
  });

  testWidgets('quay lại sau 31 giây ở nền → khoá; sau 5 giây → không', (
    tester,
  ) async {
    final auth = _FakeAuth(result: AppAuthResult.success);
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(_lockScreen, findsNothing);
    auth.result = AppAuthResult.failed;

    await _leaveAndReturn(tester, clock, const Duration(seconds: 5));
    expect(_lockScreen, findsNothing);
    expect(auth.calls, 1);

    await _leaveAndReturn(tester, clock, const Duration(seconds: 31));
    expect(_lockScreen, findsOneWidget);
    expect(auth.calls, 2);
  });

  testWidgets('đang ở hộp thoại xác thực của hệ thống thì không tính là rời app', (
    tester,
  ) async {
    final auth = _FakeAuth()..pending = Completer<AppAuthResult>();
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(auth.calls, 1);

    // Android mở Activity PIN → app xuống nền 60 giây trong lúc đang xác thực.
    await _leaveAndReturn(tester, clock, const Duration(seconds: 60));
    auth.pending!.complete(AppAuthResult.success);
    await tester.pumpAndSettle();
    expect(_lockScreen, findsNothing);
    expect(auth.calls, 1);
  });

  testWidgets('máy đã gỡ khoá màn hình: không kẹt ngoài app', (tester) async {
    final auth = _FakeAuth(result: AppAuthResult.unavailable)
      ..supported = false;
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(_lockScreen, findsNothing);
  });

  testWidgets('lỗi nền tảng nhưng máy vẫn có khoá: giữ màn khoá', (
    tester,
  ) async {
    final auth = _FakeAuth(result: AppAuthResult.unavailable);
    await _pump(tester, appLock: true, auth: auth, clock: clock);
    expect(_lockScreen, findsOneWidget);
  });
}
