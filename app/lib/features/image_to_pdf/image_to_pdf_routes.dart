import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'image_to_pdf_paths.dart';
import 'screens/edit_screen.dart';
import 'screens/image_picker_screen.dart';
import 'screens/result_screen.dart';
import 'services/export_service.dart';

export 'image_to_pdf_paths.dart';

/// Route của feature `image_to_pdf` (gộp trong `core/router/app_router.dart`).
///
/// `Routes.imageToPdf`: `extra` bỏ trống → màn chọn ảnh; `extra: List<String>` (đường dẫn ảnh,
/// vd. từ chia sẻ / máy quét) → vào thẳng màn sửa.
final List<RouteBase> imageToPdfRoutes = [
  GoRoute(
    path: Routes.imageToPdf,
    builder: (context, state) {
      final extra = state.extra;
      if (extra is List && extra.isNotEmpty) {
        return EditScreen(paths: extra.whereType<String>().toList());
      }
      return const ImagePickerScreen();
    },
  ),
  GoRoute(
    path: img2pdfAddPath,
    // extra (tuỳ chọn): int = số ảnh còn thêm được.
    builder: (context, state) => ImagePickerScreen(
      addMode: true,
      remaining: state.extra is int ? state.extra! as int : null,
    ),
  ),
  GoRoute(
    path: img2pdfEditPath,
    redirect: (context, state) =>
        state.extra is List ? null : Routes.imageToPdf,
    builder: (context, state) => EditScreen(
      paths: (state.extra! as List).whereType<String>().toList(),
    ),
  ),
  GoRoute(
    path: img2pdfResultPath,
    redirect: (context, state) =>
        state.extra is ExportOutcome ? null : Routes.imageToPdf,
    builder: (context, state) =>
        ResultScreen(outcome: state.extra! as ExportOutcome),
  ),
];
