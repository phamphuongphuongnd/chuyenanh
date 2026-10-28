import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_viewer/data/text_decoder.dart';
import 'package:pdf_office/features/office_viewer/logic/text_search.dart';

void main() {
  test('splitLinesCapped: file nhỏ giống splitLines', () {
    expect(splitLinesCapped('a\r\nb\nc\rd'), ['a', 'b', 'c', 'd']);
    expect(splitLinesCapped(''), ['']);
    expect(splitLinesCapped('a\n'), ['a', '']);
  });

  test('splitLinesCapped: dòng dài bị cắt thành đoạn <= maxLen, ghép lại đủ', () {
    final long = 'x' * 12345;
    final out = splitLinesCapped('$long\nend', maxLen: 5000);
    expect(out.length, 4);
    expect(out.take(3).every((s) => s.length <= 5000), isTrue);
    expect(out.take(3).join(), long);
    expect(out.last, 'end');
  });

  test('splitLinesCapped: không cắt giữa cặp surrogate', () {
    final s = '😀' * 10; // 20 code unit
    final out = splitLinesCapped(s, maxLen: 5);
    expect(out.join(), s);
    for (final part in out) {
      expect(part.runes.length * 2, part.length);
    }
  });

  test('findHitsLimited: dừng ở limit và báo truncated', () {
    final r = findHitsLimited([('a' * 100)], 'a', limit: 10);
    expect(r.hits, hasLength(10));
    expect(r.truncated, isTrue);
  });

  test('findHitsLimited: ít kết quả hơn limit → không truncated, giống findHits', () {
    final blocks = ['Hello hello', 'nothing', 'HELLO'];
    final r = findHitsLimited(blocks, 'hello', limit: 10);
    expect(r.truncated, isFalse);
    expect(r.hits, findHits(blocks, 'hello'));
    expect(findHitsLimited(blocks, '  ').hits, isEmpty);
  });
}
