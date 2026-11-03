import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/tts/read_aloud_controller.dart';

import 'fake_tts_engine.dart';

Future<(ReadAloudController, FakeTtsEngine, List<int>)> _ready(
  List<String> paragraphs, {
  bool available = true,
}) async {
  final engine = FakeTtsEngine(available: available);
  final announced = <int>[];
  final c = ReadAloudController(
    engine: engine,
    paragraphs: paragraphs,
    onParagraph: announced.add,
  );
  addTearDown(c.dispose);
  await c.setLocale('vi-VN');
  return (c, engine, announced);
}

class _ThrowingSpeakEngine extends FakeTtsEngine {
  @override
  Future<void> speak(String text) async => throw StateError('hỏng');
}

void main() {
  test('speak ném lỗi: ghi lỗi, thoát khỏi playing', () async {
    final engine = _ThrowingSpeakEngine();
    final c = ReadAloudController(engine: engine, paragraphs: ['A.']);
    addTearDown(c.dispose);
    await c.setLocale('vi-VN');
    await c.play();
    expect(c.error, contains('hỏng'));
    expect(c.status, isNot(ReadAloudStatus.playing));
  });

  test('engine báo onError khi đang đọc: không kẹt playing', () async {
    final (c, e, _) = await _ready(['A.']);
    await c.play();
    e.onError?.call('lỗi speak');
    expect(c.error, 'lỗi speak');
    expect(c.isPlaying, isFalse);
  });

  test(
    'kiểm tra ngôn ngữ: có giọng → sẵn sàng, đặt ngôn ngữ và tốc độ',
    () async {
      final (c, e, _) = await _ready(['A']);
      expect(e.checked, ['vi-VN']);
      expect(e.languages, ['vi-VN']);
      expect(e.speed, 1.0);
      expect(c.status, ReadAloudStatus.idle);
    },
  );

  test('không có giọng → unavailable; cài xong kiểm tra lại → idle', () async {
    final (c, e, _) = await _ready(['A'], available: false);
    expect(c.status, ReadAloudStatus.unavailable);
    await c.play();
    expect(e.spoken, isEmpty);
    e.available = true;
    await c.recheck();
    expect(c.status, ReadAloudStatus.idle);
  });

  Future<ReadAloudController> withEngines(FakeTtsEngine e) async {
    final c = ReadAloudController(engine: e, paragraphs: ['A']);
    addTearDown(c.dispose);
    await c.setLocale('vi-VN');
    return c;
  }

  test('bộ đọc mặc định thiếu tiếng, bộ thứ hai có → chuyển sang và đọc được', () async {
    final e = FakeTtsEngine(
      installedEngines: ['samsung', 'google'],
      engineHasLanguage: {'samsung': false, 'google': true},
      current: 'samsung',
    );
    final c = await withEngines(e);
    expect(e.engineSwitches, ['google']);
    expect(e.current, 'google');
    expect(c.status, ReadAloudStatus.idle);
    await c.play();
    expect(e.spoken, ['A']);
  });

  test('không bộ đọc nào có tiếng → unavailable, trả về bộ ban đầu', () async {
    final e = FakeTtsEngine(
      installedEngines: ['samsung', 'google'],
      engineHasLanguage: {'samsung': false, 'google': false},
      current: 'samsung',
    );
    final c = await withEngines(e);
    expect(c.status, ReadAloudStatus.unavailable);
    expect(e.engineSwitches, ['google', 'samsung']);
    expect(e.current, 'samsung');
  });

  test('bộ đọc mặc định đã có tiếng → không đổi bộ', () async {
    final e = FakeTtsEngine(
      installedEngines: ['samsung', 'google'],
      engineHasLanguage: {'samsung': true, 'google': true},
      current: 'samsung',
    );
    final c = await withEngines(e);
    expect(c.status, ReadAloudStatus.idle);
    expect(e.engineSwitches, isEmpty);
  });

  test('đọc lần lượt, bỏ đoạn rỗng, hết thì về đầu', () async {
    final (c, e, ann) = await _ready(['Một.', '', 'Ba.']);
    await c.play();
    expect(e.spoken, ['Một.']);
    e.finish();
    await pumpEventQueue();
    expect(e.spoken, ['Một.', 'Ba.']);
    expect(ann, [0, 2]);
    expect(c.currentParagraph, 2);
    e.finish();
    await pumpEventQueue();
    expect(c.status, ReadAloudStatus.idle);
    expect(c.currentParagraph, 0);
  });

  test('đoạn trước / sau khi đang đọc', () async {
    final (c, e, ann) = await _ready(['A.', 'B.', 'C.']);
    expect(c.canPrev, isFalse);
    await c.play();
    await c.next();
    expect(e.spoken.last, 'B.');
    expect(c.canPrev, isTrue);
    await c.next();
    expect(e.spoken.last, 'C.');
    expect(c.canNext, isFalse);
    await c.previous();
    expect(e.spoken.last, 'B.');
    expect(ann, [0, 1, 2, 1]);
  });

  test('tạm dừng rồi phát tiếp từ từ đang đọc (theo onProgress)', () async {
    final (c, e, _) = await _ready(['Xin chào thế giới.']);
    await c.play();
    e.onProgress?.call(4, 8); // đang đọc "chào"
    await c.pause();
    expect(c.status, ReadAloudStatus.paused);
    expect(e.stops, 1);
    await c.play();
    expect(e.spoken.last, 'chào thế giới.');
  });

  test('dừng: lần phát sau đọc lại từ đầu đoạn, báo lại onParagraph', () async {
    final (c, e, ann) = await _ready(['A.', 'B.']);
    await c.play();
    await c.next();
    await c.stop();
    expect(c.status, ReadAloudStatus.idle);
    expect(c.currentParagraph, 1);
    await c.play();
    expect(e.spoken.last, 'B.');
    expect(ann, [0, 1, 1]);
  });

  test(
    'đổi tốc độ khi đang đọc → đọc lại phần hiện tại với tốc độ mới',
    () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      await c.setSpeed(1.5);
      expect(e.speed, 1.5);
      expect(e.spoken, ['A.', 'A.']);
    },
  );

  test('dispose khi đang đọc thì dừng engine và gỡ callback', () async {
    final e = FakeTtsEngine();
    final c = ReadAloudController(engine: e, paragraphs: ['A.']);
    await c.setLocale('vi-VN');
    await c.play();
    c.dispose();
    expect(e.stops, 1);
    expect(e.onComplete, isNull);
  });

  group('nối thêm đoạn (dàn trang tiến dần)', () {
    test('appendParagraphs: giữ vị trí / trạng thái đang đọc, đoạn mới đánh số tiếp', () async {
      final (c, e, ann) = await _ready(['A.', 'B.']);
      await c.play();
      c.appendParagraphs(['C.', 'D.']);
      expect(c.isPlaying, isTrue);
      expect(c.paragraphCount, 4);
      expect(c.currentParagraph, 0);
      expect(e.stops, 0);
      for (var i = 0; i < 3; i++) {
        e.finish();
        await Future<void>.delayed(Duration.zero);
      }
      expect(e.spoken, ['A.', 'B.', 'C.', 'D.']);
      expect(ann, [0, 1, 2, 3]);
    });

    test('appendParagraphs rỗng / đoạn rỗng không đổi gì đáng kể', () async {
      final (c, _, _) = await _ready(['A.']);
      c.appendParagraphs(const []);
      expect(c.paragraphCount, 1);
      c.appendParagraphs(['  ']);
      expect(c.paragraphCount, 2);
      expect(c.canNext, isFalse);
    });

    test('đọc hết phần có khi còn đoạn sắp tới: chờ (vẫn playing), nối thêm thì đọc tiếp', () async {
      final (c, e, ann) = await _ready(['A.']);
      c.setMoreComing(true);
      await c.play();
      e.finish();
      expect(c.isPlaying, isTrue);
      expect(e.spoken, ['A.']);

      c.appendParagraphs(['B.']);
      expect(e.spoken, ['A.', 'B.']);
      expect(c.currentParagraph, 1);
      expect(ann, [0, 1]);
    });

    test('đang chờ mà hết đoạn sắp tới (setMoreComing false): kết thúc như đọc hết', () async {
      final (c, e, _) = await _ready(['A.']);
      c.setMoreComing(true);
      await c.play();
      e.finish();
      expect(c.isPlaying, isTrue);
      c.setMoreComing(false);
      expect(c.status, ReadAloudStatus.idle);
      expect(c.currentParagraph, 0);
    });

    test('đang chờ rồi nối thêm toàn đoạn rỗng: vẫn chờ, không ném lỗi', () async {
      final (c, e, _) = await _ready(['A.']);
      c.setMoreComing(true);
      await c.play();
      e.finish();
      c.appendParagraphs(['   ']);
      expect(c.isPlaying, isTrue);
      expect(e.spoken, ['A.']);
    });

    test('không còn đoạn sắp tới: đọc hết thì về idle như cũ', () async {
      final (c, e, _) = await _ready(['A.']);
      await c.play();
      e.finish();
      expect(c.status, ReadAloudStatus.idle);
    });

    test('đang chờ ở cuối mà tạm dừng, rồi nối thêm: không tự đọc', () async {
      final (c, e, _) = await _ready(['A.']);
      c.setMoreComing(true);
      await c.play();
      e.finish();
      await c.pause();
      c.appendParagraphs(['B.']);
      expect(c.status, ReadAloudStatus.paused);
      expect(e.spoken, ['A.']);
    });
  });
}
