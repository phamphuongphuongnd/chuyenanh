import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Truy cập chuỗi: `context.l10n.core_ok`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 6 ngôn ngữ của app (đã bỏ tiếng Thái 26/10) (thứ tự hiển thị trong màn Ngôn ngữ).
const List<Locale> appLocales = [
  Locale('vi'),
  Locale('en'),
  Locale('zh'),
  Locale('ja'),
  Locale('ko'),
  Locale('id'),
];

/// Tên ngôn ngữ viết bằng chính ngôn ngữ đó.
const Map<String, String> localeNativeNames = {
  'vi': 'Tiếng Việt',
  'en': 'English',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'id': 'Bahasa Indonesia',
};
