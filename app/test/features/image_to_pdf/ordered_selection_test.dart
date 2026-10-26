import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/image_to_pdf/models/ordered_selection.dart';

void main() {
  test('số thứ tự theo thứ tự bấm, bắt đầu từ 1', () {
    final s = OrderedSelection<String>();
    s.toggle('a');
    s.toggle('c');
    s.toggle('b');
    expect(s.numberOf('a'), 1);
    expect(s.numberOf('c'), 2);
    expect(s.numberOf('b'), 3);
    expect(s.numberOf('zzz'), isNull);
    expect(s.items, ['a', 'c', 'b']);
  });

  test('bỏ chọn giữa chừng thì các ảnh sau dồn số', () {
    final s = OrderedSelection<String>()
      ..toggle('a')
      ..toggle('b')
      ..toggle('c');
    s.toggle('a');
    expect(s.numberOf('b'), 1);
    expect(s.numberOf('c'), 2);
    expect(s.length, 2);
  });

  test('đủ giới hạn thì không chọn thêm được nhưng vẫn bỏ chọn được', () {
    final s = OrderedSelection<int>(limit: 2);
    expect(s.toggle(1), isTrue);
    expect(s.toggle(2), isTrue);
    expect(s.isFull, isTrue);
    expect(s.toggle(3), isFalse);
    expect(s.items, [1, 2]);
    expect(s.toggle(1), isTrue);
    expect(s.items, [2]);
  });

  test('add không thêm trùng, clear xoá hết', () {
    final s = OrderedSelection<int>(limit: 5);
    expect(s.add(1), isTrue);
    expect(s.add(1), isFalse);
    s.clear();
    expect(s.isEmpty, isTrue);
  });

  test('giới hạn mặc định là maxImagesPerPdf', () {
    expect(OrderedSelection<int>().limit, maxImagesPerPdf);
  });
}
