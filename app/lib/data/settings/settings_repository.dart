import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/l10n.dart' show appLocales;
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
    this.storageBannerDismissedAt,
  });

  /// `null` = theo ngôn ngữ máy.
  final Locale? locale;
  final ThemeMode themeMode;
  final PageSizeOption defaultPageSize;

  /// `null` = thư mục mặc định (`Documents/Phiotron PDF`).
  final String? outputDir;

  /// Khoá app bằng vân tay / khuôn mặt / PIN của máy (mặc định tắt).
  final bool appLock;

  /// Lúc người dùng tắt biểu ngữ xin quyền "Truy cập tất cả file" (`null` = chưa tắt).
  final DateTime? storageBannerDismissedAt;

  AppSettings copyWith({
    Locale? Function()? locale,
    ThemeMode? themeMode,
    PageSizeOption? defaultPageSize,
    String? Function()? outputDir,
    bool? appLock,
    DateTime? Function()? storageBannerDismissedAt,
  }) => AppSettings(
    locale: locale != null ? locale() : this.locale,
    themeMode: themeMode ?? this.themeMode,
    defaultPageSize: defaultPageSize ?? this.defaultPageSize,
    outputDir: outputDir != null ? outputDir() : this.outputDir,
    appLock: appLock ?? this.appLock,
    storageBannerDismissedAt: storageBannerDismissedAt != null
        ? storageBannerDismissedAt()
        : this.storageBannerDismissedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.themeMode == themeMode &&
      other.defaultPageSize == defaultPageSize &&
      other.outputDir == outputDir &&
      other.appLock == appLock &&
      other.storageBannerDismissedAt == storageBannerDismissedAt;

  @override
  int get hashCode =>
      Object.hash(
    locale,
    themeMode,
    defaultPageSize,
    outputDir,
    appLock,
    storageBannerDismissedAt,
  );
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
  static const kStorageBannerDismissedAt = 'settings.storageBannerDismissedAt';

  AppSettings load() {
    final code = _prefs.getString(kLocale);
    // Ngôn ngữ đã bỏ (zh, ja, ko, id…) → null = theo máy (rơi về vi/en).
    final supported = code == null
        ? null
        : appLocales.where((l) => l.languageCode == code).firstOrNull;
    return AppSettings(
      locale: supported,
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == _prefs.getString(kThemeMode),
        orElse: () => ThemeMode.system,
      ),
      defaultPageSize: PageSizeOption.fromName(
        _prefs.getString(kDefaultPageSize),
      ),
      outputDir: _prefs.getString(kOutputDir),
      appLock: _prefs.getBool(kAppLock) ?? false,
      storageBannerDismissedAt: switch (_prefs.getInt(kStorageBannerDismissedAt)) {
        final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
        null => null,
      },
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

  Future<void> setStorageBannerDismissedAt(DateTime? at) => at == null
      ? _prefs.remove(kStorageBannerDismissedAt)
      : _prefs.setInt(kStorageBannerDismissedAt, at.millisecondsSinceEpoch);
}
