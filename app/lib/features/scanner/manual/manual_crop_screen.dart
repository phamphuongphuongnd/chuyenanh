import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'corner_geometry.dart';

/// Kéo bốn góc quanh tài liệu rồi cắt thẳng (perspective). Dùng khi máy không có
/// trình quét tự động. Trả đường dẫn file ảnh đã cắt qua `Navigator.pop` (`null` = huỷ).
class ManualCropScreen extends StatefulWidget {
  const ManualCropScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _Loaded {
  const _Loaded(this.width, this.height, this.corners);
  final int width, height;
  final List<ops.NormPoint> corners;
}

Future<_Loaded> _load(String path) => Isolate.run(() {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  final info = ops.probe(bytes);
  final found = ops.detectDocumentCorners(bytes);
  return _Loaded(
    info.width,
    info.height,
    found != null && isValidQuad(found) ? found : defaultCorners(),
  );
});

class _ManualCropScreenState extends State<ManualCropScreen> {
  late final Future<_Loaded> _future = _load(widget.imagePath);
  List<ops.NormPoint>? _corners;
  int? _dragging;
  bool _busy = false;

  Future<void> _crop(List<ops.NormPoint> corners) async {
    setState(() => _busy = true);
    try {
      final path = widget.imagePath;
      final bytes = await Isolate.run(
        () => ops.perspectiveWarp(
          Uint8List.fromList(File(path).readAsBytesSync()),
          corners,
          outLongSide: 3000,
        ),
      );
      final out = p.join(
        p.dirname(path),
        'crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(out).writeAsBytes(bytes, flush: true);
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final err = e is FormatException ? const CorruptFile() : AppError.from(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(appErrorMessage(context, err))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      // AppBar sáng theo theme mặc định (không đặt màu riêng).
      appBar: AppBar(title: Text(l.scan_manualTitle)),
      body: FutureBuilder<_Loaded>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Symbols.broken_image_rounded,
              title: appErrorMessage(context, const CorruptFile()),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final corners = _corners ??= data.corners;
          final valid = isValidQuad(corners);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Text(
                  l.scan_manualHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: t.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  // Chừa lề để chấm góc ở mép ảnh không bị cắt.
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: data.width / data.height,
                      child: LayoutBuilder(
                        builder: (context, box) => _CropArea(
                          imagePath: widget.imagePath,
                          size: box.biggest,
                          corners: corners,
                          onStart: (pos) =>
                              _dragging = nearestCornerIndex(corners, pos),
                          onMove: (pos) {
                            final i = _dragging;
                            if (i == null) return;
                            setState(() {
                              _corners = [...corners]..[i] = clampPoint(pos);
                            });
                          },
                          onEnd: () => _dragging = null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: valid && !_busy ? () => _crop(corners) : null,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.scan_manualDone),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CropArea extends StatelessWidget {
  const _CropArea({
    required this.imagePath,
    required this.size,
    required this.corners,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
  });

  final String imagePath;
  final Size size;
  final List<ops.NormPoint> corners;
  final void Function(ops.NormPoint) onStart;
  final void Function(ops.NormPoint) onMove;
  final VoidCallback onEnd;

  ops.NormPoint _norm(Offset o) =>
      ops.NormPoint(o.dx / size.width, o.dy / size.height);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => onStart(_norm(d.localPosition)),
      onPanUpdate: (d) => onMove(_norm(d.localPosition)),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: Stack(
        fit: StackFit.expand,
        // Không cắt chấm góc khi góc nằm sát mép ảnh (đã chừa lề 16 ở ngoài).
        clipBehavior: Clip.none,
        children: [
          Image.file(File(imagePath), fit: BoxFit.fill),
          CustomPaint(
            painter: _QuadPainter([
              for (final c in corners)
                Offset(c.x * size.width, c.y * size.height),
            ], AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.points, this.color);
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final pt in points) {
      canvas.drawCircle(pt, 13, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 10, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.points != points || old.color != color;
}
