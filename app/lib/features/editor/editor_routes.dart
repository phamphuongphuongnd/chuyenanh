import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `editor` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> editorRoutes = [
  GoRoute(
    path: Routes.annotate,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.edit_title} · annotate',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.sign,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.edit_title} · sign',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.fillForm,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.edit_title} · fillForm',
      detail: state.extra as String?,
    ),
  ),
];
