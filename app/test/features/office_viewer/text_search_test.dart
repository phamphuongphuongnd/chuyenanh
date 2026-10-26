import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_viewer/logic/text_search.dart';

void main() {
  test('findHits: không phân biệt hoa thường, theo thứ tự khối', () {
    final hits = findHits(['Hello hello', 'nothing', 'HELLO'], 'hello');
    expect(hits, const [
      SearchHit(0, 0, 5),
      SearchHit(0, 6, 5),
      SearchHit(2, 0, 5),
    ]);
  });

  test('findHits: query rỗng / chỉ khoảng trắng → không có kết quả', () {
    expect(findHits(['abc'], ''), isEmpty);
    expect(findHits(['abc'], '   '), isEmpty);
  });

  test('findHits: ký tự đặc biệt regex được escape; tiếng Việt có dấu', () {
    expect(findHits(['a.b (c) a.b'], 'a.b'), hasLength(2));
    expect(findHits(['Nguyễn Văn A'], 'nguyễn'), hasLength(1));
    expect(findHits(['axb'], 'a.b'), isEmpty);
  });

  test('highlightSegments tách đúng đoạn khớp', () {
    expect(highlightSegments('abXabc', 'ab'), const [
      TextSegment('ab', true, 0),
      TextSegment('X', false, 2),
      TextSegment('ab', true, 3),
      TextSegment('c', false, 5),
    ]);
  });

  test('highlightSegments: không khớp / rỗng → một đoạn', () {
    expect(highlightSegments('abc', 'z'), const [TextSegment('abc', false, 0)]);
    expect(highlightSegments('abc', ''), const [TextSegment('abc', false, 0)]);
    expect(highlightSegments('', 'a'), const [TextSegment('', false, 0)]);
  });
}
