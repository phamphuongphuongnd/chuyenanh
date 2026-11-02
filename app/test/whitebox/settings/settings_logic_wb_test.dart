// Kiểm thử hộp trắng A13 — app/lib/features/settings/settings_logic.dart
// Thiết kế: test-output/whitebox/settings/settings_logic/buoc-1..5. Expected chép từ Bước 5.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/settings_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_settings_'));
  tearDown(() => tmp.deleteSync(recursive: true));
  String missing() => p.join(tmp.path, 'khong_co');

  group('U1 appShareMessage', () {
    test('1-1 android ⇒ kèm Google Play', () => expect(appShareMessage('Hi', AppPlatform.android), 'Hi\n\n$kPlayStoreUrl'));
    test('1-2 ios có link ⇒ kèm App Store, không nhắc Android', () {
      final m = appShareMessage('Hi', AppPlatform.ios, appStoreUrl: 'https://apps.apple.com/app/id1');
      expect(m.contains('play.google'), isFalse);
      expect(m.contains('Android'), isFalse);
      expect(m, 'Hi\n\nhttps://apps.apple.com/app/id1');
    });
    test('1-3 ios chưa có link ⇒ chỉ lời giới thiệu', () => expect(appShareMessage('Hi', AppPlatform.ios, appStoreUrl: ''), 'Hi'));
    test('1-4 nền tảng khác ⇒ chỉ lời giới thiệu', () => expect(appShareMessage('Hi', AppPlatform.other), 'Hi'));
  });

  group('U2 isDirectoryWritable', () {
    test('2-1 ghi được, không để lại file thử', () async {
      expect(await isDirectoryWritable(tmp.path), isTrue);
      expect(tmp.listSync(), isEmpty);
    });
    test('2-2 rỗng ⇒ false', () async => expect(await isDirectoryWritable(''), isFalse));
    test('2-3 không có / là file ⇒ false', () async {
      final f = File(p.join(tmp.path, 'f.txt'))..writeAsStringSync('x');
      expect(await isDirectoryWritable(missing()), isFalse);
      expect(await isDirectoryWritable(f.path), isFalse);
    });
  });

  group('U3 effectiveOutputDir', () {
    test('3-1 có cấu hình', () => expect(effectiveOutputDir('/x'), '/x'));
    test('3-2 null ⇒ mặc định', () => expect(effectiveOutputDir(null), defaultAndroidOutputDir));
    test('3-3 rỗng ⇒ mặc định', () => expect(effectiveOutputDir(''), defaultAndroidOutputDir));
  });

  group('U4 chooseOutputDirectory', () {
    Future<(OutputDirResult, String?, String?)> run(String? picked, {String? before}) async {
      final c = await _container();
      final n = c.read(settingsProvider.notifier);
      if (before != null) await n.setOutputDir(before);
      String? title;
      final r = await chooseOutputDirectory(n, (t) async {
        title = t;
        return picked;
      }, 'Chọn');
      return (r, c.read(settingsProvider).outputDir, title);
    }

    test('4-1 thư mục ghi được ⇒ applied', () async {
      final (r, dir, title) = await run(tmp.path);
      expect(title, 'Chọn');
      expect(dir, tmp.path);
      expect(r, OutputDirResult.applied);
    });
    test('4-2 huỷ ⇒ cancelled', () async {
      final (r, dir, _) = await run(null);
      expect(dir, isNull);
      expect(r, OutputDirResult.cancelled);
    });
    test('4-3 chuỗi rỗng ⇒ cancelled, không đổi', () async {
      final (r, dir, _) = await run('', before: '/cu');
      expect(dir, '/cu');
      expect(r, OutputDirResult.cancelled);
    });
    test('4-4 không ghi được ⇒ notWritable, giữ cũ', () async {
      final (r, dir, _) = await run(missing(), before: '/cu');
      expect(dir, '/cu');
      expect(r, OutputDirResult.notWritable);
    });
  });

  group('U5 applyOutputDirectory', () {
    test('5-1 ghi được ⇒ true, lưu', () async {
      final c = await _container();
      final ok = await applyOutputDirectory(c.read(settingsProvider.notifier), tmp.path);
      expect(c.read(settingsProvider).outputDir, tmp.path);
      expect(ok, isTrue);
    });
    test('5-2 không ghi được ⇒ false, giữ cũ', () async {
      final c = await _container();
      final n = c.read(settingsProvider.notifier);
      await n.setOutputDir('/cu');
      final ok = await applyOutputDirectory(n, missing());
      expect(c.read(settingsProvider).outputDir, '/cu');
      expect(ok, isFalse);
    });
    test('5-3 null ⇒ về mặc định', () async {
      final c = await _container();
      final n = c.read(settingsProvider.notifier);
      await n.setOutputDir('/x');
      final ok = await applyOutputDirectory(n, null);
      expect(c.read(settingsProvider).outputDir, isNull);
      expect(ok, isTrue);
    });
  });
}
