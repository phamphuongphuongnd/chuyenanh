import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/link_opener.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/qr/barcode_reader.dart';
import 'package:pdf_office/features/qr/qr_content.dart';
import 'package:pdf_office/features/qr/qr_history.dart';
import 'package:pdf_office/features/qr/qr_scan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReader implements BarcodeReader {
  FakeReader(this.codes);
  final List<ScannedCode> codes;
  final List<String> paths = [];

  @override
  Future<List<ScannedCode>> read(String imagePath) async {
    paths.add(imagePath);
    return codes;
  }
}

class FakePicker implements QrImagePicker {
  final List<QrImageSource> sources = [];

  @override
  Future<String?> pick(QrImageSource source) async {
    sources.add(source);
    return '/tmp/qr.jpg';
  }
}

const _url = ScannedCode(format: CodeFormat.qrCode, raw: 'https://example.com/x');
const _wifi = ScannedCode(
  format: CodeFormat.qrCode,
  raw: 'WIFI:S:Nha Minh;T:WPA;P:matkhau123;;',
);

void main() {
  late FakePicker picker;
  late List<Uri> launched;
  late List<String> clipboard;

  setUp(() {
    picker = FakePicker();
    launched = [];
    clipboard = [];
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    FakeReader reader, {
    Map<String, Object> prefsValues = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          barcodeReaderProvider.overrideWithValue(reader),
          qrImagePickerProvider.overrideWithValue(picker),
          linkLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const QrScanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  testWidgets('màn trống có 2 nút; chọn ảnh → 2 thẻ mã, chỉ link có nút Mở', (
    tester,
  ) async {
    final reader = FakeReader([_url, _wifi]);
    final container = await pump(tester, reader);

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);
    expect(find.text('Scan QR codes and barcodes'), findsOneWidget);

    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();

    expect(picker.sources, [QrImageSource.gallery]);
    expect(reader.paths, ['/tmp/qr.jpg']);
    expect(find.text('2 codes found'), findsOneWidget);
    expect(find.byType(QrCodeCard), findsNWidgets(2));
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('https://example.com/x'), findsOneWidget);
    expect(find.text('Network name'), findsOneWidget);
    expect(find.text('Nha Minh'), findsOneWidget);
    expect(find.text('matkhau123'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Copy'), findsNWidgets(2));
    expect(find.text('Share'), findsNWidgets(2));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://example.com/x')]);

    // Chép mật khẩu Wi‑Fi bằng nút riêng.
    await tester.tap(find.byTooltip('Copy Password'));
    await tester.pump();
    expect(clipboard, ['matkhau123']);
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Lịch sử đã lưu cả 2 mã.
    expect(container.read(qrHistoryProvider), [_url, _wifi]);
  });

  testWidgets('không thấy mã → EmptyState gợi ý', (tester) async {
    await pump(tester, FakeReader(const []));
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(picker.sources, [QrImageSource.camera]);
    expect(find.text('No code found'), findsOneWidget);
    expect(find.byType(QrCodeCard), findsNothing);
  });

  testWidgets('lịch sử: mở lại một mã và xoá toàn bộ', (tester) async {
    final container = await pump(
      tester,
      FakeReader(const []),
      prefsValues: {
        'qr.history': jsonEncode([
          {'format': 'qrCode', 'raw': 'Xin chào'},
        ]),
      },
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Xin chào'), findsOneWidget);

    await tester.tap(find.text('Xin chào'));
    await tester.pumpAndSettle();
    expect(find.byType(QrCodeCard), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    // Quay lại màn đầu rồi xoá lịch sử.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(qrHistoryProvider), isEmpty);
    expect(find.text('Recent'), findsNothing);
  });
}
