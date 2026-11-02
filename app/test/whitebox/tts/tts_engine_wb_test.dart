// Kiểm thử hộp trắng (A15) — tts_engine.dart (FlutterTtsEngine). Mã bộ theo
// test-output/whitebox/tts/tts_engine/buoc-5-du-lieu-thu.md. Plugin flutter_tts mock bằng lớp con FlutterTts
// ghi lời gọi (và kênh 'flutter_tts' giả cho bộ 1-1 không truyền instance).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdf_office/features/tts/tts_engine.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

class _SpyTts extends FlutterTts {
  final log = <String>[];
  bool fail = false;
  dynamic available = true;

  Future<dynamic> _rec(String s, [dynamic r]) async {
    log.add(s);
    if (fail) throw PlatformException(code: 'x');
    return r;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _rec('awaitSpeakCompletion:$awaitCompletion');
  @override
  Future<dynamic> setSharedInstance(bool sharedSession) =>
      _rec('setSharedInstance:$sharedSession');
  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) => _rec(
    'setIosAudioCategory:${category.name}:${options.map((o) => o.name).join(',')}',
  );
  @override
  Future<dynamic> setQueueMode(int queueMode) =>
      _rec('setQueueMode:$queueMode');
  @override
  Future<dynamic> isLanguageAvailable(String language) =>
      _rec('isLanguageAvailable:$language', available);
  @override
  Future<dynamic> setLanguage(String language) => _rec('setLanguage:$language');
  @override
  Future<dynamic> get getVoices => _rec('getVoices', [
    {'name': 'Linh', 'locale': 'vi-VN'},
  ]);
  @override
  Future<dynamic> clearVoice() => _rec('clearVoice');
  @override
  Future<dynamic> setVoice(Map<String, String> voice) =>
      _rec('setVoice:${voice['name']}');
  @override
  Future<dynamic> setSpeechRate(double rate) => _rec('setSpeechRate:$rate');
  @override
  Future<dynamic> speak(String text, {bool focus = false}) =>
      _rec('speak:$text');
  @override
  Future<dynamic> stop() => _rec('stop');
}

