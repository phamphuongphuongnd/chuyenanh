// Provider của feature `reader`.
// `pdfRenderEngineProvider` trỏ tới impl thật `PdfxRenderEngine` (pdfx).
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../engines/pdf/pdf_render_engine.dart';
import '../../engines/pdf/pdf_security.dart';
import '../../engines/pdf/pdfx_render_engine.dart';

final pdfRenderEngineProvider = Provider<PdfRenderEngine>(
  (ref) => PdfxRenderEngine(security: ref.watch(pdfSecurityProvider)),
);

/// Chọn một file PDF (trả về đường dẫn, null nếu huỷ). Test thay bằng bản giả.
typedef PdfFilePicker = Future<String?> Function();

final pdfFilePickerProvider = Provider<PdfFilePicker>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return file?.path;
  },
);

/// Chia sẻ danh sách file (share sheet hệ thống). Test thay bằng bản giả.
typedef FileSharer = Future<void> Function(List<String> paths);

final fileSharerProvider = Provider<FileSharer>(
  (ref) => (paths) async {
    await SharePlus.instance.share(
      ShareParams(files: [for (final path in paths) XFile(path)]),
    );
  },
);
