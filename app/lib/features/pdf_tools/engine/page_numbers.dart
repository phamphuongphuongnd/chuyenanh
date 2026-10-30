// Đánh số trang PDF: hàm thuần (định dạng nhãn, chọn trang, tính vị trí theo hướng xoay)
// + job chạy TRONG isolate + engine gọi job. Job không import Flutter widget.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import '../logic/vi_nfc.dart';
import 'isolate_job.dart';
import 'page_ranges.dart';
import 'pdf_ops.dart' show isLatin1, makeFont, openPdfFile;
import 'syncfusion_pdf_tools.dart' show PdfFontLoader, loadBundledFont;

/// Kiểu nhãn số trang.
enum PageNumberStyle {
  /// `1`
  plain,

  /// `1 / n`
  ofTotal,

  /// `Trang 1` (chữ theo ngôn ngữ app, xem [PageNumberSpec.pageWordTemplate]).
  pageWord,

  /// `- 1 -`
  dashed,
}

/// Hàng đặt số: mép trên / mép dưới trang.
enum PageNumberVAlign { top, bottom }

/// Cột đặt số: trái / giữa / phải.
enum PageNumberHAlign { left, center, right }

/// Chỗ thay số trong mẫu "Trang {n}".
const pageNumberToken = '{n}';

/// Giới hạn tuỳ chọn (UI và engine dùng chung).
const double minPageNumberFontSize = 8;
const double maxPageNumberFontSize = 24;
const int maxPageNumberStart = 99999;

/// Tuỳ chọn đánh số. Chỉ chứa kiểu đơn giản → gửi được sang isolate.
class PageNumberSpec {
  const PageNumberSpec({
    this.style = PageNumberStyle.plain,
    this.vAlign = PageNumberVAlign.bottom,
    this.hAlign = PageNumberHAlign.center,
    this.fontSize = 11,
    this.colorArgb = 0xFF000000,
    this.margin = 24,
    this.startNumber = 1,
    this.ranges,
    this.skipFirstPage = false,
    this.pageWordTemplate = 'Page $pageNumberToken',
  });

  final PageNumberStyle style;
  final PageNumberVAlign vAlign;
  final PageNumberHAlign hAlign;

  /// Cỡ chữ (point), trong [minPageNumberFontSize]..[maxPageNumberFontSize].
  final double fontSize;
  final int colorArgb;

  /// Khoảng cách (point) từ mép trang (theo hướng đang xem) tới khung chữ.
  final double margin;

  /// Số của trang đầu tiên được đánh số.
  final int startNumber;

  /// Các khoảng trang (1-based) được đánh số; `null` = tất cả.
  final List<PageRange>? ranges;

  /// Bỏ trang 1 (bìa): không vẽ số, không tính vào thứ tự.
  final bool skipFirstPage;

  /// Mẫu nhãn kiểu [PageNumberStyle.pageWord], chứa [pageNumberToken] (vd. "Trang {n}").
  final String pageWordTemplate;
}

// --------------------------------------------------------------------------
// Hàm thuần

/// Nhãn của trang mang số [number]; [total] = số lớn nhất sẽ được vẽ (dùng cho "1 / n").
String formatPageLabel(
  PageNumberStyle style,
  int number,
  int total, {
  String pageWordTemplate = 'Page $pageNumberToken',
}) {
  switch (style) {
    case PageNumberStyle.plain:
      return '$number';
    case PageNumberStyle.ofTotal:
      return '$number / $total';
    case PageNumberStyle.pageWord:
      final t = pageWordTemplate.trim();
      if (t.contains(pageNumberToken)) {
        return t.replaceAll(pageNumberToken, '$number');
      }
      return t.isEmpty ? '$number' : '$t $number';
    case PageNumberStyle.dashed:
      return '- $number -';
  }
}

