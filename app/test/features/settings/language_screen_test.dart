import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/settings/language_screen.dart';
import 'package:pdf_office/features/settings/settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {String? locale}) async {
  SharedPreferences.setMockInitialValues({SettingsRepository.kLocale: ?locale});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: ref.watch(settingsProvider).locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LanguageScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('hiện "Theo máy" + 6 ngôn ngữ bằng tên bản địa', (tester) async {
    await _pump(tester, locale: 'en');
    expect(find.text('Follow device'), findsOneWidget);
    for (final name in localeNativeNames.values) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('chọn tiếng Việt đổi tức thì: tiêu đề và settings', (
    tester,
  ) async {
    final c = await _pump(tester, locale: 'en');
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lang_vi')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).locale, const Locale('vi'));
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Theo máy'), findsOneWidget);
  });

  testWidgets('"Theo máy" xoá lựa chọn', (tester) async {
    final c = await _pump(tester, locale: 'ja');
    await tester.tap(find.byKey(const ValueKey('lang_system')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).locale, isNull);
  });

  testWidgets('dấu tích ở ngôn ngữ đang chọn', (tester) async {
    await _pump(tester, locale: 'ko');
    final tile = find.ancestor(
      of: find.text('한국어'),
      matching: find.byType(ChoiceTile),
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Symbols.check_rounded)),
      findsOneWidget,
    );
    // Chỉ một mục mang dấu tích.
    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
  });
}
