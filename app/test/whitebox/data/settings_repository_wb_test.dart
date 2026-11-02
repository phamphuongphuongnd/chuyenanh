// Kiểm thử hộp trắng A12 — app/lib/data/settings/settings_repository.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/page_size.dart';
import 'package:pdf_office/data/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final other = PageSizeOption.values.firstWhere((e) => e != PageSizeOption.a4);
  const base = AppSettings(
    locale: Locale('vi'),
    themeMode: ThemeMode.dark,
    outputDir: '/out',
  );

  group('U1 copyWith', () {
    test('U1.1 không truyền gì ⇒ bản sao bằng hệt', () {
      final c = base.copyWith();
      expect(
        (c.locale, c.themeMode, c.defaultPageSize, c.outputDir, c.appLock),
        (const Locale('vi'), ThemeMode.dark, PageSizeOption.a4, '/out', false),
      );
    });
    test('U1.2 locale: () => null ⇒ xoá locale (theo máy), giữ trường khác', () {
      final c = base.copyWith(locale: () => null);
      expect((c.locale, c.themeMode, c.outputDir), (null, ThemeMode.dark, '/out'));
    });
    test('U1.3 themeMode ⇒ đổi themeMode', () {
      expect(base.copyWith(themeMode: ThemeMode.light).themeMode, ThemeMode.light);
    });
    test('U1.4 defaultPageSize ⇒ đổi khổ giấy', () {
      expect(base.copyWith(defaultPageSize: other).defaultPageSize, other);
    });
    test('U1.5 outputDir: () => null ⇒ về thư mục mặc định', () {
      final c = base.copyWith(outputDir: () => null);
      expect((c.outputDir, c.locale), (null, const Locale('vi')));
    });
    test('U1.6 appLock ⇒ bật khoá app', () {
      final c = base.copyWith(appLock: true);
      expect((c.appLock, c.themeMode), (true, ThemeMode.dark));
    });
  });

  group('U2 operator ==', () {
    test('U2.1 mọi trường bằng nhau ⇒ true, hashCode bằng nhau', () {
      const same = AppSettings(
        locale: Locale('vi'),
        themeMode: ThemeMode.dark,
        outputDir: '/out',
      );
      expect(base == same, isTrue);
      expect(base.hashCode, same.hashCode);
    });
    test('U2.2 khác kiểu ⇒ false', () {
      expect(base == Object(), isFalse);
    });
    test('U2.3 khác locale ⇒ false', () {
      expect(base == base.copyWith(locale: () => const Locale('en')), isFalse);
    });
    test('U2.4 khác themeMode ⇒ false', () {
      expect(base == base.copyWith(themeMode: ThemeMode.light), isFalse);
    });
    test('U2.5 khác defaultPageSize ⇒ false', () {
      expect(base == base.copyWith(defaultPageSize: other), isFalse);
    });
    test('U2.6 khác outputDir ⇒ false', () {
      expect(base == base.copyWith(outputDir: () => '/khac'), isFalse);
    });
    test('U2.7 khác appLock ⇒ false', () {
      expect(base == base.copyWith(appLock: true), isFalse);
    });
  });

  Future<SettingsRepository> repo(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SettingsRepository(await SharedPreferences.getInstance());
  }

  group('U3 load', () {
    test('U3.1 chưa lưu gì ⇒ mặc định (theo máy, system, A4, null, khoá tắt)', () async {
      final s = (await repo({})).load();
      expect(s, const AppSettings());
      expect((s.locale, s.themeMode, s.outputDir, s.appLock), (null, ThemeMode.system, null, false));
    });
    test('U3.2 locale "vi" ⇒ Locale("vi")', () async {
      final s = (await repo({SettingsRepository.kLocale: 'vi'})).load();
      expect(s.locale, const Locale('vi'));
    });
    test('U3.3 locale "" ⇒ null (theo máy)', () async {
      final s = (await repo({SettingsRepository.kLocale: ''})).load();
      expect(s.locale, isNull);
    });
    test('U3.4 themeMode "dark" ⇒ dark; tên lạ ⇒ system', () async {
      expect((await repo({SettingsRepository.kThemeMode: 'dark'})).load().themeMode, ThemeMode.dark);
      expect((await repo({SettingsRepository.kThemeMode: 'xyz'})).load().themeMode, ThemeMode.system);
    });
    test('U3.5 appLock đã lưu true ⇒ true', () async {
      final s = (await repo({SettingsRepository.kAppLock: true})).load();
      expect(s.appLock, isTrue);
    });
  });

  group('U4 setLocale', () {
    test('U4.1 locale null ⇒ xoá khoá', () async {
      final r = await repo({SettingsRepository.kLocale: 'vi'});
      await r.setLocale(null);
      expect(r.load().locale, isNull);
      expect((await SharedPreferences.getInstance()).containsKey(SettingsRepository.kLocale), isFalse);
    });
    test('U4.2 locale ja ⇒ lưu mã ngôn ngữ', () async {
      final r = await repo({});
      await r.setLocale(const Locale('ja', 'JP'));
      expect((await SharedPreferences.getInstance()).getString(SettingsRepository.kLocale), 'ja');
      expect(r.load().locale, const Locale('ja'));
    });
  });

  group('U5 setOutputDir', () {
    test('U5.1 null ⇒ xoá (thư mục mặc định)', () async {
      final r = await repo({SettingsRepository.kOutputDir: '/old'});
      await r.setOutputDir(null);
      expect(r.load().outputDir, isNull);
    });
    test('U5.2 chuỗi rỗng ⇒ xoá (thư mục mặc định)', () async {
      final r = await repo({SettingsRepository.kOutputDir: '/old'});
      await r.setOutputDir('');
      expect((await SharedPreferences.getInstance()).containsKey(SettingsRepository.kOutputDir), isFalse);
      expect(r.load().outputDir, isNull);
    });
    test('U5.3 "/out" ⇒ lưu', () async {
      final r = await repo({});
      await r.setOutputDir('/out');
      expect(r.load().outputDir, '/out');
    });
  });

  test('U6.1 setAppLock ⇒ lưu, load đọc lại đúng', () async {
    final r = await repo({});
    await r.setAppLock(true);
    expect(r.load().appLock, isTrue);
    await r.setAppLock(false);
    expect(r.load().appLock, isFalse);
  });
}
