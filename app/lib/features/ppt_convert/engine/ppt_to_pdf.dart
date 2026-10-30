// PowerPoint (.pptx) → PDF: mỗi slide chụp thành ảnh PNG (bằng widget `SlideView` của trình
// xem PPTX) rồi ghép thành PDF trong isolate, mỗi slide một trang đúng tỉ lệ slide.
//
// Phần chụp slide cần cây widget thật nên tách sau [SlideRasterizer] (impl ở
// `slide_rasterizer.dart`) để test thay bằng bản giả. Các hàm thuần ở đầu file có unit test.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:path/path.dart' as p;
import 'package:pptx_reader/pptx_reader.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/cancel_token.dart';
import '../../../core/utils/file_paths.dart';
import '../../office_pptx/pptx_engine_impl.dart';
import '../../office_pptx/pptx_layout.dart';

// ---------------------------------------------------------------- tuỳ chọn + hàm thuần

/// Chất lượng ảnh slide nhúng vào PDF.
enum PptPdfQuality {
  standard(150),
  high(200);

  const PptPdfQuality(this.dpi);

  /// Số điểm ảnh trên mỗi inch của trang PDF.
  final int dpi;
}

class PptToPdfOptions {
  const PptToPdfOptions({
    this.quality = PptPdfQuality.standard,
    this.includeHidden = false,
  });

  final PptPdfQuality quality;

  /// `true` = xuất cả slide ẩn (`show="0"`). Mặc định bỏ như khi trình chiếu.
  final bool includeHidden;

  PptToPdfOptions copyWith({PptPdfQuality? quality, bool? includeHidden}) =>
      PptToPdfOptions(
        quality: quality ?? this.quality,
        includeHidden: includeHidden ?? this.includeHidden,
      );
}

/// Chỉ số (0-based) các slide sẽ thành trang PDF, giữ thứ tự trình chiếu.
List<int> slidesToExport(PptxDeck deck, {bool includeHidden = false}) =>
    visibleSlideIndexes(deck, showHidden: includeHidden);

/// Số slide ẩn của bản trình chiếu.
int hiddenSlideCount(PptxDeck deck) =>
    deck.slides.where((s) => s.hidden).length;

/// Khổ trang PDF mặc định khi file ghi kích thước slide hỏng (16:9 của PowerPoint, pt).
const Size kFallbackSlidePageSize = Size(960, 540);

/// Khổ trang PDF (pt = 1/72 inch) của mỗi slide. 12700 EMU = 1 pt nên trùng đúng kích
/// thước canvas `slideCanvasSize` mà trình xem dùng. Kích thước hỏng (≤ 0) → 16:9.
Size pdfPageSizeOf(PptxDeck deck) {
  final s = slideCanvasSize(deck);
  if (!(s.width > 0) || !(s.height > 0)) return kFallbackSlidePageSize;
  return s;
}

/// Hệ số phóng khi chụp: canvas slide tính bằng pt (1 pt = 1/72 inch) → px theo [dpi].
double slidePixelRatio(int dpi) => dpi / 72;

/// Tên gốc của file PDF ra (chưa có đuôi, chưa chống trùng): `/a/Bao cao.pptx` → `Bao cao`.
String pptToPdfBaseName(String path) => p.basenameWithoutExtension(path);

/// Kiểm tra đuôi file: chỉ nhận `.pptx`. `.ppt` (định dạng nhị phân cũ) và đuôi khác →
/// [UnsupportedFormat] mang đuôi file (không dấu chấm, chữ thường).
void ensurePptxPath(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext == '.pptx') return;
  throw UnsupportedFormat(ext.startsWith('.') ? ext.substring(1) : ext);
}

// ---------------------------------------------------------------- interface

/// Chụp một slide thành ảnh PNG có kích thước `pdfPageSizeOf(deck) × dpi / 72` px.
abstract interface class SlideRasterizer {
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  });
}

/// Đổi .pptx sang PDF.
abstract interface class PptToPdfEngine {
  /// Đọc deck. Đuôi không phải `.pptx` → [UnsupportedFormat]; nội dung hỏng → [CorruptFile].
  Future<PptxDeck> openDeck(String path);

