import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import 'edited_output.dart';
import 'editor_common.dart';
import 'editor_viewer.dart';

/// Màn điền form AcroForm: ô chữ, checkbox, radio, combo, list (`Routes.fillForm`).
/// Lưu ra file MỚI; có tuỳ chọn lưu bản "phẳng" (ô không sửa lại được).
class FillFormScreen extends ConsumerStatefulWidget {
  const FillFormScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<FillFormScreen> createState() => _FillFormScreenState();
}

enum _SaveMode { editable, flatten }

class _FillFormScreenState extends ConsumerState<FillFormScreen> {
  final PdfViewerController _controller = PdfViewerController();

  bool _dirty = false;
  bool _failed = false;

  /// `null` = chưa nạp xong; `false` = PDF không có ô form.
  bool? _hasFields;

  Widget? _viewer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final EditorViewerArgs _args = EditorViewerArgs(
    path: widget.path,
    controller: _controller,
    onLoaded: () {
      if (!mounted) return;
      setState(() => _hasFields = _controller.getFormFields().isNotEmpty);
    },
    onLoadFailed: () {
      if (mounted) setState(() => _failed = true);
    },
    onChanged: () {
      if (mounted && !_dirty) setState(() => _dirty = true);
    },
  );

  Future<void> _save(_SaveMode mode) async {
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
      kind: EditKind.fillForm,
      flatten: mode == _SaveMode.flatten,
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
            IconButton(
              key: const Key('save'),
              tooltip: l.edit_saveAsNew,
              icon: const Icon(Icons.save_outlined),
              onPressed: _failed ? null : () => _save(_SaveMode.editable),
            ),
            PopupMenuButton<_SaveMode>(
              key: const Key('saveMenu'),
              enabled: !_failed,
              onSelected: _save,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _SaveMode.flatten,
                  child: Text(l.edit_flattenSave),
                ),
              ],
            ),
          ],
        ),
        body: _failed
            ? EmptyState(title: l.edit_loadFailed, icon: Icons.error_outline)
            : Column(
                children: [
                  if (_hasFields == false)
                    HintBanner(
                      l.edit_noFormFields,
                      icon: Icons.warning_amber_outlined,
                    )
                  else
                    HintBanner(l.edit_formHint),
                  Expanded(child: _viewer ??= viewerBuilder(context, _args)),
                ],
              ),
      ),
    );
  }
}
