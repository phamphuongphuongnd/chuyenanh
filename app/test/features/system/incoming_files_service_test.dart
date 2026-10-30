import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/system/incoming_files_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(kIncomingChannelName);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('takeInitial doc map {paths, failed, unsupported} tu native', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'takeInitial');
      return {
        'paths': ['/cache/incoming/a.pdf', '', 3],
        'failed': 2,
        'unsupported': 1,
      };
    });
    final batch = await IncomingFilesService().takeInitial();
    expect(batch.paths, ['/cache/incoming/a.pdf']);
    expect(batch.failed, 2);
    expect(batch.unsupported, 1);
    expect(batch.isEmpty, isFalse);
  });

  test('takeInitial chap nhan List<String> tran', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => ['/x/a.png']);
    final batch = await IncomingFilesService().takeInitial();
    expect(batch.paths, ['/x/a.png']);
    expect(batch.failed, 0);
  });

  test('khong co plugin native: lo rong, khong nem loi', () async {
    final batch = await IncomingFilesService().takeInitial();
    expect(batch.isEmpty, isTrue);
  });

  test('native loi PlatformException: lo rong', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'x');
    });
    expect((await IncomingFilesService().takeInitial()).isEmpty, isTrue);
  });

  test('native goi onFiles -> handler nhan lo; lo rong bi bo qua', () async {
    final s = IncomingFilesService();
    final got = <IncomingBatch>[];
    s.setFilesHandler(got.add);

    Future<void> send(Object? args) => messenger.handlePlatformMessage(
      kIncomingChannelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall('onFiles', args)),
      (_) {},
    );

    await send({
      'paths': ['/c/1.jpg', '/c/2.jpg'],
      'failed': 0,
    });
    await send({'paths': <String>[], 'failed': 0});
    expect(got, hasLength(1));
    expect(got.single.paths, ['/c/1.jpg', '/c/2.jpg']);
    s.setFilesHandler(null);
  });
}
