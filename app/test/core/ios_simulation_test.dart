// Giả lập iOS trên máy dev (không có Xcode/Simulator): ghi đè nền tảng = iOS và kiểm giao diện,
// luồng quét, cấu hình native. Không thay thế việc thử trên iPhone thật.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/file_scanner/file_scanner.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/settings/settings_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.docs);
  final String docs;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

class _RecordingScanner implements FileScanner {
  List<String>? roots;
  @override
  Future<ScanResult> scan(
    List<String> roots, {
    void Function(int found)? onProgress,
  }) async {
    this.roots = roots;
    return const ScanResult(files: []);
  }
}

class _Granted implements StoragePermissionService {
  @override
  Future<bool> isGranted() async => true;
  @override
  Future<bool> request() async => true;
}

Future<void> _pumpSettings(WidgetTester tester, AppPlatform platform) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appPlatformProvider.overrideWithValue(platform),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Cài đặt giả lập iOS', () {
    testWidgets('iOS: ẩn mục Thư mục lưu, vẫn còn các mục khác', (t) async {
      await _pumpSettings(t, AppPlatform.ios);
      expect(find.byKey(const ValueKey('settings_outputDir')), findsNothing);
      expect(find.byKey(const ValueKey('settings_language')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_share')), findsOneWidget);
    });

    testWidgets('Android: vẫn hiện mục Thư mục lưu', (t) async {
      await _pumpSettings(t, AppPlatform.android);
      expect(find.byKey(const ValueKey('settings_outputDir')), findsOneWidget);
    });
  });

  group('Quét tài liệu giả lập iOS', () {
    late AppDatabase db;
    late Directory tmp;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tmp = Directory.systemTemp.createTempSync('ios_sim_');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    });
    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    Future<List<String>?> scanRootsUsed(AppPlatform platform) async {
      final scanner = _RecordingScanner();
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appPlatformProvider.overrideWithValue(platform),
          fileScannerProvider.overrideWithValue(scanner),
          storagePermissionProvider.overrideWithValue(_Granted()),
          // Máy dev (Windows): thư mục gốc kiểu Android rỗng, như trên iOS.
          scanRootsProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(c.dispose);
      c.read(scanControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return scanner.roots;
    }

    test('iOS: quét đúng thư mục Documents của app', () async {
      expect(await scanRootsUsed(AppPlatform.ios), [tmp.path]);
    });

    test('nền tảng khác: không quét, giữ hành vi cũ', () async {
      expect(await scanRootsUsed(AppPlatform.other), isNull);
    });
  });

  group('Cấu hình native iOS', () {
    test('Info.plist có khoá chia sẻ file, loại tài liệu, tên app', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      for (final k in [
        'UIFileSharingEnabled',
        'LSSupportsOpeningDocumentsInPlace',
        'CFBundleDocumentTypes',
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'com.adobe.pdf',
      ]) {
        expect(plist, contains(k), reason: k);
      }
      expect(plist, contains('<string>PDF Office</string>'));
    });

    test('Deployment target >= 15.5 ở mọi cấu hình', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbx)
          .map((m) => double.parse(m.group(1)!))
          .toList();
      expect(targets, isNotEmpty);
      expect(targets.every((v) => v >= 15.5), isTrue);
    });

    test('Icon iOS: PNG đủ cỡ, không kênh alpha (App Store/Xcode yêu cầu)', () {
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final icons = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.extension(f.path) == '.png')
          .toList();
      expect(icons.length, 15);
      for (final f in icons) {
        final b = f.readAsBytesSync();
        // IHDR: byte 25 = kiểu màu (2 = RGB, 6 = RGBA).
        expect(b[25], 2, reason: p.basename(f.path));
      }
    });

    test('Workflow CI build IPA không ký tồn tại', () {
      final yml = File('../.github/workflows/ios-build.yml').readAsStringSync();
      expect(yml, contains('flutter build ios --release --no-codesign'));
      expect(yml, contains('PDFOffice-ios.ipa'));
    });

    // Tag ios-sim-* chỉ dành cho workflow simulator; khớp cả ios-* nên phải loại trừ.
    test('Workflow ios-build.yml bỏ qua tag ios-sim-*', () {
      final yml = File('../.github/workflows/ios-build.yml').readAsStringSync();
      expect(yml, contains("tags: ['ios-*', '!ios-sim-*']"));
    });

    // lib/l10n/ bị gitignore; flutter pub get tự sinh gói l10n nên phải gộp ARB trước.
    for (final name in ['ios-build.yml', 'ios-sim.yml']) {
      test('Workflow $name chạy merge_arb trước flutter pub get', () {
        final yml = File('../.github/workflows/$name').readAsStringSync();
        // So khớp dòng lệnh, không so khớp comment có nhắc tên lệnh.
        final merge = yml.indexOf('- run: dart tool/merge_arb.dart');
        final pubGet = yml.indexOf('- run: flutter pub get');
        expect(merge, isNonNegative);
        expect(pubGet, isNonNegative);
        expect(merge, lessThan(pubGet));
      });
    }
  });
}
