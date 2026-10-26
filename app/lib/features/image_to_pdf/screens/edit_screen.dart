import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/output_directory.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../../../engines/pdf/image_to_pdf_engine.dart';
import '../../../data/settings/settings_providers.dart';
import '../image_to_pdf_paths.dart';
import '../image_to_pdf_providers.dart';
import '../models/edit_session.dart';
import '../models/image_item.dart';
import '../models/ordered_selection.dart';
import '../models/pdf_estimate.dart';
import '../services/export_service.dart';
import '../services/output_registry.dart';
import '../widgets/edited_image.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/options_sheet.dart';

/// Bước 2: sửa danh sách ảnh (kéo thả đổi thứ tự, xoay, cắt, lọc, xoá, thêm) rồi chọn
/// tuỳ chọn và xuất PDF.
class EditScreen extends ConsumerStatefulWidget {
  const EditScreen({super.key, required this.paths});

  /// Đường dẫn ảnh theo thứ tự đã chọn.
  final List<String> paths;

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  final EditSession _session = EditSession();
  bool _loading = true;
  bool _busy = false;
  ImageToPdfOptions? _lastOptions;
  String? _lastName;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  /// Đọc thông tin rồi thêm ảnh vào phiên. Trả về số ảnh hỏng bị bỏ qua.
  Future<int> _addPaths(List<String> paths) async {
    final processor = ref.read(imageProcessorProvider);
    final items = <ImageItem>[];
    var skipped = 0;
    for (final path in paths) {
      final info = await processor.probe(path);
      if (!mounted) return 0;
      if (info == null) {
        skipped++;
        continue;
      }
      items.add(
        ImageItem(
          id: _session.nextId(),
          originalPath: path,
          originalWidth: info.width,
          originalHeight: info.height,
        ),
      );
    }
    final added = _session.addAll(items);
    if (added < items.length) {
      _snack(context.l10n.img2pdf_maxImages(maxImagesPerPdf));
    }
    return skipped;
  }

