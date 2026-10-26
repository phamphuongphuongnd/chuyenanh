import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/image_to_pdf/image_to_pdf_paths.dart';
import 'package:pdf_office/features/image_to_pdf/services/export_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/output_registry.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;
  late String pdfPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('img2pdf_result');
    pdfPath = p.join(tmp.path, 'Scan.pdf');
    File(pdfPath).writeAsBytesSync(List.filled(3000, 1));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Harness> open(WidgetTester tester, {int skipped = 0}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = Harness(tmp: tmp);
    await h.pump(
      tester,
      initialLocation: img2pdfResultPath,
      extra: ExportOutcome(
        outputPath: pdfPath,
        pageCount: 4,
        sizeBytes: 3000,
        skippedCount: skipped,
      ),
    );
    return h;
  }

  testWidgets('hiện tên file, số trang, dung lượng, thư mục và 3 nút', (tester) async {
    await open(tester);
    expect(find.text('PDF created'), findsOneWidget);
    expect(find.text('Scan.pdf'), findsOneWidget);
    expect(find.text('4 page(s) • 2.93 KB'), findsOneWidget);
    expect(find.text('Saved in "${p.basename(tmp.path)}"'), findsOneWidget);
    expect(find.byKey(const ValueKey('open_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('share_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('rename_button')), findsOneWidget);
    expect(find.textContaining('could not be read'), findsNothing);
  });

  testWidgets('báo số ảnh hỏng đã bị bỏ qua', (tester) async {
    await open(tester, skipped: 2);
    expect(find.text('2 image(s) could not be read and were skipped.'), findsOneWidget);
  });

  testWidgets('nút Xong về trang chủ', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('done_button')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('nút đóng (X) về trang chủ', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('nút Back của hệ thống cũng về trang chủ', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('đổi tên: file thật và DB đều đổi, màn kết quả cập nhật', (tester) async {
    final h = await open(tester);
    await tester.runAsync(() => registerOutputDocument(h.db, pdfPath));

    await tester.tap(find.byKey(const ValueKey('rename_button')));
    await tester.pumpAndSettle();
    expect(find.text('Rename file'), findsOneWidget);
    // ô nhập có sẵn tên cũ không đuôi
    expect(find.widgetWithText(TextField, 'Scan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Invoice');
    await tester.tap(find.text('OK'));
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Invoice.pdf').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();

    final newPath = p.join(tmp.path, 'Invoice.pdf');
    expect(find.text('Invoice.pdf'), findsOneWidget);
    expect(File(newPath).existsSync(), isTrue);
    expect(File(pdfPath).existsSync(), isFalse);
    final doc = await tester.runAsync(() => h.db.documentsDao.getByPath(newPath));
    expect(doc?.name, 'Invoice.pdf');
  });

  testWidgets('thiếu extra → quay về màn chọn ảnh thay vì lỗi', (tester) async {
    final h = Harness(tmp: tmp);
    await h.pump(tester, initialLocation: img2pdfResultPath);
    expect(find.text('Select images'), findsNothing); // album có tên 'Recent'
    expect(find.text('Recent'), findsOneWidget);
  });
}
