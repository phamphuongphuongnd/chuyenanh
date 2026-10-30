import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedScan extends ScanController {
  @override
  ScanState build() => const ScanState(phase: ScanPhase.done);
}

DocItem _doc(String name) => DocItem(
  path: '/storage/$name',
  name: name,
  ext: name.split('.').last,
  size: 1000,
  modified: DateTime(2026, 1, 2, 3, 4),
  folder: 'Download',
);

Future<void> _pump(
  WidgetTester tester, {
  List<DocItem> recents = const [],
  List<DocItem> favorites = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const MainShell()),
      GoRoute(
        path: Routes.imageToPdf,
        builder: (_, _) => const Scaffold(body: Text('IMAGE-TO-PDF-SCREEN')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        scanControllerProvider.overrideWith(_FixedScan.new),
        documentsProvider.overrideWith((ref) => Stream.value(recents)),
        homeRecentItemsProvider.overrideWith((ref) => Stream.value(recents)),
        favoritePathsProvider.overrideWith((ref) => Stream.value(<String>{})),
        homeFavoriteItemsProvider.overrideWith((ref) => Stream.value(favorites)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thanh dưới có đúng 5 nút', (tester) async {
    await _pump(tester);
    for (final key in [
      'nav-home',
      'nav-files',
      'nav-convert',
      'nav-tools',
      'nav-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('Trang chủ có ô tìm kiếm, 3 ô tính năng và danh sách gần đây', (
    tester,
  ) async {
    await _pump(tester, recents: [_doc('gan-day.pdf')]);
    expect(find.byKey(const ValueKey('home-tab-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-imageToPdf')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-scanner')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-pdfToImage')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-view-all')), findsOneWidget);
    expect(find.text('gan-day.pdf'), findsOneWidget);
  });

  testWidgets('Trang chủ có mục Yêu thích cạnh Gần đây', (tester) async {
    await _pump(
      tester,
      recents: [_doc('gan-day.pdf')],
      favorites: [_doc('thich.pdf')],
    );
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-favorites-all')), findsOneWidget);
    expect(find.text('thich.pdf'), findsOneWidget);
  });

  testWidgets('chưa có yêu thích → hiện dòng trống', (tester) async {
    await _pump(tester);
    expect(find.text('No favorites yet'), findsOneWidget);
  });

  testWidgets('nút giữa (⇄) vào thẳng Ảnh sang PDF', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('nav-convert')));
    await tester.pumpAndSettle();

    expect(find.text('IMAGE-TO-PDF-SCREEN'), findsOneWidget);
  });

  testWidgets('đổi qua Tập tin, Công cụ, Cài đặt', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('nav-files')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('files-tab-0')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-favorites')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-recents')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-tools')));
    await tester.pumpAndSettle();
    // Công cụ ở nhóm đầu (nhóm Công cụ PDF nằm dưới màn 800×600, danh sách dựng lười).
    expect(find.byKey(const ValueKey('tool-scanner')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings_language')), findsOneWidget);
  });
}
