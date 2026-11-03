import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/system/app_lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_office/features/translate/translate_providers.dart';
import 'package:pdf_office/features/translate/translate_sheet.dart';
import 'package:pdf_office/features/translate/translator_engine.dart';

import 'translate_sheet_test.dart' show FakeTranslatorEngine;

/// Engine dịch chậm: mỗi đoạn chờ [gate] mới xong (để đóng bảng giữa chừng).
class _SlowEngine extends FakeTranslatorEngine {
  _SlowEngine(this.gate) : super(downloaded: {'en', 'vi'});
  final Completer<void> gate;

  @override
  TranslatorSession open({required String source, required String target}) =>
      _SlowSession(gate);
}

class _SlowSession implements TranslatorSession {
  _SlowSession(this.gate);
  final Completer<void> gate;

  @override
  Future<String> translate(String text) async {
    await gate.future;
    return 'x $text';
  }

  @override
  Future<void> close() async {}
}

/// Dựng app giả: Trang chủ → trang đọc (bấm "open" mở bảng dịch), qua `GoRouter` + `AppLockGate` như app thật.
Future<GoRouter> _pumpApp(WidgetTester tester, TranslatorEngine engine) async {
  final router = GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'reflow',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTranslateSheet(
                    context,
                    paragraphs: const ['Hello world', 'Good morning'],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translatorEngineProvider.overrideWithValue(engine),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp.router(
        builder: (context, child) => AppLockGate(child: child!),
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/reflow'));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byTooltip('Đóng'), findsOneWidget);
  // Kiểm chứng chính bộ dò: lúc bảng mở phải thấy lớp xám.
  expect(
    tester0Barriers().any((b) => (b.color?.a ?? 0) > 0),
    isTrue,
    reason: 'bộ dò phải thấy scrim khi bảng đang mở',
  );
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

/// Route trang cũng dựng ModalBarrier trong suốt; "lớp xám sót" = barrier có màu (alpha > 0).
void _noBarrier() {
  final scrims = tester0Barriers().where((b) => (b.color?.a ?? 0) > 0).toList();
  expect(scrims, isEmpty, reason: 'còn lớp xám mờ của route đã đóng');
}

List<ModalBarrier> tester0Barriers() => find
    .byType(ModalBarrier)
    .evaluate()
    .map((e) => e.widget as ModalBarrier)
    .toList();

void main() {
  testWidgets('✕ rồi Back về Trang chủ: không còn ModalBarrier', (tester) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    _noBarrier();
    expect(find.text('open'), findsOneWidget);
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    _noBarrier();
    await _systemBack(tester); // Back thừa ở Trang chủ không được làm hỏng gì.
    await tester.pumpAndSettle();
    _noBarrier();
  });

  testWidgets('Back khi bảng đang mở rồi Back nữa', (tester) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    await _systemBack(tester);
    await tester.pumpAndSettle();
    _noBarrier();
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    _noBarrier();
  });

  testWidgets('hai Back nhanh liền nhau (không chờ hoạt ảnh)', (tester) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 30));
    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 30));
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    _noBarrier();
  });

  testWidgets('✕ rồi Back ngay trong lúc bảng đang trượt xuống', (tester) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pump(const Duration(milliseconds: 40));
    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 40));
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    _noBarrier();
  });

  testWidgets('đóng bảng khi đang dịch (Future chưa xong) rồi xong', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pumpApp(tester, _SlowEngine(gate));
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    _noBarrier();
    await _systemBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    _noBarrier();
  });

  testWidgets('đóng bảng khi hộp thoại "dịch tiếp?" sắp hiện', (tester) async {
    // 12 đoạn → hết lô 10 còn đoạn → hỏi "dịch tiếp". Đóng bảng sau khi xong lô.
    final engine = FakeTranslatorEngine(downloaded: {'en', 'vi'});
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTranslateSheet(
                  context,
                  paragraphs: [for (var i = 0; i < 40; i++) 'Sentence $i here'],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [translatorEngineProvider.overrideWithValue(engine)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pumpAndSettle();
    // Hộp thoại "dịch tiếp?" đang hiện: Back đóng hộp thoại, Back nữa đóng bảng.
    await _systemBack(tester);
    await tester.pumpAndSettle();
    await _systemBack(tester);
    await tester.pumpAndSettle();
    _noBarrier();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('chạm ✕ hai lần liền: chỉ đóng bảng, không pop nhầm trang đọc', (
    tester,
  ) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    final close = find.byTooltip('Đóng');
    final center = tester.getCenter(close);
    final g1 = await tester.startGesture(center);
    await g1.up();
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'trang đọc phải còn');
    _noBarrier();
  });

  testWidgets('chạm một ngôn ngữ trong bảng chọn hai lần: bảng dịch còn', (
    tester,
  ) async {
    await _pumpApp(tester, FakeTranslatorEngine());
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('translate_target')));
    await tester.pumpAndSettle();
    final option = find.byKey(const ValueKey('translate_tgt_vi'));
    final center = tester.getCenter(option);
    final g1 = await tester.startGesture(center);
    await g1.up();
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('translate_start')), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsAtLeastNWidgets(1)); // đổi: trước ja/'Tiếng Nhật' (đã bỏ)
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    _noBarrier();
  });
}