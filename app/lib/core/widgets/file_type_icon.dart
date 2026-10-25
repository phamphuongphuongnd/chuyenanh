import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/doc_type.dart';

/// Biểu tượng loại file tự vẽ: trang giấy gập góc + nhãn màu (PDF/DOC/XLS/PPT/TXT…).
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon(
    this.type, {
    super.key,
    this.size = 40,
    this.locked = false,
  });

  /// Tiện: `FileTypeIcon.forPath('/a/b.pdf')`.
  FileTypeIcon.forPath(
    String path, {
    super.key,
    this.size = 40,
    this.locked = false,
  }) : type = docTypeFromPath(path);

  final DocType type;

  /// Chiều cao; chiều rộng = 0.8 × size.
  final double size;

  /// Vẽ ổ khoá nhỏ góc dưới (PDF có mật khẩu).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size * 0.8,
      height: size,
      child: CustomPaint(
        painter: _FileTypePainter(
          color: AppColors.forDocType(type),
          label: type.label,
          paper: dark ? const Color(0xFF2A2A2A) : Colors.white,
          border: dark ? Colors.white24 : const Color(0xFFDDDDDD),
          locked: locked,
        ),
      ),
    );
  }
}

class _FileTypePainter extends CustomPainter {
  _FileTypePainter({
    required this.color,
    required this.label,
    required this.paper,
    required this.border,
    required this.locked,
  });

  final Color color;
  final String label;
  final Color paper;
  final Color border;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fold = w * 0.3;
    final r = w * 0.08;

    // Trang giấy gập góc trên phải.
    final page = Path()
      ..moveTo(r, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    canvas.drawPath(page, Paint()..color = paper);
    canvas.drawPath(
      page,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Tam giác góc gập.
    final corner = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w - fold, fold)
      ..lineTo(w, fold)
      ..close();
    canvas.drawPath(corner, Paint()..color = color.withValues(alpha: 0.45));

    // Nhãn màu.
    final bandTop = h * 0.52;
    final bandHeight = h * 0.28;
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.06, bandTop, w * 0.92, bandHeight),
      Radius.circular(r),
    );
    canvas.drawRRect(band, Paint()..color = color);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: bandHeight * 0.62,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w * 0.9);
    tp.paint(
      canvas,
      Offset(
        -w * 0.06 + (w * 0.92 - tp.width) / 2,
        bandTop + (bandHeight - tp.height) / 2,
      ),
    );

    if (locked) {
      final s = w * 0.36;
      final c = Offset(w - s * 0.55, h - s * 0.55);
      canvas.drawCircle(c, s * 0.6, Paint()..color = paper);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, s * 0.12),
          width: s * 0.7,
          height: s * 0.5,
        ),
        Radius.circular(s * 0.08),
      );
      final lockPaint = Paint()..color = const Color(0xFF424242);
      canvas.drawRRect(body, lockPaint);
      canvas.drawArc(
        Rect.fromCenter(
          center: c.translate(0, -s * 0.12),
          width: s * 0.44,
          height: s * 0.5,
        ),
        3.14159,
        3.14159,
        false,
        Paint()
          ..color = const Color(0xFF424242)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.1,
      );
    }
  }

  @override
  bool shouldRepaint(_FileTypePainter old) =>
      old.color != color ||
      old.label != label ||
      old.paper != paper ||
      old.border != border ||
      old.locked != locked;
}
