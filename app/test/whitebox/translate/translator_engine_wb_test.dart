// Kiểm thử hộp trắng (A15) — translator_engine.dart. Mã bộ theo
// test-output/whitebox/translate/translator_engine/buoc-5-du-lieu-thu.md. ML Kit mock bằng
// OnDeviceTranslatorModelManager giả (lớp con) và kênh 'google_mlkit_on_device_translator' giả.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:pdf_office/features/translate/translator_engine.dart';

class _FakeModels extends OnDeviceTranslatorModelManager {
  final calls = <String>[];
  bool downloaded = true;
  bool downloadOk = true;
  bool downloadThrows = false;
  bool? lastWifi;

  @override
  Future<bool> isModelDownloaded(String model) async {
    calls.add('check:$model');
    return downloaded;
  }

  @override
  Future<bool> downloadModel(String model, {bool isWifiRequired = true}) async {
    calls.add('download:$model');
    lastWifi = isWifiRequired;
    if (downloadThrows) throw PlatformException(code: 'network');
    return downloadOk;
  }

  @override
  Future<bool> deleteModel(String model) async {
    calls.add('delete:$model');
    return true;
  }
}

const _channel = MethodChannel('google_mlkit_on_device_translator');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channelCalls = <MethodCall>[];

  setUp(() {
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      channelCalls.add(call);
      if (call.method == 'nlp#manageLanguageModelModels') return true;
      if (call.method == 'nlp#startLanguageTranslator') return 'dịch';
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<Object?> run(Future<Object?> Function() f) =>
      Future.sync(f).then((v) => v ?? 'ok', onError: (Object e) => e);

  group('U1 constructor', () {
    test('1-1 không truyền manager ⇒ dùng ML Kit thật (kênh nền tảng)', () async {
      final r = await run(() => MlKitTranslatorEngine().isModelDownloaded('vi'));
      expect(channelCalls.map((c) => c.method), ['nlp#manageLanguageModelModels']);
      expect((channelCalls.single.arguments as Map)['model'], 'vi');
      expect(r, true);
    });
    test('1-2 truyền manager ⇒ dùng manager đó', () async {
      final m = _FakeModels();
      final r = await run(
        () => MlKitTranslatorEngine(modelManager: m).isModelDownloaded('vi'),
      );
      expect(m.calls, ['check:vi']);
      expect(channelCalls, isEmpty);
      expect(r, true);
    });
  });

  group('U2 _lang + U3 isModelDownloaded', () {
    test('2-1 / 3-1 vi ⇒ hỏi gói vi', () async {
      final m = _FakeModels()..downloaded = false;
      final r = await run(
        () => MlKitTranslatorEngine(modelManager: m).isModelDownloaded('vi'),
      );
      expect(m.calls, ['check:vi']);
      expect(r, false);
    });
    test('2-2 / 3-2 fr ⇒ ArgumentError, không hỏi ML Kit', () async {
      final m = _FakeModels();
      final r = await run(
        () => MlKitTranslatorEngine(modelManager: m).isModelDownloaded('fr'),
      );
      expect(m.calls, isEmpty);
      expect(r, isA<ArgumentError>());
    });
  });

  group('U4 downloadModel', () {
    test('4-1 vi, tải thành công ⇒ xong, cho tải bằng dữ liệu di động', () async {
      final m = _FakeModels();
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).downloadModel('vi'));
      expect(m.calls, ['download:vi']);
      expect(m.lastWifi, isFalse);
      expect(r, 'ok');
    });
    test('4-2 fr ⇒ ArgumentError, không tải', () async {
      final m = _FakeModels();
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).downloadModel('fr'));
      expect(m.calls, isEmpty);
      expect(r, isA<ArgumentError>());
    });
    test('4-3 PlatformException (mất mạng) ⇒ TranslateModelDownloadFailed(vi, cause)', () async {
      final m = _FakeModels()..downloadThrows = true;
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).downloadModel('vi'));
      expect(m.calls, ['download:vi']);
      expect(r, isA<TranslateModelDownloadFailed>());
      final f = r! as TranslateModelDownloadFailed;
      expect(f.code, 'vi');
      expect(f.cause, isA<PlatformException>());
    });
    test('4-4 ML Kit trả false ⇒ TranslateModelDownloadFailed(vi)', () async {
      final m = _FakeModels()..downloadOk = false;
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).downloadModel('vi'));
      expect(m.calls, ['download:vi']);
      expect(r, isA<TranslateModelDownloadFailed>());
      expect((r! as TranslateModelDownloadFailed).code, 'vi');
    });
  });

  group('U5 deleteModel', () {
    test('5-1 vi ⇒ xoá gói vi', () async {
      final m = _FakeModels();
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).deleteModel('vi'));
      expect(m.calls, ['delete:vi']);
      expect(r, 'ok');
    });
    test('5-2 fr ⇒ ArgumentError, không xoá', () async {
      final m = _FakeModels();
      final r = await run(() => MlKitTranslatorEngine(modelManager: m).deleteModel('fr'));
      expect(m.calls, isEmpty);
      expect(r, isA<ArgumentError>());
    });
  });

  group('U6 open', () {
    test('6-1 vi → en ⇒ phiên dịch vi→en', () async {
      final s = MlKitTranslatorEngine(modelManager: _FakeModels())
          .open(source: 'vi', target: 'en');
      final r = await s.translate('xin chào');
      final call = channelCalls.single;
      expect(call.method, 'nlp#startLanguageTranslator');
      expect((call.arguments as Map)['source'], 'vi');
      expect((call.arguments as Map)['target'], 'en');
      expect(r, 'dịch');
    });
    test('6-2 nguồn fr ⇒ ArgumentError', () {
      final e = MlKitTranslatorEngine(modelManager: _FakeModels());
      expect(() => e.open(source: 'fr', target: 'en'), throwsArgumentError);
    });
    test('6-3 đích fr ⇒ ArgumentError', () {
      final e = MlKitTranslatorEngine(modelManager: _FakeModels());
      expect(() => e.open(source: 'vi', target: 'fr'), throwsArgumentError);
    });
  });

  group('U7 _MlKitSession.close', () {
    test('7-1 đóng lần đầu ⇒ giải phóng bộ dịch', () async {
      final s = MlKitTranslatorEngine(modelManager: _FakeModels())
          .open(source: 'vi', target: 'en');
      await s.close();
      expect(channelCalls.map((c) => c.method), ['nlp#closeLanguageTranslator']);
    });
    test('7-2 đóng lần hai ⇒ không gọi lại', () async {
      final s = MlKitTranslatorEngine(modelManager: _FakeModels())
          .open(source: 'vi', target: 'en');
      await s.close();
      await s.close();
      expect(channelCalls.map((c) => c.method), ['nlp#closeLanguageTranslator']);
    });
  });
}
