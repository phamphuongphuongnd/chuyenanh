// Nén PDF: 3 mức.
//  - Nhẹ: mở bằng Syncfusion, ghi lại toàn bộ (không incremental) với nén cao nhất —
//    giữ nguyên chữ chọn được. Chạy trọn trong isolate.
//  - Vừa / Mạnh: render từng trang thành JPEG bằng [PdfRenderEngine] (CHỈ luồng chính —
//    plugin pdfx), rồi dựng PDF mới mỗi trang một ảnh đúng khổ trang gốc (trong isolate).
//    Chữ gốc được trích trước và vẽ lại thành lớp chữ vô hình (compress_text_layer.dart) nên
//    vẫn chọn / tìm / sao chép được. Liên kết (URI, nội bộ), highlight/underline/strikeout và ghi
//    chú được dựng lại (compress_annotations.dart); ô biểu mẫu, hình vẽ… bị mất và được đếm để báo.
//    Trang không có chữ (ảnh quét) giữ ảnh, không OCR.
//  - Không bao giờ ra file to hơn gốc: kết quả phải nhỏ hơn gốc ≥ 5% ([kMinSavingRatio]). Bản ảnh
//    không đạt (PDF chữ thuần/vector hay bị) → bỏ, thử mức Nhẹ; Nhẹ cũng không đạt → KHÔNG ghi file
//    mới, trả [CompressResult.alreadyOptimal]. Quyết định ở cấp file (không trộn trang vector + ảnh).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../convert/engine/font_set.dart';
import '../../reader/reader_providers.dart' show pdfRenderEngineProvider;
import 'compress_annotations.dart';
import 'compress_text_layer.dart';
import 'isolate_job.dart';
import 'pdf_ops.dart' show openPdfFile;
import 'syncfusion_pdf_tools.dart' show isSameFilePath;

/// Kết quả phải nhỏ hơn gốc ít nhất 5% (≤ 95% dung lượng gốc), nếu không coi là không nén được.
const double kMinSavingRatio = 0.95;

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

/// `true` nếu mức này biến trang thành ảnh (chữ vẫn chọn được nhờ lớp chữ vô hình; liên kết,
/// highlight, ghi chú dựng lại được, ô biểu mẫu / hình vẽ thì mất).
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
    this.alreadyOptimal = false,
    this.fellBackToLight = false,
    this.lostAnnotations = 0,
  });

  /// Đường dẫn file kết quả. Khi [alreadyOptimal]: file KHÔNG được ghi (đường dẫn chỉ là dự kiến).
  final String outputPath;
  final int originalBytes;
  final int outputBytes;

  /// Không nén thêm được (không mức nào nhỏ hơn gốc ≥ 5%): không có file mới, [outputBytes] = gốc.
  final bool alreadyOptimal;

  /// Bản ảnh (Vừa/Mạnh) không nhỏ hơn nên đã dùng mức Nhẹ (giữ vector).
  final bool fellBackToLight;

  /// Số chú thích ở trang dựng ảnh không dựng lại được (ô biểu mẫu, hình vẽ…).
  final int lostAnnotations;

  /// File mới nhỏ hơn file gốc.
  bool get isSmaller => !alreadyOptimal && outputBytes < originalBytes;

  int get percent =>
      alreadyOptimal ? 0 : reductionPercent(originalBytes, outputBytes);
}

/// Engine nén PDF. Test thay bằng bản giả qua [compressEngineProvider].
abstract interface class CompressEngine {
  /// Nén [inputPath] thành file mới [outputPath] (không đụng file gốc).
  /// [password]: mật khẩu file gốc nếu có — file kết quả KHÔNG có mật khẩu.
  /// Lỗi: `PasswordRequired`, `WrongPassword`, `CorruptFile`, `Cancelled`…;
  /// [outputPath] trùng file gốc → `ArgumentError`. Không bao giờ để lại file to hơn gốc: không nén
  /// được ≥ 5% thì không ghi file, trả [CompressResult.alreadyOptimal].
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
  PdfCompressEngine({
    required this._render,
    this._tempRoot,
    this._fontSource = const AssetFontSource(),
    this.requireSaving = true,
  });

  /// `false` = bỏ kiểm tra "phải nhỏ hơn ≥ 5%" (chỉ test engine với PDF mẫu tí hon).
  final bool requireSaving;

  final PdfRenderEngine _render;

