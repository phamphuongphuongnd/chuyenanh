import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';

import 'fakes.dart';

const _paths = ['/a.jpg', '/b.jpg', '/c.jpg'];

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('img2pdf_edit'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Harness> open(
    WidgetTester tester, {
    FakeProcessor? processor,
    FakeCrop? crop,
    FakeEngine? engine,
    List<String> paths = _paths,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = Harness(
      tmp: tmp,
      processor: processor,
      crop: crop,
      engine: engine,
    );
    await h.pump(tester, extra: paths);
    return h;
  }

  /// Vị trí ngang của ô ảnh trong dải thu nhỏ.
  double tileX(WidgetTester tester, int id) =>
      tester.getTopLeft(find.byKey(ValueKey('tile_$id'))).dx;

  testWidgets('mở với danh sách ảnh: hiện ảnh đầu, dải thu nhỏ đủ ảnh', (tester) async {
    final h = await open(tester);
    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    for (final id in [0, 1, 2]) {
      expect(find.byKey(ValueKey('tile_$id')), findsOneWidget);
    }
    expect(find.text('CREATE PDF (3)'), findsOneWidget);
    // ảnh xem trước lớn dùng đường dẫn ảnh đầu
    expect(h.processor.previews.any((e) => e.$1 == '/a.jpg' && e.$3 == 1400), isTrue);
  });

  testWidgets('ảnh hỏng bị bỏ qua và báo số ảnh bỏ', (tester) async {
    await open(tester, processor: FakeProcessor(badPaths: {'/b.jpg'}));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('1 image(s) could not be read and were skipped.'), findsOneWidget);
  });

  testWidgets('tất cả ảnh hỏng → thoát về trang trước', (tester) async {
    await open(
      tester,
      processor: FakeProcessor(badPaths: {'/a.jpg'}),
      paths: ['/a.jpg'],
    );
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('chọn ô trong dải để xem ảnh khác', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('tile_2')));
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('xoay áp cho ảnh đang xem (yêu cầu xem trước mới có xoay 1 lượt)', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(find.byKey(const ValueKey('tool_rotate')));
    await tester.pumpAndSettle();
    expect(
      h.processor.previews.any((e) => e.$1 == '/a.jpg' && e.$2.quarterTurns == 1),
      isTrue,
    );
    expect(
      h.processor.previews.any((e) => e.$1 == '/b.jpg' && e.$2.quarterTurns != 0),
      isFalse,
    );
  });

  testWidgets('bộ lọc chọn từ bảng', (tester) async {
    final h = await open(tester);
    await tester.tap(find.byKey(const ValueKey('tool_filter')));
    await tester.pumpAndSettle();
    expect(find.text('Magic color'), findsOneWidget);
    await tester.tap(find.text('Black & white'));
    await tester.pumpAndSettle();
    expect(
      h.processor.previews.any(
        (e) => e.$1 == '/a.jpg' && e.$2.filter == ops.ImageFilter.blackWhite,
      ),
      isTrue,
    );
  });

  testWidgets('Đặt lại chỉ bật sau khi có chỉnh sửa', (tester) async {
    await open(tester);
    InkWell reset() => tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('tool_reset')),
        matching: find.byType(InkWell),
      ),
    );
    expect(reset().onTap, isNull);
    await tester.tap(find.byKey(const ValueKey('tool_rotate')));
    await tester.pump();
    expect(reset().onTap, isNotNull);
    await tester.tap(find.byKey(const ValueKey('tool_reset')));
    await tester.pump();
    expect(reset().onTap, isNull);
  });

  testWidgets('xoá ảnh có thể hoàn tác', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('tool_delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // snackbar trượt lên
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_0')), findsNothing);
    expect(find.text('Image removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile_0')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('xoá hết ảnh → thoát', (tester) async {
    await open(tester, paths: ['/a.jpg']);
    await tester.tap(find.byKey(const ValueKey('tool_delete')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('kéo thả (nhấn giữ) đổi thứ tự trong dải', (tester) async {
    await open(tester);
    expect(tileX(tester, 0), lessThan(tileX(tester, 1)));

    final start = tester.getCenter(find.byKey(const ValueKey('tile_0')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700)); // nhấn giữ
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tileX(tester, 0), greaterThan(tileX(tester, 1)));
    // ảnh đang xem là ảnh số 0, nay ở vị trí thứ 2 hoặc 3
    expect(find.text('1 / 3'), findsNothing);
  });

  group('cắt', () {
    testWidgets('cắt xong: nguồn mới là file đã cắt', (tester) async {
      final crop = FakeCrop()..result = '/cropped.jpg';
      final h = await open(tester, crop: crop);
      await tester.tap(find.byKey(const ValueKey('tool_rotate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tool_crop')));
      await tester.pumpAndSettle();

      // nướng phép xoay vào file nguồn trước khi cắt
      expect(h.processor.bakes.single.$1, '/a.jpg');
      expect(h.processor.bakes.single.$2.quarterTurns, 1);
      expect(crop.sources, hasLength(1));
      expect(
        h.processor.previews.any(
          (e) => e.$1 == '/cropped.jpg' && e.$2.quarterTurns == 0,
        ),
        isTrue,
      );
    });

    testWidgets('huỷ màn cắt → ảnh giữ nguyên', (tester) async {
      final crop = FakeCrop(); // result = null
      final h = await open(tester, crop: crop);
      await tester.tap(find.byKey(const ValueKey('tool_crop')));
      await tester.pumpAndSettle();
      expect(
        h.processor.previews.where((e) => e.$1 == '/cropped.jpg'),
        isEmpty,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('thêm ảnh từ màn chọn ảnh', (tester) async {
    final h = await open(tester);
    await tester.tap(find.byKey(const ValueKey('add_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('asset_all_0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset_all_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset_all_5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit images'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget, reason: 'ảnh mới thêm đầu tiên được chọn xem');
    expect(find.text('CREATE PDF (5)'), findsOneWidget);
    expect(h.gallery.resolved, ['all_0', 'all_5']);
  });

  group('thoát', () {
    testWidgets('nút Back hỏi xác nhận; chọn No thì ở lại', (tester) async {
      await open(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('NO'));
      await tester.pumpAndSettle();
      expect(find.text('Edit images'), findsOneWidget);
    });

    testWidgets('chọn Yes thì thoát', (tester) async {
      await open(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('xuất PDF', () {
    Future<void> openOptions(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('create_button')));
      await tester.pumpAndSettle();
    }

    /// Xen kẽ vòng lặp sự kiện thật (file, SQLite) và bơm khung hình (timer giả)
    /// cho tới khi hộp thoại tiến độ đóng.
    Future<void> settleReal(WidgetTester tester) async {
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
    }

    testWidgets('bảng tuỳ chọn: giá trị mặc định, hướng bị khoá khi Vừa ảnh', (
      tester,
    ) async {
      await open(tester);
      await openOptions(tester);
      expect(find.text('PDF options'), findsOneWidget);
      expect(find.textContaining('Estimated size:'), findsOneWidget);
      expect(find.textContaining('3 page(s)'), findsOneWidget);
      expect(find.text('Quality: 85%'), findsOneWidget);

      ChoiceChip chip(String label) => tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, label),
      );
      expect(chip('A4').selected, isTrue);
      expect(chip('Portrait').onSelected, isNotNull);
      await tester.tap(find.text('Fit image'));
      await tester.pump();
      expect(chip('Portrait').onSelected, isNull);
    });

    testWidgets('Tạo PDF: engine nhận đúng ảnh, tuỳ chọn, rồi hiện màn kết quả', (
      tester,
    ) async {
      final engine = FakeEngine();
      final h = await open(tester, engine: engine);
      await openOptions(tester);

      await tester.tap(find.text('Letter'));
      await tester.tap(find.text('Landscape'));
      await tester.tap(find.text('Large'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hop dong.pdf');
      await tester.tap(find.text('CREATE PDF').last);
      await tester.pump();
      await settleReal(tester);

      expect(engine.imagePaths, _paths);
      expect(engine.options!.pageSize, PageSizeOption.letter);
      expect(engine.options!.orientation, PageOrientation.landscape);
      expect(engine.options!.margin, PageMargin.large);
      expect(engine.options!.jpegQuality, 85);
      expect(File(p.join(tmp.path, 'Hop dong.pdf')).existsSync(), isTrue);

      expect(find.text('PDF created'), findsOneWidget);
      expect(find.byKey(const ValueKey('result_name')), findsOneWidget);
      expect(find.text('Hop dong.pdf'), findsOneWidget);
      expect(find.text('3 page(s) • 2.00 KB'), findsOneWidget);

      // đã thêm vào DB cho Trang chủ / Gần đây
      final doc = await tester.runAsync(
        () => h.db.documentsDao.getByPath(p.join(tmp.path, 'Hop dong.pdf')),
      );
      expect(doc, isNotNull);
    });

    testWidgets('ảnh đã chỉnh sửa được áp trước khi đưa cho engine', (tester) async {
      final engine = FakeEngine();
      final h = await open(tester, engine: engine);
      await tester.tap(find.byKey(const ValueKey('tool_rotate')));
      await tester.pump();
      await openOptions(tester);
      await tester.tap(find.text('CREATE PDF').last);
      await tester.pump();
      await settleReal(tester);

      expect(h.processor.bakes, hasLength(1));
      expect(h.processor.bakes.single.$1, '/a.jpg');
      expect(engine.imagePaths!.first, endsWith('p0.jpg'));
      expect(engine.imagePaths!.sublist(1), ['/b.jpg', '/c.jpg']);
    });

    testWidgets('lỗi hết dung lượng → hộp thoại báo lý do, ở lại màn sửa', (
      tester,
    ) async {
      final engine = FakeEngine()..error = const NoSpace();
      await open(tester, engine: engine);
      await openOptions(tester);
      await tester.tap(find.text('CREATE PDF').last);
      await tester.pump();
      await settleReal(tester);

      expect(find.text("Couldn't create the PDF"), findsOneWidget);
      expect(find.text('Not enough storage space.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Edit images'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
