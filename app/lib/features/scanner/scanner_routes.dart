import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'ui/scanner_screen.dart';

/// Route của feature `scanner` (gộp trong `core/router/app_router.dart`).
final List<RouteBase> scannerRoutes = [
  GoRoute(
    path: Routes.scanner,
    builder: (context, state) => const ScannerScreen(),
  ),
];
