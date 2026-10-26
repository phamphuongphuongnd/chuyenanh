import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import '../engine/page_ranges.dart';
import '../logic/tool_rules.dart';
import '../pdf_tools_providers.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

enum _SplitUiMode { ranges, everyPage, everyN }

/// Tách PDF: theo khoảng trang, mỗi trang một file, hoặc mỗi N trang.
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen>
    with SinglePdfToolState<SplitScreen> {
  _SplitUiMode _mode = _SplitUiMode.ranges;
  final _rangesCtl = TextEditingController();
  final _everyNCtl = TextEditingController(text: '2');

  @override
  String? get initialPath => widget.path;

  @override
  void dispose() {
    _rangesCtl.dispose();
    _everyNCtl.dispose();
    super.dispose();
  }

  /// Kế hoạch hiện tại: (mode engine, số file) hoặc null nếu chưa hợp lệ; [error] = đã nhập sai.
  ({SplitMode? mode, int files, bool error}) _plan() {
    final count = input?.pageCount ?? 0;
    if (count < 1) return (mode: null, files: 0, error: false);
    switch (_mode) {
      case _SplitUiMode.everyPage:
        return (mode: const SplitEveryPage(), files: count, error: false);
      case _SplitUiMode.everyN:
        final n = int.tryParse(_everyNCtl.text.trim());
        if (n == null || n < 1) return (mode: null, files: 0, error: true);
        return (
          mode: SplitEveryN(n),
          files: splitEveryNFileCount(count, n),
          error: false,
        );
      case _SplitUiMode.ranges:
        if (_rangesCtl.text.trim().isEmpty) {
          return (mode: null, files: 0, error: false);
        }
        try {
          final ranges = parsePageRanges(_rangesCtl.text, count);
          return (mode: SplitByRanges(ranges), files: ranges.length, error: false);
        } on FormatException {
          return (mode: null, files: 0, error: true);
        } on ArgumentError {
          return (mode: null, files: 0, error: true);
        }
    }
  }

  Future<void> _split() async {
    final src = input;
    final mode = _plan().mode;
    if (src == null || mode == null) return;
    final dir = await outputDirOf(ref);
    if (!mounted) return;
    final engine = ref.read(pdfToolsEngineProvider);
    final files = await runToolJob<List<String>>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) => engine.split(
        src.path,
        mode,
        dir,
        p.basenameWithoutExtension(src.path),
        password: src.password,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (files == null || !mounted) return;
    await finish(files);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolSplit;
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
    final plan = _plan();
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final (mode, label) in [
                (_SplitUiMode.ranges, l.tools_splitModeRanges),
                (_SplitUiMode.everyPage, l.tools_splitModeEvery),
                (_SplitUiMode.everyN, l.tools_splitModeEveryN),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_mode == _SplitUiMode.ranges)
            AppTextField(
              controller: _rangesCtl,
              labelText: l.tools_splitRangesLabel,
              hintText: l.tools_splitRangesHint,
              keyboardType: TextInputType.text,
              onChanged: (_) => setState(() {}),
              errorText: plan.error
                  ? l.tools_splitInvalidRange(src.pageCount)
                  : null,
            ),
          if (_mode == _SplitUiMode.everyN)
            AppTextField(
              controller: _everyNCtl,
              labelText: l.tools_splitEveryNLabel,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              errorText: plan.error ? l.tools_invalidNumber : null,
            ),
          const SizedBox(height: 12),
          if (plan.mode != null) Text(l.tools_splitFilesCount(plan.files)),
          const SizedBox(height: 12),
          NoteBanner(l.tools_noteLosesFeatures),
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.tools_splitAction,
        onPressed: plan.mode == null ? null : _split,
      ),
    );
  }
}
