import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';

void main() {
  test('chưa huỷ → không ném', () {
    final t = CancelToken();
    expect(t.isCancelled, isFalse);
    t.throwIfCancelled();
  });

  test('huỷ → ném Cancelled, gọi listener một lần', () {
    final t = CancelToken();
    var calls = 0;
    t.onCancel(() => calls++);
    t.cancel();
    t.cancel();
    expect(t.isCancelled, isTrue);
    expect(calls, 1);
    expect(t.throwIfCancelled, throwsA(isA<Cancelled>()));
  });

  test('đăng ký sau khi đã huỷ → gọi ngay', () {
    final t = CancelToken()..cancel();
    var called = false;
    t.onCancel(() => called = true);
    expect(called, isTrue);
  });
}
