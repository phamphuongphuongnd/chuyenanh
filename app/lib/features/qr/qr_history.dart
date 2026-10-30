import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/settings/settings_providers.dart';
import 'qr_content.dart';

/// Số mã gần nhất được giữ trong lịch sử.
const int kQrHistoryLimit = 20;

const String _kHistory = 'qr.history';

/// Thêm [codes] lên đầu [history] (mã trùng được đưa lên đầu), cắt còn [limit]. Hàm thuần.
List<ScannedCode> mergeQrHistory(
  List<ScannedCode> history,
  List<ScannedCode> codes, {
  int limit = kQrHistoryLimit,
}) {
  final out = <ScannedCode>[...codes.toSet()];
  for (final c in history) {
    if (!out.contains(c)) out.add(c);
  }
  return out.length > limit ? out.sublist(0, limit) : out;
}

final qrHistoryProvider = NotifierProvider<QrHistoryNotifier, List<ScannedCode>>(
  QrHistoryNotifier.new,
);

/// Lịch sử mã đã quét (mới nhất trước), lưu bằng shared_preferences.
class QrHistoryNotifier extends Notifier<List<ScannedCode>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<ScannedCode> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_kHistory);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list.whereType<Map<String, dynamic>>())
          if (e['raw'] is String)
            ScannedCode(
              format: CodeFormat.fromName(e['format'] as String?),
              raw: e['raw'] as String,
            ),
      ].take(kQrHistoryLimit).toList();
    } catch (_) {
      // Dữ liệu hỏng → coi như trống.
      return const [];
    }
  }

  Future<void> add(List<ScannedCode> codes) async {
    if (codes.isEmpty) return;
    state = mergeQrHistory(state, codes);
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _prefs.remove(_kHistory);
  }

  Future<void> _save() => _prefs.setString(
    _kHistory,
    jsonEncode([
      for (final c in state) {'format': c.format.name, 'raw': c.raw},
    ]),
  );
}
