import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf_office/features/documents/main_shell.dart';
import 'package:pdf_office/features/settings/settings_screen.dart';

import 'support/boot.dart';
import 'support/steps.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('đi qua 5 tab và Cài đặt, chụp 11 ảnh', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    Future<void> tab(String key, String label) async {
      await tapKey(tester, key);
      await settle(tester, binding, label);
    }

    final settingsList = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    // Mở mục Cài đặt, chụp, rồi quay lại.
    Future<void> openSetting(String key, String name) async {
      await tapKey(tester, key, scrollable: settingsList);
      await shot(tester, binding, name);
      await tester.pageBack();
      await settle(tester, binding, 'back-$name');
    }

    await pumpApp(tester, locale: 'en');
    await settle(tester, binding, 'boot');
    expect(find.byType(MainShell), findsOneWidget);
    await shot(tester, binding, '01-home');

    await tab('nav-files', 'tab-files');
    await shot(tester, binding, '02-files');

    await tab('nav-tools', 'tab-tools');
    await shot(tester, binding, '03-tools');

    await tab('nav-settings', 'tab-settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    // iOS không cho chọn thư mục tuỳ ý → mục "Thư mục lưu" phải bị ẩn.
    if (Platform.isIOS) {
      expect(find.byKey(const ValueKey('settings_outputDir')), findsNothing);
    }
    await shot(tester, binding, '04-settings');

    await openSetting('settings_language', '05-language');
    await openSetting('settings_theme', '06-theme');
    await openSetting('settings_pageSize', '07-page-size');
    await openSetting('settings_privacy', '08-privacy');
    await openSetting('settings_about', '09-about');

    // Đổi sang tiếng Việt rồi xem lại Trang chủ.
    await tapKey(tester, 'settings_language', scrollable: settingsList);
    await settle(tester, binding, 'language-open');
    await tapKey(tester, 'lang_vi');
    await settle(tester, binding, 'language-vi');
    await tester.pageBack();
    await settle(tester, binding, 'back-language-vi');
    await tab('nav-home', 'tab-home-vi');
    expect(find.text('Trang chủ'), findsWidgets);
    await shot(tester, binding, '10-home-vi');

    // Chế độ tối.
    await tab('nav-settings', 'tab-settings-dark');
    await tapKey(tester, 'settings_theme', scrollable: settingsList);
    await settle(tester, binding, 'theme-open');
    await tapKey(tester, 'theme_dark');
    await settle(tester, binding, 'theme-dark');
    await tester.pageBack();
    await settle(tester, binding, 'back-theme-dark');
    await tab('nav-home', 'tab-home-dark');
    final brightness = Theme.of(
      tester.element(find.byType(MainShell)),
    ).brightness;
    expect(brightness, Brightness.dark);
    await shot(tester, binding, '11-home-dark');
  });
}
