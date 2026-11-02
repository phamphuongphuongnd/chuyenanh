// Kiểm thử hộp trắng (A09 · reader) — shortcut_service.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/shortcut_service/buoc-5-du-lieu-thu.md.
// SS1-5, SS2-5, SS3-4 (lỗi loại khác ném tiếp) CHƯA viết: chưa có yêu cầu — chờ người dùng chốt.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(kShortcutChannelName);
  const other = MethodChannel('wb_a09/other');

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(other, null);
  });

  /// Đặt native giả trả [reply] (hoặc ném nếu là Exception); ghi lại lời gọi.
  List<MethodCall> mock(MethodChannel ch, Object? reply) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(ch, (call) async {
      calls.add(call);
      if (reply is Exception) throw reply;
      return reply;
    });
    return calls;
  }

  Future<void> sendFromNative(MethodCall call) => messenger.handlePlatformMessage(
    kShortcutChannelName,
    const StandardMethodCodec().encodeMethodCall(call),
    (_) {},
  );

  group('constructor', () {
    test('SS0-1 không truyền kênh ⇒ dùng kênh com.phuong.pdfoffice/shortcut', () async {
      final calls = mock(channel, true);
      expect(await ShortcutService().isSupported(), isTrue);
      expect(calls.map((c) => c.method), ['isSupported']);
    });
    test('SS0-2 truyền kênh riêng ⇒ gọi qua kênh đó', () async {
      final main = mock(channel, true);
      final calls = mock(other, true);
      expect(await ShortcutService(channel: other).isSupported(), isTrue);
      expect(calls.map((c) => c.method), ['isSupported']);
      expect(main, isEmpty);
    });
  });

  group('isSupported', () {
    test('SS1-1 native trả true ⇒ true', () async {
      final calls = mock(channel, true);
      expect(await ShortcutService().isSupported(), isTrue);
      expect(calls, hasLength(1));
    });
    test('SS1-2 native trả null ⇒ false', () async {
      final calls = mock(channel, null);
      expect(await ShortcutService().isSupported(), isFalse);
      expect(calls, hasLength(1));
    });
    test('SS1-3 không có plugin native ⇒ false, không ném', () async {
      final r = await ShortcutService().isSupported().then((v) => v as Object, onError: (Object e) => e);
      expect(r, false);
    });
    test('SS1-4 native ném PlatformException ⇒ false, không ném', () async {
      final calls = mock(channel, PlatformException(code: 'ERR'));
      final r = await ShortcutService().isSupported().then((v) => v as Object, onError: (Object e) => e);
      expect(calls, hasLength(1));
      expect(r, false);
    });
  });

  group('requestPinShortcut', () {
    test('SS2-1 native trả true ⇒ true, gửi đúng path + label', () async {
      final calls = mock(channel, true);
      expect(await ShortcutService().requestPinShortcut(path: '/sdcard/a.pdf', label: 'a'), isTrue);
      expect(calls.single.method, 'requestPinShortcut');
      expect(calls.single.arguments, {'path': '/sdcard/a.pdf', 'label': 'a'});
    });
    test('SS2-2 native trả null ⇒ false', () async {
      final calls = mock(channel, null);
      expect(await ShortcutService().requestPinShortcut(path: '/a.pdf', label: 'a'), isFalse);
      expect(calls, hasLength(1));
    });
    test('SS2-3 không có plugin native ⇒ false, không ném', () async {
      final r = await ShortcutService()
          .requestPinShortcut(path: '/a.pdf', label: 'a')
          .then((v) => v as Object, onError: (Object e) => e);
      expect(r, false);
    });
    test('SS2-4 native ném PlatformException ⇒ false, không ném', () async {
      final calls = mock(channel, PlatformException(code: 'ERR'));
      final r = await ShortcutService()
          .requestPinShortcut(path: '/a.pdf', label: 'a')
          .then((v) => v as Object, onError: (Object e) => e);
      expect(calls, hasLength(1));
      expect(r, false);
    });
  });

  group('takeInitialPath', () {
    test('SS3-1 native trả đường dẫn ⇒ đường dẫn; trả null (mở bình thường) ⇒ null', () async {
      mock(channel, '/sdcard/b.pdf');
      expect(await ShortcutService().takeInitialPath(), '/sdcard/b.pdf');
      mock(channel, null);
      expect(await ShortcutService().takeInitialPath(), isNull);
    });
    test('SS3-2 không có plugin native ⇒ null, không ném', () async {
      final r = await ShortcutService().takeInitialPath().then((v) => v as Object?, onError: (Object e) => e);
      expect(r, isNull);
    });
    test('SS3-3 native ném PlatformException ⇒ null, không ném', () async {
      final calls = mock(channel, PlatformException(code: 'ERR'));
      final r = await ShortcutService().takeInitialPath().then((v) => v as Object?, onError: (Object e) => e);
      expect(calls, hasLength(1));
      expect(r, isNull);
    });
  });

  group('setOpenPathHandler + callback', () {
    test('SS4-1 / SS5-1 đặt handler, native gọi openPath "/sdcard/c.pdf" ⇒ handler nhận đường dẫn', () async {
      final s = ShortcutService();
      final opened = <String>[];
      s.setOpenPathHandler(opened.add);
      await sendFromNative(const MethodCall('openPath', '/sdcard/c.pdf'));
      expect(opened, ['/sdcard/c.pdf']);
      s.setOpenPathHandler(null);
    });
    test('SS4-2 gỡ handler (null) ⇒ native gọi openPath không tới handler cũ', () async {
      final s = ShortcutService();
      final opened = <String>[];
      s.setOpenPathHandler(opened.add);
      s.setOpenPathHandler(null);
      await sendFromNative(const MethodCall('openPath', '/sdcard/c.pdf'));
      expect(opened, isEmpty);
    });
    test('SS5-2 native gọi method khác ⇒ không gọi handler', () async {
      final s = ShortcutService();
      final opened = <String>[];
      s.setOpenPathHandler(opened.add);
      await sendFromNative(const MethodCall('somethingElse', '/sdcard/c.pdf'));
      expect(opened, isEmpty);
      s.setOpenPathHandler(null);
    });
    test('SS5-3 openPath với đối số không phải chuỗi ⇒ không gọi handler', () async {
      final s = ShortcutService();
      final opened = <String>[];
      s.setOpenPathHandler(opened.add);
      await sendFromNative(const MethodCall('openPath', 42));
      expect(opened, isEmpty);
      s.setOpenPathHandler(null);
    });
    test('SS5-4 openPath với chuỗi rỗng ⇒ không gọi handler', () async {
      final s = ShortcutService();
      final opened = <String>[];
      s.setOpenPathHandler(opened.add);
      await sendFromNative(const MethodCall('openPath', ''));
      expect(opened, isEmpty);
      s.setOpenPathHandler(null);
    });
  });
}