/// Chỉ số trang (0-based, tăng dần, không trùng) sẽ được đánh số.
///
/// [ranges] `null` = mọi trang; khoảng ngoài `1..pageCount` → [FormatException].
/// [skipFirst] bỏ trang 1 kể cả khi nó nằm trong [ranges].
List<int> selectNumberedPages(
  int pageCount, {
  List<PageRange>? ranges,
  bool skipFirst = false,
}) {
  if (pageCount < 1) return const [];
  final pages = <int>{};
  if (ranges == null) {
    for (var i = 0; i < pageCount; i++) {
      pages.add(i);
    }
  } else {
    validateRanges(ranges, pageCount);
    for (final r in ranges) {
      for (var n = r.start; n <= r.end; n++) {
        pages.add(n - 1);
      }
    }
  }
  if (skipFirst) pages.remove(0);
  return pages.toList()..sort();
}

/// Góc xoay hiển thị (0/90/180/270) của trang.
int pageRotationDegrees(sf.PdfPageRotateAngle a) => switch (a) {
  sf.PdfPageRotateAngle.rotateAngle0 => 0,
  sf.PdfPageRotateAngle.rotateAngle90 => 90,
  sf.PdfPageRotateAngle.rotateAngle180 => 180,
  sf.PdfPageRotateAngle.rotateAngle270 => 270,
};

/// Khổ trang như người xem thấy: xoay 90/270 thì đổi rộng ↔ cao.
Size visualPageSize(Size raw, int rotationDeg) {
  final r = ((rotationDeg % 360) + 360) % 360;
  return (r == 90 || r == 270) ? Size(raw.height, raw.width) : raw;
}

/// Đổi điểm ([vx], [vy]) trên trang ĐANG XEM (gốc trên trái, đã xoay) về toạ độ trang gốc
/// chưa xoay [raw] (hệ toạ độ của `page.graphics`). PDF `/Rotate` = xoay theo chiều kim
/// đồng hồ khi hiển thị.
Offset visualToRawPoint(double vx, double vy, Size raw, int rotationDeg) {
  switch (((rotationDeg % 360) + 360) % 360) {
    case 90:
      return Offset(vy, raw.height - vx);
    case 180:
      return Offset(raw.width - vx, raw.height - vy);
    case 270:
      return Offset(raw.width - vy, vx);
    default:
      return Offset(vx, vy);
  }
}

/// Khung chữ số trang trên trang đang xem [pageW]×[pageH] (gốc trên trái).
///
/// Cách mép [margin] theo hàng/cột đã chọn; khung lớn hơn chỗ trống thì bị kẹp vào trong
/// trang (không âm).
Rect pageNumberRect({
  required double pageW,
  required double pageH,
  required double textW,
  required double textH,
  required PageNumberVAlign vAlign,
  required PageNumberHAlign hAlign,
  required double margin,
}) {
  final m = math.max(0.0, margin);
  final maxLeft = math.max(0.0, pageW - textW);
  final maxTop = math.max(0.0, pageH - textH);
  final double x = switch (hAlign) {
    PageNumberHAlign.left => m,
    PageNumberHAlign.center => (pageW - textW) / 2,
    PageNumberHAlign.right => pageW - m - textW,
  };
  final double y = switch (vAlign) {
    PageNumberVAlign.top => m,
    PageNumberVAlign.bottom => pageH - m - textH,
  };
  return Rect.fromLTWH(
    x.clamp(0.0, maxLeft),
    y.clamp(0.0, maxTop),
    textW,
    textH,
  );
}

// --------------------------------------------------------------------------
// Job (chạy trong isolate)

