import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../engine/pdf_ops.dart' show isLatin1;
import '../engine/watermark_layout.dart';
import '../logic/tool_rules.dart';
import '../pdf_tools_providers.dart';
import 'pdf_file_picker.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

const _palette = <int>[
  0xFFE5393B,
  0xFF000000,
  0xFF1E88E5,
  0xFF43A047,
  0xFFF4511E,
  0xFF78909C,
];

/// Khổ trang A4 dọc (point) — dùng để quy đổi cỡ chữ sang ô xem trước.
const _previewPageWidth = 595.0;

/// Thêm watermark chữ hoặc ảnh lên mọi trang.
class WatermarkScreen extends ConsumerStatefulWidget {
  const WatermarkScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends ConsumerState<WatermarkScreen>
    with SinglePdfToolState<WatermarkScreen> {
  bool _isText = true;
  final _textCtl = TextEditingController(text: 'CONFIDENTIAL');
  Uint8List? _image;
  int _color = _palette.first;
  double _fontSize = 48;
  double _imageScale = 0.5;
  double _opacity = 0.3;
  double _angle = -45;
  double _alignX = 0;
  double _alignY = 0;

  @override
  String? get initialPath => widget.path;

  @override
  void dispose() {
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await ref.read(pdfFilePickerProvider).pickImageBytes();
    if (!mounted || bytes == null) return;
    if (!isPngOrJpeg(bytes)) {
      showToolMessage(context, context.l10n.tools_wmNeedImage);
      return;
    }
    setState(() {
      _image = bytes;
      if (_angle == -45) _angle = 0;
    });
  }

  void _setMode(bool text) {
    setState(() {
      _isText = text;
      // Gợi ý góc: chữ chéo -45, ảnh thẳng 0 (chỉ đổi nếu người dùng chưa chỉnh).
      if (_angle == -45 || _angle == 0) _angle = text ? -45 : 0;
    });
  }

  PlacedWatermarkSpec? _buildSpec(BuildContext context) {
    final l = context.l10n;
    if (_isText) {
      final text = _textCtl.text.trim();
      if (text.isEmpty) {
        showToolMessage(context, l.tools_wmNeedText);
        return null;
      }
      return PlacedWatermarkSpec.text(
        text,
        fontSize: _fontSize,
        colorArgb: _color,
        opacity: _opacity,
        angle: _angle,
        alignX: _alignX,
        alignY: _alignY,
      );
    }
    final image = _image;
    if (image == null) {
      showToolMessage(context, l.tools_wmNeedImage);
      return null;
    }
    return PlacedWatermarkSpec.image(
      image,
      imageScale: _imageScale,
      opacity: _opacity,
      angle: _angle,
      alignX: _alignX,
      alignY: _alignY,
    );
  }

  Future<void> _apply() async {
    final src = input;
    if (src == null) return;
    final built = _buildSpec(context);
    if (built == null) return;
    final out = await newOutputPath(ref, suffixedName(src.path, 'watermark'));
    if (!mounted) return;
    final engine = ref.read(pdfToolsEngineProvider);
    final result = await runToolJob<String>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) => engine.watermark(
        src.path,
        built,
        out,
        password: src.password,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (result == null || !mounted) return;
    await finish([result]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolWatermark;
    final res = results;
    if (res != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: res, onDone: () => context.pop()),
      );
    }
    final src = input;
    if (src == null) {
      return ToolScaffold(
        title: title,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: pickNew),
      );
    }
    final nonLatin = _isText && !isLatin1(_textCtl.text);
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          Center(
            child: _Preview(
              isText: _isText,
              text: _textCtl.text,
              image: _image,
              color: _color,
              fontSize: _fontSize,
              imageScale: _imageScale,
              opacity: _opacity,
              angle: _angle,
              alignX: _alignX,
              alignY: _alignY,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l.tools_wmTypeText),
                selected: _isText,
                onSelected: (_) => _setMode(true),
              ),
              ChoiceChip(
                label: Text(l.tools_wmTypeImage),
                selected: !_isText,
                onSelected: (_) => _setMode(false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isText) ...[
            AppTextField(
              controller: _textCtl,
              labelText: l.tools_wmTextLabel,
              onChanged: (_) => setState(() {}),
            ),
            if (nonLatin) ...[
              const SizedBox(height: 8),
              NoteBanner(l.tools_wmNonLatinNote, icon: Icons.warning_amber_outlined),
            ],
            const SizedBox(height: 12),
            Text(l.tools_wmColor),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            _LabeledSlider(
              label: l.tools_wmFontSize,
              value: _fontSize,
              min: 12,
              max: 120,
              divisions: 108,
              display: '${_fontSize.round()}',
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(l.tools_wmChooseImage),
            ),
            _LabeledSlider(
              label: l.tools_wmImageSize,
              value: _imageScale,
              min: 0.1,
              max: 1,
              divisions: 18,
              display: '${(_imageScale * 100).round()}%',
              onChanged: (v) => setState(() => _imageScale = v),
            ),
          ],
          _LabeledSlider(
            label: l.tools_wmOpacity,
            value: _opacity,
            min: 0.05,
            max: 1,
            divisions: 19,
            display: '${(_opacity * 100).round()}%',
            onChanged: (v) => setState(() => _opacity = v),
          ),
          _LabeledSlider(
            label: l.tools_wmAngle,
            value: _angle,
            min: -90,
            max: 90,
            divisions: 36,
            display: '${_angle.round()}°',
            onChanged: (v) => setState(() => _angle = v),
          ),
          const SizedBox(height: 8),
          Text(l.tools_wmPosition),
          const SizedBox(height: 4),
          _PositionGrid(
            alignX: _alignX,
            alignY: _alignY,
            onChanged: (x, y) => setState(() {
              _alignX = x;
              _alignY = y;
            }),
          ),
          const SizedBox(height: 16),
          NoteBanner(l.tools_noteLosesFeatures),
        ],
      ),
      bottom: PrimaryActionButton(label: l.tools_wmAction, onPressed: _apply),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}

