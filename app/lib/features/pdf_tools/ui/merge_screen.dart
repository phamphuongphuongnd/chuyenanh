import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/tool_rules.dart';
import '../pdf_tools_providers.dart';
import 'pdf_file_picker.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Gộp nhiều PDF: chọn, sắp thứ tự (kéo thả), đặt tên, gộp.
class MergeScreen extends ConsumerStatefulWidget {
  const MergeScreen({super.key, this.path});

  /// File đầu tiên (từ `extra` của route); null → tự chọn.
  final String? path;

  @override
  ConsumerState<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends ConsumerState<MergeScreen> {
  final List<PdfInput> _items = [];
  List<String>? _results;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final first = widget.path;
      if (first != null) {
        await _addPaths([first]);
      } else {
        await _pickMore();
      }
    });
  }

  Future<void> _pickMore() async {
    final picked = await ref.read(pdfFilePickerProvider).pickPdfs(multiple: true);
    if (!mounted || picked.isEmpty) return;
    await _addPaths(picked);
  }

  Future<void> _addPaths(List<String> paths) async {
    setState(() => _busy = true);
    for (final path in paths) {
      if (!mounted) return;
      final input = await loadPdfInput(context, ref, path);
      if (input != null && mounted) setState(() => _items.add(input));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _merge() async {
    final l = context.l10n;
    if (_items.length < 2) {
      showToolMessage(context, l.tools_mergeNeedTwo);
      return;
    }
    final name = await showNameDialog(
      context,
      title: l.tools_mergeNameTitle,
      initial: mergedDefaultName([for (final i in _items) i.path]),
      confirmLabel: l.tools_mergeAction,
    );
    if (name == null || !mounted) return;
    final out = await newOutputPath(ref, name);
    if (!mounted) return;
    final engine = ref.read(pdfToolsEngineProvider);
    final passwords = {
      for (final i in _items)
        if (i.password != null) i.path: i.password!,
    };
    final result = await runToolJob<String>(
      context,
      title: l.core_processing,
      job: (onProgress, token) => engine.merge(
        [for (final i in _items) i.path],
        out,
        passwords: passwords,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (result == null || !mounted) return;
    await registerOutputs(ref, [result]);
    if (mounted) setState(() => _results = [result]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolMerge;
    final results = _results;
    if (results != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: results, onDone: () => context.pop()),
      );
    }
    if (_items.isEmpty) {
      return ToolScaffold(
        title: title,
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: _pickMore),
      );
    }
    final t = context.tokens;
    return ToolScaffold(
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolHintText(l.tools_mergeHint),
                const SizedBox(height: 10),
                NoteBanner(l.tools_noteLosesFeatures),
                if (_items.length < 2) ...[
                  const SizedBox(height: 10),
                  ToolHintText(l.tools_mergeNeedTwo, color: t.primaryText),
                ],
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              buildDefaultDragHandles: false,
              // Thẻ đang kéo: không vẽ bóng chữ nhật mặc định (thẻ bo góc, không bóng).
              proxyDecorator: (child, _, _) =>
                  Material(type: MaterialType.transparency, child: child),
              itemCount: _items.length,
              onReorderItem: (from, to) => setState(() {
                final item = _items.removeAt(from);
                _items.insert(to, item);
              }),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  key: ObjectKey(item),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ToolCard(
                    padding: EdgeInsets.zero,
                    child: ToolFileRow(
                      path: item.path,
                      info: pdfInputInfo(context, item),
                      locked: item.password != null,
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.tools_remove,
                            icon: Icon(Symbols.close_rounded, color: t.textMuted),
                            onPressed: () =>
                                setState(() => _items.removeAt(index)),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Symbols.drag_indicator_rounded,
                                color: t.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryActionButton(
              label: l.tools_addFiles,
              icon: Symbols.add_rounded,
              onPressed: _busy ? null : _pickMore,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryActionButton(
              label: l.tools_mergeAction,
              onPressed: _busy || _items.length < 2 ? null : _merge,
            ),
          ),
        ],
      ),
    );
  }
}
