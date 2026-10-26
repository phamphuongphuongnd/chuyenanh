import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import '../../reader/reader_providers.dart';
import '../logic/page_edit_list.dart';
import '../logic/tool_rules.dart';
import '../pdf_tools_providers.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Sắp xếp trang: lưới ảnh thu nhỏ, chọn, kéo thả, xoay, xoá, trích.
class OrganizeScreen extends ConsumerStatefulWidget {
  const OrganizeScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends ConsumerState<OrganizeScreen>
    with SinglePdfToolState<OrganizeScreen> {
  PageEditList? _edit;
  _Thumbnails? _thumbs;

  @override
  String? get initialPath => widget.path;

  @override
  void onInputReady(PdfInput input) {
    _thumbs?.dispose();
    _thumbs = _Thumbnails(
      () async {
        // Engine render (T3) có thể chưa có → không có ảnh thu nhỏ, hiện ô số trang.
        final engine = ref.read(pdfRenderEngineProvider);
        return engine.openFile(input.path, password: input.password);
      },
    );
    setState(() => _edit = PageEditList.fromCount(input.pageCount));
  }

  @override
  void dispose() {
    _thumbs?.dispose();
    super.dispose();
  }

  void _update(PageEditList Function(PageEditList e) f) {
    final e = _edit;
    if (e != null) setState(() => _edit = f(e));
  }

  Future<void> _save({required bool extractOnly}) async {
    final l = context.l10n;
    final src = input;
    final edit = _edit;
    if (src == null || edit == null) return;
    final List<PageOp> ops;
    if (extractOnly) {
      if (!edit.hasSelection) {
        showToolMessage(context, l.tools_extractNeedSelection);
        return;
      }
      ops = edit.selectedOps();
    } else {
      if (!edit.isModified) {
        showToolMessage(context, l.tools_organizeNoChange);
        return;
      }
      ops = edit.toOps();
    }
    final out = await newOutputPath(
      ref,
      suffixedName(src.path, extractOnly ? 'extract' : 'organized'),
    );
    if (!mounted) return;
    final engine = ref.read(pdfToolsEngineProvider);
    final result = await runToolJob<String>(
      context,
      title: l.core_processing,
      job: (onProgress, token) => engine.organize(
        src.path,
        ops,
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
    final title = l.core_toolOrganize;
    final res = results;
    if (res != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: res, onDone: () => context.pop()),
      );
    }
    final src = input;
    final edit = _edit;
    if (src == null || edit == null) {
      return ToolScaffold(
        title: title,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: pickNew),
      );
    }
    return ToolScaffold(
      title: title,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: PdfInputCard(input: src, onChange: pickNew),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l.tools_organizeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _Toolbar(
            edit: edit,
            onSelectAll: () => _update((e) => e.allSelected ? e.clearSelection() : e.selectAll()),
            onRotate: (deg) => _update((e) => e.rotateSelected(deg)),
            onMove: (d) => _update((e) => e.moveSelected(d)),
            onDelete: () {
              if (edit.allSelected) {
                showToolMessage(context, l.tools_organizeKeepOne);
                return;
              }
              _update((e) => e.deleteSelected());
            },
            onExtract: () => _save(extractOnly: true),
            onReset: () =>
                setState(() => _edit = PageEditList.fromCount(src.pageCount)),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio: 0.68,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: edit.length,
              itemBuilder: (context, index) {
                final entry = edit.pages[index];
                return DragTarget<int>(
                  onWillAcceptWithDetails: (d) => d.data != index,
                  onAcceptWithDetails: (d) =>
                      _update((e) => e.move(d.data, index)),
                  builder: (context, candidate, _) {
                    final tile = _PageTile(
                      key: ValueKey('page-${entry.uid}'),
                      entry: entry,
                      position: index + 1,
                      selected: edit.isSelected(entry.uid),
                      highlight: candidate.isNotEmpty,
                      thumbs: _thumbs,
                      onTap: () => _update((e) => e.toggle(entry.uid)),
                    );
                    return LongPressDraggable<int>(
                      data: index,
                      feedback: SizedBox(
                        width: 100,
                        height: 140,
                        child: Opacity(
                          opacity: 0.85,
                          child: Material(color: Colors.transparent, child: tile),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: tile),
                      child: tile,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.core_save,
        icon: Icons.save_outlined,
        onPressed: () => _save(extractOnly: false),
      ),
    );
  }
}

/// Hàng công cụ: chọn tất cả, đếm, xoay, dời, xoá, trích, hoàn lại.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.edit,
    required this.onSelectAll,
    required this.onRotate,
    required this.onMove,
    required this.onDelete,
    required this.onExtract,
    required this.onReset,
  });

  final PageEditList edit;
  final VoidCallback onSelectAll;
  final ValueChanged<int> onRotate;
  final ValueChanged<int> onMove;
  final VoidCallback onDelete;
  final VoidCallback onExtract;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final has = edit.hasSelection;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          TextButton(
            onPressed: onSelectAll,
            child: Text(
              edit.allSelected ? l.tools_clearSelection : l.tools_selectAll,
            ),
          ),
          if (has) Text(l.tools_selectedCount(edit.selected.length)),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l.tools_rotate,
            icon: const Icon(Icons.rotate_left),
            onPressed: has ? () => onRotate(-90) : null,
          ),
          IconButton(
            tooltip: l.tools_rotate,
            icon: const Icon(Icons.rotate_right),
            onPressed: has ? () => onRotate(90) : null,
          ),
          IconButton(
            tooltip: l.tools_moveEarlier,
            icon: const Icon(Icons.arrow_back),
            onPressed: has ? () => onMove(-1) : null,
          ),
          IconButton(
            tooltip: l.tools_moveLater,
            icon: const Icon(Icons.arrow_forward),
            onPressed: has ? () => onMove(1) : null,
          ),
          IconButton(
            tooltip: l.core_delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: has ? onDelete : null,
          ),
          IconButton(
            tooltip: l.tools_extract,
            icon: const Icon(Icons.file_copy_outlined),
            onPressed: has ? onExtract : null,
          ),
          IconButton(
            tooltip: l.tools_reset,
            icon: const Icon(Icons.restart_alt),
            onPressed: edit.isModified ? onReset : null,
          ),
        ],
      ),
    );
  }
}

