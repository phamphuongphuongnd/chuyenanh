import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/reader/logic/reader_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('mac dinh: sang, cuon doc, lien tuc', () async {
    final c = await _container({});
    final prefs = c.read(readerPrefsProvider);
    expect(prefs.darkMode, isFalse);
    expect(prefs.horizontal, isFalse);
    expect(prefs.singlePage, isFalse);
  });

  test('doi tuy chon duoc luu va doc lai o lan mo sau', () async {
    final c = await _container({});
    final n = c.read(readerPrefsProvider.notifier);
    await n.setDarkMode(true);
    await n.setHorizontal(true);
    await n.setSinglePage(true);
    expect(c.read(readerPrefsProvider).darkMode, isTrue);

    final stored = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(stored)],
    );
    addTearDown(c2.dispose);
    final again = c2.read(readerPrefsProvider);
    expect(again.darkMode, isTrue);
    expect(again.horizontal, isTrue);
    expect(again.singlePage, isTrue);
  });

  test('ma tran dao mau khong doi do trong suot, dao RGB', () {
    expect(kInvertColorMatrix.length, 20);
    // R' = 255 - R
    expect(kInvertColorMatrix[0], -1);
    expect(kInvertColorMatrix[4], 255);
    // alpha giu nguyen
    expect(kInvertColorMatrix[18], 1);
  });
}