Future<(FlutterTtsEngine, _SpyTts)> _engine({bool fail = false}) async {
  final spy = _SpyTts()..fail = fail;
  final e = FlutterTtsEngine(spy);
  await pumpEventQueue();
  return (e, spy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final channelCalls = <String>[];

  setUp(() {
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          channelCalls.add(call.method);
          return 1;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('U1 constructor', () {
    test(
      '1-1 không truyền FlutterTts ⇒ tự tạo FlutterTts (gọi kênh flutter_tts)',
      () async {
        final e = FlutterTtsEngine();
        await pumpEventQueue();
        await e.speak('xin chào');
        expect(channelCalls, containsAll(['awaitSpeakCompletion', 'speak']));
      },
    );
    test('1-2 truyền FlutterTts ⇒ dùng đúng instance đó', () async {
      final (_, spy) = await _engine();
      expect(spy.log.first, 'awaitSpeakCompletion:false');
      expect(spy.completionHandler, isNotNull);
      expect(spy.errorHandler, isNotNull);
      expect(spy.progressHandler, isNotNull);
    });
  });

  group('U2–U4 closure handler', () {
    test('2-1 chưa gắn onComplete ⇒ engine báo xong không lỗi', () async {
      final (_, spy) = await _engine();
      expect(() => spy.completionHandler!(), returnsNormally);
    });
    test('2-2 gắn onComplete ⇒ được gọi 1 lần', () async {
      final (e, spy) = await _engine();
      var n = 0;
      e.onComplete = () => n++;
      spy.completionHandler!();
      expect(n, 1);
    });
    test('3-1 chưa gắn onError ⇒ không lỗi', () async {
      final (_, spy) = await _engine();
      expect(() => spy.errorHandler!('boom'), returnsNormally);
    });
    test('3-2 gắn onError ⇒ nhận chuỗi thông báo', () async {
      final (e, spy) = await _engine();
      final got = <String>[];
      e.onError = got.add;
      spy.errorHandler!(42);
      expect(got, ['42']);
    });
    test('4-1 chưa gắn onProgress ⇒ không lỗi', () async {
      final (_, spy) = await _engine();
      expect(() => spy.progressHandler!('abc', 0, 1, 'a'), returnsNormally);
    });
    test('4-2 gắn onProgress ⇒ nhận (start, end)', () async {
      final (e, spy) = await _engine();
      final got = <(int, int)>[];
      e.onProgress = (s, t) => got.add((s, t));
      spy.progressHandler!('xin chào', 4, 8, 'chào');
      expect(got, [(4, 8)]);
    });
  });

  group('U5 _init', () {
    test(
      '5-1 Android ⇒ QUEUE_FLUSH (setQueueMode 0), không cấu hình iOS',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final (_, spy) = await _engine();
        expect(spy.log, contains('setQueueMode:0'));
        expect(
          spy.log.where(
            (l) => l.startsWith('setShared') || l.startsWith('setIos'),
          ),
          isEmpty,
        );
      },
    );
    test(
      '5-2 iOS ⇒ shared instance + playback/duckOthers, không setQueueMode',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final (_, spy) = await _engine();
        expect(
          spy.log,
          containsAll([
            'setSharedInstance:true',
            'setIosAudioCategory:playback:duckOthers',
          ]),
        );
        expect(spy.log.where((l) => l.startsWith('setQueueMode')), isEmpty);
      },
    );
    test('5-3 nền tảng khác (Windows) ⇒ không cấu hình riêng', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final (_, spy) = await _engine();
      expect(spy.log, ['awaitSpeakCompletion:false']);
    });
  });

  group('U6 _guard', () {
    test('6-1 lời gọi thành công ⇒ trả kết quả', () async {
      final (e, spy) = await _engine();
      final r = await e.isLanguageAvailable('vi-VN');
      expect(spy.log.last, 'isLanguageAvailable:vi-VN');
      expect(r, isTrue);
    });
    test('6-2 kênh nền tảng lỗi ⇒ nuốt lỗi (không ném), kết quả mặc định; speak báo onError', () async {
      // Sửa sau Bước 6: trước đây speak nuốt lỗi im lặng; nay báo qua onError (controller thoát `playing`).
      final (e, spy) = await _engine(fail: true);
      final errors = <String>[];
      e.onError = errors.add;
      final r = await Future.wait<Object?>([
        e.speak('x').then((_) => 'ok', onError: (Object x) => x),
        e.isLanguageAvailable('vi-VN').then((v) => v, onError: (Object x) => x),
        e.voicesFor('vi-VN').then((v) => v, onError: (Object x) => x),
      ]);
      expect(
        spy.log,
        containsAll(['speak:x', 'isLanguageAvailable:vi-VN', 'getVoices']),
      );
      expect(r, ['ok', false, isEmpty]);
      expect(errors, hasLength(1));
    });
  });

  group('U7 isLanguageAvailable', () {
    for (final (id, raw, want) in <(String, dynamic, bool)>[
      ('7-1', true, true),
      ('7-2', 1, true),
      ('7-3', 0, false),
    ]) {
      test('$id plugin trả $raw ⇒ $want', () async {
        final (e, spy) = await _engine();
        spy.available = raw;
        expect(await e.isLanguageAvailable('vi-VN'), want);
      });
    }
  });

  group('U8 setVoice', () {
    test(
      '8-1 null ⇒ bỏ giọng chọn, đặt lại ngôn ngữ (giọng mặc định)',
      () async {
        final (e, spy) = await _engine();
        spy.log.clear();
        await e.setVoice(null, 'vi-VN');
        expect(spy.log, ['clearVoice', 'setLanguage:vi-VN']);
      },
    );
    test('8-2 có giọng ⇒ setVoice(map)', () async {
      final (e, spy) = await _engine();
      spy.log.clear();
      await e.setVoice(const TtsVoice(name: 'Linh', locale: 'vi-VN'), 'vi-VN');
      expect(spy.log, ['setVoice:Linh']);
    });
  });
}
