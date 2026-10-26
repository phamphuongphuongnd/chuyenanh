import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/cancel_token.dart';

/// Hàm chạy trong isolate: nhận [args], báo tiến độ qua [JobPort], trả kết quả sendable.
/// Phải là hàm **top-level / static** (không bắt biến ngoài).
typedef IsolateJob =
    Future<Object?> Function(Map<String, Object?> args, JobPort port);

/// Kênh gửi tin từ isolate về luồng chính.
class JobPort {
  JobPort._(this._send);
  final SendPort _send;

  /// Tiến độ 0.0 → 1.0.
  void progress(double value) => _send.send(<Object?>['p', value]);

  /// Đã ghi xong một file kết quả (để dọn nếu job bị huỷ/lỗi giữa chừng).
  void fileWritten(String path) => _send.send(<Object?>['f', path]);
}

class _Request {
  _Request(this.reply, this.job, this.args);
  final SendPort reply;
  final IsolateJob job;
  final Map<String, Object?> args;
}

/// Mã lỗi đi qua ranh giới isolate.
const _kWrongPassword = 'wrongPassword';
const _kPasswordRequired = 'passwordRequired';
const _kCorrupt = 'corrupt';
const _kArgument = 'argument';
const _kFormat = 'format';
const _kRange = 'range';
const _kOther = 'other';

Future<void> _entry(_Request req) async {
  try {
    final result = await req.job(req.args, JobPort._(req.reply));
    req.reply.send(<Object?>['r', result]);
  } on WrongPassword {
    req.reply.send(<Object?>['e', _kWrongPassword, '']);
  } on PasswordRequired {
    req.reply.send(<Object?>['e', _kPasswordRequired, '']);
  } on CorruptFile catch (e) {
    req.reply.send(<Object?>['e', _kCorrupt, e.detail ?? '']);
  } on RangeError catch (e) {
    req.reply.send(<Object?>['e', _kRange, e.toString()]);
  } on ArgumentError catch (e) {
    req.reply.send(<Object?>['e', _kArgument, e.toString()]);
  } on FormatException catch (e) {
    req.reply.send(<Object?>['e', _kFormat, e.message]);
  } catch (e) {
    req.reply.send(<Object?>['e', _kOther, e.toString()]);
  }
}

/// Chạy [job] trong một isolate riêng, chuyển tiến độ về [onProgress], huỷ được bằng
/// [cancelToken] (kill isolate rồi xoá file đã ghi dở và ném [Cancelled]).
///
/// Lỗi trong isolate được dựng lại thành [AppError] (mật khẩu/hỏng file) hoặc
/// [ArgumentError]/[RangeError]/[FormatException] (tham số sai).
/// [plannedOutputs]: các path job sẽ ghi — dọn `.tmp` và file đã xong nếu huỷ/lỗi.
Future<Object?> runIsolateJob(
  IsolateJob job,
  Map<String, Object?> args, {
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
  List<String> plannedOutputs = const [],
}) async {
  cancelToken?.throwIfCancelled();
  final port = ReceivePort();
  final exitPort = ReceivePort();
  final errorPort = ReceivePort();
  final written = <String>[];
  final done = Completer<Object?>();

  Future<void> cleanup() async {
    // File đã ghi xong trong lần chạy này + file `.tmp` dở dang. Không bao giờ xoá
    // path đích có sẵn từ trước (job chưa ghi tới).
    final targets = <String>{
      ...written,
      for (final p in written) '$p.tmp',
      for (final p in plannedOutputs) '$p.tmp',
    };
    for (final p in targets) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  late final Isolate isolate;
  try {
    isolate = await Isolate.spawn<_Request>(
      _entry,
      _Request(port.sendPort, job, args),
      onExit: exitPort.sendPort,
      onError: errorPort.sendPort,
      errorsAreFatal: true,
    );
  } catch (e) {
    port.close();
    exitPort.close();
    errorPort.close();
    throw Unknown(e);
  }

  port.listen((Object? msg) {
    if (msg is! List || done.isCompleted) return;
    switch (msg[0]) {
      case 'p':
        onProgress?.call((msg[1] as num).toDouble().clamp(0.0, 1.0));
      case 'f':
        written.add(msg[1] as String);
      case 'r':
        done.complete(msg[1]);
      case 'e':
        done.completeError(_rebuild(msg[1] as String, msg[2] as String));
    }
  });
  errorPort.listen((Object? msg) {
    if (!done.isCompleted) done.completeError(Unknown(msg ?? 'error'));
  });
  exitPort.listen((_) {
    if (!done.isCompleted) done.completeError(const Unknown('isolate exited'));
  });
  cancelToken?.onCancel(() {
    if (!done.isCompleted) done.completeError(const Cancelled());
  });

  try {
    final result = await done.future;
    onProgress?.call(1);
    return result;
  } catch (e) {
    isolate.kill(priority: Isolate.immediate);
    await cleanup();
    rethrow;
  } finally {
    port.close();
    exitPort.close();
    errorPort.close();
  }
}

Object _rebuild(String kind, String detail) => switch (kind) {
  _kWrongPassword => const WrongPassword(),
  _kPasswordRequired => const PasswordRequired(),
  _kCorrupt => CorruptFile(detail.isEmpty ? null : detail),
  _kRange => RangeError(detail),
  _kArgument => ArgumentError(detail),
  _kFormat => FormatException(detail),
  _ => Unknown(detail),
};
