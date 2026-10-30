import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import 'signature_image.dart';

/// Màu bút chọn nhanh.
const List<Color> kPenColors = [
  Color(0xFF111111),
  Color(0xFF1A3FA8),
  Color(0xFFC62828),
  Color(0xFF2E7D32),
];

/// Mở bảng vẽ chữ ký. Trả về PNG nền trong suốt đã cắt sát nét, hoặc `null` nếu huỷ.
Future<Uint8List?> showSignaturePadSheet(BuildContext context) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const SignaturePadSheet(),
  );
}

class SignaturePadSheet extends StatefulWidget {
  const SignaturePadSheet({super.key});

  @override
  State<SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<SignaturePadSheet> {
  final GlobalKey<SfSignaturePadState> _padKey = GlobalKey();

  Color _color = kPenColors.first;
  double _width = 3;
  bool _hasInk = false;
  bool _busy = false;
  bool _showEmptyWarning = false;

  void _clear() {
    _padKey.currentState?.clear();
    setState(() {
      _hasInk = false;
      _showEmptyWarning = false;
    });
  }

  Future<void> _use() async {
    if (!_hasInk) {
      setState(() => _showEmptyWarning = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final image = await _padKey.currentState!.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        setState(() => _busy = false);
        return;
      }
      final trimmed = trimSignaturePng(data.buffer.asUint8List());
      if (!mounted) return;
      if (trimmed == null) {
        setState(() {
          _busy = false;
          _hasInk = false;
          _showEmptyWarning = true;
        });
        return;
      }
      Navigator.of(context).pop(trimmed);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: t.text,
    );
    // Sheet đã có tay kéo (`showDragHandle`) nên lề trên nhỏ.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.edit_drawSignature,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 14),
          // Ô vẽ: luôn nền trắng (mực tối) ở cả giao diện tối, bo 16, viền `line`.
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showEmptyWarning ? AppColors.primary : t.line,
                width: _showEmptyWarning ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  const Positioned(
                    left: 16,
                    right: 16,
                    bottom: 40,
                    child: Divider(height: 1, color: Colors.black26),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 14,
                    child: Text(
                      l.edit_signHere,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.light.textMuted,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: SfSignaturePad(
                      key: _padKey,
                      backgroundColor: Colors.transparent,
                      strokeColor: _color,
                      minimumStrokeWidth: _width * 0.5,
                      maximumStrokeWidth: _width,
                      onDraw: (_, _) {
                        if (!_hasInk) {
                          setState(() {
                            _hasInk = true;
                            _showEmptyWarning = false;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showEmptyWarning)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                l.edit_signatureEmpty,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: t.primaryText,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(l.edit_penColor, style: labelStyle),
              const SizedBox(width: 10),
              for (final c in kPenColors)
                _PenDot(
                  key: Key('pen_${c.toARGB32()}'),
                  color: c,
                  selected: _color == c,
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
          Row(
            children: [
              Text(l.edit_penWidth, style: labelStyle),
              Expanded(
                child: Slider(
                  value: _width,
                  min: 1.5,
                  max: 8,
                  activeColor: AppColors.primary,
                  inactiveColor: t.surface2,
                  onChanged: (v) => setState(() => _width = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('clearPad'),
                      onPressed: _busy ? null : _clear,
                      child: Text(l.edit_clear),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('usePad'),
                      onPressed: _busy ? null : _use,
                      child: Text(l.edit_useSignature),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chấm màu bút tròn 32; đang chọn = viền đỏ chủ đạo + dấu ✓ trắng (thấy rõ cả trên mực đen).
class _PenDot extends StatelessWidget {
  const _PenDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : t.lineStrong,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? const Icon(
                    Symbols.check_rounded,
                    size: 16,
                    weight: 700,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
