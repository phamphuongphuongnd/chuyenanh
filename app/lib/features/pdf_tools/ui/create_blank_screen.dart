import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/settings/settings_providers.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import '../logic/tool_rules.dart';
import '../pdf_tools_providers.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

const _backgrounds = <int>[
  0xFFFFFFFF,
  0xFFFFF59D,
  0xFFBBDEFB,
  0xFFC8E6C9,
  0xFFF8BBD0,
  0xFFE0E0E0,
];

/// Danh mục (ghi vào metadata `subject`); `null` = không đặt.
const _categories = <String?>[null, 'Work', 'Study', 'Personal', 'Notes'];

/// Tạo tài liệu PDF trắng / kẻ dòng / kẻ ô.
class CreateBlankScreen extends ConsumerStatefulWidget {
  const CreateBlankScreen({super.key});

  @override
  ConsumerState<CreateBlankScreen> createState() => _CreateBlankScreenState();
}

class _CreateBlankScreenState extends ConsumerState<CreateBlankScreen> {
  BlankTemplate _template = BlankTemplate.blank;
  late PageSizeOption _pageSize;
  bool _landscape = false;
  int _background = _backgrounds.first;
  String? _category;
  final _titleCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _pagesCtl = TextEditingController(text: '1');
  List<String>? _results;

  @override
  void initState() {
    super.initState();
    final def = ref.read(settingsProvider).defaultPageSize;
    // "Vừa ảnh" chỉ có nghĩa với Ảnh→PDF; ở đây coi như A4.
    _pageSize = def == PageSizeOption.letter
        ? PageSizeOption.letter
        : PageSizeOption.a4;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _nameCtl.dispose();
    _pagesCtl.dispose();
    super.dispose();
  }

  int? get _pages => parseBlankPageCount(_pagesCtl.text);

  void _stepPages(int delta) {
    final n = (_pages ?? 1) + delta;
    setState(() => _pagesCtl.text = '${n.clamp(1, 1000)}');
  }

  Future<void> _create() async {
    final l = context.l10n;
    final pages = _pages;
    if (pages == null) {
      showToolMessage(context, l.tools_blankPagesInvalid);
      return;
    }
    final title = _titleCtl.text.trim();
    final fileName = _nameCtl.text.trim().isNotEmpty
        ? _nameCtl.text.trim()
        : (title.isNotEmpty ? title : l.tools_blankDefaultName);
    final out = await newOutputPath(ref, fileName);
    if (!mounted) return;
    final spec = BlankDocSpec(
      template: _template,
      title: title,
      pageSize: _pageSize,
      landscape: _landscape,
      backgroundArgb: _background,
      category: _category,
      pageCount: pages,
    );
    final engine = ref.read(pdfToolsEngineProvider);
    final result = await runToolJob<String>(
      context,
      title: l.core_processing,
      job: (onProgress, token) =>
          engine.createBlank(spec, out, onProgress: onProgress, cancelToken: token),
    );
    if (result == null || !mounted) return;
    await registerOutputs(ref, [result]);
    if (mounted) setState(() => _results = [result]);
  }

  String _templateLabel(BlankTemplate t) {
    final l = context.l10n;
    return switch (t) {
      BlankTemplate.blank => l.tools_templateBlank,
      BlankTemplate.lined => l.tools_templateLined,
      BlankTemplate.grid => l.tools_templateGrid,
    };
  }

  String _categoryLabel(String? c) {
    final l = context.l10n;
    return switch (c) {
      'Work' => l.tools_catWork,
      'Study' => l.tools_catStudy,
      'Personal' => l.tools_catPersonal,
      'Notes' => l.tools_catNotes,
      _ => l.tools_catNone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolCreateBlank;
    final results = _results;
    if (results != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: results, onDone: () => context.pop()),
      );
    }
    final pagesError = _pages == null ? l.tools_blankPagesInvalid : null;
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: _BlankPreview(
              template: _template,
              landscape: _landscape,
              background: _background,
              pageSize: _pageSize,
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(l.tools_blankTemplate),
          Wrap(
            spacing: 8,
            children: [
              for (final t in BlankTemplate.values)
                ChoiceChip(
                  label: Text(_templateLabel(t)),
                  selected: _template == t,
                  onSelected: (_) => setState(() => _template = t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _titleCtl,
            labelText: l.tools_blankTitleLabel,
            hintText: l.tools_blankTitleHint,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _nameCtl,
            labelText: l.core_fileName,
            hintText: l.tools_blankDefaultName,
          ),
          const SizedBox(height: 16),
          _SectionLabel(l.tools_blankPageSize),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('A4'),
                selected: _pageSize == PageSizeOption.a4,
                onSelected: (_) => setState(() => _pageSize = PageSizeOption.a4),
              ),
              ChoiceChip(
                label: const Text('Letter'),
                selected: _pageSize == PageSizeOption.letter,
                onSelected: (_) =>
                    setState(() => _pageSize = PageSizeOption.letter),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(l.tools_orientation),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l.tools_portrait),
                selected: !_landscape,
                onSelected: (_) => setState(() => _landscape = false),
              ),
              ChoiceChip(
                label: Text(l.tools_landscape),
                selected: _landscape,
                onSelected: (_) => setState(() => _landscape = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(l.tools_blankBackground),
          Wrap(
            spacing: 8,
            children: [
              for (final c in _backgrounds)
                GestureDetector(
                  onTap: () => setState(() => _background = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _background == c
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26,
                        width: _background == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(l.tools_blankCategory),
          Wrap(
            spacing: 8,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(_categoryLabel(c)),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(l.tools_blankPages),
          Row(
            children: [
              IconButton.outlined(
                tooltip: '-',
                icon: const Icon(Icons.remove),
                onPressed: () => _stepPages(-1),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: AppTextField(
                  controller: _pagesCtl,
                  keyboardType: TextInputType.number,
                  errorText: pagesError,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: '+',
                icon: const Icon(Icons.add),
                onPressed: () => _stepPages(1),
              ),
            ],
          ),
        ],
      ),
      bottom: PrimaryActionButton(label: l.tools_blankCreate, onPressed: _create),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Xem trước trang: nền + mẫu dòng/ô.
class _BlankPreview extends StatelessWidget {
  const _BlankPreview({
    required this.template,
    required this.landscape,
    required this.background,
    required this.pageSize,
  });

  final BlankTemplate template;
  final bool landscape;
  final int background;
  final PageSizeOption pageSize;

  @override
  Widget build(BuildContext context) {
    final (pw, ph) = pageSize.portraitPoints;
    final ratio = landscape ? ph / pw : pw / ph;
    const longSide = 200.0;
    final w = ratio >= 1 ? longSide : longSide * ratio;
    final h = ratio >= 1 ? longSide / ratio : longSide;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Color(background),
        border: Border.all(color: Colors.black26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: CustomPaint(painter: _TemplatePainter(template)),
    );
  }
}

class _TemplatePainter extends CustomPainter {
  _TemplatePainter(this.template);
  final BlankTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 0.6;
    const margin = 10.0;
    switch (template) {
      case BlankTemplate.blank:
        break;
      case BlankTemplate.lined:
        for (var y = margin + 10; y < size.height - margin; y += 10) {
          canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
        }
      case BlankTemplate.grid:
        for (var y = margin; y <= size.height - margin; y += 8) {
          canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
        }
        for (var x = margin; x <= size.width - margin; x += 8) {
          canvas.drawLine(Offset(x, margin), Offset(x, size.height - margin), paint);
        }
    }
  }

  @override
  bool shouldRepaint(_TemplatePainter old) => old.template != template;
}
