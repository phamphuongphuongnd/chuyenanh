// Kiểm thử hộp trắng A07 — scanner/model/scan_session.dart (Bước 6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' show ImageFilter;
import 'package:pdf_office/features/scanner/model/scan_session.dart';

void main() {
  late ProviderContainer c;
  late ProviderSubscription<Object?> keep;
  setUp(() {
    c = ProviderContainer();
    keep = c.listen(scanSessionProvider, (_, _) {});
    c.read(scanSessionProvider.notifier).addPaths(['1.jpg', '2.jpg', '3.jpg']);
  });
  tearDown(() {
    keep.close();
    c.dispose();
  });

  List<String> paths() => c.read(scanSessionProvider).map((p) => p.path).toList();

  group('U1 reorder', () {
    test('U1-B1 chỉ số hợp lệ ⇒ đổi thứ tự', () {
      c.read(scanSessionProvider.notifier).reorder(2, 0);
      expect(paths(), ['3.jpg', '1.jpg', '2.jpg']);
    });
    test('U1-B2 chỉ số sai ⇒ RangeError, state giữ nguyên', () {
      expect(() => c.read(scanSessionProvider.notifier).reorder(5, 0), throwsRangeError);
      expect(paths(), ['1.jpg', '2.jpg', '3.jpg']);
    });
  });

  group('U2 _update (qua setFilter / rotate)', () {
    test('U2-B1 id khớp ⇒ chỉ trang đó đổi', () {
      final id = c.read(scanSessionProvider)[1].id;
      c.read(scanSessionProvider.notifier).setFilter(id, ImageFilter.grayscale);
      expect(c.read(scanSessionProvider).map((p) => p.filter).toList(),
          [ImageFilter.original, ImageFilter.grayscale, ImageFilter.original]);
    });
    test('U2-B2 id không khớp ⇒ không trang nào đổi', () {
      c.read(scanSessionProvider.notifier).rotate('khong-co');
      expect(c.read(scanSessionProvider).every((p) => p.quarterTurns == 0), isTrue);
      expect(paths(), ['1.jpg', '2.jpg', '3.jpg']);
    });
  });
}
