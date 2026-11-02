// Kiểm thử hộp trắng A13 — app/lib/features/system/incoming_files_service.dart
// Thiết kế: test-output/whitebox/system/incoming_files_service/buoc-1..5. Expected chép từ Bước 5.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/system/incoming_files_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(kIncomingChannelName);
  const other = MethodChannel('test/x');

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(other, null);
  });

  Future<void> send(String method, Object? args) => messenger.handlePlatformMessage(
    kIncomingChannelName,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );

  group('U1 fromNative', () {
    test('1-1 List trần ⇒ chỉ giữ chuỗi khác rỗng', () {
      final b = IncomingBatch.fromNative(['/c/a.pdf', '', 5]);
      expect(b.paths, ['/c/a.pdf']);
      expect(b.failed, 0);
      expect(b.unsupported, 0);
    });
    test('1-2 Map ⇒ đủ 3 trường', () {
      final b = IncomingBatch.fromNative({'paths': ['/c/a.pdf'], 'failed': 2, 'unsupported': 1});
      expect(b.paths, ['/c/a.pdf']);
      expect(b.failed, 2);
      expect(b.unsupported, 1);
    });
    test('1-3 null / chuỗi ⇒ lô rỗng', () {
      expect(IncomingBatch.fromNative(null).isEmpty, isTrue);
      expect(IncomingBatch.fromNative('x').isEmpty, isTrue);
    });
  });

  group('U2 isEmpty', () {
    test('2-1 mặc định ⇒ true', () => expect(const IncomingBatch().isEmpty, isTrue));
    test('2-2 có path ⇒ false', () => expect(const IncomingBatch(paths: ['/a']).isEmpty, isFalse));
    test('2-3 failed 1 ⇒ false', () => expect(const IncomingBatch(failed: 1).isEmpty, isFalse));
    test('2-4 unsupported 1 ⇒ false', () => expect(const IncomingBatch(unsupported: 1).isEmpty, isFalse));
  });

  group('U3 _paths', () {
    test('3-1 lọc null/rỗng', () {
      expect(IncomingBatch.fromNative({'paths': ['/a', '', null, '/b']}).paths, ['/a', '/b']);
    });
    test('3-2 paths không phải List ⇒ rỗng', () {
      expect(IncomingBatch.fromNative({'paths': '/a.pdf'}).paths, isEmpty);
    });
  });

  group('U4 _count', () {
    test('4-1 số dương ⇒ giữ', () => expect(IncomingBatch.fromNative({'failed': 3}).failed, 3));
    test('4-2 0 / âm ⇒ 0', () {
      final b = IncomingBatch.fromNative({'failed': 0, 'unsupported': -4});
      expect(b.failed, 0);
      expect(b.unsupported, 0);
    });
    test('4-3 không phải int ⇒ 0', () {
      final b = IncomingBatch.fromNative({'failed': '2', 'unsupported': 1.5});
      expect(b.failed, 0);
      expect(b.unsupported, 0);
    });
  });

  group('U5 hàm tạo', () {
    test('5-1 mặc định dùng kênh incoming', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c.method);
        return ['/c/a.pdf'];
      });
      final b = await IncomingFilesService().takeInitial();
      expect(calls, ['takeInitial']);
      expect(b.paths, ['/c/a.pdf']);
    });
    test('5-2 kênh truyền vào được dùng', () async {
      var hit = 0;
      messenger.setMockMethodCallHandler(other, (c) async {
        hit++;
        return ['/z.png'];
      });
      final b = await IncomingFilesService(channel: other).takeInitial();
      expect(hit, 1);
      expect(b.paths, ['/z.png']);
    });
  });

  group('U6 takeInitial', () {
    test('6-1 native trả map ⇒ lô', () async {
      String? method;
      messenger.setMockMethodCallHandler(channel, (c) async {
        method = c.method;
        return {'paths': ['/c/1.jpg']};
      });
      final b = await IncomingFilesService().takeInitial();
      expect(method, 'takeInitial');
      expect(b.paths, ['/c/1.jpg']);
    });
    test('6-2 không có plugin ⇒ lô rỗng, không ném', () async {
      final r = await IncomingFilesService().takeInitial().then((v) => v as Object, onError: (Object e) => e);
      expect(r, isA<IncomingBatch>());
      expect((r as IncomingBatch).isEmpty, isTrue);
    });
    test('6-3 PlatformException ⇒ lô rỗng', () async {
      messenger.setMockMethodCallHandler(channel, (c) async => throw PlatformException(code: 'e'));
      final r = await IncomingFilesService().takeInitial().then((v) => v as Object, onError: (Object e) => e);
      expect((r as IncomingBatch).isEmpty, isTrue);
    });
  });

  group('U7/U8 setFilesHandler + callback', () {
    test('7-1/8-1 onFiles có path ⇒ handler nhận 1 lô', () async {
      final s = IncomingFilesService();
      final got = <IncomingBatch>[];
      s.setFilesHandler(got.add);
      await send('onFiles', {'paths': ['/c/a.pdf']});
      s.setFilesHandler(null);
      expect(got.single.paths, ['/c/a.pdf']);
    });
    test('7-2 gỡ handler ⇒ không gọi nữa', () async {
      final s = IncomingFilesService();
      final got = <IncomingBatch>[];
      s.setFilesHandler(got.add);
      s.setFilesHandler(null);
      await send('onFiles', {'paths': ['/c/a.pdf']});
      expect(got, isEmpty);
    });
    test('8-2 lô rỗng ⇒ bỏ qua', () async {
      final s = IncomingFilesService();
      final got = <IncomingBatch>[];
      s.setFilesHandler(got.add);
      await send('onFiles', {'paths': <String>[], 'failed': 0});
      s.setFilesHandler(null);
      expect(got, isEmpty);
    });
    test('8-3 method khác ⇒ bỏ qua', () async {
      final s = IncomingFilesService();
      final got = <IncomingBatch>[];
      s.setFilesHandler(got.add);
      await send('other', {'paths': ['/c/a.pdf']});
      s.setFilesHandler(null);
      expect(got, isEmpty);
    });
  });
}
