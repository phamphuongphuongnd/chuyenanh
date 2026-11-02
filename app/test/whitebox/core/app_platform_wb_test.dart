// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/platform/app_platform.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/app_platform/buoc-5-du-lieu-thu.md
// Máy chạy test là Windows: chỉ đi được nhánh "other" của detectPlatform (bộ 1.2, 1.3 cần thiết bị thật).
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/platform/app_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeDeviceInfo extends DeviceInfoPlatform with MockPlatformInterfaceMixin {
  _FakeDeviceInfo({this.sdkInt, this.error});
  final int? sdkInt;
  final Object? error;
  int calls = 0;

  @override
  Future<BaseDeviceInfo> deviceInfo() async {
    calls++;
    if (error != null) throw error!;
    final info = AndroidDeviceInfo.setMockInitialValues(
      version: AndroidBuildVersion.setMockInitialValues(
        codename: 'REL',
        incremental: '1',
        previewSdkInt: 0,
        release: '11',
        sdkInt: sdkInt!,
      ),
      board: 'b',
      bootloader: 'b',
      brand: 'b',
      device: 'd',
      display: 'd',
      fingerprint: 'f',
      hardware: 'h',
      host: 'h',
      id: 'i',
      manufacturer: 'm',
      model: 'm',
      product: 'p',
      name: 'n',
      supported32BitAbis: const [],
      supported64BitAbis: const [],
      supportedAbis: const [],
      tags: 't',
      time: 0,
      type: 'user',
      isPhysicalDevice: true,
      freeDiskSize: 0,
      totalDiskSize: 0,
      systemFeatures: const [],
      isLowRamDevice: false,
      physicalRamSize: 0,
      availableRamSize: 0,
    );
    return BaseDeviceInfo(info.data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U1 detectPlatform', () {
    test('1.1 máy không phải Android/iOS ⇒ other', () {
      // Điều kiện tiên quyết của bộ: chạy trên máy dev (không phải Android/iOS).
      expect(Platform.isAndroid || Platform.isIOS, isFalse);
      expect(detectPlatform(), AppPlatform.other);
    });
  });

  group('U2 defaultShareOrigin', () {
    test('2.1 iOS, có view ⇒ Rect neo 1×1 nằm trong màn hình (logic px)', () {
      final r = defaultShareOrigin(platform: AppPlatform.ios);
      expect(r, isNotNull);
      final view = PlatformDispatcher.instance.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      expect(r!.width, 1);
      expect(r.height, 1);
      expect(r.left >= 0 && r.left <= size.width, isTrue, reason: '$r / $size');
      expect(r.top >= 0 && r.top <= size.height, isTrue, reason: '$r / $size');
    });

    test('2.2 Android ⇒ null', () {
      expect(defaultShareOrigin(platform: AppPlatform.android), isNull);
    });

    test('2.3 không truyền platform, máy dev (other) ⇒ null', () {
      expect(defaultShareOrigin(), isNull);
    });
  });

  group('U3 androidSdkIntProvider (MỚI)', () {
    late DeviceInfoPlatform old;
    setUp(() => old = DeviceInfoPlatform.instance);
    tearDown(() => DeviceInfoPlatform.instance = old);

    Future<(int?, _FakeDeviceInfo)> read(AppPlatform platform, _FakeDeviceInfo fake) async {
      DeviceInfoPlatform.instance = fake;
      final c = ProviderContainer(
        overrides: [appPlatformProvider.overrideWithValue(platform)],
      );
      addTearDown(c.dispose);
      return (await c.read(androidSdkIntProvider.future), fake);
    }

    test('3.1 không phải Android (iOS) ⇒ null, không hỏi DeviceInfo', () async {
      final (v, fake) = await read(AppPlatform.ios, _FakeDeviceInfo(sdkInt: 30));
      expect(fake.calls, 0);
      expect(v, isNull);
    });

    test('3.2 Android, đọc được ⇒ sdkInt (30)', () async {
      final (v, fake) = await read(AppPlatform.android, _FakeDeviceInfo(sdkInt: 30));
      expect(fake.calls, 1);
      expect(v, 30);
    });

    test('3.3 Android, plugin ném Exception ⇒ null', () async {
      final (v, fake) = await read(
        AppPlatform.android,
        _FakeDeviceInfo(error: PlatformException(code: 'x')),
      );
      expect(fake.calls, 1);
      expect(v, isNull);
    });
  });
}
