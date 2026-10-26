import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'about_screen.dart';
import 'language_screen.dart';
import 'settings_screen.dart';

/// Route của feature `settings` (gộp trong `core/router/app_router.dart`).
/// Cả 3 route đều là `GoRoute` cấp cao nhất (app_smoke_test kiểm điều này). Giao diện,
/// Thư mục lưu, Khổ giấy là màn con mở bằng `Navigator.push` từ [SettingsScreen].
final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: Routes.settings,
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: Routes.language,
    builder: (context, state) => const LanguageScreen(),
  ),
  GoRoute(
    path: Routes.about,
    builder: (context, state) => const AboutScreen(),
  ),
];
