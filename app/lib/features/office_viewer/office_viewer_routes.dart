import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'screens/office_screens.dart';

/// Route của feature `office_viewer` (gộp trong `core/router/app_router.dart`).
/// `extra`: `String` (đường dẫn file).
final List<RouteBase> officeViewerRoutes = [
  GoRoute(
    path: Routes.docxViewer,
    builder: (context, state) =>
        DocxViewerScreen(path: state.extra as String?),
  ),
  GoRoute(
    path: Routes.xlsxViewer,
    builder: (context, state) =>
        XlsxViewerScreen(path: state.extra as String?),
  ),
  GoRoute(
    path: Routes.txtViewer,
    builder: (context, state) => TxtViewerScreen(path: state.extra as String?),
  ),
];
