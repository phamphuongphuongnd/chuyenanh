import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `office_pptx` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> officePptxRoutes = [
  GoRoute(
    path: Routes.pptxViewer,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.pptx_title} · pptxViewer',
      detail: state.extra as String?,
    ),
  ),
];
