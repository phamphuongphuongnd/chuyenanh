import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/settings/settings_providers.dart';
import 'features/reader/shortcut/shortcut_launcher.dart';
import 'features/system/app_lock_gate.dart';
import 'features/system/incoming_files.dart';

class PdfOfficeApp extends ConsumerWidget {
  const PdfOfficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final router = ref.watch(appRouterProvider);
    // Mở trình đọc khi app được bật từ lối tắt màn hình chính (T3).
    ref.watch(shortcutLaunchProvider);
    // Mở file nhận từ app khác ("Mở bằng", "Chia sẻ tới", iOS "Mở trong").
    ref.watch(incomingFilesProvider);
    return MaterialApp.router(
      // Lớp khoá app (vân tay / PIN) phủ lên mọi màn.
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox()),
      onGenerateTitle: (context) => context.l10n.core_appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
