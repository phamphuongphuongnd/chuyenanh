import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'ui/pdf_to_ppt_screen.dart';
import 'ui/ppt_to_pdf_screen.dart';

String? _pathOf(GoRouterState state) {
  final extra = state.extra;
  return extra is String ? extra : null;
}

/// Route của feature `ppt_convert` (PowerPoint ↔ PDF).
final List<RouteBase> pptConvertRoutes = [
  GoRoute(
    path: Routes.pptToPdf,
    builder: (_, state) => PptToPdfScreen(path: _pathOf(state)),
  ),
  GoRoute(
    path: Routes.pdfToPpt,
    builder: (_, state) => PdfToPptScreen(path: _pathOf(state)),
  ),
];
