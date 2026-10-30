import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/features/translate/translate_providers.dart';
import 'package:pdf_office/features/translate/translate_sheet.dart';
import 'package:pdf_office/features/translate/translator_engine.dart';

/// Engine giả: dịch thành "[đích] chữ gốc"; gói tải/xoá trong bộ nhớ.
class FakeTranslatorEngine implements TranslatorEngine {
  FakeTranslatorEngine({Set<String>? downloaded, this.failDownload = false})
    : downloaded = downloaded ?? {'en'};

  final Set<String> downloaded;
  bool failDownload;
  final List<String> downloadCalls = [];
  final List<String> deleteCalls = [];
  int translateCalls = 0;
  int opened = 0;
  int closed = 0;

  @override
  Future<bool> isModelDownloaded(String code) async =>
      downloaded.contains(code);

  @override
  Future<void> downloadModel(String code) async {
    downloadCalls.add(code);
    if (failDownload) throw TranslateModelDownloadFailed(code);
    downloaded.add(code);
  }

  @override
  Future<void> deleteModel(String code) async {
    deleteCalls.add(code);
    downloaded.remove(code);
  }

  @override
  TranslatorSession open({required String source, required String target}) {
    opened++;
    return _FakeSession(this, target);
  }
}

class _FakeSession implements TranslatorSession {
  _FakeSession(this.engine, this.target);

  final FakeTranslatorEngine engine;
  final String target;

  @override
  Future<String> translate(String text) async {
    engine.translateCalls++;
    return '[$target] $text';
  }

  @override
  Future<void> close() async => engine.closed++;
}

Future<void> _openSheet(
  WidgetTester tester,
  FakeTranslatorEngine engine,
  List<String> paragraphs, {
  Locale locale = const Locale('vi'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [translatorEngineProvider.overrideWithValue(engine)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTranslateSheet(context, paragraphs: paragraphs),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('gói chưa tải → hỏi tải → tải → dịch ra chữ, đóng bộ dịch', (
    tester,
  ) async {
    final engine = FakeTranslatorEngine(downloaded: {'en'});
    await _openSheet(tester, engine, ['Hello world', '  ', 'Good morning']);

    // Nguồn tự nhận tiếng Anh, đích = ngôn ngữ app (vi).
    expect(find.text('Tự nhận · Tiếng Anh'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Số đoạn: 2. Dịch ngay trên máy.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cần tải gói dịch Tiếng Việt'), findsOneWidget);
    expect(find.textContaining('cần mạng một lần'), findsOneWidget);
    expect(engine.translateCalls, 0);

    await tester.tap(find.text('Tải'));
    await tester.pumpAndSettle();

    expect(engine.downloadCalls, ['vi']);
    expect(find.text('[vi] Hello world'), findsOneWidget);
    expect(find.text('[vi] Good morning'), findsOneWidget);
    // Đoạn gốc vẫn hiện song song.
    expect(find.text('Hello world'), findsOneWidget);
    expect(engine.opened, 1);
    expect(engine.closed, 1);
    expect(find.byKey(const ValueKey('translate_copy_all')), findsOneWidget);
    expect(find.byKey(const ValueKey('translate_share')), findsOneWidget);
  });

  testWidgets('tải lỗi → báo lỗi mạng rõ ràng, không dịch', (tester) async {
    final engine = FakeTranslatorEngine(downloaded: {'en'}, failDownload: true);
    await _openSheet(tester, engine, ['Hello world']);

    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kiểm tra kết nối mạng'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    expect(engine.translateCalls, 0);
    expect(engine.opened, 0);
    expect(find.byKey(const ValueKey('translate_start')), findsOneWidget);
  });

  testWidgets('gói đã có → dịch luôn; đổi chiều đổi nguồn/đích', (
    tester,
  ) async {
    final engine = FakeTranslatorEngine(downloaded: {'en', 'vi'});
    await _openSheet(tester, engine, ['Hello']);

    await tester.tap(find.byKey(const ValueKey('translate_swap')));
    await tester.pumpAndSettle();
    // Sau khi đổi chiều: nguồn Tiếng Việt, đích Tiếng Anh.
    expect(find.text('Tự nhận · Tiếng Anh'), findsNothing);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Tiếng Anh'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pumpAndSettle();
    expect(engine.downloadCalls, isEmpty);
    expect(find.text('[en] Hello'), findsOneWidget);
  });

  testWidgets('hơn 300 đoạn → dịch 300 rồi hỏi có dịch tiếp không', (
    tester,
  ) async {
    final engine = FakeTranslatorEngine(downloaded: {'en', 'vi'});
    await _openSheet(tester, engine, [
      for (var i = 0; i < 302; i++) 'Paragraph $i',
    ]);

    await tester.tap(find.byKey(const ValueKey('translate_start')));
    await tester.pumpAndSettle();
    expect(engine.translateCalls, 300);
    expect(find.text('Dịch tiếp?'), findsOneWidget);
    expect(find.textContaining('Còn 2 đoạn nữa'), findsOneWidget);

    await tester.tap(find.text('Dịch tiếp'));
    await tester.pumpAndSettle();
    expect(engine.translateCalls, 302);
    expect(engine.closed, 2);
  });

  testWidgets('không có chữ → trạng thái trống', (tester) async {
    await _openSheet(tester, FakeTranslatorEngine(), ['  ', '']);
    expect(find.text('Không có chữ để dịch'), findsOneWidget);
    expect(find.byKey(const ValueKey('translate_start')), findsNothing);
  });

  testWidgets('màn Gói dịch đã tải: xoá một gói', (tester) async {
    final engine = FakeTranslatorEngine(downloaded: {'en', 'vi'});
    await _openSheet(tester, engine, ['Hello']);

    await tester.tap(find.byKey(const ValueKey('translate_models')));
    await tester.pumpAndSettle();
    expect(find.text('Gói dịch đã tải'), findsOneWidget);
    // Gói tiếng Anh có sẵn, không có nút xoá.
    expect(find.byKey(const ValueKey('translate_delete_en')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('translate_delete_vi')));
    await tester.pumpAndSettle();
    expect(find.text('Xoá gói Tiếng Việt?'), findsOneWidget);
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    expect(engine.deleteCalls, ['vi']);
    expect(find.byKey(const ValueKey('translate_download_vi')), findsOneWidget);
  });
}
