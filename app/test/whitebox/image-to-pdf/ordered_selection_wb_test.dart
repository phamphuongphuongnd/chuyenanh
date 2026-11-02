// Kiểm thử hộp trắng (A06) — models/ordered_selection.dart. Mã bộ = buoc-5-du-lieu-thu.md của ordered_selection.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/image_to_pdf/models/ordered_selection.dart';

void main() {
  group('U1 numberOf', () {
    test('1-1 chưa chọn ⇒ null', () {
      final s = OrderedSelection<String>()..add('a');
      expect(s.numberOf('z'), isNull);
    });
    test('1-2 đã chọn ⇒ số thứ tự 1-based theo thứ tự bấm', () {
      final s = OrderedSelection<String>()
        ..add('a')
        ..add('b');
      expect(s.numberOf('a'), 1);
      expect(s.numberOf('b'), 2);
    });
  });

  group('U2 toggle', () {
    test('2-1 đang chọn ⇒ bỏ chọn, true, ảnh sau dồn số', () {
      final s = OrderedSelection<String>()
        ..add('a')
        ..add('b');
      expect(s.toggle('a'), isTrue);
      expect(s.items, ['b']);
      expect(s.numberOf('b'), 1);
    });
    test('2-2 chưa chọn, đã đủ giới hạn ⇒ false, không đổi', () {
      final s = OrderedSelection<int>(limit: 2)
        ..add(1)
        ..add(2);
      expect(s.toggle(3), isFalse);
      expect(s.items, [1, 2]);
    });
    test('2-3 chưa chọn, còn chỗ ⇒ thêm cuối, true', () {
      final s = OrderedSelection<int>(limit: 2)..add(1);
      expect(s.toggle(2), isTrue);
      expect(s.items, [1, 2]);
    });
  });

  group('U3 add', () {
    test('3-1 đã có ⇒ false, không thêm trùng', () {
      final s = OrderedSelection<int>()..add(1);
      expect(s.add(1), isFalse);
      expect(s.items, [1]);
    });
    test('3-2 chưa có, đã đủ ⇒ false', () {
      final s = OrderedSelection<int>(limit: 1)..add(1);
      expect(s.add(2), isFalse);
      expect(s.items, [1]);
    });
    test('3-3 chưa có, còn chỗ ⇒ true, thêm cuối', () {
      final s = OrderedSelection<int>(limit: 3)..add(1);
      expect(s.add(2), isTrue);
      expect(s.items, [1, 2]);
    });
  });
}
