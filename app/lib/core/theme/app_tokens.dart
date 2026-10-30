import 'package:flutter/material.dart';

/// Họ font giao diện (Be Vietnam Pro, đóng gói ở `assets/ui_fonts/`, giấy phép OFL).
const String kUiFontFamily = 'BeVietnamPro';

/// Token màu sáng/tối của thiết kế `design-mobile/README.md` §1.1.
/// Lấy trong widget: `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.textMuted,
    required this.line,
    required this.lineStrong,
    required this.primaryText,
    required this.primarySoft,
    required this.input,
    required this.scrim,
    required this.snackbarBg,
    required this.snackbarFg,
    required this.filesAllHeader,
    required this.tintBlue,
    required this.tintOrange,
  });

  /// Nền màn.
  final Color bg;

  /// Thẻ, danh sách, thanh dưới, sheet, hộp thoại.
  final Color surface;

  /// Skeleton, nền minh hoạ trống.
  final Color surface2;
  final Color text;

  /// Phụ đề, nhãn nhóm, icon phụ.
  final Color textMuted;

  /// Đường kẻ, viền thẻ.
  final Color line;

  /// Viền nút phụ, sao chưa chọn, tay kéo sheet.
  final Color lineStrong;

  /// Chữ đỏ trên nền ("Xem tất cả ›", tiêu đề nhóm, mục đang chọn).
  final Color primaryText;

  /// Nền icon Cài đặt, băng xin quyền, mục điều hướng đang chọn.
  final Color primarySoft;

  /// Nền ô nhập.
  final Color input;

  /// Lớp phủ sau sheet / hộp thoại.
  final Color scrim;
  final Color snackbarBg;
  final Color snackbarFg;

  /// Thanh tiêu đề tab "Tất cả" của Tập tin.
  final Color filesAllHeader;

  /// Nền icon "Quét tài liệu" / "PDF sang ảnh".
  final Color tintBlue;
  final Color tintOrange;

  static const light = AppTokens(
    bg: Color(0xFFF5F3F1),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEEBE8),
    text: Color(0xFF1C1918),
    textMuted: Color(0xFF6B6461),
    line: Color(0x141C1918),
    lineStrong: Color(0x2E1C1918),
    primaryText: Color(0xFFC62828),
    primarySoft: Color(0xFFFDECEC),
    input: Color(0xFFFFF8E1),
    scrim: Color(0x6114100F),
    snackbarBg: Color(0xFF2B2726),
    snackbarFg: Color(0xFFFFFFFF),
    filesAllHeader: Color(0xFF25212B),
    tintBlue: Color(0xFFE3F0FD),
    tintOrange: Color(0xFFFEEDE4),
  );

  static const dark = AppTokens(
    bg: Color(0xFF121111),
    surface: Color(0xFF1E1C1B),
    surface2: Color(0xFF2A2726),
    text: Color(0xFFF4F0EE),
    textMuted: Color(0xFFA8A09C),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x33FFFFFF),
    primaryText: Color(0xFFFF7B76),
    primarySoft: Color(0xFF3A1E1E),
    input: Color(0xFF2C2A22),
    scrim: Color(0x99000000),
    snackbarBg: Color(0xFFF4F0EE),
    snackbarFg: Color(0xFF1C1918),
    filesAllHeader: Color(0xFF2C2833),
    tintBlue: Color(0xFF14283D),
    tintOrange: Color(0xFF3A2117),
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? text,
    Color? textMuted,
    Color? line,
    Color? lineStrong,
    Color? primaryText,
    Color? primarySoft,
    Color? input,
    Color? scrim,
    Color? snackbarBg,
    Color? snackbarFg,
    Color? filesAllHeader,
    Color? tintBlue,
    Color? tintOrange,
  }) => AppTokens(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    primaryText: primaryText ?? this.primaryText,
    primarySoft: primarySoft ?? this.primarySoft,
    input: input ?? this.input,
    scrim: scrim ?? this.scrim,
    snackbarBg: snackbarBg ?? this.snackbarBg,
    snackbarFg: snackbarFg ?? this.snackbarFg,
    filesAllHeader: filesAllHeader ?? this.filesAllHeader,
    tintBlue: tintBlue ?? this.tintBlue,
    tintOrange: tintOrange ?? this.tintOrange,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      primaryText: l(primaryText, other.primaryText),
      primarySoft: l(primarySoft, other.primarySoft),
      input: l(input, other.input),
      scrim: l(scrim, other.scrim),
      snackbarBg: l(snackbarBg, other.snackbarBg),
      snackbarFg: l(snackbarFg, other.snackbarFg),
      filesAllHeader: l(filesAllHeader, other.filesAllHeader),
      tintBlue: l(tintBlue, other.tintBlue),
      tintOrange: l(tintOrange, other.tintOrange),
    );
  }
}

/// Bóng đổ của thiết kế (§1.6). Danh sách và thẻ file không đổ bóng.
abstract final class AppShadows {
  static const primary = [
    BoxShadow(color: Color(0x47E5393B), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const navAction = [
    BoxShadow(color: Color(0x59E5393B), blurRadius: 18, offset: Offset(0, 8)),
  ];
  static const menu = [
    BoxShadow(color: Color(0x38000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const dialog = [
    BoxShadow(color: Color(0x40000000), blurRadius: 50, offset: Offset(0, 20)),
  ];
}

extension AppTokensContext on BuildContext {
  /// Token sáng/tối hiện tại (mặc định bản sáng nếu theme chưa gắn).
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
