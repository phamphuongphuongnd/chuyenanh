import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:image_ops/image_ops.dart' as ops;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/errors/app_error.dart';
import '../../core/utils/file_paths.dart';
import 'image_to_pdf_engine.dart';

/// Cạnh dài tối đa của ảnh nhúng vào PDF (px).
const int maxEmbeddedLongSide = 3000;

/// Một ảnh đầu vào kèm chỉnh sửa (xoay / lọc / cắt) sẽ áp dụng trước khi nhúng.
class ImageToPdfInput {
  const ImageToPdfInput(this.path, [this.edit = const ops.ImageEdit()]);

  final String path;
  final ops.ImageEdit edit;
}

/// Vị trí ảnh trên trang theo tuỳ chọn. Hàm thuần — có unit test.
///
/// Khổ cố định (A4/Letter): ảnh luôn được co/giãn cho vừa vùng trừ lề (giữ tỉ lệ, căn giữa).
/// `fit`: trang ôm sát ảnh ở 150 dpi + lề.
ops.PagePlacement planImagePage({
  required int imageWidth,
  required int imageHeight,
  required ImageToPdfOptions options,
}) {
  final fit = options.pageSize == PageSizeOption.fit;
  return ops.placeImageOnPage(
    imagePxWidth: imageWidth,
    imagePxHeight: imageHeight,
    size: switch (options.pageSize) {
      PageSizeOption.a4 => ops.PageSizePreset.a4,
      PageSizeOption.letter => ops.PageSizePreset.letter,
      PageSizeOption.fit => ops.PageSizePreset.fitImage,
    },
    orientation: switch (options.orientation) {
      PageOrientation.auto => ops.PageOrientation.auto,
      PageOrientation.portrait => ops.PageOrientation.portrait,
      PageOrientation.landscape => ops.PageOrientation.landscape,
    },
    margin: switch (options.margin) {
      PageMargin.none => ops.MarginPreset.none,
      PageMargin.small => ops.MarginPreset.small,
      PageMargin.large => ops.MarginPreset.large,
    },
    // dpi thấp → kích thước tự nhiên rất lớn → ảnh luôn lấp đầy vùng trang.
    dpiForFit: fit ? 150 : 1,
  );
}

/// Ảnh đã xử lý trong isolate, sẵn sàng nhúng.
class _Prepared {
  const _Prepared(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

class _PrepareArgs {
  const _PrepareArgs(this.path, this.edit, this.quality);
  final String path;
  final ops.ImageEdit edit;
  final int quality;
}

/// Chạy trong isolate: đọc, áp chỉnh sửa, thu nhỏ, nén lại. Ném lỗi nếu ảnh hỏng.
_Prepared _prepare(_PrepareArgs a) {
  final bytes = File(a.path).readAsBytesSync();
  final edit = a.edit.copyWith(
    maxLongSide: a.edit.maxLongSide != null &&
            a.edit.maxLongSide! < maxEmbeddedLongSide
        ? a.edit.maxLongSide
        : maxEmbeddedLongSide,
  );
  final out = ops.applyEdit(bytes, edit, jpegQuality: a.quality);
  final info = ops.probe(out);
  return _Prepared(out, info.width, info.height);
}

/// Impl Syncfusion của [ImageToPdfEngine]: mỗi ảnh một trang.
///
/// Phần nặng (giải mã, chỉnh sửa, nén) chạy trong `Isolate.run` từng ảnh; ghép trang ở isolate chính.
class SyncfusionImageToPdfEngine implements ImageToPdfEngine {
  const SyncfusionImageToPdfEngine();

  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) => createPdfFromInputs(
    inputs: [for (final p in imagePaths) ImageToPdfInput(p)],
    outputPath: outputPath,
    options: options,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  /// Như [createPdf] nhưng mỗi ảnh kèm [ops.ImageEdit] (xoay, bộ lọc, cắt…).
  Future<ImageToPdfResult> createPdfFromInputs({
    required List<ImageToPdfInput> inputs,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (inputs.isEmpty) throw const CorruptFile('no images');
    cancelToken?.throwIfCancelled();

    final doc = sf.PdfDocument();
    try {
      doc.pageSettings.margins.all = 0;
      final skipped = <String>[];
      var pages = 0;
      for (var i = 0; i < inputs.length; i++) {
        cancelToken?.throwIfCancelled();
        final input = inputs[i];
        _Prepared prepared;
        try {
          final args = _PrepareArgs(input.path, input.edit, options.jpegQuality);
          prepared = await Isolate.run(() => _prepare(args));
        } catch (_) {
          skipped.add(input.path);
          onProgress?.call((i + 1) / inputs.length);
          continue;
        }
        cancelToken?.throwIfCancelled();
        final pl = planImagePage(
          imageWidth: prepared.width,
          imageHeight: prepared.height,
          options: options,
        );
        doc.pageSettings.size = Size(pl.pageWidth, pl.pageHeight);
        final page = doc.pages.add();
        page.graphics.drawImage(
          sf.PdfBitmap(prepared.bytes),
          Rect.fromLTWH(
            pl.imageLeft,
            pl.imageTop,
            pl.imageWidth,
            pl.imageHeight,
          ),
        );
        pages++;
        onProgress?.call((i + 1) / inputs.length);
      }
      if (pages == 0) throw const CorruptFile('all images failed');
      cancelToken?.throwIfCancelled();
      final bytes = await doc.save();
      cancelToken?.throwIfCancelled();
      await writeAtomically(outputPath, bytes);
      return ImageToPdfResult(
        outputPath: outputPath,
        pageCount: pages,
        skippedImages: skipped,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    } finally {
      doc.dispose();
    }
  }
}
