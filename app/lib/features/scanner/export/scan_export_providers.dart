import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/output_directory.dart';
import '../../image_to_pdf/image_to_pdf_providers.dart';
import '../scanner_providers.dart';
import 'scan_exporter.dart';

/// Bộ xuất dùng engine Ảnh→PDF (T2) và OCR (ML Kit) qua provider; thư mục lưu theo cài đặt.
final scanExporterProvider = FutureProvider.autoDispose<ScanExporter>((
  ref,
) async {
  final outDir = await ref.watch(outputDirectoryProvider.future);
  final tmp = await getTemporaryDirectory();
  return ScanExporter(
    pdfEngine: ref.watch(imageToPdfEngineProvider),
    ocrEngine: ref.watch(ocrEngineProvider),
    outputDir: outDir,
    tempDir: p.join(tmp.path, 'scan_export'),
  );
});
