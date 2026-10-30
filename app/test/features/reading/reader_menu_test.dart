import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/reader/reader_viewer.dart';
import 'package:pdf_office/features/reader/screens/pdf_reader_screen.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';
import 'package:pdf_office/features/reading/reflow_args.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trình đọc PDF (file không tồn tại → màn lỗi, menu ⋮ vẫn dùng được) trong GoRouter có route reflow giả.
Future<List<Object?>> _pumpReader(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final pushed = <Object?>[];
  final router = GoRouter(
    initialLocation: '/test-reader',
    routes: [
      GoRoute(
        path: '/test-reader',
        builder: (context, state) => const PdfReaderScreen(
          args: OpenFileArgs('/khong-co/tai-lieu.pdf', initialPage: 2),
        ),
      ),
      GoRoute(
        path: Routes.reflow,
        builder: (_, state) {
          pushed.add(state.extra);
          return const Scaffold(body: Text('reflow-opened'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bookmarksForPathProvider.overrideWith(
          (ref, path) => Stream.value(const <Bookmark>[]),
        ),
        shortcutSupportedProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  testWidgets('menu ⋮ có 3 mục đọc dàn chữ / đọc to / dịch', (tester) async {
    await _pumpReader(tester);
    await tester.tap(find.byKey(const Key('reader_menuButton')));
    await tester.pumpAndSettle();

    for (final (label, icon) in [
      ('Reading mode', Symbols.chrome_reader_mode_rounded),
      ('Read aloud', Symbols.record_voice_over_rounded),
      ('Translate', Symbols.translate_rounded),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(find.byIcon(icon), findsOneWidget, reason: label);
    }
  });

  for (final (label, mode) in [
    ('Reading mode', ReflowMode.read),
    ('Read aloud', ReflowMode.readAloud),
    ('Translate', ReflowMode.translate),
  ]) {
    testWidgets('mục "$label" mở Routes.reflow ở trang hiện tại, chế độ $mode', (
      tester,
    ) async {
      final pushed = await _pumpReader(tester);
      await tester.tap(find.byKey(const Key('reader_menuButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text('reflow-opened'), findsOneWidget);
      expect(pushed.last, isA<ReflowArgs>());
      expect(
        pushed.last,
        ReflowArgs(
          const OpenFileArgs('/khong-co/tai-lieu.pdf', initialPage: 2),
          mode: mode,
        ),
      );
    });
  }
}
