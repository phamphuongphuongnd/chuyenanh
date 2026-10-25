import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `settings` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: Routes.settings,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.settings_title} · settings'),
  ),
  GoRoute(
    path: Routes.language,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.settings_title} · language'),
  ),
  GoRoute(
    path: Routes.about,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.settings_title} · about'),
  ),
];
