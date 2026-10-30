import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/insert_pages.dart';

/// Viết gọn kế hoạch: `O0` = trang gốc 1, `I0` = trang chèn 1.
List<String> plan(int count, int after, int inserted) => [
  for (final r in planInsertion(
    sourcePageCount: count,
    insertAfter: after,
    insertedCount: inserted,
  ))
    r.toString(),
];

void main() {
  group('planInsertion', () {
    test('chèn đầu tài liệu', () {
      expect(plan(3, 0, 2), ['I0', 'I1', 'O0', 'O1', 'O2']);
    });

    test('chèn sau trang 1 (2 trang)', () {
      expect(plan(3, 1, 2), ['O0', 'I0', 'I1', 'O1', 'O2']);
    });

    test('chèn sau trang giữa', () {
      expect(plan(4, 2, 1), ['O0', 'O1', 'I0', 'O2', 'O3']);
    });

    test('chèn cuối tài liệu', () {
      expect(plan(3, 3, 2), ['O0', 'O1', 'O2', 'I0', 'I1']);
    });

    test('tài liệu 1 trang: đầu và cuối', () {
      expect(plan(1, 0, 1), ['I0', 'O0']);
      expect(plan(1, 1, 1), ['O0', 'I0']);
    });

    test('mọi vị trí: đủ trang, mỗi trang gốc/chèn đúng một lần, thứ tự giữ nguyên', () {
      for (var count = 1; count <= 6; count++) {
        for (var after = 0; after <= count; after++) {
          for (var n = 1; n <= 3; n++) {
            final r = planInsertion(
              sourcePageCount: count,
              insertAfter: after,
              insertedCount: n,
            );
            expect(r, hasLength(count + n));
            final originals = [for (final x in r.whereType<OriginalPage>()) x.index];
            final inserted = [for (final x in r.whereType<InsertedPage>()) x.index];
            expect(originals, List.generate(count, (i) => i));
            expect(inserted, List.generate(n, (i) => i));
            // khối chèn liền nhau, bắt đầu đúng sau `after` trang gốc
            expect(r.indexWhere((x) => x is InsertedPage), after);
            expect(r.sublist(after, after + n).every((x) => x is InsertedPage), isTrue);
          }
        }
      }
    });

    test('tham số sai', () {
      expect(() => plan(3, -1, 1), throwsRangeError);
      expect(() => plan(3, 4, 1), throwsRangeError);
      expect(() => plan(3, 1, 0), throwsArgumentError);
      expect(() => plan(0, 0, 1), throwsArgumentError);
    });
  });

  group('resolveInsertAfter / neighborPageIndex', () {
    test('đầu / sau trang N / cuối', () {
      expect(resolveInsertAfter(InsertWhere.start, 2, 5), 0);
      expect(resolveInsertAfter(InsertWhere.afterPage, 2, 5), 2);
      expect(resolveInsertAfter(InsertWhere.afterPage, 5, 5), 5);
      expect(resolveInsertAfter(InsertWhere.end, 2, 5), 5);
      expect(() => resolveInsertAfter(InsertWhere.afterPage, 0, 5), throwsRangeError);
      expect(() => resolveInsertAfter(InsertWhere.afterPage, 6, 5), throwsRangeError);
    });

    test('trang kề bên: trang trước chỗ chèn, hoặc trang đầu', () {
      expect(neighborPageIndex(0), 0);
      expect(neighborPageIndex(1), 0);
      expect(neighborPageIndex(3), 2);
    });
  });

  group('pagesFromRanges / insertedPageCount', () {
    test('tất cả trang hoặc theo khoảng, giữ thứ tự gõ', () {
      expect(pagesFromRanges(null, 3), [0, 1, 2]);
      expect(pagesFromRanges(const [PageRange(3, 4), PageRange(1, 1)], 5), [2, 3, 0]);
      expect(() => pagesFromRanges(const [PageRange(2, 6)], 5), throwsFormatException);
      expect(() => pagesFromRanges(const [], 5), throwsArgumentError);
      expect(() => pagesFromRanges(null, 0), throwsA(isA<CorruptFile>()));
    });

    test('đếm trang chèn theo loại nội dung', () {
      expect(insertedPageCount(const InsertBlank(4)), 4);
      expect(
        insertedPageCount(InsertImages([Uint8List(1), Uint8List(1)])),
        2,
      );
      expect(
        insertedPageCount(
          const InsertPdfPages('x.pdf', ranges: [PageRange(2, 3)]),
          otherPageCount: 5,
        ),
        2,
      );
      expect(insertedPageCount(const InsertPdfPages('x.pdf'), otherPageCount: 7), 7);
    });
  });

  group('khổ trang ảnh', () {
    test('A4 theo hướng ảnh', () {
      expect(a4PageForImage(100, 200), a4Portrait);
      expect(a4PageForImage(300, 200), a4Portrait.flipped);
    });

    test('ảnh vừa trang trừ lề, giữ tỉ lệ, căn giữa', () {
      const page = Size(600, 800);
      final r = fitImageRect(imageWidth: 200, imageHeight: 100, page: page, margin: 20);
      expect(r.width, closeTo(560, 0.01));
      expect(r.height, closeTo(280, 0.01));
      expect(r.left, closeTo(20, 0.01));
      expect(r.top, closeTo(260, 0.01));

      final tall = fitImageRect(imageWidth: 10, imageHeight: 1000, page: page, margin: 20);
      expect(tall.height, closeTo(760, 0.01));
      expect(tall.center.dx, closeTo(300, 0.01));
    });
  });
}
