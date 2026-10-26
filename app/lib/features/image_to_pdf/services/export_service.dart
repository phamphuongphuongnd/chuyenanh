import 'dart:io';

import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/image_to_pdf_engine.dart';
import '../models/image_item.dart';
import '../models/pdf_estimate.dart';
import 'image_processor.dart';

/// Kết quả xuất PDF cho màn kết quả.
class ExportOutcome {
  const ExportOutcome({
    required this.outputPath,
    required this.pageCount,
    required this.sizeBytes,
    required this.skippedCount,
  });

  final String outputPath;
  final int pageCount;
  final int sizeBytes;

  /// Số ảnh hỏng bị bỏ qua.
  final int skippedCount;
}

/// Tên người dùng nhập → tên file không đuôi: bỏ khoảng trắng thừa và đuôi `.pdf`;
/// rỗng thì dùng [fallback].
String normalizePdfName(String input, {required String fallback}) {
  var name = input.trim();
  if (name.toLowerCase().endsWith('.pdf')) {
    name = name.substring(0, name.length - 4).trim();
  }
  return name.isEmpty ? fallback : name;
}

/// Ghép các bước xuất: áp chỉnh sửa (xoay / bộ lọc) vào file tạm, gọi engine, dọn file tạm.
///
/// Dùng đúng interface [ImageToPdfEngine] nên thay engine (hoặc dùng bản giả khi test) tuỳ ý.
class ImageToPdfExporter {
  ImageToPdfExporter({
    required this.engine,
    required this.processor,
    required this.workDir,
  });

  final ImageToPdfEngine engine;
  final ImageProcessor processor;

  /// Nơi ghi ảnh đã áp chỉnh sửa (được xoá sạch sau khi xuất).
  final Directory workDir;

  Future<ExportOutcome> export({
    required List<ImageItem> items,
    required ImageToPdfOptions options,
    required String outputDir,
    required String fileName,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (items.isEmpty) throw const CorruptFile('no images');
    cancelToken?.throwIfCancelled();

    final bakeDir = Directory(
      '${workDir.path}${Platform.pathSeparator}bake_${DateTime.now().microsecondsSinceEpoch}',
    );
    final bakeCount = items
        .where((e) => e.edit != const ops.ImageEdit())
        .length;
    var bakeDone = 0;
    var bakeSkipped = 0;
    final paths = <String>[];
    try {
      for (final item in items) {
        cancelToken?.throwIfCancelled();
        if (item.edit == const ops.ImageEdit()) {
          paths.add(item.path);
          continue;
        }
        try {
          paths.add(
            await processor.bake(
              item.path,
              item.edit,
              outDir: bakeDir,
              name: 'p${item.id}',
            ),
          );
        } catch (_) {
          bakeSkipped++;
        }
        bakeDone++;
        onProgress?.call(
          combineProgress(
            bakeCount: bakeCount,
            bakeDone: bakeDone,
            pageCount: items.length,
            engineProgress: 0,
          ),
        );
      }
      if (paths.isEmpty) throw const CorruptFile('all images failed');
      cancelToken?.throwIfCancelled();

      final out = await uniqueOutputPath(outputDir, fileName, 'pdf');
      final result = await engine.createPdf(
        imagePaths: paths,
        outputPath: out,
        options: options,
        cancelToken: cancelToken,
        onProgress: (p) => onProgress?.call(
          combineProgress(
            bakeCount: bakeCount,
            bakeDone: bakeDone,
            pageCount: items.length,
            engineProgress: p,
          ),
        ),
      );
      final size = await File(result.outputPath).length();
      return ExportOutcome(
        outputPath: result.outputPath,
        pageCount: result.pageCount,
        sizeBytes: size,
        skippedCount: bakeSkipped + result.skippedImages.length,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    } finally {
      try {
        if (await bakeDir.exists()) await bakeDir.delete(recursive: true);
      } catch (_) {
        // File tạm — bỏ qua.
      }
    }
  }
}
