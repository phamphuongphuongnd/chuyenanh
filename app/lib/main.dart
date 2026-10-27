import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/l10n/l10n.dart';
import 'data/settings/settings_providers.dart';
import 'features/scanner/capture/scan_temp_cleanup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    for (final l in appLocales) initializeDateFormatting(l.languageCode),
  ]);
  final prefs = await SharedPreferences.getInstance();
  // Dọn ảnh quét bỏ dở ở nền, không chặn khung hình đầu.
  unawaited(cleanupStaleScanFiles(null));
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PdfOfficeApp(),
    ),
  );
}
