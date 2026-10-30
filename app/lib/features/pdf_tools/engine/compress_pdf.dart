// Nén PDF: 3 mức.
//  - Nhẹ: mở bằng Syncfusion, ghi lại toàn bộ (không incremental) với nén cao nhất —
//    giữ nguyên chữ chọn được. Chạy trọn trong isolate.
//  - Vừa / Mạnh: render từng trang thành JPEG bằng [PdfRenderEngine] (CHỈ luồng chính —
//    plugin pdfx), rồi dựng PDF mới mỗi trang một ảnh đúng khổ trang gốc (trong isolate).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../reader/reader_providers.dart' show pdfRenderEngineProvider;
import 'isolate_job.dart';
import 'pdf_ops.dart' show openPdfFile;

/// Mức nén.
enum CompressLevel { light, medium, strong }

/// Thông số render lại trang (mức Vừa / Mạnh).
class RasterSettings {
  const RasterSettings(this.dpi, this.jpegQuality);

  final double dpi;

  /// Chất lượng JPEG 1–100.
  final int jpegQuality;

  @override
  bool operator ==(Object other) =>
      other is RasterSettings &&
      other.dpi == dpi &&
      other.jpegQuality == jpegQuality;

  @override
  int get hashCode => Object.hash(dpi, jpegQuality);

  @override
  String toString() => 'RasterSettings($dpi dpi, q$jpegQuality)';
}

/// Thông số render theo mức. `null` = mức Nhẹ (không render lại, giữ chữ).
RasterSettings? rasterSettingsFor(CompressLevel level) => switch (level) {
  CompressLevel.light => null,
  CompressLevel.medium => const RasterSettings(150, 70),
  CompressLevel.strong => const RasterSettings(100, 50),
};

/// `true` nếu mức này biến trang thành ảnh (mất chữ chọn được, liên kết, chú thích).
bool compressLevelRasterizes(CompressLevel level) =>
    rasterSettingsFor(level) != null;

/// Phần trăm dung lượng giảm được (số nguyên 0–100).
///
/// File mới không nhỏ hơn (hoặc [originalBytes] ≤ 0) → 0. Có giảm nhưng dưới 0,5% → 1
/// (để không hiện "giảm 0%" khi thực tế có nhỏ hơn).
int reductionPercent(int originalBytes, int outputBytes) {
  if (originalBytes <= 0 || outputBytes >= originalBytes) return 0;
  final saved = originalBytes - math.max(0, outputBytes);
  final pct = (saved * 100 / originalBytes).round();
  return pct.clamp(1, 100);
}

/// Tên cơ sở file kết quả: `/a/report.pdf` → `report_compressed`.
String compressedBaseName(String inputPath) =>
    '${p.basenameWithoutExtension(inputPath)}_compressed';

/// Kết quả nén.
class CompressResult {
  const CompressResult({
    required this.outputPath,
    required this.originalBytes,
    required this.outputBytes,
  });

  final String outputPath;
  final int originalBytes;
  final int outputBytes;

  /// File mới nhỏ hơn file gốc.
  bool get isSmaller => outputBytes < originalBytes;

  int get percent => reductionPercent(originalBytes, outputBytes);
}

/// Engine nén PDF. Test thay bằng bản giả qua [compressEngineProvider].
abstract interface class CompressEngine {
  /// Nén [inputPath] thành file mới [outputPath] (không đụng file gốc).
  /// [password]: mật khẩu file gốc nếu có — file kết quả KHÔNG có mật khẩu.
  /// Lỗi: `PasswordRequired`, `WrongPassword`, `CorruptFile`, `Cancelled`…
  Future<CompressResult> compress(
    String inputPath,
    String outputPath,
    CompressLevel level, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}

/// Impl thật: Syncfusion (mức Nhẹ, dựng PDF ảnh) + [PdfRenderEngine] (render trang).
class PdfCompressEngine implements CompressEngine {
  PdfCompressEngine({required this._render, this._tempRoot});

  final PdfRenderEngine _render;

  /// Thư mục cha chứa ảnh trang tạm (mặc định thư mục tạm hệ thống).
  final String? _tempRoot;

  /// Tỉ trọng tiến độ của bước render (phần còn lại là dựng PDF).
  static const double _renderShare = 0.8;

