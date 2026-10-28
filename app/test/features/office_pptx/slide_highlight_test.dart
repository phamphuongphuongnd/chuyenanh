import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_pptx/pptx_search.dart';
import 'package:pdf_office/features/office_pptx/slide_view.dart';

void main() {
  const base = TextStyle(color: Colors.white, fontSize: 20);

  test('tô vàng mọi chỗ khớp, không phân biệt hoa thường', () {
    final spans = highlightSpans('Level one, LEVEL two', base, 'level', null);
    expect(spans.map((s) => s.text), ['Level', ' one, ', 'LEVEL', ' two']);
    expect(spans[0].style?.backgroundColor, const Color(0xFFFFEB3B));
    expect(spans[0].style?.color, Colors.black);
    expect(spans[1].style?.backgroundColor, isNull);
    expect(spans[1].style?.color, Colors.white);
    expect(spans[2].style?.backgroundColor, const Color(0xFFFFEB3B));
  });

  test('truy vấn rỗng hoặc không khớp: giữ nguyên một đoạn', () {
    for (final q in ['', '   ', 'xyz']) {
      final spans = highlightSpans('Level one', base, q, null);
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Level one');
      expect(spans.single.style, base);
    }
  });

  testWidgets('PptxSearchHighlight.queryOf lấy từ khoá từ cây widget', (
    tester,
  ) async {
    String? seen;
    await tester.pumpWidget(
      PptxSearchHighlight(
        query: 'abc',
        child: Builder(
          builder: (context) {
            seen = PptxSearchHighlight.queryOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, 'abc');
  });

  test(
    'highlightRunSpans: chỗ khớp trải qua nhiều run, kết quả hiện tại tô cam',
    () {
      // Đoạn "Level one" gồm 2 run: "Lev" + "el one"; khớp "level" trải qua cả hai.
      final ranges = findMatchRanges('level one level', 'level');
      final a = highlightRunSpans(
        'Lev',
        0,
        ranges,
        base,
        null,
        isCurrent: (k) => k == 1,
      );
      final b = highlightRunSpans(
        'el one level',
        3,
        ranges,
        base,
        null,
        isCurrent: (k) => k == 1,
      );
      expect(a.map((s) => s.text), ['Lev']);
      expect(a.single.style?.backgroundColor, const Color(0xFFFFEB3B));
      expect(b.map((s) => s.text), ['el', ' one ', 'level']);
      expect(b[0].style?.backgroundColor, const Color(0xFFFFEB3B));
      expect(b[1].style?.backgroundColor, isNull);
      expect(b[2].style?.backgroundColor, const Color(0xFFFF9800));
    },
  );
}
