import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/editor/editor_providers.dart';
import 'package:pdf_office/features/editor/sign_screen.dart';
import 'package:pdf_office/features/editor/signature_store.dart';
import 'package:pdf_office/features/reader/reader_providers.dart';

import 'editor_test_helpers.dart';

void main() {
  late Directory outDir;
  late Directory storeDir;
  late SignatureStore store;
  late FakeRenderEngine render;
  late FakeSignEngine sign;

  setUp(() {
    outDir = Directory.systemTemp.createTempSync('sign_out_');
    storeDir = Directory.systemTemp.createTempSync('sign_store_');
    store = SignatureStore(storeDir);
    render = FakeRenderEngine();
    sign = FakeSignEngine();
  });
  tearDown(() {
    outDir.deleteSync(recursive: true);
    storeDir.deleteSync(recursive: true);
  });

  List<Override> overrides({
    PdfRenderEngine? renderEngine,
    SignaturePhotoPicker? photoPicker,
  }) => [
    outputDirectoryProvider.overrideWith((ref) async => outDir.path),
    signatureStoreProvider.overrideWith((ref) async => store),
    pdfRenderEngineProvider.overrideWithValue(renderEngine ?? render),
    pdfSignEngineProvider.overrideWithValue(sign),
    if (photoPicker != null)
      signaturePhotoPickerProvider.overrideWithValue(photoPicker),
  ];

  Future<void> open(
    WidgetTester tester, {
    SignaturePhotoPicker? photoPicker,
  }) async {
    await pumpEditorScreen(
      tester,
      screen: const SignScreen(path: '/x/Hop dong.pdf'),
      overrides: overrides(photoPicker: photoPicker),
    );
    await settle(
      tester,
      until: () => find.textContaining('Page 1').evaluate().isNotEmpty,
    );
  }

  /// Lưu sẵn một chữ ký vào kho giả; trả về tên file.
  Future<String> seedSignature(WidgetTester tester) async {
    final saved = await tester.runAsync(
      () => store.save(testPng(w: 80, h: 30, r: 10, g: 10, b: 120)),
    );
    return saved!.fileName;
  }

  testWidgets('mo xong: hien trang 1/2, goi y, o chu ky moi', (tester) async {
    await open(tester);
    expect(find.text('Hop dong.pdf'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('newSignature')), findsOneWidget);
    await settle(
      tester,
      until: () =>
          find.textContaining('No saved signatures yet').evaluate().isNotEmpty,
    );
    expect(find.textContaining('No saved signatures yet'), findsOneWidget);
  });

  testWidgets('o nhap chu ky tu anh hien canh o chu ky moi', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('importSignature')), findsOneWidget);
    expect(find.text('From photo'), findsOneWidget);
    expect(find.byIcon(Symbols.add_photo_alternate_rounded), findsOneWidget);
  });

  testWidgets('nhap tu anh: xem truoc, dung chu ky -> luu kho va dat len trang', (
    tester,
  ) async {
    final picker = _FakePhotoPicker(_paperPhoto(stroke: true));
    await open(tester, photoPicker: picker);

    await tester.tap(find.byKey(const Key('importSignature')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('importFromCamera')), findsOneWidget);
    await tester.tap(find.byKey(const Key('importFromGallery')));
    await settle(
      tester,
      until: () => find.byKey(const Key('useImported')).evaluate().isNotEmpty,
    );
    expect(picker.sources, [SignaturePhotoSource.gallery]);
    expect(find.byKey(const Key('importPreview')), findsOneWidget);
    expect(find.byKey(const Key('importThreshold')), findsOneWidget);

    await tester.tap(find.byKey(const Key('useImported')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('placed_1')), findsOneWidget);
    final saved = await tester.runAsync(store.list);
    expect(saved, hasLength(1));
  });

  testWidgets('nhap tu anh trang tinh -> bao khong tach duoc net', (
    tester,
  ) async {
    await open(tester, photoPicker: _FakePhotoPicker(_paperPhoto()));
    await tester.tap(find.byKey(const Key('importSignature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importFromGallery')));
    await settle(
      tester,
      until: () => find
          .textContaining('No signature strokes found')
          .evaluate()
          .isNotEmpty,
    );
    expect(find.textContaining('No signature strokes found'), findsOneWidget);
    expect(find.byKey(const Key('useImported')), findsNothing);
    expect(find.byKey(const Key('placed_1')), findsNothing);
  });

  testWidgets('chon chu ky da luu: dat giua trang, ky va luu dung toa do', (
    tester,
  ) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('placed_1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('apply')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    expect(sign.placements, hasLength(1));
    final p = sign.placements!.single;
    expect(p.pageIndex, 0);
    // Trang giả 600x800; chữ ký ở giữa trang, rộng 32% → 192pt.
    expect(p.bounds.center.dx, closeTo(300, 1));
    expect(p.bounds.center.dy, closeTo(400, 1));
    expect(p.bounds.width, closeTo(192, 1));
    // Tỷ lệ ảnh 80:30 được giữ.
    expect(p.bounds.width / p.bounds.height, closeTo(80 / 30, 0.01));
    expect(sign.outputPath, endsWith('Hop dong_signed.pdf'));
    expect(File(sign.outputPath!).existsSync(), isTrue);
    expect(sign.password, isNull);
  });

  testWidgets('keo chu ky sang phai thi toa do PDF tang', (tester) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );

    await tester.drag(find.byKey(const Key('placed_1')), const Offset(60, 0));
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    expect(sign.placements!.single.bounds.center.dx, greaterThan(310));
    expect(sign.placements!.single.bounds.center.dy, closeTo(400, 1));
  });

  testWidgets('keo tay cam goc: doi co, giu ti le anh', (tester) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('resize_1')).evaluate().isNotEmpty,
    );

    await tester.drag(find.byKey(const Key('resize_1')), const Offset(40, 20));
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    final b = sign.placements!.single.bounds;
    expect(b.width, greaterThan(192 + 10));
    expect(b.width / b.height, closeTo(80 / 30, 0.01));
  });

  testWidgets('doi trang: chu ky chi hien o trang da dat; ky nhieu trang', (
    tester,
  ) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('nextPage')));
    await settle(
      tester,
      until: () => find.text('Page 2 of 2').evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('placed_1')), findsNothing);

    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_2')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('apply')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);
    expect(sign.placements!.map((e) => e.pageIndex), [0, 1]);
  });

  testWidgets('go chu ky bang nut x truoc khi luu', (tester) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('remove_1')));
    await tester.pump();
    expect(find.byKey(const Key('placed_1')), findsNothing);

    // Chưa có chữ ký nào → báo, không gọi engine.
    await tester.tap(find.byKey(const Key('apply')));
    await tester.pump();
    expect(find.text('Add at least one signature to the page first.'),
        findsAtLeastNWidgets(1));
    expect(sign.placements, isNull);
  });

  testWidgets('xoa chu ky da luu: hoi xac nhan roi xoa file', (tester) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('delete_$name')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this signature?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isEmpty,
    );
    expect(find.byKey(Key('saved_$name')), findsNothing);
    expect(storeDir.listSync(), isEmpty);
  });

  testWidgets('thoat khi da dat chu ky chua luu: hoi xac nhan', (tester) async {
    final name = await seedSignature(tester);
    await open(tester);
    await settle(
      tester,
      until: () => find.byKey(Key('saved_$name')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(Key('saved_$name')));
    await settle(
      tester,
      until: () => find.byKey(const Key('placed_1')).evaluate().isNotEmpty,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('PDF co mat khau: hoi mat khau, sai thi hoi lai, dung thi mo', (
    tester,
  ) async {
    render = FakeRenderEngine(requiredPassword: 'abc');
    await pumpEditorScreen(
      tester,
      screen: const SignScreen(path: '/x/Mat.pdf'),
      overrides: overrides(),
    );
    await settle(tester, until: () => find.text('Password').evaluate().isNotEmpty);
    expect(find.text('Password'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'sai');
    await tester.tap(find.text('OK'));
    await settle(
      tester,
      until: () => find.text('Incorrect password.').evaluate().isNotEmpty,
    );
    expect(find.text('Incorrect password.'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('OK'));
    await settle(
      tester,
      until: () => find.textContaining('Page 1').evaluate().isNotEmpty,
    );
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(render.triedPasswords, [null, 'sai', 'abc']);
  });

  testWidgets('khong mo duoc PDF -> man loi co nut thu lai', (tester) async {
    await pumpEditorScreen(
      tester,
      screen: const SignScreen(path: '/x/Hong.pdf'),
      overrides: overrides(renderEngine: _BrokenRenderEngine()),
    );
    await settle(
      tester,
      until: () => find.text('Retry').evaluate().isNotEmpty,
    );
    expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
    expect(
      find.text('The file is damaged or cannot be read.'),
      findsOneWidget,
    );
  });
}

/// Ảnh "chụp" giấy trắng 240x120; [stroke] = có một nét đen đặc ở giữa.
Uint8List _paperPhoto({bool stroke = false}) {
  final image = img.Image(width: 240, height: 120);
  img.fill(image, color: img.ColorRgb8(252, 252, 250));
  if (stroke) {
    img.fillRect(
      image,
      x1: 40,
      y1: 50,
      x2: 199,
      y2: 69,
      color: img.ColorRgb8(15, 15, 20),
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

class _FakePhotoPicker implements SignaturePhotoPicker {
  _FakePhotoPicker(this.bytes);

  final Uint8List bytes;
  final List<SignaturePhotoSource> sources = [];

  @override
  Future<Uint8List?> pick(SignaturePhotoSource source) async {
    sources.add(source);
    return bytes;
  }
}

class _BrokenRenderEngine extends FakeRenderEngine {
  @override
  Future<PdfRenderDocument> openFile(
    String path, {
    String? password,
  }) async => throw const CorruptFile('x');
}
