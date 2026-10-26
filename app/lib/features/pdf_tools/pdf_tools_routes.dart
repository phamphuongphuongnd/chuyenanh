import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'ui/create_blank_screen.dart';
import 'ui/lock_screen.dart';
import 'ui/merge_screen.dart';
import 'ui/organize_screen.dart';
import 'ui/split_screen.dart';
import 'ui/unlock_screen.dart';
import 'ui/watermark_screen.dart';

/// `extra` của route là path PDF đầu vào (`String?`); giá trị khác kiểu coi như không có.
String? _pathOf(GoRouterState state) {
  final extra = state.extra;
  return extra is String ? extra : null;
}

/// Route của feature `pdf_tools` (gộp trong `core/router/app_router.dart`).
final List<RouteBase> pdfToolsRoutes = [
  GoRoute(
    path: Routes.merge,
    builder: (context, state) => MergeScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.split,
    builder: (context, state) => SplitScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.organize,
    builder: (context, state) => OrganizeScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.lock,
    builder: (context, state) => LockScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.unlock,
    builder: (context, state) => UnlockScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.watermark,
    builder: (context, state) => WatermarkScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.createBlank,
    builder: (context, state) => const CreateBlankScreen(),
  ),
];