  /// Chụp các slide theo [options] bằng [rasterizer] rồi ghi PDF vào [outputPath] (ghi an
  /// toàn qua file tạm). Trả về [outputPath]. Không còn slide nào để xuất → [CorruptFile].
  /// Huỷ → [Cancelled] (không để lại file dở).
  Future<String> convert(
    PptxDeck deck,
    String outputPath, {
    required SlideRasterizer rasterizer,
    PptToPdfOptions options = const PptToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}

// ---------------------------------------------------------------- impl

/// Phần tiến độ dành cho bước chụp slide (phần còn lại là ghép PDF trong isolate).
const double _renderShare = 0.8;

class DefaultPptToPdfEngine implements PptToPdfEngine {
  const DefaultPptToPdfEngine({this.loader = loadPptxDeckFromFile});

  /// Hàm parse file → deck (mặc định pptx_reader trong isolate).
  final Future<PptxDeck> Function(String path) loader;

  @override
  Future<PptxDeck> openDeck(String path) async {
    ensurePptxPath(path);
    return loader(path);
  }

  @override
  Future<String> convert(
    PptxDeck deck,
    String outputPath, {
    required SlideRasterizer rasterizer,
    PptToPdfOptions options = const PptToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final indexes = slidesToExport(deck, includeHidden: options.includeHidden);
    if (indexes.isEmpty) throw const CorruptFile('no slides to export');
    cancelToken?.throwIfCancelled();

    final page = pdfPageSizeOf(deck);
    final dpi = options.quality.dpi;
    // Ảnh PNG từng slide ghi ra thư mục tạm để không giữ cả bộ trong RAM.
    Directory? tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('pptpdf_');
      final pngPaths = <String>[];
      for (var k = 0; k < indexes.length; k++) {
        cancelToken?.throwIfCancelled();
        final png = await rasterizer.renderSlide(
          deck,
          deck.slides[indexes[k]],
          dpi: dpi,
        );
        cancelToken?.throwIfCancelled();
        final file = File(p.join(tmp.path, 'slide_$k.png'));
        await file.writeAsBytes(png, flush: false);
        pngPaths.add(file.path);
        onProgress?.call((k + 1) / indexes.length * _renderShare);
      }
      await _buildPdfInIsolate(
        _PdfArgs(pngPaths, page.width, page.height, outputPath),
        onPage: (done) => onProgress?.call(
          _renderShare + (1 - _renderShare) * done / pngPaths.length,
        ),
        cancelToken: cancelToken,
      );
      return outputPath;
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    } finally {
      if (tmp != null) {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}

// ---------------------------------------------------------------- dựng PDF (isolate)

class _PdfArgs {
  const _PdfArgs(this.pngPaths, this.pageWidth, this.pageHeight, this.outPath);
  final List<String> pngPaths;
  final double pageWidth;
  final double pageHeight;
  final String outPath;
}

/// Tin nhắn từ isolate dựng PDF: `int` = số trang đã thêm, `'done'` = đã ghi file,
/// `List` = lỗi `[message, stack]` (từ `onError`), `null` = isolate đã thoát.
Future<void> _buildPdfInIsolate(
  _PdfArgs args, {
  required void Function(int done) onPage,
  CancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  final port = ReceivePort();
  final completer = Completer<void>();
  Isolate? isolate;
  var cancelled = false;

  void finish([Object? error]) {
    if (completer.isCompleted) return;
    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete();
    }
  }

  port.listen((msg) {
    if (msg is int) {
      onPage(msg);
    } else if (msg == 'done') {
      finish();
    } else if (msg is List) {
      finish(CorruptFile('pdf build failed: ${msg.isEmpty ? '' : msg.first}'));
    } else if (msg == null) {
      // Thoát mà chưa báo xong (bị kill / lỗi không bắt được).
      finish(
        cancelled ? const Cancelled() : const CorruptFile('pdf isolate exit'),
      );
    }
  });
  cancelToken?.onCancel(() {
    cancelled = true;
    isolate?.kill(priority: Isolate.immediate);
    finish(const Cancelled());
  });

  try {
    isolate = await Isolate.spawn<(SendPort, _PdfArgs)>(
      _pdfIsolateMain,
      (port.sendPort, args),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    if (cancelled) isolate.kill(priority: Isolate.immediate);
    await completer.future;
  } catch (_) {
    // Bị huỷ / lỗi giữa chừng: dọn file dở (file tạm của writeAtomically, file đích).
    await _deleteQuietly('${args.outPath}.tmp');
    if (cancelled) await _deleteQuietly(args.outPath);
    rethrow;
  } finally {
    port.close();
  }
}

Future<void> _deleteQuietly(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> _pdfIsolateMain((SendPort, _PdfArgs) message) async {
  final (send, a) = message;
  final doc = sf.PdfDocument();
  try {
    // Một section cho mọi trang: các slide cùng khổ.
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.orientation = a.pageWidth > a.pageHeight
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    section.pageSettings.size = Size(a.pageWidth, a.pageHeight);
    final rect = Rect.fromLTWH(0, 0, a.pageWidth, a.pageHeight);
    for (var i = 0; i < a.pngPaths.length; i++) {
      final bytes = File(a.pngPaths[i]).readAsBytesSync();
      final page = section.pages.add();
      page.graphics.drawImage(sf.PdfBitmap(bytes), rect);
      send.send(i + 1);
    }
    final out = await doc.save();
    await writeAtomically(a.outPath, out);
    send.send('done');
  } finally {
    doc.dispose();
  }
}