  @override
  Future<CompressResult> compress(
    String inputPath,
    String outputPath,
    CompressLevel level, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final originalBytes = await _length(inputPath);
    final pw = (password == null || password.isEmpty) ? null : password;
    final raster = rasterSettingsFor(level);
    if (raster == null) {
      await runIsolateJob(
        compressLightJob,
        {'input': inputPath, 'password': pw, 'output': outputPath},
        onProgress: onProgress,
        cancelToken: cancelToken,
        plannedOutputs: [outputPath],
      );
    } else {
      await _rasterize(
        inputPath,
        outputPath,
        raster,
        password: pw,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    return CompressResult(
      outputPath: outputPath,
      originalBytes: originalBytes,
      outputBytes: await _length(outputPath),
    );
  }

  Future<void> _rasterize(
    String inputPath,
    String outputPath,
    RasterSettings raster, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final root = Directory(_tempRoot ?? Directory.systemTemp.path);
    await root.create(recursive: true);
    final tmp = await root.createTemp('compress_');
    PdfRenderDocument? doc;
    try {
      // Render (pdfx) chỉ chạy được ở luồng chính; file có mật khẩu được impl tự giải mã.
      doc = await _render.openFile(inputPath, password: password);
      final count = doc.pageCount;
      if (count < 1) throw const CorruptFile('no pages');
      final images = <String>[];
      final widths = <double>[];
      final heights = <double>[];
      for (var i = 0; i < count; i++) {
        cancelToken?.throwIfCancelled();
        final size = await doc.pageSize(i);
        final jpg = await doc.renderPage(
          i,
          dpi: raster.dpi,
          format: RenderFormat.jpg,
          jpgQuality: raster.jpegQuality,
          cancelToken: cancelToken,
        );
        cancelToken?.throwIfCancelled();
        // Ghi ra đĩa từng trang để không giữ cả tài liệu trong RAM, và isolate chỉ cần path.
        final path = p.join(tmp.path, 'p$i.jpg');
        await File(path).writeAsBytes(jpg, flush: false);
        images.add(path);
        widths.add(size.width);
        heights.add(size.height);
        onProgress?.call((i + 1) / count * _renderShare);
      }
      await doc.close();
      doc = null;
      await runIsolateJob(
        compressRasterBuildJob,
        {
          'images': images,
          'widths': widths,
          'heights': heights,
          'output': outputPath,
        },
        onProgress: onProgress == null
            ? null
            : (v) => onProgress(_renderShare + v * (1 - _renderShare)),
        cancelToken: cancelToken,
        plannedOutputs: [outputPath],
      );
    } finally {
      try {
        await doc?.close();
      } catch (_) {}
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<int> _length(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException catch (e) {
      final err = AppError.from(e);
      throw err is Unknown ? CorruptFile(e.message) : err;
    }
  }
}

final compressEngineProvider = Provider<CompressEngine>(
  (ref) => PdfCompressEngine(render: ref.watch(pdfRenderEngineProvider)),
);

// --------------------------------------------------------------------------
// Jobs chạy TRONG isolate (hàm top-level, tham số/kết quả sendable).

/// Mức Nhẹ: ghi lại toàn bộ tài liệu với nén tốt nhất, bỏ mật khẩu.
Future<Object?> compressLightJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final output = args['output'] as String;
  final doc = await openPdfFile(input, password: password);
  try {
    port.progress(0.2);
    // Mở có mật khẩu rồi lưu thì file kết quả không còn mật khẩu (như merge/watermark).
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    doc.compressionLevel = sf.PdfCompressionLevel.best;
    // Mặc định Syncfusion lưu kiểu incremental (chép nguyên file cũ + phần thêm) → file
    // còn to hơn. Tắt đi để ghi lại từ đầu (bỏ object thừa của các lần sửa cũ).
    doc.fileStructure.incrementalUpdate = false;
    final bytes = await doc.save();
    port.progress(0.9);
    await writeAtomically(output, bytes);
    port.fileWritten(output);
    return output;
  } finally {
    doc.dispose();
  }
}

/// Mức Vừa/Mạnh: dựng PDF mới, trang i là ảnh `images[i]` phủ kín khổ `widths[i]×heights[i]` pt.
Future<Object?> compressRasterBuildJob(
  Map<String, Object?> args,
  JobPort port,
) async {
  final images = (args['images'] as List).cast<String>();
  final widths = (args['widths'] as List).cast<double>();
  final heights = (args['heights'] as List).cast<double>();
  final output = args['output'] as String;
  if (images.isEmpty ||
      images.length != widths.length ||
      images.length != heights.length) {
    throw ArgumentError('images/widths/heights');
  }
  final doc = sf.PdfDocument();
  try {
    doc.compressionLevel = sf.PdfCompressionLevel.best;
    for (var i = 0; i < images.length; i++) {
      final w = widths[i] > 0 ? widths[i] : 595.0;
      final h = heights[i] > 0 ? heights[i] : 842.0;
      // Syncfusion chỉ cho đổi khổ trước khi thêm trang → mỗi trang một section; đặt
      // orientation trước size (thư viện chuẩn hoá size theo orientation).
      final section = doc.sections!.add();
      final settings = section.pageSettings;
      settings.margins.all = 0;
      settings.orientation = w > h
          ? sf.PdfPageOrientation.landscape
          : sf.PdfPageOrientation.portrait;
      settings.size = Size(w, h);
      final page = section.pages.add();
      final bytes = await File(images[i]).readAsBytes();
      page.graphics.drawImage(
        sf.PdfBitmap(bytes),
        Rect.fromLTWH(0, 0, w, h),
      );
      port.progress((i + 1) / images.length * 0.85);
    }
    final bytes = await doc.save();
    port.progress(0.95);
    await writeAtomically(output, bytes);
    port.fileWritten(output);
    return output;
  } finally {
    doc.dispose();
  }
}
