import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_routes.dart';
import 'package:pdf_office/features/pdf_tools/engine/syncfusion_pdf_tools.dart';
import 'package:pdf_office/features/pdf_tools/ui/create_blank_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/lock_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/merge_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/organize_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:pdf_office/features/pdf_tools/ui/split_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/unlock_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/watermark_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_test_harness.dart';

Future<void> _openRoute(
  WidgetTester tester,
  String location, {
  Object? extra,
  required FakeToolsEngine engine,
  required FakePicker picker,
  required Directory dir,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final router = GoRouter(
    initialLocation: location,
    initialExtra: extra,
    routes: pdfToolsRoutes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        outputDirectoryProvider.overrideWith((ref) async => dir.path),
        pdfToolsEngineProvider.overrideWithValue(engine),
        pdfFilePickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('tools_routes'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('provider trỏ tới engine Syncfusion thật', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(pdfToolsEngineProvider), isA<SyncfusionPdfTools>());
  });

  final screens = <String, Type>{
    Routes.merge: MergeScreen,
    Routes.split: SplitScreen,
    Routes.organize: OrganizeScreen,
    Routes.lock: LockScreen,
    Routes.unlock: UnlockScreen,
    Routes.watermark: WatermarkScreen,
    Routes.createBlank: CreateBlankScreen,
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} dựng đúng màn, không extra → tự mở hộp chọn file', (tester) async {
      final picker = FakePicker();
      await _openRoute(
        tester,
        entry.key,
        engine: FakeToolsEngine(),
        picker: picker,
        dir: tmp,
      );
      await settle(tester, rounds: 2);
      expect(find.byType(entry.value), findsOneWidget);
      // createBlank không cần file
      expect(picker.pdfCalls, entry.key == Routes.createBlank ? 0 : 1);
    });
  }

  testWidgets('extra là path → nạp thẳng file, không mở hộp chọn', (tester) async {
    final picker = FakePicker();
    await _openRoute(
      tester,
      Routes.split,
      extra: '/x/doc.pdf',
      engine: FakeToolsEngine(pageCounts: {'/x/doc.pdf': 4}),
      picker: picker,
      dir: tmp,
    );
    await settle(tester);
    expect(picker.pdfCalls, 0);
    expect(find.text('doc.pdf'), findsOneWidget);
    expect(find.text('4 pages'), findsOneWidget);
  });

  testWidgets('extra sai kiểu bị bỏ qua (coi như null)', (tester) async {
    final picker = FakePicker();
    await _openRoute(
      tester,
      Routes.merge,
      extra: 42,
      engine: FakeToolsEngine(),
      picker: picker,
      dir: tmp,
    );
    await settle(tester, rounds: 2);
    expect(picker.pdfCalls, 1);
  });
}
