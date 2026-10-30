import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/page_size.dart';
import 'settings_repository.dart';

export 'settings_repository.dart';

/// Override trong `main()` bằng instance đã `await SharedPreferences.getInstance()`.
/// Test: `SharedPreferences.setMockInitialValues({})` rồi override tương tự.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Cài đặt hiện tại; đổi qua `ref.read(settingsProvider.notifier).setXxx(...)` — UI cập nhật tức thì.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: () => locale);
    await _repo.setLocale(locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repo.setThemeMode(mode);
  }

  Future<void> setDefaultPageSize(PageSizeOption size) async {
    state = state.copyWith(defaultPageSize: size);
    await _repo.setDefaultPageSize(size);
  }

  Future<void> setOutputDir(String? dir) async {
    state = state.copyWith(outputDir: () => dir);
    await _repo.setOutputDir(dir);
  }

  /// Bật/tắt khoá app. Chỉ lưu — việc xác thực trước khi đổi do màn Cài đặt lo.
  Future<void> setAppLock(bool enabled) async {
    state = state.copyWith(appLock: enabled);
    await _repo.setAppLock(enabled);
  }
}