/// Ô một trang: ảnh thu nhỏ (hoặc ô số trang), số thứ tự hiện tại, dấu chọn, xoay.
class _PageTile extends StatelessWidget {
  const _PageTile({
    super.key,
    required this.entry,
    required this.position,
    required this.selected,
    required this.highlight,
    required this.thumbs,
    required this.onTap,
  });

  final PageEntry entry;
  final int position;
  final bool selected;
  final bool highlight;
  final _Thumbnails? thumbs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final borderColor = selected
        ? scheme.primary
        : highlight
        ? scheme.tertiary
        : scheme.outlineVariant;
    return Semantics(
      selected: selected,
      label: l.tools_pageNumber(entry.sourceIndex + 1),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor, width: selected ? 3 : 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: RotatedBox(
                        quarterTurns: entry.rotation ~/ 90,
                        child: _PageImage(
                          index: entry.sourceIndex,
                          thumbs: thumbs,
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.check_circle,
                          size: 22,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('$position', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({required this.index, required this.thumbs});

  final int index;
  final _Thumbnails? thumbs;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Text(
        '${index + 1}',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.black38),
      ),
    );
    final t = thumbs;
    if (t == null) return placeholder;
    return FutureBuilder<Uint8List?>(
      future: t.thumbnail(index),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return placeholder;
        return Image.memory(data, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }
}

/// Nạp ảnh thu nhỏ từng trang theo yêu cầu, có nhớ. Mở tài liệu render một lần;
/// không mở được (chưa có engine render, file lạ…) → mọi ô trả `null`.
class _Thumbnails {
  _Thumbnails(this._open);

  final Future<PdfRenderDocument> Function() _open;
  Future<PdfRenderDocument?>? _doc;
  final Map<int, Future<Uint8List?>> _cache = {};
  bool _disposed = false;

  Future<PdfRenderDocument?> _document() => _doc ??= () async {
    try {
      return await _open();
    } catch (_) {
      return null;
    }
  }();

  Future<Uint8List?> thumbnail(int index) => _cache.putIfAbsent(index, () async {
    final doc = await _document();
    if (doc == null || _disposed) return null;
    try {
      return await doc.renderThumbnail(index, maxSide: 240);
    } catch (_) {
      return null;
    }
  });

  void dispose() {
    _disposed = true;
    _doc?.then((d) => d?.close());
  }
}
