import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(kShortcutChannelName);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('requestPinShortcut gui path + label, tra ve ket qua native', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    final ok = await ShortcutService().requestPinShortcut(
      path: '/sdcard/a.pdf',
      label: 'a',
    );
    expect(ok, isTrue);
    expect(received!.method, 'requestPinShortcut');
    expect(received!.arguments, {'path': '/sdcard/a.pdf', 'label': 'a'});
  });

  test('isSupported / takeInitialPath doc tu native', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isSupported' => true,
        'takeInitialPath' => '/sdcard/b.pdf',
        _ => null,
      };
    });
    final s = ShortcutService();
    expect(await s.isSupported(), isTrue);
    expect(await s.takeInitialPath(), '/sdcard/b.pdf');
  });

  test('khong co plugin native (iOS, test): an toan, tra ve false/null', () async {
    final s = ShortcutService();
    expect(await s.isSupported(), isFalse);
    expect(await s.takeInitialPath(), isNull);
    expect(await s.requestPinShortcut(path: '/a.pdf', label: 'a'), isFalse);
  });

  test('native goi openPath -> handler nhan duong dan', () async {
    final s = ShortcutService();
    final opened = <String>[];
    s.setOpenPathHandler(opened.add);
    await messenger.handlePlatformMessage(
      kShortcutChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openPath', '/sdcard/c.pdf'),
      ),
      (_) {},
    );
    expect(opened, ['/sdcard/c.pdf']);
    s.setOpenPathHandler(null);
  });
}
