import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/theme/app_theme.dart';
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
    } catch (e, st) {
      debugPrint('scan: quét lỗi: $e | $st');
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
          // Cao theo nội dung (mặc định bị giới hạn 9/16 màn), màn thấp thì cuộn.
          isScrollControlled: true,
          useSafeArea: true,
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
    } catch (e, st) {
      debugPrint('scan: xuất lỗi: $e | $st');
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
    final t = context.tokens;
    return PopScope(
      canPop: pages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        // AppBar sáng theo theme mặc định (không đặt màu riêng).
        appBar: AppBar(title: Text(l.scan_title)),
        body: pages.isEmpty
            ? EmptyState(
                icon: Symbols.document_scanner_rounded,
                title: l.scan_emptyTitle,
                message: l.scan_emptyMessage,
                actionLabel: l.scan_scanButton,
                onAction: _addPages,
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                // Thẻ không đổ bóng kể cả khi đang kéo (thiết kế §1.6).
                proxyDecorator: (child, _, _) =>
                    Material(color: Colors.transparent, child: child),
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
            : DecoratedBox(
                // Thanh dưới: nền `surface`, kẻ trên `line`; 2 nút viên.
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: _addPages,
                            icon: const Icon(
                              Symbols.add_a_photo_rounded,
                              size: 20,
                            ),
                            label: Text(
                              l.scan_addMore,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _export,
                            icon: const Icon(Symbols.ios_share_rounded, size: 20),
                            label: Text(
                              l.scan_export,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
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
    final l = context.l10n;
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.scan_filter),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in ops.ImageFilter.values)
                    _FilterPill(
                      label: scanFilterLabel(context, f),
                      selected: f == widget.current,
                      onTap: () =>
                          Navigator.of(context).pop((filter: f, all: _all)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              activeColor: AppColors.primary,
              value: _all,
              onChanged: (v) => setState(() => _all = v ?? false),
              title: Text(
                l.scan_applyToAll,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: t.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip bộ lọc dạng viên cao 36: đang chọn = nền đỏ chữ trắng, chưa chọn = `surface2`.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? AppColors.primary : t.surface2,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : t.text,
            ),
          ),
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
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.scan_export),
            // Công tắc OCR trong khối nền `primarySoft` bo 16.
            Material(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                secondary: Icon(
                  Symbols.manage_search_rounded,
                  color: t.primaryText,
                ),
                title: Text(
                  l.scan_searchablePdf,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l.scan_searchablePdfHint,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: t.textMuted,
                    ),
                  ),
                ),
                value: _searchable,
                onChanged: (v) => setState(() => _searchable = v),
              ),
            ),
            const SizedBox(height: 8),
            SheetOption(
              icon: Symbols.picture_as_pdf_rounded,
              label: l.scan_exportPdf,
              onTap: () => _pick(_ExportKind.pdf),
            ),
            SheetOption(
              icon: Symbols.article_rounded,
              label: l.scan_exportDocx,
              onTap: () => _pick(_ExportKind.docx),
            ),
            SheetOption(
              icon: Symbols.text_snippet_rounded,
              label: l.scan_exportTxt,
              onTap: () => _pick(_ExportKind.txt),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                l.scan_ocrLanguage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Dropdown ngôn ngữ OCR: ô bo 14 nền `input`.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.input,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OcrScript>(
                  value: _script,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: t.surface,
                  icon: Icon(
                    Symbols.expand_more_rounded,
                    color: t.textMuted,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.text,
                  ),
                  items: [
                    for (final s in OcrScript.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          _scriptName(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (s) => setState(() => _script = s ?? _script),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