/// Lưới 3×3 chọn vị trí watermark.
class _PositionGrid extends StatelessWidget {
  const _PositionGrid({
    required this.alignX,
    required this.alignY,
    required this.onChanged,
  });

  final double alignX;
  final double alignY;
  final void Function(double x, double y) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (final y in const [-1.0, 0.0, 1.0])
              Row(
                children: [
                  for (final x in const [-1.0, 0.0, 1.0])
                    Expanded(
                      child: InkWell(
                        key: ValueKey('pos_${x.toInt()}_${y.toInt()}'),
                        onTap: () => onChanged(x, y),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: alignX == x && alignY == y
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Ô xem trước trang A4 với watermark (xấp xỉ: không đo chữ chính xác như engine).
class _Preview extends StatelessWidget {
  const _Preview({
    required this.isText,
    required this.text,
    required this.image,
    required this.color,
    required this.fontSize,
    required this.imageScale,
    required this.opacity,
    required this.angle,
    required this.alignX,
    required this.alignY,
  });

  final bool isText;
  final String text;
  final Uint8List? image;
  final int color;
  final double fontSize;
  final double imageScale;
  final double opacity;
  final double angle;
  final double alignX;
  final double alignY;

  @override
  Widget build(BuildContext context) {
    const width = 180.0;
    const height = width * 1.414;
    const scale = width / _previewPageWidth;
    Widget? mark;
    if (isText && text.trim().isNotEmpty) {
      mark = Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: fontSize * scale,
          color: Color(color),
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (!isText && image != null) {
      mark = Image.memory(image!, width: width * imageScale);
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // vài dòng giả làm nội dung trang
          for (var i = 0; i < 9; i++)
            Positioned(
              left: 14,
              right: i.isEven ? 14 : 40,
              top: 18 + i * 14.0,
              child: Container(height: 5, color: Colors.black12),
            ),
          if (mark != null)
            Align(
              alignment: Alignment(alignX * 0.8, alignY * 0.85),
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: mark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
