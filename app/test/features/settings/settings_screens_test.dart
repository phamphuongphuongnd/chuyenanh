import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/utils/link_opener.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/core/utils/url_safety.dart';
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
  LinkLauncher? launcher,
}) async {
  // Màn Cài đặt dài hơn khung 600px mặc định của test.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    SettingsRepository.kLocale: locale,
    ...prefsValues,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      directoryPickerProvider.overrideWithValue((_) async => pickedDir),
      if (launcher != null) linkLauncherProvider.overrideWithValue(launcher),
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
Future<void> _realIo(WidgetTester tester, {bool Function()? until}) async {
  // Có [until]: chờ tới khi đạt điều kiện (tối đa ~5 giây) thay vì số vòng cố định,
  // vì ghi/xoá file thật chậm hơn nhiều khi máy đang tải.
  final rounds = until == null ? 10 : 170;
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (until != null && until()) return;
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
    tearDown(() async {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows: handle chưa release kịp sau isDirectoryWritable probe → bỏ qua
      }
    });

    testWidgets('chọn thư mục ghi được: lưu và hiện đường dẫn', (tester) async {
      final c = await _pump(tester, pickedDir: tmp.path);
      await tester.tap(_key('settings_outputDir'));
      await tester.pumpAndSettle();
      await tester.tap(_key('output_dir_choose'));
      await _realIo(tester, until: () => c.read(settingsProvider).outputDir == tmp.path);
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

  group('SettingsScreen nhóm Về ứng dụng', () {
    testWidgets('có 2 nhóm và 3 mục mới: Chia sẻ, Phản hồi, Chính sách', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('About the app'), findsOneWidget);
      expect(_key('settings_share'), findsOneWidget);
      expect(_key('settings_feedback'), findsOneWidget);
      expect(_key('settings_privacy'), findsOneWidget);
    });

    testWidgets('Chính sách bảo mật mở màn có nội dung', (tester) async {
      await _pump(tester);
      await tester.tap(_key('settings_privacy'));
      await tester.pumpAndSettle();
      expect(_key('privacy_body'), findsOneWidget);
      expect(find.textContaining('offline'), findsWidgets);
    });

    testWidgets('Phản hồi mở email; không mở được thì báo lỗi', (tester) async {
      Uri? opened;
      var ok = true;
      await _pump(
        tester,
        launcher: (uri) async {
          opened = uri;
          return ok;
        },
      );
      await tester.tap(_key('settings_feedback'));
      await tester.pumpAndSettle();
      expect(opened?.scheme, 'mailto');
      expect(find.text('Could not open an email app'), findsNothing);

      ok = false;
      await tester.tap(_key('settings_feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open an email app'), findsOneWidget);
    });
  });

  group('Link chia sẻ ứng dụng', () {
    test('link tải là https hợp lệ trỏ tới file APK trong repo', () {
      final uri = safeLinkUri(kAppDownloadUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, endsWith('.apk'));
    });

    test('nội dung chia sẻ gồm lời giới thiệu và link ở dòng cuối', () {
      final msg = appShareMessage('Xin chào');
      expect(msg, startsWith('Xin chào\n'));
      expect(msg.endsWith(kAppDownloadUrl), isTrue);
    });
  });
}
