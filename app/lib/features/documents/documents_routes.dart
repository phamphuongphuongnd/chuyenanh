import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'main_shell.dart';
import 'list_screens.dart';

/// Route của feature `documents` (gộp trong `core/router/app_router.dart`).
final List<RouteBase> documentsRoutes = [
  GoRoute(path: Routes.home, builder: (context, state) => const MainShell()),
  GoRoute(
    path: Routes.search,
    builder: (context, state) => const SearchScreen(),
  ),
  GoRoute(
    path: Routes.recents,
    builder: (context, state) => const RecentsScreen(),
  ),
  GoRoute(
    path: Routes.favorites,
    builder: (context, state) => const FavoritesScreen(),
  ),
];
