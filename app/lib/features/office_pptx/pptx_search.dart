// Tìm chữ trong deck PPTX (thuần Dart, không phụ thuộc Flutter).
import 'package:pptx_reader/pptx_reader.dart';

/// Một kết quả: `page` là vị trí trong danh sách slide đang hiển thị,
/// `slideIndex` là vị trí trong `deck.slides`.
class PptxHit {
  const PptxHit({
    required this.page,
    required this.slideIndex,
    this.inNotes = false,
  });
  final int page;
  final int slideIndex;
  final bool inNotes;

  @override
  bool operator ==(Object other) =>
      other is PptxHit &&
      other.page == page &&
      other.slideIndex == slideIndex &&
      other.inNotes == inNotes;

  @override
  int get hashCode => Object.hash(page, slideIndex, inNotes);

  @override
  String toString() => 'PptxHit(page: $page, slide: $slideIndex, notes: $inNotes)';
}

/// Đếm số lần [needle] (đã hạ chữ thường) xuất hiện không chồng lấn trong [hay].
int _count(String hay, String needle) {
  var n = 0;
  var from = 0;
  while (true) {
    final i = hay.indexOf(needle, from);
    if (i < 0) return n;
    n++;
    from = i + needle.length;
  }
}

void _paragraphs(List<PptxParagraph> ps, List<String> out) {
  for (final p in ps) {
    out.add(p.runs.map((r) => r.text).join());
  }
}

void _shapeTexts(PptxShape s, List<String> out) {
  switch (s) {
    case PptxTextShape():
      _paragraphs(s.paragraphs, out);
    case PptxTableShape():
      for (final row in s.rows) {
        for (final cell in row.cells) {
          _paragraphs(cell.paragraphs, out);
        }
      }
    case PptxGroupShape():
      for (final c in s.children) {
        _shapeTexts(c, out);
      }
    default:
      break;
  }
}

/// Mọi kết quả khớp [query] (không phân biệt hoa thường) trong các slide
/// [visibleSlideIndexes], theo thứ tự slide; mỗi lần xuất hiện là một kết quả.
/// [includeNotes] = true thì tìm cả ghi chú (sau chữ trên slide của cùng slide).
List<PptxHit> findPptxHits(
  PptxDeck deck,
  List<int> visibleSlideIndexes,
  String query, {
  bool includeNotes = false,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final hits = <PptxHit>[];
  for (var page = 0; page < visibleSlideIndexes.length; page++) {
    final si = visibleSlideIndexes[page];
    if (si < 0 || si >= deck.slides.length) continue;
    final slide = deck.slides[si];
    final texts = <String>[];
    for (final s in slide.shapes) {
      _shapeTexts(s, texts);
    }
    var n = 0;
    for (final t in texts) {
      n += _count(t.toLowerCase(), q);
    }
    for (var i = 0; i < n; i++) {
      hits.add(PptxHit(page: page, slideIndex: si));
    }
    if (includeNotes) {
      final notes = slide.notesText;
      if (notes != null) {
        final m = _count(notes.toLowerCase(), q);
        for (var i = 0; i < m; i++) {
          hits.add(PptxHit(page: page, slideIndex: si, inNotes: true));
        }
      }
    }
  }
  return hits;
}
