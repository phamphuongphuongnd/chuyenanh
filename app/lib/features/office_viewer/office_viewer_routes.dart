import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `office_viewer` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> officeViewerRoutes = [
  GoRoute(
    path: Routes.docxViewer,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.office_title} · docxViewer',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.xlsxViewer,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.office_title} · xlsxViewer',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.txtViewer,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.office_title} · txtViewer',
      detail: state.extra as String?,
    ),
  ),
];