Future<Object?> pageNumbersJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final spec = args['spec'] as PageNumberSpec;
  final fontBytes = args['fontBytes'] as Uint8List?;
  final output = args['output'] as String;
  final doc = await openPdfFile(input, password: password);
  final List<int> bytes;
  try {
    // Mở có mật khẩu rồi lưu thì file kết quả không còn mật khẩu (như watermark).
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final targets = selectNumberedPages(
      doc.pages.count,
      ranges: spec.ranges,
      skipFirst: spec.skipFirstPage,
    );
    if (targets.isEmpty) throw ArgumentError('no pages to number');
    final total = spec.startNumber + targets.length - 1;
    String label(int n) => composeVietnamese(
      formatPageLabel(
        spec.style,
        n,
        total,
        pageWordTemplate: spec.pageWordTemplate,
      ),
    );
    final font = makeFont(
      label(spec.startNumber),
      spec.fontSize.clamp(minPageNumberFontSize, maxPageNumberFontSize),
      fontBytes,
    );
    final brush = sf.PdfSolidBrush(
      sf.PdfColor(
        (spec.colorArgb >> 16) & 0xFF,
        (spec.colorArgb >> 8) & 0xFF,
        spec.colorArgb & 0xFF,
      ),
    );
    for (var k = 0; k < targets.length; k++) {
      final page = doc.pages[targets[k]];
      final raw = page.size;
      final rot = pageRotationDegrees(page.rotation);
      final view = visualPageSize(raw, rot);
      final text = label(spec.startNumber + k);
      final m = font.measureString(text);
      final box = pageNumberRect(
        pageW: view.width,
        pageH: view.height,
        textW: m.width + 2, // +2: tránh xuống dòng do làm tròn
        textH: m.height,
        vAlign: spec.vAlign,
        hAlign: spec.hAlign,
        margin: spec.margin,
      );
      final g = page.graphics;
      g.save();
      // Đưa hệ toạ độ về "trang đang xem" để chữ nằm đúng chỗ và đứng thẳng khi xem.
      // Cùng phép biến đổi Syncfusion dùng cho trang mới có góc xoay.
      final origin = visualToRawPoint(0, 0, raw, rot);
      if (rot != 0) {
        g.translateTransform(origin.dx, origin.dy);
        g.rotateTransform(-rot.toDouble());
      }
      g.drawString(text, font, brush: brush, bounds: box);
      g.restore();
      port.progress((k + 1) / targets.length * 0.9);
    }
    bytes = await doc.save();
  } finally {
    doc.dispose();
  }
  await writeAtomically(output, bytes);
  port.fileWritten(output);
  return output;
}

// --------------------------------------------------------------------------
// Engine

/// Thêm số trang vào PDF (thay được bằng bản giả trong test).
abstract interface class PageNumbersEngine {
  /// Ghi bản đã đánh số ra [outputPath] (khác file gốc), trả về path đó.
  Future<String> addPageNumbers(
    String inputPath,
    PageNumberSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}

/// Bản Syncfusion: vẽ thẳng lên trang gốc (giữ annotation/form/link), chạy trong isolate.
class SyncfusionPageNumbers implements PageNumbersEngine {
  const SyncfusionPageNumbers({this.fontLoader = loadBundledFont});

  /// Nạp font Unicode (Noto) khi nhãn có chữ ngoài Latin-1. `null` = không nạp.
  final PdfFontLoader? fontLoader;

  @override
  Future<String> addPageNumbers(
    String inputPath,
    PageNumberSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (spec.fontSize < minPageNumberFontSize ||
        spec.fontSize > maxPageNumberFontSize) {
      throw ArgumentError.value(spec.fontSize, 'fontSize', 'must be 8..24');
    }
    if (spec.startNumber < 1 || spec.startNumber > maxPageNumberStart) {
      throw RangeError.range(spec.startNumber, 1, maxPageNumberStart, 'startNumber');
    }
    if (spec.margin < 0) {
      throw ArgumentError.value(spec.margin, 'margin', 'must be >= 0');
    }
    if (p.normalize(p.absolute(outputPath)) ==
        p.normalize(p.absolute(inputPath))) {
      throw ArgumentError('output must differ from input: $outputPath');
    }
    cancelToken?.throwIfCancelled();
    // Chọn font theo nhãn mẫu đã chuẩn hoá NFC (chữ số không đổi hệ chữ).
    final sample = composeVietnamese(
      formatPageLabel(
        spec.style,
        spec.startNumber,
        spec.startNumber,
        pageWordTemplate: spec.pageWordTemplate,
      ),
    );
    final fontBytes = isLatin1(sample) ? null : await fontLoader?.call(sample);
    final r = await runIsolateJob(
      pageNumbersJob,
      {
        'input': inputPath,
        'password': password,
        'spec': spec,
        'fontBytes': fontBytes,
        'output': outputPath,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }
}