  Future<void> _loadInitial() async {
    final skipped = await _addPaths(widget.paths);
    if (!mounted) return;
    setState(() => _loading = false);
    if (_session.isEmpty) {
      _snack(context.l10n.img2pdf_skippedImages(skipped));
      _exit();
    } else if (skipped > 0) {
      _snack(context.l10n.img2pdf_skippedImages(skipped));
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    if (_session.remainingCapacity <= 0) {
      _snack(context.l10n.img2pdf_maxImages(maxImagesPerPdf));
      return;
    }
    final paths = await context.push<List<String>>(
      img2pdfAddPath,
      extra: _session.remainingCapacity,
    );
    if (paths == null || paths.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final skipped = await _addPaths(paths);
      if (mounted && skipped > 0) {
        _snack(context.l10n.img2pdf_skippedImages(skipped));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    _session.removeCurrent();
    if (_session.isEmpty) {
      _exit();
      return;
    }
    _snack(
      context.l10n.img2pdf_imageRemoved,
      action: SnackBarAction(
        label: context.l10n.img2pdf_undo,
        onPressed: _session.undoRemove,
      ),
    );
  }

  Future<void> _pickFilter() async {
    final item = _session.current;
    if (item == null) return;
    final filter = await showFilterSheet(context, current: item.edit.filter);
    if (filter != null) _session.setFilterCurrent(filter);
  }

  Future<void> _crop() async {
    final item = _session.current;
    if (item == null || _busy) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final processor = ref.read(imageProcessorProvider);
      final workDir = await ref.read(workDirProvider)();
      // "Nướng" phép xoay vào file nguồn để màn cắt hiện đúng hình người dùng đang thấy.
      final source = await processor.bake(
        item.path,
        ops.ImageEdit(rotationQuarterTurns: item.edit.quarterTurns),
        outDir: workDir,
        name: 'crop_src_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      final cropped = await ref
          .read(cropServiceProvider)
          .crop(
            source,
            title: l.img2pdf_cropTitle,
            toolbarColor: AppColors.primary,
          );
      if (cropped == null || !mounted) return;
      final info = await processor.probe(cropped);
      if (info == null) throw const CorruptFile('crop result');
      _session.applyCroppedCurrent(
        path: cropped,
        width: info.width,
        height: info.height,
      );
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_session.isEmpty) return;
    final settings = ref.read(settingsProvider);
    final request = await showOptionsSheet(
      context,
      items: _session.items,
      initialOptions:
          _lastOptions ?? ImageToPdfOptions(pageSize: settings.defaultPageSize),
      initialName: _lastName ?? defaultPdfName(DateTime.now()),
    );
    if (request == null || !mounted) return;
    _lastOptions = request.options;
    _lastName = request.fileName;
    await _export(request);
  }

  Future<void> _export(ExportRequest request) async {
    final l = context.l10n;
    final items = _session.items;
    final ctrl = showProgressDialog(context, title: l.img2pdf_creating);
    ExportOutcome? outcome;
    AppError? failure;
    try {
      final outputDir = await ref.read(outputDirectoryProvider.future);
      final exporter = ImageToPdfExporter(
        engine: ref.read(imageToPdfEngineProvider),
        processor: ref.read(imageProcessorProvider),
        workDir: await ref.read(workDirProvider)(),
      );
      outcome = await exporter.export(
        items: items,
        options: request.options,
        outputDir: outputDir,
        fileName: normalizePdfName(
          request.fileName,
          fallback: defaultPdfName(DateTime.now()),
        ),
        onProgress: ctrl.update,
        cancelToken: ctrl.cancelToken,
      );
      try {
        await registerOutputDocument(
          ref.read(appDatabaseProvider),
          outcome.outputPath,
        );
      } catch (_) {
        // Ghi DB lỗi không làm hỏng file đã tạo — lần quét sau sẽ thấy file.
      }
    } on Cancelled {
      return;
    } catch (e) {
      failure = AppError.from(e);
    } finally {
      ctrl.close();
    }
    if (!mounted) return;
    if (failure != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: l.img2pdf_exportFailed,
          content: Text(appErrorMessage(ctx, failure!)),
          showCancel: false,
          onConfirm: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }
    context.pushReplacement(img2pdfResultPath, extra: outcome);
  }

  Future<void> _onBack() async {
    if (_session.isEmpty || _loading) {
      _exit();
      return;
    }
    final l = context.l10n;
    final discard = await showConfirmDialog(
      context,
      title: l.img2pdf_discardTitle,
      message: l.img2pdf_discardMessage,
      confirmLabel: l.core_yes,
      cancelLabel: l.core_no,
    );
    if (discard && mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.img2pdf_editTitle),
          actions: [
            IconButton(
              key: const ValueKey('add_button'),
              tooltip: l.img2pdf_add,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _loading ? null : _add,
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            if (_loading) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l.img2pdf_preparing),
                  ],
                ),
              );
            }
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildPreview()),
                    _buildToolbar(l),
                    _buildStrip(),
                    _buildCreateButton(l),
                  ],
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black26,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final item = _session.current;
    if (item == null) return const SizedBox.shrink();
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? Colors.black : const Color(0xFFE0E0E0),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: EditedImage(
                key: ValueKey('preview_${item.id}'),
                path: item.path,
                edit: item.edit,
                maxSide: 1400,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l.img2pdf_pageOf(_session.currentIndex + 1, _session.length),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppLocalizations l) {
    final item = _session.current;
    final canEdit = item != null && !_busy;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _ToolButton(
              key: const ValueKey('tool_rotate'),
              icon: Icons.rotate_right,
              label: l.img2pdf_rotate,
              onTap: canEdit ? _session.rotateCurrent : null,
            ),
            _ToolButton(
              key: const ValueKey('tool_crop'),
              icon: Icons.crop,
              label: l.img2pdf_crop,
              onTap: canEdit ? _crop : null,
            ),
            _ToolButton(
              key: const ValueKey('tool_filter'),
              icon: Icons.auto_fix_high_outlined,
              label: l.img2pdf_filter,
              onTap: canEdit ? _pickFilter : null,
            ),
            _ToolButton(
              key: const ValueKey('tool_reset'),
              icon: Icons.restart_alt,
              label: l.img2pdf_reset,
              onTap: canEdit && item.isEdited ? _session.resetCurrent : null,
            ),
            _ToolButton(
              key: const ValueKey('tool_delete'),
              icon: Icons.delete_outline,
              label: l.core_delete,
              onTap: canEdit ? _remove : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrip() {
    final items = _session.items;
    final l = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                key: const ValueKey('strip'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                itemCount: items.length,
                onReorderItem: _session.reorder,
                itemBuilder: (context, i) => _stripTile(items[i], i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: const ValueKey('strip_add'),
                onTap: _busy ? null : _add,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add),
                      Text(
                        l.img2pdf_add,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stripTile(ImageItem item, int index) {
    final selected = index == _session.currentIndex;
    return Padding(
      key: ValueKey('tile_${item.id}'),
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _session.select(index),
        child: Container(
          width: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                EditedImage(
                  path: item.path,
                  edit: item.edit,
                  maxSide: 160,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    color: Colors.black54,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(AppLocalizations l) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('create_button'),
              onPressed: _busy || _session.isEmpty ? null : _create,
              child: Text(
                '${l.img2pdf_createPdf.toUpperCase()} (${_session.length})',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    // Expanded: 5 nút chia đều bề rộng, vừa cả màn 320dp.
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
