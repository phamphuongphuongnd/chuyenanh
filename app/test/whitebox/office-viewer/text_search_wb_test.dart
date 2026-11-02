// Kiểm thử hộp trắng A08 — logic/text_search.dart. Mã bộ theo
// test-output/whitebox/office-viewer/text_search/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_viewer/logic/text_search.dart';

void main() {
  group('U1 SearchHit ==', () {
    const h = SearchHit(1, 2, 3);
    test('U1-P1 cùng giá trị ⇒ bằng', () {
      expect(h == const SearchHit(1, 2, 3), isTrue);
      expect(h.hashCode, const SearchHit(1, 2, 3).hashCode);
    });
    test('U1-P2 khác kiểu ⇒ khác', () => expect(h == ('x' as Object), isFalse));
    test('U1-P3 khác block ⇒ khác', () => expect(h == const SearchHit(9, 2, 3), isFalse));
    test('U1-P4 khác start ⇒ khác', () => expect(h == const SearchHit(1, 9, 3), isFalse));
    test('U1-P5 khác length ⇒ khác', () => expect(h == const SearchHit(1, 2, 9), isFalse));
  });

  group('U2 TextSegment ==', () {
    const s = TextSegment('ab', true, 0);
    test('U2-P1 cùng giá trị ⇒ bằng', () => expect(s == const TextSegment('ab', true, 0), isTrue));
    test('U2-P2 khác kiểu ⇒ khác', () => expect(s == (1 as Object), isFalse));
    test('U2-P3 khác text ⇒ khác', () => expect(s == const TextSegment('ac', true, 0), isFalse));
    test('U2-P4 khác matched ⇒ khác', () => expect(s == const TextSegment('ab', false, 0), isFalse));
    test('U2-P5 khác start ⇒ khác', () => expect(s == const TextSegment('ab', true, 1), isFalse));
  });

  group('U3 _regexFor (qua findHits)', () {
    test('U3-P1 truy vấn "a" ⇒ có regex, tìm được', () {
      expect(findHits(['a'], 'a'), const [SearchHit(0, 0, 1)]);
    });
    test('U3-P2 truy vấn "  " ⇒ không regex ⇒ rỗng', () {
      expect(findHits(['a  b'], '  '), isEmpty);
    });
  });

  group('U4 findHits', () {
    test('U4-P1 "Ab a" tìm "a" ⇒ 2 chỗ, không phân biệt hoa thường', () {
      expect(findHits(['Ab a'], 'a'), const [SearchHit(0, 0, 1), SearchHit(0, 3, 1)]);
    });
    test('U4-P2 truy vấn rỗng ⇒ rỗng', () => expect(findHits(['a'], ''), isEmpty));
    test('U4-P3 không khối ⇒ rỗng', () => expect(findHits(const [], 'a'), isEmpty));
    test('U4-P4 khối 0 không khớp, khối 1 khớp ⇒ đúng chỉ số khối', () {
      expect(findHits(['x', 'a'], 'a'), const [SearchHit(1, 0, 1)]);
    });
  });

  group('U5 highlightSegments', () {
    test('U5-P1 "xAby" / "ab" ⇒ x | Ab | y', () {
      expect(highlightSegments('xAby', 'ab'), const [
        TextSegment('x', false, 0),
        TextSegment('Ab', true, 1),
        TextSegment('y', false, 3),
      ]);
    });
    test('U5-P2 truy vấn trắng ⇒ 1 đoạn', () {
      expect(highlightSegments('xAby', ' '), const [TextSegment('xAby', false, 0)]);
    });
    test('U5-P3 chuỗi rỗng ⇒ 1 đoạn rỗng', () {
      expect(highlightSegments('', 'a'), const [TextSegment('', false, 0)]);
    });
    test('U5-P4 khớp ngay đầu ⇒ ab | Y', () {
      expect(highlightSegments('abY', 'ab'), const [
        TextSegment('ab', true, 0),
        TextSegment('Y', false, 2),
      ]);
    });
    test('U5-P5 khớp ở cuối ⇒ x | ab (không đoạn đuôi)', () {
      expect(highlightSegments('xab', 'ab'), const [
        TextSegment('x', false, 0),
        TextSegment('ab', true, 1),
      ]);
    });
    test('U5-P6 không khớp ⇒ 1 đoạn duy nhất', () {
      expect(highlightSegments('xyz', 'ab'), const [TextSegment('xyz', false, 0)]);
    });
  });
}
