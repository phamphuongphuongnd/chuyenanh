import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

export 'app_colors.dart';
export 'app_tokens.dart';

/// Theme sáng/tối theo thiết kế `design-mobile/` (font Be Vietnam Pro, token [AppTokens]).
///
/// AppBar sáng theo nền; trình xem và màn có ô tìm kiếm trên thanh tiêu đề tự đặt màu.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final t = isDark ? AppTokens.dark : AppTokens.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: t.surface,
          onSurface: t.text,
          onSurfaceVariant: t.textMuted,
          surfaceContainerHighest: t.surface2,
          outlineVariant: t.line,
        );
    const pill = StadiumBorder();
    const buttonText = TextStyle(
      fontFamily: kUiFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: kUiFontFamily,
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      // Màn con: thanh tiêu đề sáng theo nền màn, chữ đậm. Màn có ô tìm kiếm trắng trên
      // thanh tiêu đề (AppSearchField) và trình xem tự đặt nền màu (đỏ / màu loại file).
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: t.text,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        dividerColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: t.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: t.text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 14.5,
          height: 1.5,
          color: t.textMuted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: t.scrim,
        dragHandleColor: t.lineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: t.line),
        ),
        textStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: t.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.snackbarBg,
        actionTextColor: isDark ? AppColors.primaryDark : const Color(0xFFFF7B76),
        contentTextStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: t.snackbarFg,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: t.line, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: t.lineStrong, width: 1.5),
          textStyle: buttonText,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primaryText,
          textStyle: buttonText.copyWith(fontSize: 14),
          shape: pill,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primary.withValues(alpha: 0.16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorStyle: TextStyle(
          fontFamily: kUiFontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: t.primaryText,
        ),
      ),
    );
  }
}
