import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nền đọc của chế độ dàn chữ.
enum ReflowTheme { light, sepia, dark }

/// Màu nền / chữ / chữ phụ của từng nền đọc (cố định, không theo sáng/tối của app).
extension ReflowThemeColors on ReflowTheme {
  Color get background => switch (this) {
    ReflowTheme.light => const Color(0xFFFFFFFF),
    ReflowTheme.sepia => const Color(0xFFF4ECD8),
    ReflowTheme.dark => const Color(0xFF121111),
  };

  Color get foreground => switch (this) {
    ReflowTheme.light => const Color(0xFF1C1918),
    ReflowTheme.sepia => const Color(0xFF4B3A2A),
    ReflowTheme.dark => const Color(0xFFE6E0DC),
  };

  Color get muted => switch (this) {
    ReflowTheme.light => const Color(0xFF6B6461),
    ReflowTheme.sepia => const Color(0xFF8A7458),
    ReflowTheme.dark => const Color(0xFFA8A09C),
  };
}

/// Mức giãn dòng (hệ số `height` của chữ thân).
const List<double> kReflowLineHeights = [1.3, 1.6, 2.0];

const double kReflowMinFont = 12;
const double kReflowMaxFont = 40;
const double kReflowDefaultFont = 18;

/// Cài đặt hiển thị của chế độ dàn chữ.
@immutable
class ReflowPrefs {
  const ReflowPrefs({
    this.fontSize = kReflowDefaultFont,
    this.theme = ReflowTheme.light,
    this.lineHeight = 1.6,
  });

  final double fontSize;
  final ReflowTheme theme;
  final double lineHeight;

  ReflowPrefs copyWith({
    double? fontSize,
    ReflowTheme? theme,
    double? lineHeight,
  }) => ReflowPrefs(
    fontSize: fontSize ?? this.fontSize,
    theme: theme ?? this.theme,
    lineHeight: lineHeight ?? this.lineHeight,
  );
}

/// Cỡ chữ / nền / giãn dòng — nhớ trong phiên (không ghi đĩa).
class ReflowPrefsNotifier extends Notifier<ReflowPrefs> {
  @override
  ReflowPrefs build() => const ReflowPrefs();

  void setFontSize(double v) => state = state.copyWith(
    fontSize: v.clamp(kReflowMinFont, kReflowMaxFont).toDouble(),
  );

  void setTheme(ReflowTheme t) => state = state.copyWith(theme: t);

  void setLineHeight(double h) => state = state.copyWith(lineHeight: h);
}

final reflowPrefsProvider = NotifierProvider<ReflowPrefsNotifier, ReflowPrefs>(
  ReflowPrefsNotifier.new,
);
