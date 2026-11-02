// Kiểm thử hộp trắng (Bước 6) cho lib/features/pdf_tools/engine/isolate_job.dart.
// Mã bộ = mã ở test-output/whitebox/pdf-tools/isolate_job/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 — không chỉnh cho khớp code; FAIL thật giữ nguyên.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';
import 'package:pdf_office/features/pdf_tools/engine/isolate_job.dart';

// ---- Job mẫu (top-level, chạy trong isolate) ----

Future<Object?> _okJob(Map<String, Object?> a, JobPort port) async {
  final progress = a['progress'] as List?;
  if (progress != null) {
    for (final v in progress) {
      port.progress((v as num).toDouble());
    }
  }
  return a['value'];
}

Future<Object?> _throwJob(Map<String, Object?> a, JobPort port) async {
  switch (a['kind']) {
    case 'wrong':
      throw const WrongPassword();
    case 'required':
      throw const PasswordRequired();
    case 'corrupt':
      throw const CorruptFile('bad xref');
    case 'corruptNull':
      throw const CorruptFile();
    case 'range':
      throw RangeError.range(5, 0, 3, 'idx');
    case 'argument':
      throw ArgumentError('bad arg');
    case 'format':
      throw const FormatException('bad fmt');
    default:
      throw StateError('boom');
  }
}

Future<Object?> _sideEffectJob(Map<String, Object?> a, JobPort port) async {
  File(a['path']! as String).writeAsStringSync('ran');
  return 'ran';
}

Future<Object?> _writeThenThrowJob(Map<String, Object?> a, JobPort port) async {
  final path = a['path']! as String;
  File(path).writeAsStringSync('partial');
  port.fileWritten(path);
  throw ArgumentError('after write');
}

Future<Object?> _floodJob(Map<String, Object?> a, JobPort port) async {
  for (var i = 1; i <= 200; i++) {
    port.progress(i / 200);
  }
  await Completer<void>().future; // chờ mãi tới khi bị kill
  return null;
}

Future<Object?> _exitJob(Map<String, Object?> a, JobPort port) async {
  Isolate.exit();
}

Future<Object?> _asyncErrorJob(Map<String, Object?> a, JobPort port) async {
  // Lỗi không ai bắt (ngoài chuỗi await của job).
  unawaited(Future<void>.delayed(Duration.zero, () => throw StateError('late failure')));
  await Completer<void>().future;
  return null;
}

Future<Object?> _slowJob(Map<String, Object?> a, JobPort port) async {
  port.progress(0.1);
  await Future<void>.delayed(const Duration(seconds: 20));
  return 'late';
}

