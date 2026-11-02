// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/link_opener.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/link_opener/buoc-5-du-lieu-thu.md
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/link_opener.dart';

void main() {
  group('U1 linkLauncherOf', () {
    Future<BuildContext> ctxIn(WidgetTester tester, Widget Function(Widget) wrap) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      return ctx;
    }

    testWidgets('1.1 trong ProviderScope có ghi đè ⇒ trả launcher ghi đè', (tester) async {
      Future<bool> fake(Uri u) async => true;
      final ctx = await ctxIn(
        tester,
        (child) => ProviderScope(
          overrides: [linkLauncherProvider.overrideWithValue(fake)],
          child: child,
        ),
      );
      expect(linkLauncherOf(ctx), same(fake));
    });

    testWidgets('1.2 không có ProviderScope ⇒ không ném, trả launcher mặc định', (tester) async {
      final noScope = await ctxIn(tester, (child) => child);
      final r = linkLauncherOf(noScope);
      final scoped = await ctxIn(tester, (child) => ProviderScope(child: child));
      // Launcher mặc định của provider (chưa ghi đè) = launcher mặc định khi thiếu scope.
      expect(r, linkLauncherOf(scoped));
    });
  });

  group('U2 openLink', () {
    test('2.1 https an toàn, launcher true ⇒ (uri, opened: true), gọi launcher 1 lần', () async {
      final calls = <Uri>[];
      final r = await openLink((u) async {
        calls.add(u);
        return true;
      }, 'https://a.com/x');
      expect(calls.map((u) => u.toString()), ['https://a.com/x']);
      expect(r.uri.toString(), 'https://a.com/x');
      expect(r.opened, isTrue);
    });

    test('2.1b https an toàn, launcher false ⇒ (uri, opened: false)', () async {
      final r = await openLink((u) async => false, 'https://a.com/x');
      expect(r.uri.toString(), 'https://a.com/x');
      expect(r.opened, isFalse);
    });

    test('2.2 scheme nguy hiểm ⇒ (null, false), KHÔNG gọi launcher', () async {
      var called = false;
      final r = await openLink((u) async {
        called = true;
        return true;
      }, 'javascript:alert(1)');
      expect(called, isFalse);
      expect(r.uri, isNull);
      expect(r.opened, isFalse);
    });

    test('2.3 launcher ném lỗi ⇒ (uri, false), không ném ra ngoài', () async {
      var called = false;
      final r = await openLink((u) async {
        called = true;
        throw StateError('no app');
      }, 'mailto:a@b.com');
      expect(called, isTrue);
      expect(r.uri.toString(), 'mailto:a@b.com');
      expect(r.opened, isFalse);
    });
  });
}
