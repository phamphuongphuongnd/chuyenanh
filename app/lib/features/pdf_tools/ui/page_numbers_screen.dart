import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_tools_engine.dart' show PageRange;
import '../engine/page_numbers.dart';
import '../engine/page_ranges.dart';
import '../logic/tool_rules.dart';
import '../page_numbers_providers.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

const _palette = <int>[
  0xFF000000,
  0xFF616161,
  0xFFE5393B,
  0xFF1E88E5,
  0xFF43A047,
];

/// Khổ trang A4 dọc (point) — dùng để quy đổi cỡ chữ / lề sang ô xem trước.
const _previewPageWidth = 595.0;

/// Kế hoạch đánh số theo tuỳ chọn hiện tại.
typedef _Plan = ({
  int? start,
  List<PageRange>? ranges,
  bool rangeMissing,
  bool rangeError,
  int count,
});

/// Đánh số trang: kiểu số, vị trí, cỡ chữ, màu, lề, số bắt đầu, phạm vi trang, bỏ bìa.
class PageNumbersScreen extends ConsumerStatefulWidget {
  const PageNumbersScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<PageNumbersScreen> createState() => _PageNumbersScreenState();
}

class _PageNumbersScreenState extends ConsumerState<PageNumbersScreen>
    with SinglePdfToolState<PageNumbersScreen> {
  PageNumberStyle _style = PageNumberStyle.plain;
  PageNumberVAlign _vAlign = PageNumberVAlign.bottom;
  PageNumberHAlign _hAlign = PageNumberHAlign.center;
  double _fontSize = 11;
  int _color = _palette.first;
  double _margin = 24;
  bool _allPages = true;
  bool _skipFirst = false;
  final _startCtl = TextEditingController(text: '1');
  final _rangeCtl = TextEditingController();

  @override
  String? get initialPath => widget.path;

  @override
  void dispose() {
    _startCtl.dispose();
    _rangeCtl.dispose();
    super.dispose();
  }

  _Plan _plan(int pageCount) {
    final n = int.tryParse(_startCtl.text.trim());
    final start = (n != null && n >= 1 && n <= maxPageNumberStart) ? n : null;
    List<PageRange>? ranges;
    var missing = false;
    var error = false;
    if (!_allPages) {
      if (_rangeCtl.text.trim().isEmpty) {
        missing = true;
      } else {
        try {
          ranges = parsePageRanges(_rangeCtl.text, pageCount);
        } on FormatException {
          error = true;
        } on ArgumentError {
          error = true;
        }
      }
    }
    final count = (missing || error)
        ? 0
        : selectNumberedPages(
            pageCount,
            ranges: ranges,
            skipFirst: _skipFirst,
          ).length;
    return (
      start: start,
      ranges: ranges,
      rangeMissing: missing,
      rangeError: error,
      count: count,
    );
  }

  String _label(PageNumberStyle style, _Plan plan, int pageCount) {
    final start = plan.start ?? 1;
    final total = plan.count > 0 ? start + plan.count - 1 : pageCount;
    return formatPageLabel(
      style,
      start,
      total,
      pageWordTemplate: context.l10n.pagenum_pageWord(pageNumberToken),
    );
  }

  Future<void> _apply() async {
    final src = input;
    if (src == null) return;
    final l = context.l10n;
    final plan = _plan(src.pageCount);
    final start = plan.start;
    if (start == null) {
      showToolMessage(context, l.pagenum_invalidStart);
      return;
    }
    if (plan.rangeMissing || plan.rangeError) {
      showToolMessage(context, l.pagenum_invalidRange(src.pageCount));
      return;
    }
    if (plan.count == 0) {
      showToolMessage(context, l.pagenum_noPages);
      return;
    }
    final spec = PageNumberSpec(
      style: _style,
      vAlign: _vAlign,
      hAlign: _hAlign,
      fontSize: _fontSize,
      colorArgb: _color,
      margin: _margin,
      startNumber: start,
      ranges: plan.ranges,
      skipFirstPage: _skipFirst,
      pageWordTemplate: l.pagenum_pageWord(pageNumberToken),
    );
    final out = await newOutputPath(ref, suffixedName(src.path, 'numbered'));
    if (!mounted) return;
    final engine = ref.read(pageNumbersEngineProvider);
    final result = await runToolJob<String>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) => engine.addPageNumbers(
        src.path,
        spec,
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
    final title = l.core_toolPageNumbers;
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
    final plan = _plan(src.pageCount);
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          // Khối xem trước: nền phụ, trang A4 trắng ở giữa.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: context.tokens.surface2,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: _Preview(
              label: _label(_style, plan, src.pageCount),
              vAlign: _vAlign,
              hAlign: _hAlign,
              fontSize: _fontSize,
              color: _color,
              margin: _margin,
            ),
          ),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolSectionLabel(l.pagenum_style),
                ToolChipWrap(
                  children: [
                    for (final s in PageNumberStyle.values)
                      ToolChoiceChip(
                        key: ValueKey('style_${s.name}'),
                        label: _label(s, plan, src.pageCount),
                        selected: _style == s,
                        onTap: () => setState(() => _style = s),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ToolSectionLabel(l.pagenum_position),
                _PositionGrid(
                  vAlign: _vAlign,
                  hAlign: _hAlign,
                  onChanged: (v, h) => setState(() {
                    _vAlign = v;
                    _hAlign = h;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LabeledSlider(
                  label: l.pagenum_fontSize,
                  value: _fontSize,
                  min: minPageNumberFontSize,
                  max: maxPageNumberFontSize,
                  divisions:
                      (maxPageNumberFontSize - minPageNumberFontSize).round(),
                  display: '${_fontSize.round()}',
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
                const SizedBox(height: 8),
                _LabeledSlider(
                  label: l.pagenum_margin,
                  value: _margin,
                  min: 8,
                  max: 72,
                  divisions: 16,
                  display: '${_margin.round()} pt',
                  onChanged: (v) => setState(() => _margin = v),
                ),
                const SizedBox(height: 12),
                ToolSectionLabel(l.pagenum_color),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in _palette)
                      ToolColorDot(
                        color: Color(c),
                        selected: _color == c,
                        onTap: () => setState(() => _color = c),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolSectionLabel(l.pagenum_startAt),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 140,
                    child: AppTextField(
                      key: const ValueKey('pagenum_start'),
                      controller: _startCtl,
                      keyboardType: TextInputType.number,
                      errorText: plan.start == null
                          ? l.pagenum_invalidStart
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ToolSectionLabel(l.pagenum_pages),
                ToolChipWrap(
                  children: [
                    ToolChoiceChip(
                      label: l.pagenum_allPages,
                      selected: _allPages,
                      onTap: () => setState(() => _allPages = true),
                    ),
                    ToolChoiceChip(
                      label: l.pagenum_customRange,
                      selected: !_allPages,
                      onTap: () => setState(() => _allPages = false),
                    ),
                  ],
                ),
                if (!_allPages) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const ValueKey('pagenum_range'),
                    controller: _rangeCtl,
                    labelText: l.pagenum_rangeLabel,
                    hintText: l.pagenum_rangeHint,
                    keyboardType: TextInputType.text,
                    onChanged: (_) => setState(() {}),
                    errorText: plan.rangeError
                        ? l.pagenum_invalidRange(src.pageCount)
                        : null,
                  ),
                ],
                const SizedBox(height: 8),
                // ToolCard là DecoratedBox có nền: ListTile cần Material riêng
                // để hiệu ứng mực khi chạm không bị nền thẻ che.
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    key: const ValueKey('pagenum_skipFirst'),
                    contentPadding: EdgeInsets.zero,
                    value: _skipFirst,
                    onChanged: (v) => setState(() => _skipFirst = v),
                    title: Text(
                      l.pagenum_skipFirst,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.text,
                      ),
                    ),
                    subtitle: Text(
                      l.pagenum_skipFirstHint,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: context.tokens.textMuted,
                      ),
                    ),
                  ),
                ),
                if (plan.count > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Symbols.format_list_numbered_rounded,
                        size: 18,
                        color: context.tokens.primaryText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.pagenum_summary(plan.count),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (!plan.rangeMissing && !plan.rangeError) ...[
                  const SizedBox(height: 6),
                  NoteBanner(l.pagenum_noPages, warning: true),
                ],
              ],
            ),
          ),
        ],
      ),
      bottom: PrimaryActionButton(label: l.pagenum_action, onPressed: _apply),
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
    final t = context.tokens;
    // Nhãn + giá trị ở trên, thanh trượt đỏ chủ đạo rộng hết khối ở dưới.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                ),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Lưới 2×3 chọn vị trí số trang (hàng trên / dưới × trái / giữa / phải).
