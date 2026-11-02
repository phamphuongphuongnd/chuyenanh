// Kiểm thử hộp trắng A13 — app/lib/features/qr/qr_history.dart
// Thiết kế: test-output/whitebox/qr/qr_history/buoc-1..5. Expected chép từ Bước 5.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/qr/qr_content.dart';
import 'package:pdf_office/features/qr/qr_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScannedCode q(String x) => ScannedCode(format: CodeFormat.qrCode, raw: x);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> make(Map<String, Object> init) async {
    SharedPreferences.setMockInitialValues(init);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    return (c, prefs);
  }

  group('U1 mergeQrHistory', () {
    test('1-1 history rỗng, mã trùng trong codes ⇒ 1', () => expect(mergeQrHistory([], [q('a'), q('a')]), [q('a')]));
    test('1-2 thêm mã mới lên đầu', () => expect(mergeQrHistory([q('b')], [q('a')]), [q('a'), q('b')]));
    test('1-3 mã trùng đưa lên đầu', () => expect(mergeQrHistory([q('b'), q('a')], [q('a')]), [q('a'), q('b')]));
    test('1-4 cắt theo limit', () => expect(mergeQrHistory([q('b'), q('c'), q('d')], [q('a')], limit: 2), [q('a'), q('b')]));
  });

  group('U2 build', () {
    test('2-1 chưa có ⇒ []', () async {
      final (c, _) = await make({});
      expect(c.read(qrHistoryProvider), isEmpty);
    });
    test('2-2 JSON hợp lệ ⇒ lọc mục hỏng, tối đa 20', () async {
      final list = <Object>[
        {'format': 'ean13', 'raw': '1'},
        {'raw': 5},
        {'format': 'zz', 'raw': 'x'},
        'bad',
        for (var i = 0; i < 25; i++) {'format': 'qrCode', 'raw': 'n$i'},
      ];
      final (c, _) = await make({'qr.history': jsonEncode(list)});
      final h = c.read(qrHistoryProvider);
      expect(h.first, const ScannedCode(format: CodeFormat.ean13, raw: '1'));
      expect(h[1], const ScannedCode(format: CodeFormat.unknown, raw: 'x'));
      expect(h.where((e) => e.raw == '5'), isEmpty);
      expect(h.length, 20);
    });
    test('2-3 JSON hỏng ⇒ []', () async {
      final (c, _) = await make({'qr.history': '{not json'});
      expect(c.read(qrHistoryProvider), isEmpty);
    });
  });

  group('U3 add', () {
    test('3-1 thêm ⇒ state + lưu prefs', () async {
      final (c, prefs) = await make({});
      await c.read(qrHistoryProvider.notifier).add([q('a')]);
      expect(c.read(qrHistoryProvider), [q('a')]);
      expect(prefs.getString('qr.history'), contains('"raw":"a"'));
    });
    test('3-2 danh sách rỗng ⇒ không ghi', () async {
      final (c, prefs) = await make({});
      await c.read(qrHistoryProvider.notifier).add([]);
      expect(c.read(qrHistoryProvider), isEmpty);
      expect(prefs.containsKey('qr.history'), isFalse);
    });
  });
}
