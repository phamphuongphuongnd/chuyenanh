import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/ui/lock_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/organize_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/unlock_screen.dart';

import 'tool_test_harness.dart';

Finder page(int uid) => find.byKey(ValueKey('page-$uid'));

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tools_widget2');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('OrganizeScreen', () {
    testWidgets('chọn, xoay, dời, lưu → organize với PageOp đúng', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 4});
      await pumpTool(
        tester,
        const OrganizeScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);

      // chưa chọn gì: các nút thao tác bị khoá
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Symbols.rotate_right_rounded)).onPressed,
        isNull,
      );

      await tester.tap(page(1));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.rotate_right_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.arrow_forward_rounded)); // trang 2 ra sau trang 3
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(engine.organizes, hasLength(1));
      final ops = engine.organizes.single['ops']! as List<PageOp>;
      expect([for (final o in ops) o.sourceIndex], [0, 2, 1, 3]);
      expect([for (final o in ops) o.rotation], [0, 0, 90, 0]);
      expect(
        (engine.organizes.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/doc_organized.pdf'),
      );
      expect(find.text('All done!'), findsOneWidget);
    });

    testWidgets('xoá trang, không cho xoá hết, trích trang đã chọn', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 3});
      await pumpTool(
        tester,
        const OrganizeScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);

      // chưa sửa gì → Save báo không có thay đổi
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(find.text('No changes to save.'), findsOneWidget);
      expect(engine.organizes, isEmpty);

      // chọn tất cả rồi xoá → từ chối
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.delete_rounded));
      await tester.pump();
      expect(find.text('Keep at least one page.'), findsOneWidget);
      expect(page(0), findsOneWidget);

      // chọn lại: chỉ trang 2 → xoá
      await tester.tap(find.text('Clear selection'));
      await tester.pump();
      await tester.tap(page(1));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.delete_rounded));
      await tester.pump();
      expect(page(1), findsNothing);

      // trích trang 3 (đang chọn không còn → nhắc chọn)
      await tester.tap(find.byTooltip('Extract'));
      await tester.pump();
      // nút khoá vì chưa chọn → không gọi engine
      expect(engine.organizes, isEmpty);

      await tester.tap(page(2));
      await tester.pump();
      await tester.tap(find.byTooltip('Extract'));
      await settle(tester);
      expect(engine.organizes, hasLength(1));
      final ops = engine.organizes.single['ops']! as List<PageOp>;
      expect([for (final o in ops) o.sourceIndex], [2]);
      expect(
        (engine.organizes.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/doc_extract.pdf'),
      );
    });

    testWidgets('có engine render: hiện ảnh thu nhỏ và đóng tài liệu khi rời màn', (tester) async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 10)..clear(img.ColorRgb8(255, 0, 0))),
      );
      final render = FakeRender(png);
      await pumpTool(
        tester,
        const OrganizeScreen(path: '/x/doc.pdf'),
        engine: FakeToolsEngine(pageCounts: {'/x/doc.pdf': 3}),
        picker: FakePicker(),
        render: render,
        outDir: tmp,
      );
      await settle(tester);
      expect(render.opened, 1);
      expect(find.byType(Image), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      expect(render.closed, 1);
    });
  });

  group('LockScreen', () {
    testWidgets('mật khẩu trống / không khớp bị chặn, đúng thì ghi file _locked', (tester) async {
      final src = File(p.join(tmp.path, 'doc.pdf'));
      src.writeAsBytesSync([1, 2, 3]);
      final out = Directory(p.join(tmp.path, 'out'))..createSync();
      final engine = FakeToolsEngine(pageCounts: {src.path: 2});
      final security = FakeSecurity();
      await pumpTool(
        tester,
        LockScreen(path: src.path),
        engine: engine,
        picker: FakePicker(),
        security: security,
        outDir: out,
      );
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Lock'));
      await tester.pump();
      expect(find.text('Enter a password.'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'abc');
      await tester.enterText(fields.at(1), 'abd');
      await tester.tap(find.widgetWithText(FilledButton, 'Lock'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(security.encryptCalls, isEmpty);

      await tester.enterText(fields.at(1), 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Lock'));
      await settleUntilFound(tester, find.text('All done!'));

      expect(security.encryptCalls, ['abc']);
      final written = File(p.join(out.path, 'doc_locked.pdf'));
      expect(written.existsSync(), isTrue);
      expect(String.fromCharCodes(written.readAsBytesSync()), startsWith('LOCKED:'));
      expect(File(src.path).readAsBytesSync(), [1, 2, 3]); // file gốc không đổi
      expect(find.text('All done!'), findsOneWidget);
    });

    testWidgets('file đã có mật khẩu: nhập mật khẩu cũ, gỡ rồi đặt mật khẩu mới', (tester) async {
      final src = File(p.join(tmp.path, 'doc.pdf'));
      src.writeAsBytesSync([7]);
      final out = Directory(p.join(tmp.path, 'out'))..createSync();
      final engine = FakeToolsEngine(
        pageCounts: {src.path: 1},
        passwords: {src.path: 'secret'},
      );
      await pumpTool(
        tester,
        LockScreen(path: src.path),
        engine: engine,
        picker: FakePicker(),
        security: FakeSecurity(),
        outDir: out,
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new');
      await tester.enterText(fields.at(1), 'new');
      await tester.tap(find.widgetWithText(FilledButton, 'Lock'));
      await settleUntilFound(tester, find.text('All done!'));
      final data = String.fromCharCodes(
        File(p.join(out.path, 'doc_locked.pdf')).readAsBytesSync(),
      );
      expect(data, 'LOCKED:PLAIN:\u0007'); // đã gỡ mật khẩu cũ trước khi khoá lại
    });
  });

  group('UnlockScreen', () {
    testWidgets('file không khoá: báo không có mật khẩu', (tester) async {
      final src = File(p.join(tmp.path, 'doc.pdf'))..writeAsBytesSync([1]);
      await pumpTool(
        tester,
        UnlockScreen(path: src.path),
        security: FakeSecurity(encrypted: false),
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);
      expect(find.text('This file is not password protected.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Unlock'), findsNothing);
    });

    testWidgets('sai mật khẩu báo ngay dưới ô nhập; đúng thì ghi _unlocked', (tester) async {
      final src = File(p.join(tmp.path, 'doc.pdf'))..writeAsBytesSync([9]);
      final out = Directory(p.join(tmp.path, 'out'))..createSync();
      await pumpTool(
        tester,
        UnlockScreen(path: src.path),
        security: FakeSecurity(encrypted: true, password: 'secret'),
        picker: FakePicker(),
        outDir: out,
      );
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pump();
      expect(find.text('Enter a password.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect password.'), findsWidgets);
      expect(File(p.join(out.path, 'doc_unlocked.pdf')).existsSync(), isFalse);

      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await settleUntilFound(tester, find.text('All done!'));
      expect(File(p.join(out.path, 'doc_unlocked.pdf')).existsSync(), isTrue);
      expect(find.text('All done!'), findsOneWidget);
    });
  });
}
