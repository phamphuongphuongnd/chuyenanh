// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/cancel_token.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/cancel_token/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';

void main() {
  group('U1 cancel', () {
    test('1.1 huỷ lần đầu, 2 listener ⇒ gọi mỗi listener 1 lần, isCancelled = true', () {
      final t = CancelToken();
      final calls = <String>[];
      t
        ..onCancel(() => calls.add('a'))
        ..onCancel(() => calls.add('b'));
      expect(calls, isEmpty);
      t.cancel();
      expect(t.isCancelled, isTrue);
      expect(calls, ['a', 'b']);
    });

    test('1.2 huỷ lần hai ⇒ không gọi lại listener', () {
      final t = CancelToken();
      var n = 0;
      t.onCancel(() => n++);
      t.cancel();
      t.cancel();
      expect(n, 1);
      expect(t.isCancelled, isTrue);
    });

    test('1.3 huỷ khi chưa có listener ⇒ isCancelled = true, không lỗi', () {
      final t = CancelToken();
      expect(t.cancel, returnsNormally);
      expect(t.isCancelled, isTrue);
    });
  });

  group('U2 onCancel', () {
    test('2.1 đăng ký trước khi huỷ ⇒ chưa gọi, gọi khi huỷ', () {
      final t = CancelToken();
      var n = 0;
      t.onCancel(() => n++);
      expect(n, 0);
      t.cancel();
      expect(n, 1);
    });

    test('2.2 đăng ký sau khi đã huỷ ⇒ gọi ngay', () {
      final t = CancelToken()..cancel();
      var n = 0;
      t.onCancel(() => n++);
      expect(n, 1);
    });
  });

  group('U3 throwIfCancelled', () {
    test('3.1 chưa huỷ ⇒ không ném', () {
      expect(CancelToken().throwIfCancelled, returnsNormally);
    });

    test('3.2 đã huỷ ⇒ ném Cancelled', () {
      final t = CancelToken()..cancel();
      expect(t.throwIfCancelled, throwsA(isA<Cancelled>()));
    });
  });
}
