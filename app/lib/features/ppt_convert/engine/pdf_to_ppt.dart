import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_layout/pdf_layout.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../convert/engine/pdf_extract.dart' show extractLayoutPages;
import '../../convert/text/vietnamese_nfc.dart';
import '../../reader/reader_providers.dart' show pdfRenderEngineProvider;
import 'text_eraser.dart';

/// Độ phân giải render trang (dpi): mặc định 150, tuỳ chọn 200 (nét hơn, file nặng hơn).
const List<int> kPdfToPptDpiOptions = [150, 200];
const int kPdfToPptDefaultDpi = 150;

/// Chất lượng JPEG của ảnh slide.
const int kPdfToPptJpegQuality = 85;

/// Chế độ chuyển: giữ nguyên hình (chữ chỉ là lớp ẩn để chọn / tìm) hoặc chữ sửa được.
enum PdfToPptMode { keepImage, editableText }

/// Font của hộp chữ sửa được.
const String kPdfToPptEditableFont = 'Noto Sans';

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

/// Trích chữ của PDF thành các trang bố cục (toạ độ pt, gốc trên-trái). Mặc định chạy trong
/// `Isolate.run`. Test truyền bản giả.
typedef PdfTextExtractor =
    Future<List<LayoutPage>> Function(String inputPath, String? password);

Future<List<LayoutPage>> extractPdfTextInIsolate(
  String inputPath,
  String? password,
) async {
  final bytes = await File(inputPath).readAsBytes();
  return Isolate.run(() => extractLayoutPages(bytes, password: password));
}

/// Hộp chữ trong suốt cho slide ảnh từ chữ trích được của [page]. Toạ độ quy về khung
/// [widthPt] × [heightPt] của slide theo tỉ lệ cỡ trang lúc trích. Cỡ trang trích được lệch
/// tỉ lệ với cỡ render (trang xoay…) → trả rỗng thay vì đặt chữ sai chỗ.
List<PptxTextBox> pptxTextBoxesFromPage(
  LayoutPage page,
  double widthPt,
  double heightPt,
) => [for (final (_, box) in _pairedBoxes(page, widthPt, heightPt)) box];

/// Cặp (dòng gốc, hộp chữ đã quy khung slide); rỗng khi cỡ trang lệch tỉ lệ cỡ render.
List<(LayoutLine, PptxTextBox)> _pairedBoxes(
  LayoutPage page,
  double widthPt,
  double heightPt,
) {
  if (!(page.width > 0 && page.height > 0 && widthPt > 0 && heightPt > 0)) {
    return const [];
  }
  final kx = widthPt / page.width;
  final ky = heightPt / page.height;
  if ((kx / ky - 1).abs() > 0.02) return const [];
  return [
    for (final l in page.lines)
      if (l.text.trim().isNotEmpty && l.bounds.width > 0 && l.bounds.height > 0)
        (
          l,
          PptxTextBox(
            // NFC: PowerPoint tìm chữ Việt theo dạng dựng sẵn.
            text: composeVietnamese(l.text.trim()),
            left: l.bounds.left * kx,
            top: l.bounds.top * ky,
            width: l.bounds.width * kx,
            height: l.bounds.height * ky,
            fontSizePt: (l.fontSize > 0 ? l.fontSize : l.bounds.height * 0.8) * ky,
          ),
        ),
  ];
}

/// Kết quả "chữ sửa được" cho một trang: ảnh nền đã xoá chữ + hộp chữ hiển thị. Null khi
/// trang không làm được (không chữ, lệch tỉ lệ/xoay, ảnh không giải mã được) → giữ nguyên hình.
class EditableSlide {
  const EditableSlide(this.image, this.boxes);

  final Uint8List image;
  final List<PptxTextBox> boxes;
}

/// Xoá chữ khỏi ảnh [jpeg] của [page] và dựng hộp chữ hiển thị tương ứng (đồng bộ; chạy trong
/// isolate). Màu chữ đo từ ảnh, đậm lấy từ từ của dòng, font Noto Sans.
EditableSlide? buildEditableSlide(
  Uint8List jpeg,
  LayoutPage page,
  double widthPt,
  double heightPt,
) {
  final pairs = _pairedBoxes(page, widthPt, heightPt);
  if (pairs.isEmpty) return null;
  final erased = eraseTextFromJpeg(
    jpeg,
    [
      for (final (_, b) in pairs)
        PixelBox(b.left, b.top, b.width, b.height),
    ],
    widthUnits: widthPt,
    heightUnits: heightPt,
    quality: kPdfToPptJpegQuality,
  );
  if (erased == null) return null;
  return EditableSlide(erased.bytes, [
    for (var i = 0; i < pairs.length; i++)
      PptxTextBox(
        text: pairs[i].$2.text,
        left: pairs[i].$2.left,
        top: pairs[i].$2.top,
        width: pairs[i].$2.width,
        height: pairs[i].$2.height,
        fontSizePt: pairs[i].$2.fontSizePt,
        visible: true,
        colorRgb: erased.textColors[i],
        bold: pairs[i].$1.words.isNotEmpty && pairs[i].$1.words.every((w) => w.bold),
        fontFamily: kPdfToPptEditableFont,
      ),
  ]);
}

