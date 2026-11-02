// Kiểm thử hộp trắng (A09 · reader) — reader_prefs.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/reader_prefs/buoc-5-du-lieu-thu.md.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/reader/logic/reader_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ReaderPrefs> _built(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c.read(readerPrefsProvider);
}

(bool, bool, bool) _t(ReaderPrefs p) => (p.darkMode, p.horizontal, p.singlePage);

void main() {
  group('ReaderPrefs.copyWith', () {
    const base = ReaderPrefs(darkMode: true, horizontal: false, singlePage: true);
    test('RP1-1 không truyền gì ⇒ giữ nguyên cả 3', () => expect(_t(base.copyWith()), (true, false, true)));
    test('RP1-2 chỉ đổi darkMode=false ⇒ 2 công tắc kia giữ nguyên', () {
      expect(_t(base.copyWith(darkMode: false)), (false, false, true));
    });
    test('RP1-3 chỉ đổi horizontal=true', () => expect(_t(base.copyWith(horizontal: true)), (true, true, true)));
    test('RP1-4 chỉ đổi singlePage=false', () => expect(_t(base.copyWith(singlePage: false)), (true, false, false)));
  });

  group('ReaderPrefsNotifier.build', () {
    test('RP2-1 chưa lưu gì ⇒ tắt cả 3 (sáng, cuộn dọc, liên tục)', () async {
      expect(_t(await _built({})), (false, false, false));
    });
    test('RP2-2 đã lưu darkMode=true ⇒ chỉ darkMode bật', () async {
      expect(_t(await _built({'reader.darkMode': true})), (true, false, false));
    });
    test('RP2-3 đã lưu horizontal=true ⇒ chỉ horizontal bật', () async {
      expect(_t(await _built({'reader.horizontal': true})), (false, true, false));
    });
    test('RP2-4 đã lưu singlePage=true ⇒ chỉ singlePage bật', () async {
      expect(_t(await _built({'reader.singlePage': true})), (false, false, true));
    });
  });
}
