import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedScan extends ScanController {
  _FixedScan(this.fixed);
  final ScanState fixed;

  @override
  ScanState build() => fixed;
}

DocItem _doc(String name, {int size = 1000}) => DocItem(
  path: '/storage/$name',
  name: name,
  ext: name.split('.').last,
  size: size,
  modified: DateTime(2026, 1, 2, 3, 4),
  folder: 'Download',
);

Future<void> _pump(
  WidgetTester tester, {
  List<DocItem> docs = const [],
  ScanState scan = const ScanState(phase: ScanPhase.done),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        scanControllerProvider.overrideWith(() => _FixedScan(scan)),
        documentsProvider.overrideWith((ref) => Stream.value(docs)),
        favoritePathsProvider.overrideWith((ref) => Stream.value(<String>{})),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const HomeScreen(),
      ),
    ),
  );
  // Thanh tiến độ quét chạy mãi → không dùng pumpAndSettle khi đang quét.
  if (scan.isScanning) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

Color _appBarColor(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!;

void main() {
  testWidgets('hiện tab All/PDF/DOC/XLS/PPT/TXT và danh sách tài liệu', (
    tester,
  ) async {
    await _pump(tester, docs: [_doc('a.pdf'), _doc('b.docx')]);

    for (final label in ['All', 'PDF', 'DOC', 'XLS', 'PPT', 'TXT']) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.docx'), findsOneWidget);
  });

  testWidgets('đổi tab lọc đúng loại và đổi màu AppBar', (tester) async {
    await _pump(tester, docs: [_doc('a.pdf'), _doc('b.docx')]);
    final allColor = _appBarColor(tester);

    await tester.tap(find.widgetWithText(Tab, 'PDF'));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.docx'), findsNothing);
    expect(_appBarColor(tester), isNot(allColor));

    await tester.tap(find.widgetWithText(Tab, 'DOC'));
    await tester.pumpAndSettle();
    expect(find.text('a.pdf'), findsNothing);
    expect(find.text('b.docx'), findsOneWidget);
  });

  testWidgets('bấm ô PDF trong lưới loại file chuyển sang tab PDF', (
    tester,
  ) async {
    await _pump(tester, docs: [_doc('a.pdf'), _doc('b.docx')]);

    await tester.tap(find.byKey(const ValueKey('grid-pdf')));
    await tester.pumpAndSettle();

    expect(find.text('b.docx'), findsNothing);
    expect(find.text('a.pdf'), findsOneWidget);
  });

  testWidgets('trống + chưa có quyền → màn xin quyền và nút chọn file', (
    tester,
  ) async {
    await _pump(
      tester,
      scan: const ScanState(phase: ScanPhase.needsPermission),
    );

    expect(find.text('Allow access to your files'), findsOneWidget);
    expect(find.text('Grant access'), findsOneWidget);
    expect(find.text('Choose a file instead'), findsOneWidget);
  });

  testWidgets(
    'có tài liệu cũ + chưa có quyền → băng nhắc, vẫn hiện danh sách',
    (tester) async {
      await _pump(
        tester,
        docs: [_doc('a.pdf')],
        scan: const ScanState(phase: ScanPhase.needsPermission),
      );

      expect(
        find.text('Grant file access to find all your documents'),
        findsOneWidget,
      );
      expect(find.text('a.pdf'), findsOneWidget);
    },
  );

  testWidgets('trống và đã quét xong → thông báo không có tài liệu', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('No documents found'), findsOneWidget);
  });

  testWidgets('đang quét và chưa có gì → thanh "đã tìm N file"', (
    tester,
  ) async {
    await _pump(
      tester,
      scan: const ScanState(phase: ScanPhase.scanning, found: 42),
    );
    expect(find.text('Scanning… 42 files found'), findsOneWidget);
  });

  testWidgets('menu sắp xếp đổi và lưu lựa chọn', (tester) async {
    await _pump(tester, docs: [_doc('a.pdf')]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(docSortProvider), DocSort.dateDesc);

    await tester.tap(find.byKey(const ValueKey('sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<DocSort>, 'Name (A–Z)'),
    );
    await tester.pumpAndSettle();

    expect(container.read(docSortProvider), DocSort.nameAsc);
  });

  testWidgets('drawer có Language, Appearance, Save folder, About', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    for (final key in [
      'drawer-recents',
      'drawer-favorites',
      'drawer-language',
      'drawer-theme',
      'drawer-output',
      'drawer-about',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });
}
