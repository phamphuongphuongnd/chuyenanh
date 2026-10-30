import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/convert/convert_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, ConvertMode mode) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConvertScreen(mode: mode),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // iPhone ~390pt rong: o chon ngon ngu OCR (chu dai) khong duoc ep nhan thanh cot doc tung chu.
  testWidgets('PDF to Word: nhan ngon ngu OCR du rong tren man hinh dien thoai', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, ConvertMode.pdfToWord);
    final label = find.text('Text language for scanned pages');
    expect(label, findsOneWidget);
    final size = tester.getSize(label);
    expect(size.width, greaterThan(150), reason: 'nhan bi ep hep: ${size.width}x${size.height}');
    expect(size.height, lessThan(60), reason: 'nhan bi xep doc: ${size.width}x${size.height}');
  });

  testWidgets('PDF → Word hiện cảnh báo không giữ bố cục, không có tuỳ chọn khổ giấy', (tester) async {
    await _pump(tester, ConvertMode.pdfToWord);
    expect(find.textContaining('not preserved'), findsOneWidget);
    expect(find.text('Page size'), findsNothing);
    expect(find.text('Choose a file'), findsOneWidget);
  });

  testWidgets('Văn bản → PDF có ô nhập và tuỳ chọn, không có cảnh báo', (tester) async {
    await _pump(tester, ConvertMode.textToPdf);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Page size'), findsOneWidget);
    expect(find.text('Font size'), findsOneWidget);
    expect(find.textContaining('not preserved'), findsNothing);
  });

  testWidgets('Văn bản rỗng → báo nhập văn bản', (tester) async {
    await _pump(tester, ConvertMode.textToPdf);
    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, 'Convert'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
    await tester.pump();
    expect(find.text('Enter some text first.'), findsOneWidget);
  });

  testWidgets('Nút Chuyển đổi chữ thường đầu câu, cao 52, giãn hết bề ngang', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, ConvertMode.wordToPdf);
    final button = find.widgetWithText(FilledButton, 'Convert');
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('CONVERT'), findsNothing);
    final size = tester.getSize(button);
    expect(size.height, 52);
    expect(size.width, 390 - 32);
  });

  testWidgets('Word → PDF không có ô nhập chữ, có chọn hướng giấy', (tester) async {
    await _pump(tester, ConvertMode.wordToPdf);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Orientation'), findsOneWidget);
    expect(find.text('Font size'), findsNothing);
  });
}
