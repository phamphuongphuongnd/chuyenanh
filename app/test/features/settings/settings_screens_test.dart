import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/core/utils/page_size.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/settings_logic.dart';
import 'package:pdf_office/features/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/settings_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mở app nhỏ chỉ có route của settings, bắt đầu ở [Routes.settings].
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String locale = 'en',
  String? pickedDir,
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsRepository.kLocale: locale,
    ...prefsValues,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      directoryPickerProvider.overrideWithValue((_) async => pickedDir),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: settingsRoutes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(settingsProvider);
          return MaterialApp.router(
            routerConfig: router,
            locale: s.locale,
            themeMode: s.themeMode,
            theme: ThemeData(),
            darkTheme: ThemeData.dark(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// File I/O thật không chạy trong FakeAsync của testWidgets: nhường cho vòng lặp thật.
/// Mỗi vòng: chờ I/O thật rồi `pump` để chạy phần tiếp theo của chuỗi `await`.
Future<void> _realIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

void main() {
  group('SettingsScreen', () {
    testWidgets('liệt kê đủ các mục kèm giá trị hiện tại', (tester) async {
      await _pump(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(_key('settings_language'), findsOneWidget);
      expect(_key('settings_theme'), findsOneWidget);
      expect(_key('settings_outputDir'), findsOneWidget);
      expect(_key('settings_pageSize'), findsOneWidget);
      expect(_key('settings_about'), findsOneWidget);
      // Phụ đề: ngôn ngữ en, giao diện theo máy, thư mục mặc định, A4, phiên bản.
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Follow device'), findsOneWidget);
      expect(find.text(defaultAndroidOutputDir), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('Version $kAppVersion'), findsOneWidget);
    });

    testWidgets('chạm Ngôn ngữ mở màn Ngôn ngữ', (tester) async {
      await _pump(tester);
      await tester.tap(_key('settings_language'));
      await tester.pumpAndSettle();
      expect(_key('lang_vi'), findsOneWidget);
    });

    testWidgets('chạm Giới thiệu mở màn Giới thiệu', (tester) async {
      await _pump(tester);
      await tester.tap(_key('settings_about'));
      await tester.pumpAndSettle();
      expect(_key('about_version'), findsOneWidget);
    });
  });

  group('Giao diện', () {
    testWidgets('chọn Tối cập nhật settings và phụ đề', (tester) async {
      final c = await _pump(tester);
      await tester.tap(_key('settings_theme'));
      await tester.pumpAndSettle();
      await tester.tap(_key('theme_dark'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('chọn Sáng rồi Theo máy', (tester) async {
      final c = await _pump(
        tester,
        prefsValues: {SettingsRepository.kThemeMode: 'dark'},
      );
      await tester.tap(_key('settings_theme'));
      await tester.pumpAndSettle();
      await tester.tap(_key('theme_light'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).themeMode, ThemeMode.light);
      await tester.tap(_key('theme_system'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).themeMode, ThemeMode.system);
    });
  });

  group('Khổ giấy mặc định', () {
    testWidgets('chọn Letter lưu vào settings', (tester) async {
      final c = await _pump(tester);
      await tester.tap(_key('settings_pageSize'));
      await tester.pumpAndSettle();
      await tester.tap(_key('pagesize_letter'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).defaultPageSize, PageSizeOption.letter);
    });
  });

  group('Thư mục lưu', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('settings_ui_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    testWidgets('chọn thư mục ghi được: lưu và hiện đường dẫn', (tester) async {
      final c = await _pump(tester, pickedDir: tmp.path);
      await tester.tap(_key('settings_outputDir'));
      await tester.pumpAndSettle();
      await tester.tap(_key('output_dir_choose'));
      await _realIo(tester);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).outputDir, tmp.path);
      expect(find.text(tmp.path), findsOneWidget);
    });

    testWidgets('thư mục không ghi được: báo lỗi, không đổi cài đặt', (
      tester,
    ) async {
      final bad = p.join(tmp.path, 'khong_ton_tai');
      final c = await _pump(tester, pickedDir: bad);
      await tester.tap(_key('settings_outputDir'));
      await tester.pumpAndSettle();
      await tester.tap(_key('output_dir_choose'));
      await _realIo(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Cannot write to this folder. Please choose another one.'),
        findsOneWidget,
      );
      expect(c.read(settingsProvider).outputDir, isNull);
    });

    testWidgets('người dùng huỷ chọn: không đổi, không báo lỗi', (
      tester,
    ) async {
      final c = await _pump(tester);
      await tester.tap(_key('settings_outputDir'));
      await tester.pumpAndSettle();
      await tester.tap(_key('output_dir_choose'));
      await _realIo(tester);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).outputDir, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'nút mặc định: tắt khi đang dùng mặc định, bật rồi về mặc định',
      (tester) async {
        final c = await _pump(
          tester,
          prefsValues: {SettingsRepository.kOutputDir: tmp.path},
        );
        await tester.tap(_key('settings_outputDir'));
        await tester.pumpAndSettle();
        expect(find.text(tmp.path), findsOneWidget);
        await tester.tap(_key('output_dir_reset'));
        await tester.pumpAndSettle();
        expect(c.read(settingsProvider).outputDir, isNull);
        expect(find.text(defaultAndroidOutputDir), findsOneWidget);
        final reset = tester.widget<OutlinedButton>(_key('output_dir_reset'));
        expect(reset.onPressed, isNull);
      },
    );
  });

  group('Giới thiệu', () {
    testWidgets('hiện tên app, phiên bản, ghi chú Syncfusion', (tester) async {
      await _pump(tester, locale: 'vi');
      await tester.tap(_key('settings_about'));
      await tester.pumpAndSettle();
      expect(find.text('PDF Office'), findsOneWidget);
      expect(find.text('Phiên bản $kAppVersion'), findsOneWidget);
      expect(find.textContaining('Syncfusion Community'), findsOneWidget);
    });

    testWidgets('nút giấy phép mở trang giấy phép', (tester) async {
      await _pump(tester);
      await tester.tap(_key('settings_about'));
      await tester.pumpAndSettle();
      await tester.tap(_key('about_licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
