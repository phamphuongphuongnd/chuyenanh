import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/navigation/open_file_args.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_screen.dart';

/// Route của feature `reader` (gộp trong `core/router/app_router.dart`).
/// MÓNG tạo giữ chỗ — agent thay `PlaceholderScreen` bằng màn thật, giữ nguyên path.
final List<RouteBase> readerRoutes = [
  GoRoute(
    path: Routes.pdfReader,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.reader_title} · pdfReader',
      detail: (state.extra as OpenFileArgs?)?.path,
    ),
  ),
  GoRoute(
    path: Routes.pdfToImage,
    builder: (context, state) => PlaceholderScreen(
      title: '${context.l10n.reader_title} · pdfToImage',
      detail: state.extra as String?,
    ),
  ),
];
