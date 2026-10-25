import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `documents` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> documentsRoutes = [
  GoRoute(
    path: Routes.home,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.docs_title} · home'),
  ),
  GoRoute(
    path: Routes.search,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.docs_title} · search'),
  ),
  GoRoute(
    path: Routes.recents,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.docs_title} · recents'),
  ),
  GoRoute(
    path: Routes.favorites,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.docs_title} · favorites'),
  ),
];