class _PositionGrid extends StatelessWidget {
  const _PositionGrid({
    required this.vAlign,
    required this.hAlign,
    required this.onChanged,
  });

  final PageNumberVAlign vAlign;
  final PageNumberHAlign hAlign;
  final void Function(PageNumberVAlign v, PageNumberHAlign h) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 144,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (final v in PageNumberVAlign.values) ...[
              Row(
                children: [
                  for (final h in PageNumberHAlign.values)
                    Expanded(
                      child: InkWell(
                        key: ValueKey('pos_${v.name}_${h.name}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onChanged(v, h),
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: vAlign == v && hAlign == h
                                    ? AppColors.primary
                                    : t.lineStrong,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Khoảng giữa hai hàng gợi ý "thân trang".
              if (v == PageNumberVAlign.top) const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ô xem trước trang A4 với số trang (xấp xỉ: chữ phóng ×2 cho dễ nhìn, không đo như engine).
class _Preview extends StatelessWidget {
  const _Preview({
    required this.label,
    required this.vAlign,
    required this.hAlign,
    required this.fontSize,
    required this.color,
    required this.margin,
  });

  final String label;
  final PageNumberVAlign vAlign;
  final PageNumberHAlign hAlign;
  final double fontSize;
  final int color;
  final double margin;

  @override
  Widget build(BuildContext context) {
    const width = 180.0;
    const height = width * 1.414;
    const scale = width / _previewPageWidth;
    final pad = margin * scale;
    final alignment = Alignment(
      switch (hAlign) {
        PageNumberHAlign.left => -1.0,
        PageNumberHAlign.center => 0.0,
        PageNumberHAlign.right => 1.0,
      },
      vAlign == PageNumberVAlign.top ? -1.0 : 1.0,
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Trang giấy luôn trắng (cả giao diện tối); không đổ bóng.
        color: Colors.white,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // vài dòng giả làm nội dung trang
          for (var i = 0; i < 9; i++)
            Positioned(
              left: 14,
              right: i.isEven ? 14 : 40,
              top: 36 + i * 14.0,
              child: Container(height: 5, color: Colors.black12),
            ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: Align(
              alignment: alignment,
              child: Text(
                label,
                key: const ValueKey('pagenum_preview_label'),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: math.max(5.0, fontSize * scale * 2),
                  color: Color(color),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
