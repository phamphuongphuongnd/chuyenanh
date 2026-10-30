import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/page_size.dart';

/// Cài đặt app (bất biến).
@immutable
class AppSettings {
  const AppSettings({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.defaultPageSize = PageSizeOption.a4,
    this.outputDir,
    this.appLock = false,
  });

  /// `null` = theo ngôn ngữ máy.
  final Locale? locale;
  final ThemeMode themeMode;
  final PageSizeOption defaultPageSize;

  /// `null` = thư mục mặc định (`Documents/Phiotron PDF`).
  final String? outputDir;

  /// Khoá app bằng vân tay / khuôn mặt / PIN của máy (mặc định tắt).
  final bool appLock;

  AppSettings copyWith({
    Locale? Function()? locale,
    ThemeMode? themeMode,
    PageSizeOption? defaultPageSize,
    String? Function()? outputDir,
    bool? appLock,
  }) => AppSettings(
    locale: locale != null ? locale() : this.locale,
    themeMode: themeMode ?? this.themeMode,
    defaultPageSize: defaultPageSize ?? this.defaultPageSize,
    outputDir: outputDir != null ? outputDir() : this.outputDir,
    appLock: appLock ?? this.appLock,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.themeMode == themeMode &&
      other.defaultPageSize == defaultPageSize &&
      other.outputDir == outputDir &&
      other.appLock == appLock;

  @override
  int get hashCode =>
      Object.hash(locale, themeMode, defaultPageSize, outputDir, appLock);
}

/// Đọc/ghi [AppSettings] bằng shared_preferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const kLocale = 'settings.locale';
  static const kThemeMode = 'settings.themeMode';
  static const kDefaultPageSize = 'settings.defaultPageSize';
  static const kOutputDir = 'settings.outputDir';
  static const kAppLock = 'settings.appLock';

  AppSettings load() {
    final code = _prefs.getString(kLocale);
    return AppSettings(
      locale: code == null || code.isEmpty ? null : Locale(code),
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == _prefs.getString(kThemeMode),
        orElse: () => ThemeMode.system,
      ),
      defaultPageSize: PageSizeOption.fromName(
        _prefs.getString(kDefaultPageSize),
      ),
      outputDir: _prefs.getString(kOutputDir),
      appLock: _prefs.getBool(kAppLock) ?? false,
    );
  }

  Future<void> setLocale(Locale? locale) => locale == null
      ? _prefs.remove(kLocale)
      : _prefs.setString(kLocale, locale.languageCode);

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(kThemeMode, mode.name);

  Future<void> setDefaultPageSize(PageSizeOption size) =>
      _prefs.setString(kDefaultPageSize, size.name);

  Future<void> setOutputDir(String? dir) => dir == null || dir.isEmpty
      ? _prefs.remove(kOutputDir)
      : _prefs.setString(kOutputDir, dir);

  Future<void> setAppLock(bool enabled) => _prefs.setBool(kAppLock, enabled);
}
