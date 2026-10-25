import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `convert` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> convertRoutes = [
  GoRoute(
    path: Routes.textToPdf,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · textToPdf',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.wordToPdf,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · wordToPdf',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.excelToPdf,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · excelToPdf',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.pdfToText,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · pdfToText',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.pdfToWord,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · pdfToWord',
      detail: state.extra as String?,
    ),
  ),
  GoRoute(
    path: Routes.pdfToExcel,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.conv_title} · pdfToExcel',
      detail: state.extra as String?,
    ),
  ),
];
