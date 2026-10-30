import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/doc_type.dart';

/// Biểu tượng loại file tự vẽ: trang màu theo loại, cắt góc trên phải, nhãn chữ trắng
/// (PDF/DOC/XLS/PPT/TXT…) ở dưới. PDF có mật khẩu → huy hiệu ổ khoá tròn góc dưới phải.
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

  /// Vẽ huy hiệu ổ khoá (PDF có mật khẩu).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final page = CustomPaint(
      size: Size(size * 0.8, size),
      painter: _FileTypePainter(
        color: AppColors.forDocType(type),
        label: type.label,
      ),
    );
    if (!locked) return page;
    final t = context.tokens;
    final badge = size * 0.425;
    return SizedBox(
      width: size * 0.8,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          page,
          Positioned(
            right: -size * 0.125,
            bottom: -size * 0.1,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: t.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                Symbols.lock_rounded,
                fill: 1,
                size: badge * 0.7,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTypePainter extends CustomPainter {
  _FileTypePainter({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.16;
    // Góc cắt: từ 68% cạnh trên xuống 28% cạnh phải (như thiết kế).
    final cutX = w * 0.68;
    final cutY = h * 0.28;

    final page = Path()
      ..moveTo(r, 0)
      ..lineTo(cutX, 0)
      ..lineTo(w, cutY)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    canvas.drawPath(page, Paint()..color = color);

    // Mép gập: tam giác trắng mờ dưới đường cắt.
    final fold = Path()
      ..moveTo(cutX, 0)
      ..lineTo(w, cutY)
      ..lineTo(cutX, cutY)
      ..close();
    canvas.drawPath(fold, Paint()..color = Colors.white.withValues(alpha: 0.5));

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: kUiFontFamily,
          color: Colors.white,
          fontSize: h * 0.2125,
          fontWeight: FontWeight.w800,
          letterSpacing: h * 0.2125 * 0.03,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w);
    tp.paint(canvas, Offset((w - tp.width) / 2, h - h * 0.125 - tp.height));
  }

  @override
  bool shouldRepaint(_FileTypePainter old) =>
      old.color != color || old.label != label;
}
