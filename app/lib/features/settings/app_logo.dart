import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Logo app tự vẽ (phương án "Xấp định dạng", `design-mobile/screens/assets/logo-3-color.svg`):
/// nền kem bo góc, xấp 4 tấm thẻ màu theo loại file (DOC, XLS, PPT, PDF) xoay quanh
/// đáy, thẻ đỏ trên cùng có chữ P. Cùng hình học với adaptive icon Android.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const AppLogoPainter()),
    );
  }
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter();

  /// Nền kem của khung logo.
  static const Color background = Color(0xFFF4EEE6);

  /// Thẻ trên cùng (chữ P) = màu chủ đạo.
  static const Color front = AppColors.primary;

  /// Thẻ phía sau, từ dưới lên: DOC, XLS, PPT.
  static const List<Color> back = [AppColors.doc, AppColors.xls, AppColors.ppt];

  /// Cạnh khung vẽ gốc (đơn vị toạ độ của SVG).
  static const double _unit = 512;

  static const _card = Rect.fromLTWH(156, 130, 200, 264);
  static const _pivot = Offset(256, 400);
  static const _deg = 3.141592653589793 / 180;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _unit, size.height / _unit);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _unit, _unit),
        const Radius.circular(116),
      ),
      Paint()..color = background,
    );

    canvas.translate(26, -6);
    const angles = [-24.0, -16.0, -8.0];
    for (var i = 0; i < back.length; i++) {
      _drawCard(canvas, back[i], angles[i]);
    }
    _drawCard(canvas, front, 0);

    final p = Path()
      ..moveTo(212, 336)
      ..lineTo(212, 196)
      ..lineTo(260, 196)
      ..arcToPoint(
        const Offset(260, 284),
        radius: const Radius.circular(44),
      )
      ..lineTo(212, 284);
    canvas.drawPath(
      p,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  void _drawCard(Canvas canvas, Color color, double degrees) {
    canvas.save();
    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.rotate(degrees * _deg);
    canvas.translate(-_pivot.dx, -_pivot.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_card, const Radius.circular(30)),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
