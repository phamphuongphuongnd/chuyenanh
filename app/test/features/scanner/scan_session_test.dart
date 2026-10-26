import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' show ImageFilter;
import 'package:pdf_office/features/scanner/model/scan_page.dart';
import 'package:pdf_office/features/scanner/model/scan_session.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

List<String> _paths(ProviderContainer c) =>
    c.read(scanSessionProvider).map((p) => p.path).toList();

void main() {
  group('reorderPages (quy ước ReorderableListView)', () {
    List<ScanPage> three() => [
      const ScanPage(id: 'a', path: 'a.jpg'),
      const ScanPage(id: 'b', path: 'b.jpg'),
      const ScanPage(id: 'c', path: 'c.jpg'),
    ];

    test('kéo xuống: newIndex tính trước khi bỏ phần tử', () {
      final r = reorderPages(three(), 0, 3);
      expect(r.map((p) => p.id), ['b', 'c', 'a']);
    });

    test('kéo lên', () {
      final r = reorderPages(three(), 2, 0);
      expect(r.map((p) => p.id), ['c', 'a', 'b']);
    });

    test('đổi chỗ liền kề', () {
      final r = reorderPages(three(), 0, 2);
      expect(r.map((p) => p.id), ['b', 'a', 'c']);
    });

    test('thả tại chỗ → không đổi, và không sửa danh sách gốc', () {
      final src = three();
      expect(reorderPages(src, 1, 1).map((p) => p.id), ['a', 'b', 'c']);
      expect(reorderPages(src, 1, 2).map((p) => p.id), ['a', 'b', 'c']);
      expect(src.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('chỉ số sai → ném RangeError', () {
      expect(() => reorderPages(three(), 3, 0), throwsRangeError);
      expect(() => reorderPages(three(), 0, 4), throwsRangeError);
    });
  });

  group('ScanPage', () {
    test('toEdit phản ánh xoay + bộ lọc, xoay chuẩn hoá về 0..3', () {
      const p = ScanPage(
        id: 'a',
        path: 'a.jpg',
        quarterTurns: 3,
        filter: ImageFilter.magicColor,
      );
      final e = p.toEdit(maxLongSide: 2000);
      expect(e.rotationQuarterTurns, 3);
      expect(e.filter, ImageFilter.magicColor);
      expect(e.maxLongSide, 2000);
      expect(p.rotatedRight().quarterTurns, 0);
      expect(p.rotatedRight().rotatedRight().quarterTurns, 1);
    });

    test('isUnedited đúng khi không xoay không lọc', () {
      expect(const ScanPage(id: 'a', path: 'a').isUnedited, isTrue);
      expect(
        const ScanPage(id: 'a', path: 'a', quarterTurns: 1).isUnedited,
        isFalse,
      );
      expect(
        const ScanPage(
          id: 'a',
          path: 'a',
          filter: ImageFilter.grayscale,
        ).isUnedited,
        isFalse,
      );
    });
  });

  group('ScanSession', () {
    test('bắt đầu rỗng', () {
      expect(_container().read(scanSessionProvider), isEmpty);
    });

    test('addPaths giữ thứ tự, id không trùng, bộ lọc mặc định gốc', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg', '2.jpg']);
      n.addPaths(['3.jpg']);
      expect(_paths(c), ['1.jpg', '2.jpg', '3.jpg']);
      final ids = c.read(scanSessionProvider).map((p) => p.id).toSet();
      expect(ids, hasLength(3));
      expect(
        c.read(scanSessionProvider).every(
          (p) => p.filter == ImageFilter.original,
        ),
        isTrue,
      );
    });

    test('trang thêm sau dùng bộ lọc truyền vào', () {
      final c = _container();
      c
          .read(scanSessionProvider.notifier)
          .addPaths(['1.jpg'], filter: ImageFilter.enhance);
      expect(c.read(scanSessionProvider).single.filter, ImageFilter.enhance);
    });

    test('remove xoá đúng trang theo id', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg', '2.jpg', '3.jpg']);
      final id = c.read(scanSessionProvider)[1].id;
      n.remove(id);
      expect(_paths(c), ['1.jpg', '3.jpg']);
      n.remove('khong-co'); // không lỗi
      expect(_paths(c), hasLength(2));
    });

    test('reorder đổi thứ tự', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg', '2.jpg', '3.jpg']);
      n.reorder(0, 3);
      expect(_paths(c), ['2.jpg', '3.jpg', '1.jpg']);
    });

    test('replacePath (chụp lại) giữ vị trí + id, xoá xoay, giữ bộ lọc', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg', '2.jpg']);
      final id = c.read(scanSessionProvider)[0].id;
      n.rotate(id);
      n.setFilter(id, ImageFilter.blackWhite);
      n.replacePath(id, 'new.jpg');
      final p = c.read(scanSessionProvider)[0];
      expect(p.id, id);
      expect(p.path, 'new.jpg');
      expect(p.quarterTurns, 0);
      expect(p.filter, ImageFilter.blackWhite);
      expect(_paths(c), ['new.jpg', '2.jpg']);
    });

    test('rotate xoay phải 90° từng bước', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg']);
      final id = c.read(scanSessionProvider).single.id;
      n.rotate(id);
      n.rotate(id);
      expect(c.read(scanSessionProvider).single.quarterTurns, 2);
    });

    test('setFilter một trang và setFilterAll', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg', '2.jpg']);
      n.setFilter(c.read(scanSessionProvider)[0].id, ImageFilter.grayscale);
      expect(c.read(scanSessionProvider)[0].filter, ImageFilter.grayscale);
      expect(c.read(scanSessionProvider)[1].filter, ImageFilter.original);
      n.setFilterAll(ImageFilter.magicColor);
      expect(
        c.read(scanSessionProvider).map((p) => p.filter),
        everyElement(ImageFilter.magicColor),
      );
    });

    test('clear xoá hết', () {
      final c = _container();
      final n = c.read(scanSessionProvider.notifier);
      n.addPaths(['1.jpg']);
      n.clear();
      expect(c.read(scanSessionProvider), isEmpty);
    });
  });
}
