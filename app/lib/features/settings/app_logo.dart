import 'package:flutter/material.dart';

/// Logo app tự vẽ (không dùng tài nguyên bên ngoài): nền đỏ `#E5393B`, trang giấy gập góc
/// phải trên, mũi tên xuống. Cùng hình học với adaptive icon Android
/// (`res/drawable/ic_launcher_foreground.xml`, khung 108x108).
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

  static const Color background = Color(0xFFE5393B);
  static const Color fold = Color(0xFFF6C4C5);

  /// Cạnh khung vẽ gốc (đơn vị của toạ độ bên dưới).
  static const double _unit = 108;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _unit, size.height / _unit);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _unit, _unit),
        const Radius.circular(24),
      ),
      Paint()..color = background,
    );

    final page = Path()
      ..moveTo(35, 28)
      ..lineTo(59, 28)
      ..lineTo(73, 42)
      ..lineTo(73, 80)
      ..lineTo(35, 80)
      ..close();
    canvas.drawPath(page, Paint()..color = Colors.white);

    final foldPath = Path()
      ..moveTo(59, 28)
      ..lineTo(59, 42)
      ..lineTo(73, 42)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = fold);

    final arrow = Path()
      ..moveTo(51, 48)
      ..lineTo(57, 48)
      ..lineTo(57, 60)
      ..lineTo(65, 60)
      ..lineTo(54, 73)
      ..lineTo(43, 60)
      ..lineTo(51, 60)
      ..close();
    canvas.drawPath(arrow, Paint()..color = background);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
