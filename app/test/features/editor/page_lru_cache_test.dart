import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/editor/page_lru_cache.dart';

void main() {
  test('giữ tối đa capacity phần tử, bỏ phần tử ít dùng nhất', () {
    final c = PageLruCache<int, String>(3);
    for (var i = 0; i < 5; i++) {
      c.putIfAbsent(i, () => 'v$i');
    }
    expect(c.length, 3);
    expect(c.containsKey(0), isFalse);
    expect(c.containsKey(1), isFalse);
    expect(c.containsKey(4), isTrue);
  });

  test('truy cập lại làm phần tử "mới nhất"; không tạo lại khi đã có', () {
    final c = PageLruCache<int, String>(2);
    var made = 0;
    String make(int i) {
      made++;
      return 'v$i';
    }

    c.putIfAbsent(1, () => make(1));
    c.putIfAbsent(2, () => make(2));
    c.putIfAbsent(1, () => make(1)); // chạm lại 1
    c.putIfAbsent(3, () => make(3)); // đẩy 2 ra
    expect(made, 3);
    expect(c.containsKey(1), isTrue);
    expect(c.containsKey(2), isFalse);
  });

  test('remove xoá phần tử', () {
    final c = PageLruCache<int, String>(2)..putIfAbsent(1, () => 'a');
    c.remove(1);
    expect(c.length, 0);
  });
}
