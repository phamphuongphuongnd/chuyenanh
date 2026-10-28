// Tìm chữ trong deck PPTX (thuần Dart, không phụ thuộc Flutter).
import 'dart:collection';

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
  String toString() =>
      'PptxHit(page: $page, slide: $slideIndex, notes: $inNotes)';
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

/// Khoảng [start, end) của từng lần [lowerNeedle] xuất hiện (không chồng lấn) trong [lowerHay].
/// Cả hai đã hạ chữ thường; cùng cách đếm với [findPptxHits].
List<(int, int)> findMatchRanges(String lowerHay, String lowerNeedle) {
  if (lowerNeedle.isEmpty) return const [];
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = lowerHay.indexOf(lowerNeedle, from);
    if (i < 0) return out;
    out.add((i, i + lowerNeedle.length));
    from = i + lowerNeedle.length;
  }
}

/// Vị trí một đoạn văn trong dãy kết quả của slide: [firstOccurrence] là số kết quả
/// (trên slide đó) đứng trước đoạn này, theo đúng thứ tự của [findPptxHits].
class PptxParagraphPos {
  const PptxParagraphPos(this.slideIndex, this.firstOccurrence);
  final int slideIndex;
  final int firstOccurrence;
}

void _indexParagraphs(
  List<PptxParagraph> ps,
  int slideIndex,
  String q,
  List<int> occ,
  Map<PptxParagraph, PptxParagraphPos> out,
) {
  for (final p in ps) {
    out[p] = PptxParagraphPos(slideIndex, occ[0]);
    occ[0] += _count(p.runs.map((r) => r.text).join().toLowerCase(), q);
  }
}

void _indexShape(
  PptxShape s,
  int slideIndex,
  String q,
  List<int> occ,
  Map<PptxParagraph, PptxParagraphPos> out,
) {
  switch (s) {
    case PptxTextShape():
      _indexParagraphs(s.paragraphs, slideIndex, q, occ, out);
    case PptxTableShape():
      for (final row in s.rows) {
        for (final cell in row.cells) {
          _indexParagraphs(cell.paragraphs, slideIndex, q, occ, out);
        }
      }
    case PptxGroupShape():
      for (final c in s.children) {
        _indexShape(c, slideIndex, q, occ, out);
      }
    default:
      break;
  }
}

/// Bảng tra (theo danh tính đối tượng) đoạn văn → vị trí trong kết quả tìm, để tô riêng
/// kết quả hiện tại. Duyệt cùng thứ tự với [findPptxHits].
Map<PptxParagraph, PptxParagraphPos> indexPptxParagraphs(
  PptxDeck deck,
  List<int> visibleSlideIndexes,
  String query,
) {
  final out = HashMap<PptxParagraph, PptxParagraphPos>.identity();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return out;
  for (final si in visibleSlideIndexes) {
    if (si < 0 || si >= deck.slides.length) continue;
    final occ = [0];
    for (final s in deck.slides[si].shapes) {
      _indexShape(s, si, q, occ, out);
    }
  }
  return out;
}

/// Thứ tự (trong slide của nó) của kết quả [current] trên chữ slide; -1 nếu nằm ở ghi chú hoặc không có.
int currentOccurrenceInSlide(List<PptxHit> hits, int current) {
  if (current < 0 || current >= hits.length || hits[current].inNotes) return -1;
  final cur = hits[current];
  var n = 0;
  for (var i = 0; i < current; i++) {
    if (hits[i].slideIndex == cur.slideIndex && !hits[i].inNotes) n++;
  }
  return n;
}
