// Kiểm thử hộp trắng (A15) — read_aloud_controller.dart. Mã bộ theo
// test-output/whitebox/tts/read_aloud_controller/buoc-5-du-lieu-thu.md. Engine giả qua interface TtsEngine
// (có cổng chờ để tạo tình huống chen ngang lúc await).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/tts/read_aloud_controller.dart';
import 'package:pdf_office/features/tts/tts_engine.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';

class _Engine extends TtsEngine {
  bool available = true;
  List<TtsVoice> voices = const [TtsVoice(name: 'Linh', locale: 'vi-VN')];
  final checked = <String>[];
  final languages = <String>[];
  final spoken = <String>[];
  final voiceSet = <(TtsVoice?, String)>[];
  final speeds = <double>[];
  int stops = 0;

  /// Cổng dùng một lần.
  Completer<void>? availGate;
  Completer<void>? voicesGate;
  Completer<void>? stopGate;
  void Function()? onStopCall;

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    checked.add(locale);
    final g = availGate;
    availGate = null;
    if (g != null) await g.future;
    return available;
  }

  // Chỉ có một bộ đọc (không có bộ khác để chuyển) → hành vi cũ giữ nguyên.
  @override
  Future<List<String>> engines() async => const [];

  @override
  Future<String?> currentEngine() async => null;

  @override
  Future<void> useEngine(String engine) async {}

  @override
  Future<void> setLanguage(String locale) async => languages.add(locale);

  @override
  Future<List<TtsVoice>> voicesFor(String locale) async {
    final g = voicesGate;
    voicesGate = null;
    if (g != null) await g.future;
    return voices;
  }

  @override
  Future<void> setVoice(TtsVoice? voice, String locale) async =>
      voiceSet.add((voice, locale));

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {
    stops++;
    final cb = onStopCall;
    onStopCall = null;
    cb?.call();
    final g = stopGate;
    stopGate = null;
    if (g != null) await g.future;
  }
}

typedef _Ctx = (ReadAloudController, _Engine, List<int>);

/// Controller đã kiểm giọng xong (idle).
Future<_Ctx> _ready(List<String> paragraphs, {bool announce = true}) async {
  final e = _Engine();
  final ann = <int>[];
  final c = ReadAloudController(
    engine: e,
    paragraphs: paragraphs,
    onParagraph: announce ? ann.add : null,
  );
  await c.setLocale('vi-VN');
  return (c, e, ann);
}

/// Controller chưa gọi setLocale (checking).
(ReadAloudController, _Engine) _checking(List<String> paragraphs) {
  final e = _Engine();
  return (ReadAloudController(engine: e, paragraphs: paragraphs), e);
}

