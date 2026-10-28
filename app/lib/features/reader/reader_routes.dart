import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/open_file_args.dart';
import '../../core/router/routes.dart';
import 'screens/pdf_reader_screen.dart';
import 'screens/pdf_to_image_screen.dart';

/// Route của feature `reader` (gộp trong `core/router/app_router.dart`).
final List<RouteBase> readerRoutes = [
  GoRoute(
    path: Routes.pdfReader,
    builder: (context, state) {
      final args = state.extra;
      // Mỗi file một State riêng: mở file khác không dùng lại viewer cũ.
      return PdfReaderScreen(
        key: ValueKey(args),
        args: args is OpenFileArgs
            ? args
            : OpenFileArgs(args is String ? args : ''),
      );
    },
  ),
  GoRoute(
    path: Routes.pdfToImage,
    builder: (context, state) => PdfToImageScreen(path: state.extra as String?),
  ),
];
