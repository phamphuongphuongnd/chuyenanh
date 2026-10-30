import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_layout/pdf_layout.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../reader/reader_providers.dart' show pdfRenderEngineProvider;

/// Độ phân giải render trang (dpi): mặc định 150, tuỳ chọn 200 (nét hơn, file nặng hơn).
const List<int> kPdfToPptDpiOptions = [150, 200];
const int kPdfToPptDefaultDpi = 150;

/// Chất lượng JPEG của ảnh slide.
const int kPdfToPptJpegQuality = 85;

/// Hàm ghi gói .pptx từ các slide ảnh. Mặc định chạy [writeImagePptx] trong `Isolate.run`;
/// test truyền bản chạy đồng bộ.
typedef PptxEncoder =
    Future<Uint8List> Function(
      List<PptxImageSlide> slides,
      double slideWidthPt,
      double slideHeightPt,
      String title,
    );

/// Ghi PPTX ở isolate riêng (nén zip + dựng XML không chặn luồng giao diện).
/// Closure chỉ mang theo tham số (không dính `ref`/`State`).
Future<Uint8List> encodePptxInIsolate(
  List<PptxImageSlide> slides,
  double slideWidthPt,
  double slideHeightPt,
  String title,
) => Isolate.run(
  () => writeImagePptx(
    slides,
    slideWidthPt: slideWidthPt,
    slideHeightPt: slideHeightPt,
    title: title,
    author: 'Phiotron PDF',
  ),
);

/// PDF → PowerPoint: mỗi trang PDF render thành ảnh JPEG, đặt thành một slide ảnh.
///
/// Cỡ slide = cỡ trang 1; trang khác cỡ thì ảnh thu/phóng giữ tỉ lệ, nằm giữa slide nền trắng
/// (do [writeImagePptx] lo). Render chạy ở luồng chính (pdfx dùng platform channel), ghi
/// PPTX chạy trong `Isolate.run`.
class PdfToPptConverter {
  const PdfToPptConverter({
    required this.render,
    this.encode = encodePptxInIsolate,
  });

  final PdfRenderEngine render;
  final PptxEncoder encode;

  /// Chuyển [inputPath] (mật khẩu [password] nếu có) thành [outputPath] (.pptx).
  /// Trả về [outputPath]. Huỷ qua [cancelToken] → ném [Cancelled], không để lại file.
  /// Tiến độ: render 0 → 0.9, ghi file 0.9 → 1.
  Future<String> convert({
    required String inputPath,
    required String outputPath,
    String? password,
    int dpi = kPdfToPptDefaultDpi,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    final doc = await render.openFile(inputPath, password: password);
    final List<PptxImageSlide> slides;
    final PdfPageSize first;
    try {
      final count = doc.pageCount;
      if (count <= 0) throw const CorruptFile('no pages');
      first = await doc.pageSize(0);
      slides = <PptxImageSlide>[];
      onProgress?.call(0);
      for (var i = 0; i < count; i++) {
        token.throwIfCancelled();
        final size = i == 0 ? first : await doc.pageSize(i);
        final jpg = await doc.renderPage(
          i,
          dpi: dpi.toDouble(),
          format: RenderFormat.jpg,
          jpgQuality: kPdfToPptJpegQuality,
          cancelToken: token,
        );
        slides.add(
          PptxImageSlide(bytes: jpg, widthPt: size.width, heightPt: size.height),
        );
        onProgress?.call(0.9 * (i + 1) / count);
      }
    } finally {
      await doc.close();
    }
    token.throwIfCancelled();
    final bytes = await encode(
      slides,
      first.width,
      first.height,
      baseNameWithoutExtension(inputPath),
    );
    // Isolate.run không huỷ giữa chừng được: kiểm lại trước khi ghi ra đĩa.
    token.throwIfCancelled();
    onProgress?.call(0.95);
    await writeAtomically(outputPath, bytes);
    onProgress?.call(1);
    return outputPath;
  }
}

final pdfToPptConverterProvider = Provider<PdfToPptConverter>(
  (ref) => PdfToPptConverter(render: ref.watch(pdfRenderEngineProvider)),
);
