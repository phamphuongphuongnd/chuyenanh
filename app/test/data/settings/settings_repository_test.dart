import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/page_size.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mặc định khi chưa lưu gì', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.load(), const AppSettings());
  });

  test('notifier ghi và đọc lại', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final n = container.read(settingsProvider.notifier);
    await n.setLocale(const Locale('vi'));
    await n.setThemeMode(ThemeMode.dark);
    await n.setDefaultPageSize(PageSizeOption.letter);
    await n.setOutputDir('/sdcard/Out');

    const expected = AppSettings(
      locale: Locale('vi'),
      themeMode: ThemeMode.dark,
      defaultPageSize: PageSizeOption.letter,
      outputDir: '/sdcard/Out',
    );
    expect(container.read(settingsProvider), expected);
    expect(SettingsRepository(prefs).load(), expected);

    await n.setLocale(null);
    await n.setOutputDir(null);
    expect(SettingsRepository(prefs).load().locale, isNull);
    expect(SettingsRepository(prefs).load().outputDir, isNull);
  });

  test('khoá app: mặc định tắt, lưu và đọc lại', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    expect(repo.load().appLock, isFalse);

    await repo.setAppLock(true);
    expect(prefs.getBool(SettingsRepository.kAppLock), isTrue);
    expect(SettingsRepository(prefs).load().appLock, isTrue);

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(settingsProvider).appLock, isTrue);
    await container.read(settingsProvider.notifier).setAppLock(false);
    expect(container.read(settingsProvider).appLock, isFalse);
    expect(SettingsRepository(prefs).load().appLock, isFalse);
  });

  test('appLock tham gia copyWith, == và hashCode', () {
    const a = AppSettings();
    final b = a.copyWith(appLock: true);
    expect(b.appLock, isTrue);
    expect(b == a, isFalse);
    expect(b.copyWith(appLock: false), a);
    expect(b.copyWith().hashCode, b.hashCode);
  });
}