  /// Nguồn font Noto cho lớp chữ vô hình (test thay bằng font tệp).
  final FontSource _fontSource;

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
    if (isSameFilePath(outputPath, inputPath)) {
      throw ArgumentError('output must differ from input: $outputPath');
    }
    cancelToken?.throwIfCancelled();
    final originalBytes = await _length(inputPath);
    final pw = (password == null || password.isEmpty) ? null : password;
    final raster = rasterSettingsFor(level);
    var fellBack = false;
    if (raster != null) {
      final lost = await _rasterize(
        inputPath,
        outputPath,
        raster,
        password: pw,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      final bytes = await _length(outputPath);
      if (_savedEnough(originalBytes, bytes)) {
        return CompressResult(
          outputPath: outputPath,
          originalBytes: originalBytes,
          outputBytes: bytes,
          lostAnnotations: lost,
        );
      }
      // Bản ảnh không nhỏ hơn đủ (PDF chữ thuần/vector): bỏ, thử mức Nhẹ giữ vector.
      await _deleteQuietly(outputPath);
      fellBack = true;
    }
    await runIsolateJob(
      compressLightJob,
      {'input': inputPath, 'password': pw, 'output': outputPath},
      onProgress: fellBack ? null : onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    final bytes = await _length(outputPath);
    if (!_savedEnough(originalBytes, bytes)) {
      await _deleteQuietly(outputPath);
      return CompressResult(
        outputPath: outputPath,
        originalBytes: originalBytes,
        outputBytes: originalBytes,
        alreadyOptimal: true,
      );
    }
    return CompressResult(
      outputPath: outputPath,
      originalBytes: originalBytes,
      outputBytes: bytes,
      fellBackToLight: fellBack,
    );
  }

  bool _savedEnough(int original, int output) =>
      !requireSaving || output <= original * kMinSavingRatio;

  static Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Trả số chú thích không dựng lại được.
  Future<int> _rasterize(
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
      final text = await _extractText(
        inputPath,
        password,
        count,
        cancelToken,
      );
      final annots = await _extractAnnotations(
        inputPath,
        password,
        count,
        cancelToken,
      );
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
      final built = await runIsolateJob(
        compressRasterBuildJob,
        {
          'images': images,
          'widths': widths,
          'heights': heights,
          'output': outputPath,
          if (text != null) 'textLines': text.lines,
          if (text != null) 'fonts': text.fonts,
          if (annots != null)
            'annotations': [for (final a in annots) a.toMap()],
        },
        onProgress: onProgress == null
            ? null
            : (v) => onProgress(_renderShare + v * (1 - _renderShare)),
        cancelToken: cancelToken,
        plannedOutputs: [outputPath],
      );
      return (built is int) ? built : 0;
    } finally {
      try {
        await doc?.close();
      } catch (_) {}
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Chữ gốc từng trang + font để vẽ lại. `null` = không có lớp chữ (không có chữ, thiếu font,
  /// hoặc trích lỗi — nén vẫn chạy như bản ảnh thuần; chỉ huỷ mới ném).
  Future<({List<List<TextLineData>> lines, Map<FontSlot, Uint8List> fonts})?>
  _extractText(
    String inputPath,
    String? password,
    int pageCount,
    CancelToken? cancelToken,
  ) async {
    try {
      final r = await runIsolateJob(
        compressExtractTextJob,
        {'input': inputPath, 'password': password},
        cancelToken: cancelToken,
      );
      final pages = [
        for (final page in (r as List))
          [for (final l in (page as List)) (l as List).cast<Object>()],
      ];
      if (pages.length != pageCount || !hasAnyTextLine(pages)) return null;
      final fonts = await loadFontBytes(
        _fontSource,
        scriptsInPages(pages),
        needBold: false,
      );
      if (!fontsCover(scriptsInPages(pages), fonts)) return null;
      return (lines: pages, fonts: fonts);
    } on Cancelled {
      rethrow;
    } catch (e) {
      debugPrint('compress: không trích được chữ ($e), nén thành ảnh thuần');
      return null;
    }
  }

  /// Chú thích từng trang của PDF gốc. `null` = không đọc được (nén vẫn chạy, không giữ chú thích).
  Future<List<PageAnnotations>?> _extractAnnotations(
    String inputPath,
    String? password,
    int pageCount,
    CancelToken? cancelToken,
  ) async {
    try {
      final r = await runIsolateJob(
        compressExtractAnnotationsJob,
        {'input': inputPath, 'password': password},
        cancelToken: cancelToken,
      );
      final pages = [
        for (final m in (r as List)) PageAnnotations.fromMap(m as Map),
      ];
      return pages.length == pageCount ? pages : null;
    } on Cancelled {
      rethrow;
    } catch (e) {
      debugPrint('compress: không đọc được chú thích ($e)');
      return null;
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
/// Trả số chú thích không dựng lại được (int).
Future<Object?> compressRasterBuildJob(
  Map<String, Object?> args,
  JobPort port,
) async {
  final images = (args['images'] as List).cast<String>();
  final widths = (args['widths'] as List).cast<double>();
  final heights = (args['heights'] as List).cast<double>();
  final output = args['output'] as String;
  final annotArg = args['annotations'] as List?;
  // Lớp chữ vô hình (tuỳ chọn): chữ gốc từng trang + font; thiếu/lệch số trang → bỏ qua.
  final textArg = args['textLines'] as List?;
  final fontArg = (args['fonts'] as Map?)?.cast<FontSlot, Uint8List>();
  final textPages = (textArg != null &&
          fontArg != null &&
          textArg.length == (args['images'] as List).length)
      ? [
          for (final page in textArg)
            [for (final l in (page as List)) (l as List).cast<Object>()],
        ]
      : null;
  final fonts = textPages == null ? null : PdfFontSet(fontArg!);
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
      if (textPages != null) {
        drawInvisibleLines(page.graphics, fonts!, textPages[i]);
      }
      port.progress((i + 1) / images.length * 0.85);
    }
    // Liên kết / chú thích: dựng sau khi đủ trang (liên kết nội bộ cần trang đích).
    var lost = 0;
    if (annotArg != null && annotArg.length == images.length) {
      lost = restoreAnnotations(doc, [
        for (final m in annotArg) PageAnnotations.fromMap(m as Map),
      ]);
    }
    final bytes = await doc.save();
    port.progress(0.95);
    await writeAtomically(output, bytes);
    port.fileWritten(output);
    return lost;
  } finally {
    doc.dispose();
  }
}
