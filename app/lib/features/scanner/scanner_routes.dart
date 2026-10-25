import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `scanner` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> scannerRoutes = [
  GoRoute(
    path: Routes.scanner,
    builder: (context, state) =>
        PlaceholderScreen(title: '${context.l10n.scan_title} · scanner'),
  ),
];
