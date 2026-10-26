import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import '../../core/l10n/l10n.dart';
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.edit_drawSignature, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showEmptyWarning
                    ? theme.colorScheme.error
                    : theme.dividerColor,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 40,
                    child: Divider(height: 1, color: Colors.black26),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 14,
                    child: Text(
                      l.edit_signHere,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black38,
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
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l.edit_signatureEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l.edit_penColor, style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              for (final c in kPenColors)
                InkResponse(
                  key: Key('pen_${c.toARGB32()}'),
                  onTap: () => setState(() => _color = c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c
                              ? theme.colorScheme.primary
                              : Colors.black12,
                          width: _color == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Text(l.edit_penWidth, style: theme.textTheme.labelLarge),
              Expanded(
                child: Slider(
                  value: _width,
                  min: 1.5,
                  max: 8,
                  onChanged: (v) => setState(() => _width = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('clearPad'),
                  onPressed: _busy ? null : _clear,
                  child: Text(l.edit_clear.toUpperCase()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('usePad'),
                  onPressed: _busy ? null : _use,
                  child: Text(l.edit_useSignature.toUpperCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
