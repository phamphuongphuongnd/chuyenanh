import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/tts/read_aloud_bar.dart';
import 'package:pdf_office/features/tts/tts_engine.dart';
import 'package:pdf_office/features/tts/tts_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_tts_engine.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTtsEngine engine, {
  List<String> paragraphs = const ['Một.', 'Hai.', 'Ba.'],
  String? languageCode = 'vi',
  String? appLocale,
  ValueChanged<int>? onParagraph,
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsRepository.kLocale: ?appLocale,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ttsEngineProvider.overrideWithValue(engine),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: ReadAloudBar(
            paragraphs: paragraphs,
            languageCode: languageCode,
            onParagraph: onParagraph,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bấm phát → đọc đoạn 0; xong → sang đoạn 1, onParagraph được gọi', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final announced = <int>[];
    await _pump(tester, engine, onParagraph: announced.add);

    expect(engine.checked, ['vi-VN']);
    expect(find.text('Paragraph 1 / 3'), findsOneWidget);
    expect(tester.getSize(find.byType(ReadAloudBar)).height, 64);

    await tester.tap(find.byKey(const ValueKey('tts_play')));
    await tester.pump();
    expect(engine.spoken, ['Một.']);
    expect(announced, [0]);
    expect(find.byTooltip('Pause'), findsOneWidget);

    engine.finish();
    await tester.pump();
    expect(engine.spoken, ['Một.', 'Hai.']);
    expect(announced, [0, 1]);
    expect(find.text('Paragraph 2 / 3'), findsOneWidget);

    // Tạm dừng → engine dừng, nút trở lại Phát.
    await tester.tap(find.byKey(const ValueKey('tts_play')));
    await tester.pump();
    expect(engine.stops, 1);
    expect(find.byTooltip('Read aloud'), findsOneWidget);
  });

  testWidgets('đoạn sau / trước và dừng', (tester) async {
    final engine = FakeTtsEngine();
    await _pump(tester, engine);
    await tester.tap(find.byKey(const ValueKey('tts_play')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tts_next')));
    await tester.pumpAndSettle();
    expect(engine.spoken.last, 'Hai.');
    await tester.tap(find.byKey(const ValueKey('tts_prev')));
    await tester.pumpAndSettle();
    expect(engine.spoken.last, 'Một.');
    final stopsBefore = engine.stops;
    await tester.tap(find.byKey(const ValueKey('tts_stop')));
    await tester.pumpAndSettle();
    expect(engine.stops, stopsBefore + 1);
    expect(find.byTooltip('Read aloud'), findsOneWidget);
  });

  testWidgets('chọn tốc độ 1.5×', (tester) async {
    final engine = FakeTtsEngine();
    await _pump(tester, engine);
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tts_speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tts_speed_1.5')));
    await tester.pumpAndSettle();
    expect(engine.speed, 1.5);
    expect(find.text('1.5×'), findsOneWidget);
  });

  testWidgets('nhiều giọng → hiện nút chọn giọng', (tester) async {
    final engine = FakeTtsEngine(
      voices: const [
        TtsVoice(name: 'vi-vn-x-gft-local', locale: 'vi-VN'),
        TtsVoice(name: 'vi-vn-x-vic-local', locale: 'vi-VN'),
      ],
    );
    await _pump(tester, engine);
    await tester.tap(find.byKey(const ValueKey('tts_voice')));
    await tester.pumpAndSettle();
    expect(find.text('Device default'), findsOneWidget);
    await tester.tap(find.text('Voice 2'));
    await tester.pumpAndSettle();
    expect(engine.voiceSet.single?.name, 'vi-vn-x-vic-local');
  });

  testWidgets('chỉ một giọng → ẩn nút chọn giọng', (tester) async {
    final single = FakeTtsEngine(
      voices: const [TtsVoice(name: 'Linh', locale: 'vi-VN')],
    );
    await _pump(tester, single);
    expect(find.byKey(const ValueKey('tts_voice')), findsNothing);
  });

  testWidgets('không có giọng → thông báo + hướng dẫn cài; kiểm tra lại', (
    tester,
  ) async {
    final engine = FakeTtsEngine(available: false);
    await _pump(tester, engine);
    expect(find.text('No Tiếng Việt voice on this device'), findsOneWidget);
    expect(find.byKey(const ValueKey('tts_play')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tts_howto')));
    await tester.pumpAndSettle();
    expect(find.text('Install a reading voice'), findsOneWidget);

    engine.available = true;
    await tester.tap(find.byKey(const ValueKey('tts_recheck')));
    await tester.pumpAndSettle();
    expect(engine.checked, ['vi-VN', 'vi-VN']);
    expect(find.byKey(const ValueKey('tts_play')), findsOneWidget);
  });

  testWidgets('không truyền languageCode → dùng ngôn ngữ trong cài đặt', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    await _pump(tester, engine, languageCode: null, appLocale: 'ja');
    expect(engine.checked, ['ja-JP']);
  });

  testWidgets('đoạn dài đọc thành nhiều phần, onParagraph chỉ gọi một lần', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final announced = <int>[];
    final long = '${'a' * 2000}. ${'b' * 2000}.';
    await _pump(
      tester,
      engine,
      paragraphs: [long, 'Hết.'],
      onParagraph: announced.add,
    );
    await tester.tap(find.byKey(const ValueKey('tts_play')));
    await tester.pump();
    engine.finish();
    await tester.pump();
    expect(engine.spoken.length, 2);
    expect(engine.spoken.every((s) => s.length <= kTtsMaxChunkLength), isTrue);
    expect(announced, [0]);
    engine.finish();
    await tester.pump();
    expect(engine.spoken.last, 'Hết.');
    expect(announced, [0, 1]);
  });

  testWidgets('huỷ widget khi đang đọc → engine dừng', (tester) async {
    final engine = FakeTtsEngine();
    await _pump(tester, engine);
    await tester.tap(find.byKey(const ValueKey('tts_play')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(engine.stops, 1);
    expect(engine.onComplete, isNull);
  });
}
