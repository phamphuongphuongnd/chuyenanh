import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_security.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_pick_screen.dart';

import 'tool_test_harness.dart';

void main() {
  late Directory dir;
  late List<DocItem> items;
  late String plainPath;
  late String lockedPath;
  late String docxPath;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('pdf_pick_test');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    plainPath = '${dir.path}${Platform.pathSeparator}plain.pdf';
    lockedPath = '${dir.path}${Platform.pathSeparator}secret.pdf';
    docxPath = '${dir.path}${Platform.pathSeparator}report.docx';
    File(plainPath).writeAsStringSync('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF');
    File(lockedPath).writeAsStringSync(
      '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<< /Encrypt 5 0 R >>\n%%EOF',
    );
    File(docxPath).writeAsStringSync('not really a docx');

    // Stream cố định thay cho drift: tránh timer treo sau khi cây widget huỷ.
    items = [
      for (final path in [plainPath, lockedPath, docxPath])
        DocItem.fromFileSync(path)!,
    ];
  });

  /// Host có nút mở [PdfPickScreen]; kết quả `pop` được ghi vào [result].
  Future<void> openPicker(
    WidgetTester tester,
    PdfPickMode mode,
    List<String?> result, {
    bool encrypted = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) => Stream.value(items)),
          pdfSecurityProvider.overrideWithValue(
            FakeSecurity(encrypted: encrypted),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final r = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => PdfPickScreen(mode: mode),
                      ),
                    );
                    result.add(r);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('unlockedOnly: chỉ PDF thường, không docx, không PDF khoá', (
    tester,
  ) async {
    await openPicker(tester, PdfPickMode.unlockedOnly, []);
    await settleUntilFound(tester, find.text('plain.pdf'));
    await settle(tester);

    expect(find.text('plain.pdf'), findsOneWidget);
    expect(find.text('secret.pdf'), findsNothing);
    expect(find.text('report.docx'), findsNothing);
  });

  testWidgets('lockedOnly: chỉ PDF có /Encrypt (engine xác nhận), không docx', (
    tester,
  ) async {
    await openPicker(tester, PdfPickMode.lockedOnly, []);
    await settleUntilFound(tester, find.text('secret.pdf'));
    await settle(tester);

    expect(find.text('secret.pdf'), findsOneWidget);
    expect(find.text('plain.pdf'), findsNothing);
    expect(find.text('report.docx'), findsNothing);
  });

  testWidgets('có dấu /Encrypt nhưng engine nói chưa khoá → là PDF thường', (
    tester,
  ) async {
    await openPicker(tester, PdfPickMode.unlockedOnly, [], encrypted: false);
    await settleUntilFound(tester, find.text('secret.pdf'));
    await settle(tester);

    expect(find.text('plain.pdf'), findsOneWidget);
    expect(find.text('secret.pdf'), findsOneWidget);
    expect(find.text('report.docx'), findsNothing);
  });

  testWidgets('chạm vào dòng thì pop trả về path', (tester) async {
    final result = <String?>[];
    await openPicker(tester, PdfPickMode.unlockedOnly, result);
    await settleUntilFound(tester, find.text('plain.pdf'));
    await settle(tester);

    await tester.tap(find.text('plain.pdf'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(result, [plainPath]);
    expect(find.byType(PdfPickScreen), findsNothing);
  });

  testWidgets('ô tìm kiếm lọc theo tên', (tester) async {
    await openPicker(tester, PdfPickMode.unlockedOnly, [], encrypted: false);
    await settleUntilFound(tester, find.text('secret.pdf'));
    await settle(tester);
    expect(find.text('plain.pdf'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sec');
    await tester.pump();
    expect(find.text('secret.pdf'), findsOneWidget);
    expect(find.text('plain.pdf'), findsNothing);
  });
}
