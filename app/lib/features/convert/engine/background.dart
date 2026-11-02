import 'dart:async';
import 'dart:isolate';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/cancel_token.dart';

/// Việc chạy trong isolate: nhận hàm báo tiến độ, trả kết quả (phải gửi được qua isolate).
typedef BackgroundJob<T> = T Function(void Function(double progress) report);

class _Start<T> {
  _Start(this.job, this.port);
  final BackgroundJob<T> job;
  final SendPort port;
}

void _entry<T>(_Start<T> s) {
  try {
    final result = s.job((p) => s.port.send(<Object?>['p', p]));
    s.port.send(<Object?>['r', result]);
  } catch (e) {
    Object payload = e.toString();
    if (e is AppError && e is! Unknown) payload = e;
    try {
      s.port.send(<Object?>['e', payload]);
    } catch (_) {
      s.port.send(<Object?>['e', e.toString()]);
    }
  }
}

/// Chạy [job] trong isolate riêng; báo tiến độ, huỷ bằng [cancelToken] (kill isolate → [Cancelled]).
/// Không dùng [runInBackground] với closure bắt biến không gửi được qua isolate.
Future<T> runInBackground<T>(
  BackgroundJob<T> job, {
  void Function(double)? onProgress,
  CancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  final receive = ReceivePort();
  final completer = Completer<T>();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  errorPort.listen((dynamic e) {
    if (!completer.isCompleted) completer.completeError(Unknown('isolate: $e'));
  });
  // Isolate thoát mà chưa trả kết quả (chết sớm): chờ ngắn để tin 'r'/'e' đang bay kịp tới rồi mới báo lỗi.
  exitPort.listen((dynamic _) {
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!completer.isCompleted) completer.completeError(const Unknown('isolate: thoát đột ngột'));
    });
  });
  final Isolate isolate;
  try {
    // Gắn onError/onExit ngay lúc spawn để không lỡ lỗi của isolate chết sớm.
    isolate = await Isolate.spawn<_Start<T>>(
      _entry<T>,
      _Start<T>(job, receive.sendPort),
      errorsAreFatal: true,
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );
  } catch (_) {
    receive.close();
    errorPort.close();
    exitPort.close();
    rethrow;
  }
  cancelToken?.onCancel(() {
    isolate.kill(priority: Isolate.immediate);
    if (!completer.isCompleted) completer.completeError(const Cancelled());
  });
  receive.listen((dynamic m) {
    final msg = m as List<Object?>;
    switch (msg[0]) {
      case 'p':
        onProgress?.call(msg[1] as double);
      case 'r':
        if (!completer.isCompleted) completer.complete(msg[1] as T);
      case 'e':
        final err = msg[1];
        if (!completer.isCompleted) {
          completer.completeError(err is AppError ? err : Unknown(err!));
        }
    }
  });
  try {
    return await completer.future;
  } finally {
    receive.close();
    errorPort.close();
    exitPort.close();
    isolate.kill(priority: Isolate.immediate);
  }
}
