import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';
import 'language_screen.dart';

/// Route của feature `settings` (gộp trong `core/router/app_router.dart`).
/// Cả 3 route đều là `GoRoute` cấp cao nhất (app_smoke_test kiểm điều này).
final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: Routes.settings,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.settings_title} · settings'),
  ),
  GoRoute(
    path: Routes.language,
    builder: (context, state) => const LanguageScreen(),
  ),
  GoRoute(
    path: Routes.about,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.settings_title} · about'),
  ),
];
