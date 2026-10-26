/// Ghép kết quả OCR thành văn bản / khối tài liệu (hàm thuần, có unit test).
library;

import 'package:pdf_layout/pdf_layout.dart';

import '../../../engines/ocr/ocr_engine.dart';

// Hán + kana + dấu câu CJK + dạng toàn chiều. KHÔNG gồm Hangul (tiếng Hàn có dấu cách giữa từ).
final RegExp _noSpaceScript = RegExp(r'[　-〿぀-ヿ㐀-䶿一-鿿＀-￯]');

/// Nối các dòng của một block thành một đoạn: dấu cách ở giữa, trừ khi chỗ nối
/// là chữ Trung/Nhật (không dùng dấu cách).
String joinOcrLines(Iterable<String> lines) {
  final out = StringBuffer();
  String? prev;
  for (final raw in lines) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (prev != null) {
      final cjkJoin =
          _noSpaceScript.hasMatch(prev[prev.length - 1]) ||
          _noSpaceScript.hasMatch(t[0]);
      if (!cjkJoin) out.write(' ');
    }
    out.write(t);
    prev = t;
  }
  return out.toString();
}

/// Toàn văn nhiều trang: bỏ trang rỗng, nối bằng dòng trống.
String ocrPagesToText(List<OcrResult> pages) =>
    pages.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n\n');

/// Mỗi trang → các đoạn (block chữ lớn hơn hẳn mặt bằng → tiêu đề), giữa các trang
/// có [DocPageBreak] (kể cả trang không nhận ra chữ, để số trang DOCX khớp số trang quét).
List<DocBlock> ocrPagesToDocBlocks(List<OcrResult> pages) {
  final out = <DocBlock>[];
  for (var i = 0; i < pages.length; i++) {
    if (i > 0) out.add(const DocPageBreak());
    out.addAll(_pageBlocks(pages[i]));
  }
  return out;
}

List<DocBlock> _pageBlocks(OcrResult page) {
  final heights = <double>[
    for (final b in page.blocks)
      for (final l in b.lines)
        if (l.bounds.height > 0) l.bounds.height,
  ]..sort();
  final median = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];

  final out = <DocBlock>[];
  for (final b in page.blocks) {
    final text = b.lines.isEmpty
        ? joinOcrLines(b.text.split('\n'))
        : joinOcrLines(b.lines.map((l) => l.text));
    if (text.isEmpty) continue;
    final level = _headingLevel(b, median);
    out.add(
      level == null
          ? DocParagraph(spans: [DocSpan(text)])
          : DocHeading(level: level, spans: [DocSpan(text, bold: true)]),
    );
  }
  return out;
}

/// Tiêu đề: ≤ 2 dòng, ngắn, mọi dòng cao ≥ 1,4× dòng trung vị của trang.
int? _headingLevel(OcrBlock b, double median) {
  if (median <= 0 || b.lines.isEmpty || b.lines.length > 2) return null;
  if (b.text.length > 100) return null;
  final minH = b.lines
      .map((l) => l.bounds.height)
      .reduce((a, c) => a < c ? a : c);
  final ratio = minH / median;
  if (ratio >= 1.8) return 1;
  if (ratio >= 1.4) return 2;
  return null;
}
