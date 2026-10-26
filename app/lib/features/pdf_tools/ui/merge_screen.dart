import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
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
    final locale = Localizations.localeOf(context).toString();
    return ToolScaffold(
      title: title,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Text(l.tools_mergeHint),
                const SizedBox(height: 8),
                NoteBanner(l.tools_noteLosesFeatures),
                if (_items.length < 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.tools_mergeNeedTwo,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorderItem: (from, to) => setState(() {
                final item = _items.removeAt(from);
                _items.insert(to, item);
              }),
              itemBuilder: (context, index) {
                final item = _items[index];
                final info = [
                  l.tools_pages(item.pageCount),
                  if (item.sizeBytes != null)
                    formatFileSize(item.sizeBytes!, locale),
                ].join(' • ');
                return Card(
                  key: ObjectKey(item),
                  child: ListTile(
                    leading: FileTypeIcon.forPath(
                      item.path,
                      locked: item.password != null,
                    ),
                    title: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(info),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.tools_remove,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _items.removeAt(index)),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
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
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickMore,
              icon: const Icon(Icons.add),
              label: Text(l.tools_addFiles.toUpperCase()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _busy || _items.length < 2 ? null : _merge,
              child: Text(l.tools_mergeAction.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }
}
