import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/l10n/l10n.dart';
import 'data/settings/settings_providers.dart';
import 'features/scanner/capture/scan_temp_cleanup.dart';

final Stopwatch _boot = Stopwatch()..start();

/// Mốc thời gian khởi động; chỉ in khi build với `--dart-define=STARTUP_TRACE=true`.
void startupTrace(String m) {
  if (const bool.fromEnvironment('STARTUP_TRACE')) {
    // ignore: avoid_print
    print('STARTUP ${_boot.elapsedMilliseconds}ms $m');
  }
}

Future<void> main() async {
  startupTrace('main');
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    for (final l in appLocales) initializeDateFormatting(l.languageCode),
  ]);
  startupTrace('date-init');
  final prefs = await SharedPreferences.getInstance();
  startupTrace('prefs');
  // Dọn ảnh quét bỏ dở ở nền, không chặn khung hình đầu.
  unawaited(cleanupStaleScanFiles(null));
  WidgetsBinding.instance.addPostFrameCallback((_) => startupTrace('first-frame'));
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PdfOfficeApp(),
    ),
  );
}