Future<EditableSlide?> _eraseInIsolate(
  Uint8List jpeg,
  LayoutPage page,
  double widthPt,
  double heightPt,
) => Isolate.run(() => buildEditableSlide(jpeg, page, widthPt, heightPt));

/// PDF → PowerPoint: mỗi trang PDF render thành ảnh JPEG, đặt thành một slide ảnh, kèm hộp
/// chữ trong suốt đặt đúng chỗ chữ của trang (PowerPoint tìm / chọn được chữ; chữ vẫn là ảnh
/// bên dưới nên không sửa trực tiếp được). PDF không có chữ (bản quét) → chỉ ảnh.
///
/// Cỡ slide = cỡ trang 1; trang khác cỡ thì ảnh thu/phóng giữ tỉ lệ, nằm giữa slide nền trắng
/// (do [writeImagePptx] lo). Render chạy ở luồng chính (pdfx dùng platform channel), ghi
/// PPTX chạy trong `Isolate.run`.
class PdfToPptConverter {
  const PdfToPptConverter({
    required this.render,
    this.encode = encodePptxInIsolate,
    this.extractText = extractPdfTextInIsolate,
    this.eraseInIsolate = _eraseInIsolate,
  });

  final PdfRenderEngine render;
  final PptxEncoder encode;
  final PdfTextExtractor extractText;

  /// Xoá chữ khỏi ảnh một trang (mặc định: `Isolate.run`).
  final Future<EditableSlide?> Function(
    Uint8List jpeg,
    LayoutPage page,
    double widthPt,
    double heightPt,
  )
  eraseInIsolate;

  Future<List<LayoutPage>> _safeExtract(String inputPath, String? password) async {
    try {
      return await extractText(inputPath, password);
    } catch (_) {
      return const <LayoutPage>[];
    }
  }

  /// Chuyển [inputPath] (mật khẩu [password] nếu có) thành [outputPath] (.pptx).
  /// Trả về [outputPath]. Huỷ qua [cancelToken] → ném [Cancelled], không để lại file.
  /// Tiến độ: render 0 → 0.9 (chế độ chữ sửa được: render → 0.7, xoá chữ → 0.9), ghi file 0.9 → 1.
  /// [mode] = [PdfToPptMode.editableText]: xoá chữ khỏi ảnh nền + hộp chữ hiển thị; trang không
  /// làm được thì giữ nguyên hình.
  Future<String> convert({
    required String inputPath,
    required String outputPath,
    String? password,
    int dpi = kPdfToPptDefaultDpi,
    PdfToPptMode mode = PdfToPptMode.keepImage,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    final doc = await render.openFile(inputPath, password: password);
    // Trích chữ chạy ở isolate khác trong lúc luồng chính render ảnh. Lỗi (file hỏng, không
    // đọc được…) không làm hỏng việc chuyển: slide chỉ không có hộp chữ.
    final textFuture = _safeExtract(inputPath, password);
    final renderShare = mode == PdfToPptMode.editableText ? 0.7 : 0.9;
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
        onProgress?.call(renderShare * (i + 1) / count);
      }
    } finally {
      await doc.close();
    }
    token.throwIfCancelled();
    final pages = await textFuture;
    for (var i = 0; i < slides.length; i++) {
      final s = slides[i];
      final page = pages.where((p) => p.index == i).firstOrNull;
      if (page == null) continue;
      var bytes = s.bytes;
      var boxes = pptxTextBoxesFromPage(page, s.widthPt, s.heightPt);
      if (mode == PdfToPptMode.editableText && boxes.isNotEmpty) {
        token.throwIfCancelled();
        EditableSlide? editable;
        try {
          editable = await eraseInIsolate(s.bytes, page, s.widthPt, s.heightPt);
        } catch (_) {
          editable = null; // lỗi giải mã / xử lý: trang này giữ nguyên hình
        }
        if (editable != null && editable.boxes.isNotEmpty) {
          bytes = editable.image;
          boxes = editable.boxes;
        }
        onProgress?.call(0.7 + 0.2 * (i + 1) / slides.length);
      }
      slides[i] = PptxImageSlide(
        bytes: bytes,
        widthPt: s.widthPt,
        heightPt: s.heightPt,
        format: s.format,
        textBoxes: boxes,
      );
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