void main() {
  group('C1 currentParagraph', () {
    test('1-1 hàng đợi rỗng ⇒ 0', () async {
      final (c, _, _) = await _ready(const []);
      expect(c.hasContent, isFalse);
      expect(c.currentParagraph, 0);
    });
    test('1-2 có nội dung ⇒ chỉ số đoạn gốc của phần đang ở', () async {
      final (c, _, _) = await _ready(['', 'B.']);
      expect(c.currentParagraph, 1);
    });
  });

  group('C2 isReady', () {
    test('2-1 idle ⇒ true', () async {
      final (c, _, _) = await _ready(['A.']);
      expect(c.status, ReadAloudStatus.idle);
      expect(c.isReady, isTrue);
    });
    test('2-2 playing ⇒ true', () async {
      final (c, _, _) = await _ready(['A.']);
      await c.play();
      expect(c.status, ReadAloudStatus.playing);
      expect(c.isReady, isTrue);
    });
    test('2-3 paused ⇒ true', () async {
      final (c, _, _) = await _ready(['A.']);
      await c.play();
      await c.pause();
      expect(c.status, ReadAloudStatus.paused);
      expect(c.isReady, isTrue);
    });
    test('2-4 checking ⇒ false', () {
      final (c, _) = _checking(['A.']);
      expect(c.status, ReadAloudStatus.checking);
      expect(c.isReady, isFalse);
    });
  });

  group('C3 canPrev', () {
    test('3-1 chưa sẵn sàng ⇒ false', () {
      final (c, _) = _checking(['A.', 'B.']);
      expect(c.canPrev, isFalse);
    });
    test('3-2 đang ở đoạn đầu ⇒ false', () async {
      final (c, _, _) = await _ready(['A.', 'B.']);
      expect(c.canPrev, isFalse);
    });
    test('3-3 đang ở đoạn 2 ⇒ true', () async {
      final (c, _, _) = await _ready(['A.', 'B.']);
      await c.next();
      expect(c.currentParagraph, 1);
      expect(c.canPrev, isTrue);
    });
  });

  group('C4 canNext', () {
    test('4-1 chưa sẵn sàng ⇒ false', () {
      final (c, _) = _checking(['A.', 'B.']);
      expect(c.canNext, isFalse);
    });
    test('4-2 hàng đợi rỗng ⇒ false', () async {
      final (c, _, _) = await _ready(const []);
      expect(c.canNext, isFalse);
    });
    test('4-3 đang ở đoạn cuối ⇒ false', () async {
      final (c, _, _) = await _ready(['A.']);
      expect(c.canNext, isFalse);
    });
    test('4-4 còn đoạn sau ⇒ true', () async {
      final (c, _, _) = await _ready(['A.', 'B.']);
      expect(c.canNext, isTrue);
    });
  });

  group('C5 setParagraphs', () {
    test('5-1 đang kiểm giọng ⇒ giữ checking, không dừng engine', () async {
      final (c, e) = _checking(['A.']);
      await c.setParagraphs(['X.', 'Y.']);
      expect(e.stops, 0);
      expect(c.status, ReadAloudStatus.checking);
      expect(c.paragraphCount, 2);
    });
    test('5-2 idle ⇒ idle, về đầu, không dừng engine', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.next();
      await c.setParagraphs(['X.', 'Y.']);
      expect(e.stops, 0);
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 0);
    });
    test('5-3 đang đọc ⇒ dừng engine, idle, về đầu', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      await c.next();
      final before = e.stops;
      await c.setParagraphs(['X.', 'Y.']);
      expect(e.stops, before + 1);
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 0);
    });
  });

  group('C6 setLocale', () {
    test('6-1 cùng locale ⇒ không kiểm lại', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setLocale('vi-VN');
      expect(e.checked, ['vi-VN']);
    });
    test('6-2 locale mới khi idle ⇒ không dừng, kiểm giọng mới ⇒ idle', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setLocale('en-US');
      expect(e.stops, 0);
      expect(e.checked, ['vi-VN', 'en-US']);
      expect(c.locale, 'en-US');
      expect(c.status, ReadAloudStatus.idle);
    });
    test('6-3 locale mới khi đang đọc ⇒ dừng rồi kiểm giọng', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.setLocale('en-US');
      expect(e.stops, 1);
      expect(e.checked.last, 'en-US');
      expect(c.status, ReadAloudStatus.idle);
      expect(c.voice, isNull);
    });
  });

  group('C7 recheck', () {
    test('7-1 chưa có locale ⇒ không làm gì', () async {
      final (c, e) = _checking(['A.']);
      await c.recheck();
      expect(e.checked, isEmpty);
      expect(c.status, ReadAloudStatus.checking);
    });
    test('7-2 có locale (vừa cài giọng) ⇒ kiểm lại ⇒ idle', () async {
      final (c, e) = _checking(['A.']);
      e.available = false;
      await c.setLocale('vi-VN');
      expect(c.status, ReadAloudStatus.unavailable);
      e.available = true;
      await c.recheck();
      expect(e.checked, ['vi-VN', 'vi-VN']);
      expect(c.status, ReadAloudStatus.idle);
    });
  });

  group('C8 _checkLanguage', () {
    test('8-1 có giọng ⇒ đặt ngôn ngữ, nạp giọng, đặt tốc độ ⇒ idle', () async {
      final (c, e, _) = await _ready(['A.']);
      expect(e.languages, ['vi-VN']);
      expect(e.speeds, [1.0]);
      expect(c.voices.map((v) => v.name), ['Linh']);
      expect(c.status, ReadAloudStatus.idle);
    });
    test('8-2 dispose trong lúc hỏi giọng ⇒ không đặt ngôn ngữ', () async {
      final (c, e) = _checking(['A.']);
      final gate = Completer<void>();
      e.availGate = gate;
      final f = c.setLocale('vi-VN');
      c.dispose();
      gate.complete();
      await f;
      expect(e.checked, ['vi-VN']);
      expect(e.languages, isEmpty);
    });
    test('8-3 đổi locale trong lúc hỏi giọng ⇒ lần cũ bỏ, chỉ đặt locale mới', () async {
      final (c, e) = _checking(['A.']);
      final gate = Completer<void>();
      e.availGate = gate;
      final f1 = c.setLocale('vi-VN');
      await c.setLocale('en-US');
      gate.complete();
      await f1;
      expect(e.checked, ['vi-VN', 'en-US']);
      expect(e.languages, ['en-US']);
      expect(c.status, ReadAloudStatus.idle);
      addTearDown(c.dispose);
    });
    test('8-4 không có giọng ⇒ unavailable, không đặt ngôn ngữ', () async {
      final (c, e) = _checking(['A.']);
      e.available = false;
      await c.setLocale('vi-VN');
      expect(e.languages, isEmpty);
      expect(c.status, ReadAloudStatus.unavailable);
    });
    test('8-5 dispose trong lúc nạp giọng ⇒ không cập nhật giọng', () async {
      final (c, e) = _checking(['A.']);
      final gate = Completer<void>();
      e.voicesGate = gate;
      final f = c.setLocale('vi-VN');
      await pumpEventQueue();
      expect(e.languages, ['vi-VN']);
      c.dispose();
      gate.complete();
      await f;
      expect(c.voices, isEmpty);
      expect(c.status, ReadAloudStatus.checking);
    });
    test('8-6 đổi locale trong lúc nạp giọng ⇒ lần cũ không ghi đè', () async {
      final (c, e) = _checking(['A.']);
      final gate = Completer<void>();
      e.voicesGate = gate;
      final f1 = c.setLocale('vi-VN');
      await pumpEventQueue();
      e.voices = const [TtsVoice(name: 'Sam', locale: 'en-US')];
      await c.setLocale('en-US');
      e.voices = const [TtsVoice(name: 'Cu', locale: 'vi-VN')]; // kết quả muộn của lần cũ
      gate.complete();
      await f1;
      expect(c.locale, 'en-US');
      expect(c.voices.map((v) => v.name), ['Sam']);
      expect(c.status, ReadAloudStatus.idle);
      addTearDown(c.dispose);
    });
  });

  group('C9 play', () {
    test('9-1 chưa sẵn sàng ⇒ không đọc', () async {
      final (c, e) = _checking(['A.']);
      await c.play();
      expect(e.spoken, isEmpty);
      expect(c.status, ReadAloudStatus.checking);
    });
    test('9-2 không có nội dung ⇒ không đọc, vẫn idle', () async {
      final (c, e, _) = await _ready(const ['  ']);
      await c.play();
      expect(e.spoken, isEmpty);
      expect(c.status, ReadAloudStatus.idle);
    });
    test('9-3 đang đọc ⇒ không đọc chồng', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.play();
      expect(e.spoken, ['A.']);
    });
    test('9-4 idle ⇒ playing, đọc phần đầu', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      expect(c.status, ReadAloudStatus.playing);
      expect(e.spoken, ['A.']);
    });
  });

  group('C10 pause / C11 togglePlay', () {
    test('10-1 không đang đọc ⇒ không dừng engine', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.pause();
      expect(e.stops, 0);
      expect(c.status, ReadAloudStatus.idle);
    });
    test('10-2 đang đọc ⇒ paused, dừng engine', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.pause();
      expect(e.stops, 1);
      expect(c.status, ReadAloudStatus.paused);
    });
    test('11-1 idle ⇒ toggle = phát', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.togglePlay();
      expect(e.spoken, ['A.']);
      expect(c.status, ReadAloudStatus.playing);
    });
    test('11-2 đang đọc ⇒ toggle = tạm dừng', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.togglePlay();
      expect(e.stops, 1);
      expect(c.status, ReadAloudStatus.paused);
    });
  });

  group('C12 stop', () {
    test('12-1 chưa sẵn sàng ⇒ không làm gì', () async {
      final (c, e) = _checking(['A.']);
      await c.stop();
      expect(e.stops, 0);
      expect(c.status, ReadAloudStatus.checking);
    });
    test('12-2 đang tạm dừng ⇒ idle, đầu đoạn hiện tại, không dừng engine lần nữa', () async {
      final (c, e, _) = await _ready(['Xin chào thế giới.']);
      await c.play();
      e.onProgress?.call(4, 8);
      await c.pause();
      final before = e.stops;
      await c.stop();
      expect(e.stops, before);
      expect(c.status, ReadAloudStatus.idle);
      await c.play();
      expect(e.spoken.last, 'Xin chào thế giới.');
    });
    test('12-3 đang đọc ⇒ idle, dừng engine', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.stop();
      expect(e.stops, 1);
      expect(c.status, ReadAloudStatus.idle);
    });
  });

  group('C13 next / C14 previous', () {
    test('13-1 không có đoạn sau ⇒ đứng yên', () async {
      final (c, _, ann) = await _ready(['A.']);
      await c.next();
      expect(c.currentParagraph, 0);
      expect(ann, isEmpty);
    });
    test('13-2 có đoạn sau ⇒ sang đoạn sau (bỏ đoạn rỗng)', () async {
      final (c, _, ann) = await _ready(['A.', '', 'C.']);
      await c.next();
      expect(c.currentParagraph, 2);
      expect(ann, [2]);
    });
    test('14-1 đang ở đoạn đầu ⇒ đứng yên', () async {
      final (c, _, ann) = await _ready(['A.', 'B.']);
      await c.previous();
      expect(c.currentParagraph, 0);
      expect(ann, isEmpty);
    });
    test('14-2 ở đoạn 3 ⇒ về đoạn có chữ trước đó (bỏ đoạn rỗng)', () async {
      final (c, _, ann) = await _ready(['A.', '', 'C.']);
      await c.next();
      await c.previous();
      expect(c.currentParagraph, 0);
      expect(ann, [2, 0]);
    });
  });

  group('C15 setSpeed / C16 setVoice', () {
    test('15-1 cùng tốc độ ⇒ không gọi engine', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setSpeed(1.0);
      expect(e.speeds, [1.0]);
    });
    test('15-2 tốc độ mới ⇒ engine.setSpeed', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setSpeed(1.5);
      expect(e.speeds, [1.0, 1.5]);
      expect(c.speed, 1.5);
    });
    test('16-1 cùng giọng (null) ⇒ không gọi engine', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setVoice(null);
      expect(e.voiceSet, isEmpty);
    });
    test('16-2 chưa có locale ⇒ nhớ giọng, chưa gọi engine', () async {
      final (c, e) = _checking(['A.']);
      const v = TtsVoice(name: 'Linh', locale: 'vi-VN');
      await c.setVoice(v);
      expect(e.voiceSet, isEmpty);
      expect(c.voice, v);
    });
    test('16-3 có locale ⇒ engine.setVoice(giọng, locale)', () async {
      final (c, e, _) = await _ready(['A.']);
      const v = TtsVoice(name: 'Linh', locale: 'vi-VN');
      await c.setVoice(v);
      expect(e.voiceSet, [(v, 'vi-VN')]);
    });
  });

  group('C17 _restartIfPlaying (qua setSpeed)', () {
    test('17-1 không đang đọc ⇒ không dừng/đọc lại', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.setSpeed(2.0);
      expect(e.stops, 0);
      expect(e.spoken, isEmpty);
    });
    test('17-2 đang đọc ⇒ dừng rồi đọc lại phần hiện tại', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.setSpeed(2.0);
      expect(e.stops, 1);
      expect(e.spoken, ['A.', 'A.']);
    });
    test('17-3 lỗi engine lúc dừng (chuyển paused) ⇒ không đọc lại', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      e.onStopCall = () => e.onError?.call('lỗi');
      await c.setSpeed(2.0);
      expect(e.stops, 1);
      expect(e.spoken, ['A.']);
      expect(c.status, ReadAloudStatus.paused);
    });
  });

  group('C18 _jumpTo (qua next)', () {
    test('18-1 idle ⇒ chỉ chuyển đoạn, vẫn idle, không dừng', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.next();
      expect(e.stops, 0);
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 1);
    });
    test('18-2 đang tạm dừng ⇒ chuyển đoạn và về idle', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      await c.pause();
      await c.next();
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 1);
      expect(e.spoken, ['A.']);
    });
    test('18-3 đang đọc ⇒ dừng, đọc đoạn mới', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      await c.next();
      expect(e.stops, 1);
      expect(e.spoken, ['A.', 'B.']);
    });
    test('18-4 lỗi engine lúc dừng ⇒ không đọc đoạn mới', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      e.onStopCall = () => e.onError?.call('lỗi');
      await c.next();
      expect(e.spoken, ['A.']);
      expect(c.status, ReadAloudStatus.paused);
      expect(c.currentParagraph, 1);
    });
    test('18-5 chuyển tiếp lần nữa trong lúc dừng ⇒ chỉ đọc đoạn sau cùng', () async {
      final (c, e, _) = await _ready(['A.', 'B.', 'C.']);
      await c.play();
      e.onStopCall = () => c.next();
      await c.next();
      await pumpEventQueue();
      expect(e.spoken, ['A.', 'C.']);
      expect(c.currentParagraph, 2);
    });
  });

  group('C19 _firstSegOf', () {
    test('19-1 forward tìm thấy ⇒ phần đầu đoạn sau', () async {
      final (c, _, _) = await _ready(['A.', 'B.']);
      await c.next();
      expect(c.currentParagraph, 1);
    });
    test('19-3 lùi tìm thấy ⇒ phần đầu đoạn đó (đoạn dài nhiều phần)', () async {
      final long = List.filled(1200, 'chữ').join(' '); // > 3500 ký tự ⇒ nhiều phần
      final (c, e, _) = await _ready([long, 'B.']);
      await c.play();
      e.finish();
      await pumpEventQueue();
      expect(c.currentParagraph, 0);
      await c.stop();
      await c.play();
      expect(e.spoken.last, e.spoken.first);
    });
    test('19-4 hàng đợi rỗng, dừng ⇒ về 0, không lỗi', () async {
      final (c, _, _) = await _ready(const ['']);
      await c.stop();
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 0);
      expect(c.canPrev, isFalse);
    });
  });

  group('C20 _announce', () {
    test('20-2 cùng đoạn đã báo ⇒ không báo lại', () async {
      final (c, _, ann) = await _ready(['A.']);
      await c.play();
      await c.setSpeed(1.5);
      expect(ann, [0]);
    });
    test('20-3 không có onParagraph ⇒ vẫn đọc, không lỗi', () async {
      final (c, e, _) = await _ready(['A.'], announce: false);
      await c.play();
      expect(e.spoken, ['A.']);
    });
    test('20-4 đoạn mới + có onParagraph ⇒ báo', () async {
      final (c, _, ann) = await _ready(['A.']);
      await c.play();
      expect(ann, [0]);
    });
  });

  group('C21 _speakCurrent', () {
    test('21-1 hàng đợi bị làm rỗng ngay khi bắt đầu phát ⇒ không đọc', () async {
      final (c, e, _) = await _ready(['A.']);
      var once = true;
      c.addListener(() {
        if (once && c.status == ReadAloudStatus.playing) {
          once = false;
          c.setParagraphs(const []);
        }
      });
      await c.play();
      await pumpEventQueue();
      expect(e.spoken, isEmpty);
      expect(c.status, ReadAloudStatus.idle);
    });
    test('21-3 vị trí 0 ⇒ đọc cả phần', () async {
      final (c, e, _) = await _ready(['Xin chào.']);
      await c.play();
      expect(e.spoken, ['Xin chào.']);
    });
    test('21-4 vị trí > 0 (sau tạm dừng) ⇒ đọc tiếp từ từ đang đọc', () async {
      final (c, e, _) = await _ready(['Xin chào thế giới.']);
      await c.play();
      e.onProgress?.call(4, 8);
      await c.pause();
      await c.play();
      expect(e.spoken.last, 'chào thế giới.');
    });
  });

  group('C22 _handleProgress', () {
    Future<String> resumeAfter(void Function(_Engine e, ReadAloudController c) act) async {
      final (c, e, _) = await _ready(['Xin chào thế giới.']);
      await c.play();
      act(e, c);
      await c.pause();
      await c.play();
      return e.spoken.last;
    }

    test('22-1 tiến độ đến khi đã tạm dừng ⇒ bỏ qua', () async {
      final (c, e, _) = await _ready(['Xin chào thế giới.']);
      await c.play();
      await c.pause();
      e.onProgress?.call(4, 8);
      await c.play();
      expect(e.spoken.last, 'Xin chào thế giới.');
    });
    test('22-3 vị trí âm ⇒ bỏ qua', () async {
      expect(await resumeAfter((e, _) => e.onProgress?.call(-10, -5)), 'Xin chào thế giới.');
    });
    test('22-4 vị trí vượt độ dài ⇒ bỏ qua', () async {
      expect(await resumeAfter((e, _) => e.onProgress?.call(999, 1000)), 'Xin chào thế giới.');
    });
    test('22-5 vị trí hợp lệ ⇒ nhớ để đọc tiếp', () async {
      expect(await resumeAfter((e, _) => e.onProgress?.call(9, 12)), 'thế giới.');
    });
  });

  group('C23 _handleComplete', () {
    test('23-1 xong khi đang tạm dừng ⇒ bỏ qua', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      await c.pause();
      e.finish();
      await pumpEventQueue();
      expect(e.spoken, ['A.']);
      expect(c.status, ReadAloudStatus.paused);
    });
    test('23-2 callback cũ gọi sau dispose ⇒ bỏ qua', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      final cb = e.onComplete!;
      c.dispose();
      cb();
      await pumpEventQueue();
      expect(e.spoken, ['A.']);
    });
    test('23-3 xong phần cuối ⇒ về đầu, idle', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      await c.next();
      e.finish();
      await pumpEventQueue();
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 0);
    });
    test('23-4 còn phần sau ⇒ đọc tiếp', () async {
      final (c, e, _) = await _ready(['A.', 'B.']);
      await c.play();
      e.finish();
      await pumpEventQueue();
      expect(e.spoken, ['A.', 'B.']);
      expect(c.currentParagraph, 1);
    });
  });

  group('C24 _handleError', () {
    test('24-1 callback lỗi cũ sau dispose ⇒ bỏ qua', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      final cb = e.onError!;
      c.dispose();
      cb('lỗi');
      expect(c.error, isNull);
    });
    test('24-2 lỗi khi đang đọc ⇒ ghi lỗi, tạm dừng', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      e.onError?.call('lỗi');
      expect(c.error, 'lỗi');
      expect(c.status, ReadAloudStatus.paused);
    });
    test('24-3 lỗi khi idle ⇒ ghi lỗi, giữ idle', () async {
      final (c, e, _) = await _ready(['A.']);
      e.onError?.call('lỗi');
      expect(c.error, 'lỗi');
      expect(c.status, ReadAloudStatus.idle);
    });
  });

  group('C25 _notify', () {
    test('25-1 chưa dispose ⇒ báo listener', () async {
      final (c, _, _) = await _ready(['A.']);
      var n = 0;
      c.addListener(() => n++);
      await c.play();
      expect(n, greaterThan(0));
    });
    test('25-2 dispose trong lúc đổi locale đang chờ dừng engine ⇒ không báo, không lỗi', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      final gate = Completer<void>();
      e.stopGate = gate;
      final f = c.setLocale('en-US').then<Object?>((_) => 'ok', onError: (Object x) => x);
      c.dispose();
      gate.complete();
      expect(await f, 'ok');
      expect(e.checked, ['vi-VN', 'en-US']);
      expect(e.languages, ['vi-VN']);
    });
  });

  group('C26 dispose', () {
    test('26-1 idle ⇒ không dừng engine, gỡ callback', () async {
      final (c, e, _) = await _ready(['A.']);
      c.dispose();
      expect(e.stops, 0);
      expect(e.onComplete, isNull);
    });
    test('26-2 đang đọc ⇒ dừng engine, gỡ callback', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      c.dispose();
      expect(e.stops, 1);
      expect(e.onComplete, isNull);
    });
    test('26-3 đang tạm dừng ⇒ dừng engine, gỡ callback', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.pause();
      c.dispose();
      expect(e.stops, 2);
      expect(e.onComplete, isNull);
    });
    test('26-4 engine đã thuộc controller khác ⇒ không gỡ callback của controller kia', () async {
      final (c1, e, _) = await _ready(['A.']);
      final c2 = ReadAloudController(engine: e, paragraphs: ['B.']);
      c1.dispose();
      expect(e.onComplete, isNotNull);
      c2.dispose();
      expect(e.onComplete, isNull);
    });
  });
}

extension on _Engine {
  void finish() => onComplete?.call();
}
