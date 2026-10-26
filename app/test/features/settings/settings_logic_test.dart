import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/page_size.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/settings_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('isDirectoryWritable', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('settings_test_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('thư mục tạm ghi được và không để lại file thử', () async {
      expect(await isDirectoryWritable(tmp.path), isTrue);
      expect(tmp.listSync(), isEmpty);
    });

    test('thư mục không tồn tại -> false', () async {
      expect(await isDirectoryWritable(p.join(tmp.path, 'khong_co')), isFalse);
    });

    test('đường dẫn là file -> false', () async {
      final f = File(p.join(tmp.path, 'a.txt'))..writeAsStringSync('x');
      expect(await isDirectoryWritable(f.path), isFalse);
    });

    test('chuỗi rỗng -> false', () async {
      expect(await isDirectoryWritable(''), isFalse);
    });
  });

  group('danh sách ngôn ngữ', () {
    test('6 ngôn ngữ, mỗi cái có tên bản địa', () {
      expect(appLocales.map((l) => l.languageCode), [
        'vi',
        'en',
        'zh',
        'ja',
        'ko',
        'id',
      ]);
      for (final l in appLocales) {
        expect(localeNativeNames[l.languageCode], isNotNull);
      }
    });
  });

  group('settingsProvider', () {
    test('đổi locale cập nhật AppSettings và xoá về null = theo máy', () async {
      final c = await _container();
      final n = c.read(settingsProvider.notifier);
      await n.setLocale(const Locale('ja'));
      expect(c.read(settingsProvider).locale, const Locale('ja'));
      await n.setLocale(null);
      expect(c.read(settingsProvider).locale, isNull);
    });

    test('đổi theme cập nhật AppSettings', () async {
      final c = await _container();
      await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
    });

    test('khổ giấy mặc định', () async {
      final c = await _container();
      await c
          .read(settingsProvider.notifier)
          .setDefaultPageSize(PageSizeOption.letter);
      expect(c.read(settingsProvider).defaultPageSize, PageSizeOption.letter);
    });
  });

  group('applyOutputDirectory', () {
    test('thư mục ghi được -> lưu vào cài đặt', () async {
      final c = await _container();
      final tmp = Directory.systemTemp.createTempSync('settings_out_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final ok = await applyOutputDirectory(
        c.read(settingsProvider.notifier),
        tmp.path,
      );
      expect(ok, isTrue);
      expect(c.read(settingsProvider).outputDir, tmp.path);
    });

    test('thư mục không ghi được -> báo false, giữ nguyên cài đặt', () async {
      final c = await _container();
      final ok = await applyOutputDirectory(
        c.read(settingsProvider.notifier),
        p.join(Directory.systemTemp.path, 'settings_khong_co_xyz'),
      );
      expect(ok, isFalse);
      expect(c.read(settingsProvider).outputDir, isNull);
    });

    test('null = về mặc định', () async {
      final c = await _container();
      final n = c.read(settingsProvider.notifier);
      await n.setOutputDir('/x');
      expect(await applyOutputDirectory(n, null), isTrue);
      expect(c.read(settingsProvider).outputDir, isNull);
    });
  });
}