Future<Object?> _run(
  IsolateJob job,
  Map<String, Object?> args, {
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
  List<String> plannedOutputs = const [],
}) => runIsolateJob(
  job,
  args,
  onProgress: onProgress,
  cancelToken: cancelToken,
  plannedOutputs: plannedOutputs,
).then((v) => v, onError: (Object e) => e);

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_isolate'));
  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows: isolate vừa kill có thể chưa nhả file.
    }
  });

  group('J1 _entry / J8 _rebuild — lỗi đi qua ranh giới isolate', () {
    test('J1-1 job trả kết quả ⇒ nhận đúng kết quả', () async {
      expect(await _run(_okJob, {'value': 42}), 42);
    });
    test('J1-2 / J8-1 WrongPassword ⇒ WrongPassword', () async {
      expect(await _run(_throwJob, {'kind': 'wrong'}), isA<WrongPassword>());
    });
    test('J1-3 / J8-2 PasswordRequired ⇒ PasswordRequired', () async {
      expect(await _run(_throwJob, {'kind': 'required'}), isA<PasswordRequired>());
    });
    test('J1-4 / J8-4 CorruptFile có chi tiết ⇒ CorruptFile giữ chi tiết', () async {
      expect(
        await _run(_throwJob, {'kind': 'corrupt'}),
        isA<CorruptFile>().having((e) => e.detail, 'detail', 'bad xref'),
      );
    });
    test('J1-5 / J8-3 CorruptFile không chi tiết ⇒ CorruptFile, detail null', () async {
      expect(
        await _run(_throwJob, {'kind': 'corruptNull'}),
        isA<CorruptFile>().having((e) => e.detail, 'detail', isNull),
      );
    });
    test('J1-6 / J8-5 RangeError ⇒ RangeError', () async {
      expect(await _run(_throwJob, {'kind': 'range'}), isA<RangeError>());
    });
    test('J1-7 / J8-6 ArgumentError ⇒ ArgumentError (không phải RangeError)', () async {
      final r = await _run(_throwJob, {'kind': 'argument'});
      expect(r, isA<ArgumentError>());
      expect(r, isNot(isA<RangeError>()));
    });
    test('J1-8 / J8-7 FormatException ⇒ FormatException giữ message', () async {
      expect(
        await _run(_throwJob, {'kind': 'format'}),
        isA<FormatException>().having((e) => e.message, 'message', 'bad fmt'),
      );
    });
    test('J1-9 / J8-8 lỗi khác ⇒ Unknown (AppError)', () async {
      expect(await _run(_throwJob, {'kind': 'other'}), isA<Unknown>());
    });
  });

  group('J2 runIsolateJob', () {
    test('J2-1 không token, không tiến độ ⇒ trả kết quả', () async {
      expect(await _run(_okJob, {'value': 'x'}), 'x');
    });
    test('J2-2 token chưa huỷ ⇒ trả kết quả', () async {
      expect(await _run(_okJob, {'value': 'x'}, cancelToken: CancelToken()), 'x');
    });
    test('J2-3 token đã huỷ trước ⇒ Cancelled, job không chạy', () async {
      final marker = p.join(tmp.path, 'ran.txt');
      final r = await _run(_sideEffectJob, {'path': marker}, cancelToken: CancelToken()..cancel());
      expect(File(marker).existsSync(), isFalse);
      expect(r, isA<Cancelled>());
    });
    test('J2-4 không spawn được (tham số không gửi được) ⇒ Unknown', () async {
      final rp = ReceivePort();
      final r = await _run(_okJob, {'value': rp});
      rp.close();
      expect(r, isA<Unknown>());
    });
    test('J2-6 job ném ⇒ ném lại lỗi đã dựng', () async {
      expect(await _run(_throwJob, {'kind': 'wrong'}), isA<WrongPassword>());
    });
    test('J2-7 có onProgress ⇒ lần gọi cuối là 1.0', () async {
      final got = <double>[];
      expect(await _run(_okJob, {'value': 1}, onProgress: got.add), 1);
      expect(got, isNotEmpty);
      expect(got.last, 1.0);
    });
  });

  group('J3 listener tin nhắn', () {
    test('J3-1 tiến độ được kẹp vào 0..1, đúng thứ tự', () async {
      final got = <double>[];
      final r = await _run(_okJob, {
        'value': 1,
        'progress': [0.5, 1.5, -0.5],
      }, onProgress: got.add);
      expect(r, 1);
      expect(got, [0.5, 1.0, 0.0, 1.0]);
    });
    test('J3-2 tiến độ khi không có onProgress ⇒ bỏ qua, vẫn trả kết quả', () async {
      expect(await _run(_okJob, {'value': 2, 'progress': [0.3]}), 2);
    });
    test('J3-4 tin nhắn đến sau khi đã kết thúc (huỷ) ⇒ bị bỏ qua', () async {
      final token = CancelToken();
      final got = <double>[];
      final r = await _run(_floodJob, const {}, cancelToken: token, onProgress: (v) {
        got.add(v);
        token.cancel();
      });
      expect(r, isA<Cancelled>());
      expect(got, hasLength(1));
    });
    test('J3-5 / J7-1b file job đã ghi rồi lỗi ⇒ file bị xoá', () async {
      final path = p.join(tmp.path, 'written.pdf');
      final r = await _run(_writeThenThrowJob, {'path': path});
      expect(r, isA<ArgumentError>());
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('J4 / J5 / J6 listener lỗi, thoát, huỷ', () {
    test('J4-1 lỗi không bắt trong isolate ⇒ Unknown mang lỗi gốc', () async {
      final r = await _run(_asyncErrorJob, const {});
      expect(r, isA<Unknown>());
      expect('${(r! as Unknown).cause}', contains('late failure'));
    });
    test('J5-1 isolate thoát không trả kết quả ⇒ Unknown(isolate exited)', () async {
      final r = await _run(_exitJob, const {});
      expect(r, isA<Unknown>());
      expect((r! as Unknown).cause, 'isolate exited');
    });
    test('J6-1 huỷ khi đang chạy ⇒ Cancelled', () async {
      final token = CancelToken();
      final r = await _run(_slowJob, const {}, cancelToken: token, onProgress: (_) => token.cancel());
      expect(r, isA<Cancelled>());
    });
    test('J6-2 huỷ sau khi job xong ⇒ không lỗi, kết quả giữ nguyên', () async {
      final token = CancelToken();
      final r = await _run(_okJob, {'value': 'done'}, cancelToken: token);
      expect(r, 'done');
      expect(() => token.cancel(), returnsNormally);
    });
  });

  group('J7 cleanup', () {
    test('J7-1 huỷ: xoá .tmp dở của file dự kiến, KHÔNG xoá file đích có sẵn', () async {
      final out = p.join(tmp.path, 'out.pdf');
      File(out).writeAsStringSync('old result');
      File('$out.tmp').writeAsStringSync('partial');
      final token = CancelToken();
      final r = await _run(
        _slowJob,
        const {},
        cancelToken: token,
        onProgress: (_) => token.cancel(),
        plannedOutputs: [out],
      );
      expect(r, isA<Cancelled>());
      expect(File('$out.tmp').existsSync(), isFalse);
      expect(File(out).readAsStringSync(), 'old result');
    });
    test('J7-2 file dự kiến chưa có .tmp ⇒ dọn không lỗi, giữ lỗi của job', () async {
      final out = p.join(tmp.path, 'none.pdf');
      final r = await _run(_throwJob, {'kind': 'format'}, plannedOutputs: [out]);
      expect(r, isA<FormatException>());
      expect(File(out).existsSync(), isFalse);
    });
    test('J7-3 không có file nào để dọn ⇒ giữ lỗi của job', () async {
      expect(await _run(_throwJob, {'kind': 'required'}), isA<PasswordRequired>());
    });
  });
}
