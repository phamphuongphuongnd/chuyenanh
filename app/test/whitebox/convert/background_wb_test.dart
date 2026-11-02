// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/background.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/background/buoc-5-du-lieu-thu.md.
import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';
import 'package:pdf_office/features/convert/engine/background.dart';

/// Đối tượng ném ra mà `toString()` cũng ném → lỗi thoát khỏi `catch` của `_entry`.
class _BadToString {
  @override
  String toString() => throw StateError('toString hỏng');
}

int _job42(void Function(double) report) {
  report(0.5);
  return 42;
}

int _jobNoReport(void Function(double) report) => 7;

int _jobStateError(void Function(double) report) {
  report(0.25);
  throw StateError('x');
}

int _jobCorrupt(void Function(double) report) => throw const CorruptFile('d');

int _jobUnknown(void Function(double) report) => throw const Unknown('c');

int _jobBadToString(void Function(double) report) => throw _BadToString();

/// Như trên nhưng chờ 1 giây trước khi ném (để listener lỗi chắc chắn đã gắn) — chẩn đoán tranh chấp.
int _jobBadToStringLate(void Function(double) report) {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < 1000) {}
  throw _BadToString();
}

ReceivePort _jobUnsendable(void Function(double) report) => ReceivePort();

int _jobBusy(void Function(double) report) {
  report(0.1);
  var i = 0;
  while (true) {
    i++;
    if (i < 0) break;
  }
  return i;
}

/// Bắt kết quả trước (giá trị hoặc lỗi) để vẫn biết nhánh khi khẳng định sai.
Future<Object?> _capture<T>(Future<T> f) => f.then<Object?>((v) => v, onError: (Object e) => e);

void main() {
  group('U1 _entry (quan sát qua runInBackground)', () {
    test('U1-P1 job trả 42 ⇒ kết quả 42', () async {
      final progress = <double>[];
      final r = await _capture(runInBackground(_job42, onProgress: progress.add));
      expect(progress, [0.5]); // nhánh: job chạy, gửi 'p' rồi 'r'
      expect(r, 42);
    });

    test('U1-P2 job ném StateError ⇒ Unknown giữ chuỗi lỗi', () async {
      final progress = <double>[];
      final r = await _capture(runInBackground(_jobStateError, onProgress: progress.add));
      expect(progress, [0.25]); // job đã chạy tới chỗ ném
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause.toString(), contains('Bad state: x'));
    });

    test('U1-P3 job ném CorruptFile ⇒ giữ nguyên CorruptFile', () async {
      final r = await _capture(runInBackground(_jobCorrupt));
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, 'd');
    });

    test('U1-P4 job ném Unknown ⇒ Unknown (gửi dạng chuỗi)', () async {
      final r = await _capture(runInBackground(_jobUnknown));
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause, isA<String>()); // nhánh D3 S: payload là chuỗi
      expect(r.cause.toString(), contains('c'));
    });

    test('U1-P2b job trả giá trị không gửi được ⇒ Unknown', () async {
      final r = await _capture(runInBackground(_jobUnsendable));
      expect(r, isA<Unknown>());
    });
  });

  group('U2 runInBackground (thân chính)', () {
    test('U2-P1 không có cancelToken ⇒ trả kết quả', () async {
      final r = await _capture(runInBackground(_jobNoReport));
      expect(r, 7);
    });

    test('U2-P2 cancelToken chưa huỷ ⇒ trả kết quả', () async {
      final token = CancelToken();
      final r = await _capture(runInBackground(_jobNoReport, cancelToken: token));
      expect(token.isCancelled, isFalse);
      expect(r, 7);
    });

    test('U2-P3 cancelToken đã huỷ trước ⇒ Cancelled, job không chạy', () async {
      final token = CancelToken()..cancel();
      final progress = <double>[];
      final r = await _capture(runInBackground(_job42, onProgress: progress.add, cancelToken: token));
      expect(progress, isEmpty); // nhánh D2 Đ: ném trước khi spawn
      expect(r, isA<Cancelled>());
    });
  });

  group('U3 errorPort handler', () {
    test('U3-P1 lỗi thoát khỏi _entry (toString ném) ⇒ Unknown("isolate: …")', () async {
      final r = await _capture(runInBackground(_jobBadToString).timeout(const Duration(seconds: 20)));
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause.toString(), startsWith('isolate:'));
    });

    test('U3-P1b (chẩn đoán) lỗi thoát khỏi _entry sau 1 giây ⇒ Unknown("isolate: …")', () async {
      final r = await _capture(runInBackground(_jobBadToStringLate).timeout(const Duration(seconds: 20)));
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause.toString(), startsWith('isolate:'));
    });
  });

  group('U4 onCancel handler', () {
    test('U4-P1 huỷ khi đang chạy ⇒ Cancelled', () async {
      final token = CancelToken();
      final progress = <double>[];
      final f = runInBackground(_jobBusy, onProgress: (p) {
        progress.add(p);
        token.cancel(); // huỷ sau khi job đã chạy (đã báo tiến độ)
      }, cancelToken: token);
      final r = await _capture(f.timeout(const Duration(seconds: 20)));
      expect(progress, [0.1]);
      expect(r, isA<Cancelled>());
    });

    test('U4-P2 huỷ sau khi đã xong ⇒ giữ kết quả, không ném', () async {
      final token = CancelToken();
      final r = await _capture(runInBackground(_jobNoReport, cancelToken: token));
      Object? late;
      try {
        token.cancel(); // listener onCancel chạy với completer đã xong
      } catch (e) {
        late = e;
      }
      expect(late, isNull);
      expect(r, 7);
    });
  });

  group('U5 receive handler', () {
    test('U5-P1 tin "r" khi chưa xong ⇒ complete(kết quả)', () async {
      final r = await _capture(runInBackground(_jobNoReport));
      expect(r, 7);
    });

    test('U5-P2 tin "p" có onProgress ⇒ gọi onProgress', () async {
      final progress = <double>[];
      final r = await _capture(runInBackground(_job42, onProgress: progress.add));
      expect(progress, [0.5]);
      expect(r, 42);
    });

    test('U5-P3 tin "p" không có onProgress ⇒ bỏ qua, vẫn ra kết quả', () async {
      final r = await _capture(runInBackground(_job42));
      expect(r, 42);
    });

    test('U5-P5 tin "e" mang AppError ⇒ completeError đúng loại', () async {
      final r = await _capture(runInBackground(_jobCorrupt));
      expect(r, isA<CorruptFile>());
    });

    test('U5-P6 tin "e" mang chuỗi ⇒ Unknown(chuỗi)', () async {
      final r = await _capture(runInBackground(_jobStateError));
      expect(r, isA<Unknown>());
      expect((r as Unknown).cause, isA<String>());
    });
  });
}
