import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'qr_scan_screen.dart';

/// Route của feature `qr` (quét mã QR / mã vạch từ ảnh).
final List<RouteBase> qrRoutes = [
  GoRoute(path: Routes.qrScan, builder: (_, _) => const QrScanScreen()),
];
