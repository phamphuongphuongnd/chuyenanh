/// Một kết quả tìm: khối (dòng / đoạn) số [block], bắt đầu ở [start], dài [length].
class SearchHit {
  const SearchHit(this.block, this.start, this.length);

  final int block;
  final int start;
  final int length;

  @override
  bool operator ==(Object other) =>
      other is SearchHit &&
      other.block == block &&
      other.start == start &&
      other.length == length;

  @override
  int get hashCode => Object.hash(block, start, length);

  @override
  String toString() => 'SearchHit($block, $start, $length)';
}

/// Một đoạn chữ của dòng đã tách theo kết quả tìm.
class TextSegment {
  const TextSegment(this.text, this.matched, this.start);

  final String text;
  final bool matched;

  /// Vị trí bắt đầu trong chuỗi gốc.
  final int start;

  @override
  bool operator ==(Object other) =>
      other is TextSegment &&
      other.text == text &&
      other.matched == matched &&
      other.start == start;

  @override
  int get hashCode => Object.hash(text, matched, start);

  @override
  String toString() => 'TextSegment("$text", $matched, $start)';
}

RegExp? _regexFor(String query) {
  final q = query.trim();
  if (q.isEmpty) return null;
  return RegExp(RegExp.escape(q), caseSensitive: false);
}

/// Mọi vị trí [query] (không phân biệt hoa thường) trong từng khối, theo thứ tự.
List<SearchHit> findHits(List<String> blocks, String query) {
  final re = _regexFor(query);
  if (re == null) return const [];
  final hits = <SearchHit>[];
  for (var i = 0; i < blocks.length; i++) {
    for (final m in re.allMatches(blocks[i])) {
      hits.add(SearchHit(i, m.start, m.end - m.start));
    }
  }
  return hits;
}

/// Tách [text] thành các đoạn khớp / không khớp [query]. Không khớp → một đoạn duy nhất.
List<TextSegment> highlightSegments(String text, String query) {
  final re = _regexFor(query);
  if (re == null || text.isEmpty) return [TextSegment(text, false, 0)];
  final out = <TextSegment>[];
  var pos = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > pos) {
      out.add(TextSegment(text.substring(pos, m.start), false, pos));
    }
    out.add(TextSegment(text.substring(m.start, m.end), true, m.start));
    pos = m.end;
  }
  if (pos < text.length) out.add(TextSegment(text.substring(pos), false, pos));
  return out.isEmpty ? [TextSegment(text, false, 0)] : out;
}
