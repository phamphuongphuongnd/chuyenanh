// Kiểm thử hộp trắng A12 — app/lib/data/settings/settings_providers.dart (không rẽ nhánh)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/page_size.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() => c.dispose());

  test('U1.1 sharedPreferencesProvider chưa override ⇒ báo lỗi UnimplementedError', () {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    final r = (() {
      try {
        return bare.read(sharedPreferencesProvider);
      } catch (e) {
        return e;
      }
    })();
    expect(r, isNot(isA<SharedPreferences>()));
    expect(r.toString(), contains('UnimplementedError'));
  });

  test('U2.1 build ⇒ đọc cài đặt đã lưu', () async {
    await prefs.setString(SettingsRepository.kThemeMode, 'dark');
    await prefs.setBool(SettingsRepository.kAppLock, true);
    final fresh = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(fresh.dispose);
    final s = fresh.read(settingsProvider);
    expect((s.themeMode, s.appLock), (ThemeMode.dark, true));
  });

  test('U3.1 setLocale ⇒ state đổi ngay + lưu', () async {
    await c.read(settingsProvider.notifier).setLocale(const Locale('vi'));
    expect(c.read(settingsProvider).locale, const Locale('vi'));
    expect(prefs.getString(SettingsRepository.kLocale), 'vi');
    await c.read(settingsProvider.notifier).setLocale(null);
    expect(c.read(settingsProvider).locale, isNull);
    expect(prefs.getString(SettingsRepository.kLocale), isNull);
  });

  test('U4.1 setThemeMode ⇒ state đổi ngay + lưu', () async {
    await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
    expect(c.read(settingsProvider).themeMode, ThemeMode.light);
    expect(prefs.getString(SettingsRepository.kThemeMode), 'light');
  });

  test('U5.1 setDefaultPageSize ⇒ state đổi ngay + lưu', () async {
    final other = PageSizeOption.values.firstWhere((e) => e != PageSizeOption.a4);
    await c.read(settingsProvider.notifier).setDefaultPageSize(other);
    expect(c.read(settingsProvider).defaultPageSize, other);
    expect(prefs.getString(SettingsRepository.kDefaultPageSize), other.name);
  });

  test('U6.1 setOutputDir ⇒ state đổi ngay + lưu; null ⇒ về mặc định', () async {
    await c.read(settingsProvider.notifier).setOutputDir('/out');
    expect(c.read(settingsProvider).outputDir, '/out');
    expect(prefs.getString(SettingsRepository.kOutputDir), '/out');
    await c.read(settingsProvider.notifier).setOutputDir(null);
    expect(c.read(settingsProvider).outputDir, isNull);
    expect(prefs.containsKey(SettingsRepository.kOutputDir), isFalse);
  });

  test('U7.1 setAppLock ⇒ state đổi ngay + lưu, không đụng cài đặt khác', () async {
    final before = c.read(settingsProvider);
    await c.read(settingsProvider.notifier).setAppLock(true);
    final s = c.read(settingsProvider);
    expect(s.appLock, isTrue);
    expect(prefs.getBool(SettingsRepository.kAppLock), isTrue);
    expect(s, before.copyWith(appLock: true));
    await c.read(settingsProvider.notifier).setAppLock(false);
    expect(c.read(settingsProvider).appLock, isFalse);
    expect(prefs.getBool(SettingsRepository.kAppLock), isFalse);
  });
}
