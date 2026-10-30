import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import 'annotation_toolbar.dart';
import 'edited_output.dart';
import 'editor_common.dart';
import 'editor_viewer.dart';

/// Màn chú thích: tô sáng, gạch chân, gạch ngang, gạch sóng, ghi chú dán (`Routes.annotate`).
/// Lưu ra file MỚI, không ghi đè file gốc.
class AnnotateScreen extends ConsumerStatefulWidget {
  const AnnotateScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<AnnotateScreen> createState() => _AnnotateScreenState();
}

class _AnnotateScreenState extends ConsumerState<AnnotateScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final UndoHistoryController _undo = UndoHistoryController();

  PdfAnnotationMode _mode = PdfAnnotationMode.none;
  Color? _color;
  Annotation? _selected;
  bool _dirty = false;
  bool _failed = false;

  @override
  void dispose() {
    _undo.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setMode(PdfAnnotationMode mode) {
    _controller.annotationMode = mode;
    setState(() => _mode = mode);
  }

  void _setColor(Color color) {
    final s = _controller.annotationSettings;
    s.highlight.color = color;
    s.underline.color = color;
    s.strikethrough.color = color;
    s.squiggly.color = color;
    s.stickyNote.color = color;
    setState(() => _color = color);
  }

  void _deleteSelected() {
    final a = _selected;
    if (a == null) return;
    _controller.removeAnnotation(a);
    setState(() {
      _selected = null;
      _dirty = true;
    });
  }

  late final EditorViewerArgs _args = EditorViewerArgs(
    path: widget.path,
    controller: _controller,
    undoController: _undo,
    onLoadFailed: () {
      if (mounted) setState(() => _failed = true);
    },
    onChanged: () {
      if (mounted && !_dirty) setState(() => _dirty = true);
    },
    onAnnotationSelected: (a) {
      if (mounted) setState(() => _selected = a);
    },
  );

  /// Giữ nguyên một widget viewer duy nhất: SfPdfViewer đọc lại file mỗi lần widget đổi.
  Widget? _viewer;

  Future<void> _save() async {
    final l = context.l10n;
    if (!_dirty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.edit_noChanges)));
      return;
    }
    final out = await saveViewerDocument(
      context: context,
      ref: ref,
      viewer: _args,
      kind: EditKind.annotate,
    );
    if (out == null || !mounted) return;
    setState(() => _dirty = false);
    await showSavedDialog(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viewerBuilder = ref.watch(editorViewerBuilderProvider);
    return UnsavedChangesGuard(
      hasChanges: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            p.basename(widget.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undo,
              builder: (context, v, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('undo'),
                    tooltip: l.edit_undo,
                    icon: const Icon(Symbols.undo_rounded),
                    onPressed: v.canUndo ? _undo.undo : null,
                  ),
                  IconButton(
                    key: const Key('redo'),
                    tooltip: l.edit_redo,
                    icon: const Icon(Symbols.redo_rounded),
                    onPressed: v.canRedo ? _undo.redo : null,
                  ),
                ],
              ),
            ),
            if (_selected != null)
              IconButton(
                key: const Key('deleteAnnotation'),
                tooltip: l.edit_deleteAnnotation,
                icon: const Icon(Symbols.delete_rounded),
                onPressed: _deleteSelected,
              ),
            IconButton(
              key: const Key('save'),
              tooltip: l.edit_saveAsNew,
              icon: const Icon(Symbols.save_rounded),
              onPressed: _failed ? null : _save,
            ),
          ],
        ),
        body: _failed
            ? EmptyState(
                title: l.edit_loadFailed,
                icon: Symbols.error_rounded,
              )
            : Column(
                children: [
                  HintBanner(
                    _mode == PdfAnnotationMode.stickyNote
                        ? l.edit_stickyHint
                        : l.edit_annotateHint,
                  ),
                  Expanded(child: _viewer ??= viewerBuilder(context, _args)),
                  AnnotationToolbar(
                    mode: _mode,
                    onModeChanged: _setMode,
                    selectedColor: _color,
                    onColorChanged: _setColor,
                  ),
                ],
              ),
      ),
    );
  }
}
