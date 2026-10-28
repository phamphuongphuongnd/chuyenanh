import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/settings/settings_providers.dart';
import '../../../engines/ocr/ocr_engine.dart';
import '../capture/document_capture.dart';
import '../export/scan_export_providers.dart';
import '../export/scan_exporter.dart';
import '../manual/manual_crop_screen.dart';
import '../model/scan_page.dart';
import '../model/scan_session.dart';
import 'scan_page_tile.dart';

enum _ExportKind { pdf, txt, docx }

/// Màn Quét tài liệu: chụp nhiều trang → danh sách trang → xuất PDF / TXT / DOCX.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.autoStart = true});

  /// Mở camera quét ngay khi vào màn hình (tắt trong test).
  final bool autoStart;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(scanSessionProvider).isEmpty) _addPages();
      });
    }
  }

  void _toast(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), action: action));
  }

  void _showError(Object e) {
    if (!mounted) return;
    final err = AppError.from(e);
    if (err is Cancelled) return;
    _toast(appErrorMessage(context, err));
  }

  /// Quét tự động; không dùng được → chụp ảnh + kéo bốn góc. `null` = huỷ.
  Future<List<String>?> _capture({required int maxPages}) async {
    final capture = ref.read(documentCaptureProvider);
    try {
      return await capture.scanPages(maxPages: maxPages);
    } on ScannerUnavailable {
      if (!mounted) return null;
      _toast(context.l10n.scan_autoUnavailable);
      final photo = await capture.takePhoto();
      if (photo == null || !mounted) return null;
      final cropped = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ManualCropScreen(imagePath: photo)),
      );
      return cropped == null ? null : [cropped];
    }
  }

  Future<void> _addPages() async {
    if (_busy) return;
    _busy = true;
    try {
      final paths = await _capture(maxPages: 100);
      if (paths != null && mounted) {
        ref.read(scanSessionProvider.notifier).addPaths(paths);
      }
    } catch (e) {
      _showError(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _retake(ScanPage page) async {
    if (_busy) return;
    _busy = true;
    try {
      final paths = await _capture(maxPages: 1);
      if (paths != null && paths.isNotEmpty && mounted) {
        ref
            .read(scanSessionProvider.notifier)
            .replacePath(page.id, paths.first);
      }
    } catch (e) {
      _showError(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _pickFilter(ScanPage page) async {
    final result =
        await showModalBottomSheet<({ops.ImageFilter filter, bool all})>(
          context: context,
          showDragHandle: true,
          builder: (_) => _FilterSheet(current: page.filter),
        );
    if (result == null || !mounted) return;
    final n = ref.read(scanSessionProvider.notifier);
    if (result.all) {
      n.setFilterAll(result.filter);
    } else {
      n.setFilter(page.id, result.filter);
    }
  }

  Future<void> _export() async {
    final defaultScript = ocrScriptForLanguage(
      (ref.read(settingsProvider).locale ?? Localizations.localeOf(context))
          .languageCode,
    );
    final choice =
        await showModalBottomSheet<({_ExportKind kind, OcrScript script, bool searchable})>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _ExportSheet(initialScript: defaultScript),
        );
    if (choice == null || !mounted) return;

    final pages = ref.read(scanSessionProvider);
    final l = context.l10n;
    final ctrl = showProgressDialog(
      context,
      title: choice.kind == _ExportKind.pdf && !choice.searchable
          ? l.scan_exporting
          : l.scan_recognizing,
    );
    try {
      final exporter = await ref.read(scanExporterProvider.future);
      final ScanExportResult r = switch (choice.kind) {
        _ExportKind.pdf => await exporter.exportPdf(
          pages,
          searchable: choice.searchable,
          script: choice.script,
          onProgress: ctrl.update,
          cancelToken: ctrl.cancelToken,
        ),
        _ExportKind.txt => await exporter.exportTxt(
          pages,
          choice.script,
          onProgress: ctrl.update,
          cancelToken: ctrl.cancelToken,
        ),
        _ExportKind.docx => await exporter.exportDocx(
          pages,
          choice.script,
          onProgress: ctrl.update,
          cancelToken: ctrl.cancelToken,
        ),
      };
      ctrl.close();
      if (!mounted) return;
      final name = r.outputPath.split(RegExp(r'[\\/]')).last;
      final base = r.hasText ? l.scan_exported(name) : l.scan_noText;
      _toast(
        r.skippedCount > 0
            ? '$base ${l.img2pdf_skippedImages(r.skippedCount)}'
            : base,
        action: SnackBarAction(
          label: l.core_open,
          onPressed: () async {
            try {
              await openDocument(context, r.outputPath);
            } catch (e) {
              _showError(e);
            }
          },
        ),
      );
    } catch (e) {
      ctrl.close();
      _showError(e);
    }
  }

  Future<void> _confirmLeave() async {
    final l = context.l10n;
    final ok = await showConfirmDialog(
      context,
      title: l.scan_discardTitle,
      message: l.scan_discardMessage,
      confirmLabel: l.scan_discard,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = ref.watch(scanSessionProvider);
    final notifier = ref.read(scanSessionProvider.notifier);
    return PopScope(
      canPop: pages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.scan_title)),
        body: pages.isEmpty
            ? EmptyState(
                icon: Icons.document_scanner_outlined,
                title: l.scan_emptyTitle,
                message: l.scan_emptyMessage,
                actionLabel: l.scan_scanButton,
                onAction: _addPages,
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                itemCount: pages.length,
                onReorderItem: (o, n) => notifier.reorder(o, n > o ? n + 1 : n),
                itemBuilder: (context, i) {
                  final page = pages[i];
                  return ScanPageTile(
                    key: ValueKey(page.id),
                    page: page,
                    index: i,
                    onRotate: () => notifier.rotate(page.id),
                    onFilter: () => _pickFilter(page),
                    onRetake: () => _retake(page),
                    onDelete: () => notifier.remove(page.id),
                  );
                },
              ),
        bottomNavigationBar: pages.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addPages,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(l.scan_addMore),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _export,
                          icon: const Icon(Icons.ios_share),
                          label: Text(l.scan_export),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});
  final ops.ImageFilter current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final f in ops.ImageFilter.values)
                  ChoiceChip(
                    label: Text(scanFilterLabel(context, f)),
                    selected: f == widget.current,
                    onSelected: (_) =>
                        Navigator.of(context).pop((filter: f, all: _all)),
                  ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _all,
              onChanged: (v) => setState(() => _all = v ?? false),
              title: Text(context.l10n.scan_applyToAll),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.initialScript});
  final OcrScript initialScript;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late OcrScript _script = widget.initialScript;
  bool _searchable = true;

  String _scriptName(OcrScript s) {
    final l = context.l10n;
    return switch (s) {
      OcrScript.latin => l.scan_scriptLatin,
      OcrScript.chinese => l.scan_scriptChinese,
      OcrScript.japanese => l.scan_scriptJapanese,
      OcrScript.korean => l.scan_scriptKorean,
    };
  }

  void _pick(_ExportKind k) =>
      Navigator.of(context).pop((kind: k, script: _script, searchable: _searchable));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.manage_search),
            title: Text(l.scan_searchablePdf),
            subtitle: Text(l.scan_searchablePdfHint),
            value: _searchable,
            onChanged: (v) => setState(() => _searchable = v),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l.scan_exportPdf),
            onTap: () => _pick(_ExportKind.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l.scan_exportDocx),
            onTap: () => _pick(_ExportKind.docx),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: Text(l.scan_exportTxt),
            onTap: () => _pick(_ExportKind.txt),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text(l.scan_ocrLanguage)),
                const SizedBox(width: 8),
                DropdownButton<OcrScript>(
                  value: _script,
                  isDense: true,
                  items: [
                    for (final s in OcrScript.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          _scriptName(s),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (s) => setState(() => _script = s ?? _script),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
