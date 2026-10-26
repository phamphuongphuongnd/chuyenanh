import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/settings/settings_providers.dart';

/// Ma trận ColorFilter đảo màu RGB (giữ alpha) — chế độ đọc tối.
const List<double> kInvertColorMatrix = <double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
];

/// Tuỳ chọn của trình đọc PDF (nhớ giữa các lần mở).
class ReaderPrefs {
  const ReaderPrefs({
    this.darkMode = false,
    this.horizontal = false,
    this.singlePage = false,
  });

  /// Đảo màu trang.
  final bool darkMode;

  /// Cuộn ngang (mặc định cuộn dọc).
  final bool horizontal;

  /// Từng trang một (mặc định cuộn liên tục).
  final bool singlePage;

  ReaderPrefs copyWith({bool? darkMode, bool? horizontal, bool? singlePage}) =>
      ReaderPrefs(
        darkMode: darkMode ?? this.darkMode,
        horizontal: horizontal ?? this.horizontal,
        singlePage: singlePage ?? this.singlePage,
      );
}

const String _kDark = 'reader.darkMode';
const String _kHorizontal = 'reader.horizontal';
const String _kSingle = 'reader.singlePage';

final readerPrefsProvider = NotifierProvider<ReaderPrefsNotifier, ReaderPrefs>(
  ReaderPrefsNotifier.new,
);

class ReaderPrefsNotifier extends Notifier<ReaderPrefs> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ReaderPrefs build() {
    final p = ref.watch(sharedPreferencesProvider);
    return ReaderPrefs(
      darkMode: p.getBool(_kDark) ?? false,
      horizontal: p.getBool(_kHorizontal) ?? false,
      singlePage: p.getBool(_kSingle) ?? false,
    );
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
    await _prefs.setBool(_kDark, value);
  }

  Future<void> setHorizontal(bool value) async {
    state = state.copyWith(horizontal: value);
    await _prefs.setBool(_kHorizontal, value);
  }

  Future<void> setSinglePage(bool value) async {
    state = state.copyWith(singlePage: value);
    await _prefs.setBool(_kSingle, value);
  }
}
