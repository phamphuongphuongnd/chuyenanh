import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Truy cập chuỗi: `context.l10n.core_ok`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 7 ngôn ngữ của app (thứ tự hiển thị trong màn Ngôn ngữ).
const List<Locale> appLocales = [
  Locale('vi'),
  Locale('en'),
  Locale('zh'),
  Locale('ja'),
  Locale('ko'),
  Locale('th'),
  Locale('id'),
];

/// Tên ngôn ngữ viết bằng chính ngôn ngữ đó.
const Map<String, String> localeNativeNames = {
  'vi': 'Tiếng Việt',
  'en': 'English',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'th': 'ไทย',
  'id': 'Bahasa Indonesia',
};
