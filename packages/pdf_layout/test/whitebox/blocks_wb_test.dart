// Kiểm thử hộp trắng (A18) — lib/src/blocks.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

void main() {
  group('U1 DocSpan ==', () {
    test('U1-P1 cùng chữ, đậm, cỡ ⇒ bằng nhau', () {
      const a = DocSpan('a', bold: true, fontSizePt: 12);
      const b = DocSpan('a', bold: true, fontSizePt: 12);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
    test('U1-P2 khác kiểu ⇒ false', () {
      // ignore: unrelated_type_equality_checks
      expect(const DocSpan('a') == 'a', isFalse);
    });
    test('U1-P3 khác chữ ⇒ false', () {
      expect(const DocSpan('a') == const DocSpan('b'), isFalse);
    });
    test('U1-P4 khác đậm ⇒ false', () {
      expect(const DocSpan('a') == const DocSpan('a', bold: true), isFalse);
    });
    test('U1-P5 khác cỡ ⇒ false', () {
      expect(const DocSpan('a') == const DocSpan('a', fontSizePt: 12), isFalse);
    });
  });

  group('U2 DocSpan.toString', () {
    test('U2-P1 thường', () {
      expect(const DocSpan('a').toString(), 'DocSpan("a")');
    });
    test('U2-P2 đậm', () {
      final s = const DocSpan('a', bold: true).toString();
      expect(s, contains(', bold'));
      expect(s, isNot(contains('pt')));
    });
    test('U2-P3 có cỡ', () {
      final s = const DocSpan('a', fontSizePt: 12).toString();
      expect(s, contains('12.0pt'));
      expect(s, isNot(contains('bold')));
    });
  });

  test('U3-P1 DocTable.columnCount: 0 / 1 / hàng lệch ⇒ hàng dài nhất', () {
    expect(const DocTable(cells: []).columnCount, 0);
    expect(
      const DocTable(
        cells: [
          ['a'],
        ],
      ).columnCount,
      1,
    );
    expect(
      const DocTable(
        cells: [
          ['a'],
          ['b', 'c', 'd'],
          ['e', 'f'],
        ],
      ).columnCount,
      3,
    );
  });
}
