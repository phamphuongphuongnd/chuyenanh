import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `pdf_tools` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> pdfToolsRoutes = [
  GoRoute(
    path: Routes.merge,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · merge',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.split,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · split',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.organize,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · organize',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.lock,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · lock',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.unlock,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · unlock',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.watermark,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · watermark',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.createBlank,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.tools_title} · createBlank',
      detail: state.extra as String?,
    ),
  ),
];
