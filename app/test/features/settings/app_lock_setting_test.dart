import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/settings_routes.dart';
import 'package:pdf_office/features/system/app_authenticator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine xác thực giả: trả [result], đếm số lần gọi và lời nhắc gần nhất.
class _FakeAuth implements AppAuthenticator {
  _FakeAuth({this.result = AppAuthResult.success, this.supported = true});

  AppAuthResult result;
  bool supported;
  int calls = 0;
  String? lastReason;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<AppAuthResult> authenticate(String reason) async {
    calls++;
    lastReason = reason;
    return result;
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _FakeAuth auth,
  bool appLock = false,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    SettingsRepository.kLocale: 'en',
    SettingsRepository.kAppLock: appLock,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appAuthenticatorProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: settingsRoutes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

final _row = find.byKey(const ValueKey('settings_appLock'));
final _switch = find.byKey(const ValueKey('settings_appLock_switch'));

bool _switchValue(WidgetTester tester) => tester.widget<Switch>(_switch).value;

void main() {
  testWidgets('dòng Khoá ứng dụng có công tắc và phụ đề', (tester) async {
    await _pump(tester, auth: _FakeAuth());
    expect(_row, findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);
    expect(
      find.text("Use your device's fingerprint, face or PIN"),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _row, matching: find.byType(Switch)),
      findsOneWidget,
    );
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('bật: xác thực thành công thì lưu và công tắc bật', (
    tester,
  ) async {
    final auth = _FakeAuth();
    final c = await _pump(tester, auth: auth);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(auth.lastReason, 'Verify to turn on app lock');
    expect(c.read(settingsProvider).appLock, isTrue);
    expect(_switchValue(tester), isTrue);
  });

  testWidgets('chạm cả dòng cũng bật/tắt như công tắc', (tester) async {
    final auth = _FakeAuth();
    final c = await _pump(tester, auth: auth);
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).appLock, isTrue);
  });

  testWidgets('bật: xác thực thất bại thì không bật', (tester) async {
    final auth = _FakeAuth(result: AppAuthResult.failed);
    final c = await _pump(tester, auth: auth);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(c.read(settingsProvider).appLock, isFalse);
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('máy không có khoá màn hình: hộp thoại giải thích, không bật', (
    tester,
  ) async {
    final auth = _FakeAuth(supported: false);
    final c = await _pump(tester, auth: auth);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(find.text("Can't turn on app lock"), findsOneWidget);
    expect(c.read(settingsProvider).appLock, isFalse);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("Can't turn on app lock"), findsNothing);
  });

  testWidgets('xác thực báo không hỗ trợ khi bật: hộp thoại, không bật', (
    tester,
  ) async {
    final auth = _FakeAuth(result: AppAuthResult.unavailable);
    final c = await _pump(tester, auth: auth);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(find.text("Can't turn on app lock"), findsOneWidget);
    expect(c.read(settingsProvider).appLock, isFalse);
  });

  testWidgets('tắt: cũng phải xác thực', (tester) async {
    final auth = _FakeAuth(result: AppAuthResult.failed);
    final c = await _pump(tester, auth: auth, appLock: true);
    expect(_switchValue(tester), isTrue);
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(auth.lastReason, 'Verify to turn off app lock');
    expect(c.read(settingsProvider).appLock, isTrue);

    auth.result = AppAuthResult.success;
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).appLock, isFalse);
    expect(_switchValue(tester), isFalse);
  });
}
