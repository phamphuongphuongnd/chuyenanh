import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/features/editor/signature_pad_sheet.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import 'editor_test_helpers.dart';

void main() {
  Uint8List? result;
  var popped = false;

  Future<void> openSheet(WidgetTester tester) async {
    result = null;
    popped = false;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showSignaturePadSheet(context);
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('bam dung khi chua ve: bao loi, khong dong bang', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('usePad')));
    await tester.pump();
    expect(find.text('Please draw your signature first.'), findsOneWidget);
    expect(popped, isFalse);
    expect(find.byType(SfSignaturePad), findsOneWidget);
  });

  testWidgets('ve xong bam dung: tra ve PNG nen trong suot da cat sat net', (
    tester,
  ) async {
    await openSheet(tester);
    final pad = find.byType(SfSignaturePad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveBy(const Offset(12, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byKey(const Key('usePad')));
    await settle(tester, until: () => popped);

    expect(popped, isTrue);
    expect(result, isNotNull);
    final png = img.decodePng(result!)!;
    expect(png.width, greaterThan(10));
    expect(png.height, greaterThan(2));
    // Ảnh phải nhỏ hơn nhiều so với cả khung vẽ (800 x 440 px ở pixelRatio 3 → đã cắt sát nét).
    expect(png.width, lessThan(400 * 3));
    expect(png.numChannels, 4);
  });

  testWidgets('xoa net roi bam dung: lai bao chua ky', (tester) async {
    await openSheet(tester);
    final pad = find.byType(SfSignaturePad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await gesture.moveBy(const Offset(40, 10));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byKey(const Key('clearPad')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('usePad')));
    await tester.pump();
    expect(find.text('Please draw your signature first.'), findsOneWidget);
    expect(popped, isFalse);
  });
}
