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

void main() {
  test('kiểm tra ngôn ngữ: có giọng → sẵn sàng, đặt ngôn ngữ và tốc độ', () async {
    final (c, e, _) = await _ready(['A']);
    expect(e.checked, ['vi-VN']);
    expect(e.languages, ['vi-VN']);
    expect(e.speed, 1.0);
    expect(c.status, ReadAloudStatus.idle);
  });

  test('không có giọng → unavailable; cài xong kiểm tra lại → idle', () async {
    final (c, e, _) = await _ready(['A'], available: false);
    expect(c.status, ReadAloudStatus.unavailable);
    await c.play();
    expect(e.spoken, isEmpty);
    e.available = true;
    await c.recheck();
    expect(c.status, ReadAloudStatus.idle);
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

  test('đổi tốc độ khi đang đọc → đọc lại phần hiện tại với tốc độ mới', () async {
    final (c, e, _) = await _ready(['A.']);
    await c.play();
    await c.setSpeed(1.5);
    expect(e.speed, 1.5);
    expect(e.spoken, ['A.', 'A.']);
  });

  test('dispose khi đang đọc thì dừng engine và gỡ callback', () async {
    final e = FakeTtsEngine();
    final c = ReadAloudController(engine: e, paragraphs: ['A.']);
    await c.setLocale('vi-VN');
    await c.play();
    c.dispose();
    expect(e.stops, 1);
    expect(e.onComplete, isNull);
  });
}
