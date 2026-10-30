import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/convert/convert_routes.dart';
import '../../features/documents/documents_routes.dart';
import '../../features/editor/editor_routes.dart';
import '../../features/id_card/id_card_routes.dart';
import '../../features/image_to_pdf/image_to_pdf_routes.dart';
import '../../features/office_pptx/office_pptx_routes.dart';
import '../../features/office_viewer/office_viewer_routes.dart';
import '../../features/pdf_tools/pdf_tools_routes.dart';
import '../../features/ppt_convert/ppt_convert_routes.dart';
import '../../features/qr/qr_routes.dart';
import '../../features/reader/reader_routes.dart';
import '../../features/reading/reading_routes.dart';
import '../../features/scanner/scanner_routes.dart';
import '../../features/settings/settings_routes.dart';
import 'routes.dart';

/// Key navigator gốc (dùng cho dialog toàn cục, mở file từ intent…).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Mọi route của app = gộp `<f>Routes` của 10 feature.
List<RouteBase> get appRoutes => [
  ...documentsRoutes,
  ...imageToPdfRoutes,
  ...readerRoutes,
  ...pdfToolsRoutes,
  ...editorRoutes,
  ...convertRoutes,
  ...officeViewerRoutes,
  ...officePptxRoutes,
  ...scannerRoutes,
  ...settingsRoutes,
  ...pptConvertRoutes,
  ...idCardRoutes,
  ...qrRoutes,
  ...readingRoutes,
];

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: appRoutes,
  );
  ref.onDispose(router.dispose);
  return router;
});
