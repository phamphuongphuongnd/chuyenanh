import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/output_directory.dart';
import '../../image_to_pdf/image_to_pdf_providers.dart';
import '../scanner_providers.dart';
import 'scan_exporter.dart';

/// Thư mục tạm riêng của bộ xuất máy quét.
final scanTempDirProvider = FutureProvider<String>((ref) async {
  final tmp = await getTemporaryDirectory();
  return p.join(tmp.path, 'scan_export');
});

/// Bộ xuất dùng engine Ảnh→PDF (T2) và OCR (ML Kit) qua provider; thư mục lưu theo cài đặt.
///
/// KHÔNG dùng `autoDispose`: màn quét chỉ `ref.read(...future)` (không `watch`), provider tự huỷ giữa
/// lúc đang `await` rồi dùng `ref` → "Cannot use the Ref ... after it has been disposed" và mọi định
/// dạng xuất (PDF/TXT/DOCX) đều hỏng ngay. Cũng đọc engine trước mọi `await`.
final scanExporterProvider = FutureProvider<ScanExporter>((ref) async {
  final pdfEngine = ref.watch(imageToPdfEngineProvider);
  final ocrEngine = ref.watch(ocrEngineProvider);
  final outDir = await ref.watch(outputDirectoryProvider.future);
  final tmp = await ref.watch(scanTempDirProvider.future);
  return ScanExporter(
    pdfEngine: pdfEngine,
    ocrEngine: ocrEngine,
    outputDir: outDir,
    tempDir: tmp,
  );
});
