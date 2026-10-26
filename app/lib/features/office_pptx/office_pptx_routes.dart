import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'pptx_viewer_screen.dart';

/// Route của feature `office_pptx` (gộp trong `core/router/app_router.dart`).
final List<RouteBase> officePptxRoutes = [
  GoRoute(
    path: Routes.pptxViewer,
    builder: (context, state) =>
        PptxViewerScreen(path: (state.extra as String?) ?? ''),
  ),
];
