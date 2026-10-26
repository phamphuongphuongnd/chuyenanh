import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/utils/output_directory.dart';
import '../../core/widgets/widgets.dart';
import '../../engines/pdf/pdf_render_engine.dart';
import '../../engines/pdf/pdf_sign_engine.dart';
import '../reader/reader_providers.dart';
import 'edited_output.dart';
import 'editor_common.dart';
import 'editor_providers.dart';
import 'signature_image.dart';
import 'signature_overlay.dart';
import 'signature_overlay_model.dart';
import 'signature_pad_sheet.dart';
import 'signature_store.dart';

/// DPI render trang để xem khi đặt chữ ký (đủ nét, không ngốn RAM).
const double kSignPreviewDpi = 110;

/// Danh sách chữ ký đã lưu (mới nhất trước). `invalidate` sau khi lưu / xoá.
final savedSignaturesProvider =
    FutureProvider.autoDispose<List<SignatureEntry>>((ref) async {
      final store = await ref.watch(signatureStoreProvider.future);
      final result = <SignatureEntry>[];
      for (final s in await store.list()) {
        try {
          result.add(SignatureEntry(s, await store.read(s)));
        } on FileSystemException {
          // File vừa bị xoá / hỏng: bỏ qua, không làm hỏng cả danh sách.
        }
      }
      return result;
    });

/// Chữ ký đã lưu kèm nội dung PNG (nhỏ, tối đa [kMaxSavedSignatures] cái) — vẽ thumbnail từ bộ nhớ,
/// không giữ file mở.
class SignatureEntry {
  const SignatureEntry(this.saved, this.png);

  final SavedSignature saved;
  final Uint8List png;
}

class _PageData {
  const _PageData(this.image, this.size);

  final Uint8List image;

  /// Kích thước trang "nhìn thấy" (point) — cùng hệ với `PdfSignEngine.pageSize`.
  final Size size;
}

/// Màn ký PDF (`Routes.sign`): chọn / vẽ chữ ký, đặt lên trang (kéo, đổi cỡ), lưu ra file MỚI.
///
/// Trang được render bằng `pdfRenderEngineProvider` (feature reader) để biết đúng toạ độ trang;
/// việc đặt ảnh lên PDF do `pdfSignEngineProvider`.
class SignScreen extends ConsumerStatefulWidget {
  const SignScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends ConsumerState<SignScreen> {
  PdfRenderDocument? _doc;
  String? _password;
  Object? _openError;
  bool _opening = true;
  int _pageIndex = 0;
  final Map<int, Future<_PageData>> _pages = {};
  final Map<int, Size> _pageSizes = {};

  final List<PlacedSignature> _items = [];
  int _nextId = 1;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    // l10n cần context đã gắn vào cây → chờ khung hình đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _openError = null;
    });
    final l = context.l10n;
    final name = p.basename(widget.path);
    String? errorText;
    try {
      final render = ref.read(pdfRenderEngineProvider);
      while (true) {
        try {
          final doc = await render.openFile(widget.path, password: _password);
          if (!mounted) {
            await doc.close();
            return;
          }
          setState(() {
            _doc = doc;
            _opening = false;
          });
          return;
        } on PasswordRequired {
          errorText = null;
        } on WrongPassword {
          errorText = l.core_errorWrongPassword;
        }
        if (!mounted) return;
        final pw = await showPasswordDialog(
          context,
          message: l.core_passwordDialogMessage(name),
          errorText: errorText,
        );
        if (pw == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        _password = pw;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _openError = e;
          _opening = false;
        });
      }
    }
  }

  Future<_PageData> _loadPage(int index) async {
    final doc = _doc!;
    final size = await ref
        .read(pdfSignEngineProvider)
        .pageSize(widget.path, index, password: _password);
    final image = await doc.renderPage(index, dpi: kSignPreviewDpi);
    _pageSizes[index] = size;
    return _PageData(image, size);
  }

  Future<_PageData> _pageData(int index) =>
      _pages.putIfAbsent(index, () => _loadPage(index));

  void _goToPage(int index) {
    final count = _doc?.pageCount ?? 1;
    if (index < 0 || index >= count) return;
    setState(() {
      _pageIndex = index;
      _selectedId = null;
    });
  }

  Future<void> _addFromBytes(Uint8List png) async {
    try {
      final data = await _pageData(_pageIndex);
      final aspect = pngAspectRatio(png);
      final item = PlacedSignature(
        id: _nextId++,
        pageIndex: _pageIndex,
        pngBytes: png,
        aspect: aspect,
        norm: initialNormRect(aspect, data.size),
      );
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _selectedId = item.id;
      });
    } catch (e) {
      if (mounted) showEditorError(context, e);
    }
  }

  Future<void> _addSaved(SignatureEntry s) => _addFromBytes(s.png);

  Future<void> _drawNew() async {
    final png = await showSignaturePadSheet(context);
    if (png == null || !mounted) return;
    try {
      final store = await ref.read(signatureStoreProvider.future);
      await store.save(png);
      ref.invalidate(savedSignaturesProvider);
    } catch (e) {
      // Không lưu được thì vẫn cho dùng chữ ký vừa vẽ trong phiên này.
      if (mounted) showEditorError(context, e);
    }
    if (mounted) await _addFromBytes(png);
  }

  Future<void> _deleteSaved(SignatureEntry s) async {
    final l = context.l10n;
    final ok = await showConfirmDialog(
      context,
      title: l.edit_deleteSignatureTitle,
      message: l.edit_deleteSignatureMessage,
      confirmLabel: l.core_delete,
    );
    if (!ok || !mounted) return;
    try {
      final store = await ref.read(signatureStoreProvider.future);
      await store.delete(s.saved);
      ref.invalidate(savedSignaturesProvider);
    } catch (e) {
      if (mounted) showEditorError(context, e);
    }
  }

  void _update(int id, PlacedSignature Function(PlacedSignature) f) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    setState(() => _items[i] = f(_items[i]));
  }

  Future<void> _apply() async {
    final l = context.l10n;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.edit_noPlacements)));
      return;
    }
    final progress = showProgressDialog(context, cancellable: false);
    String? out;
    try {
      final placements = [
        for (final it in _items)
          SignaturePlacement(
            pageIndex: it.pageIndex,
            bounds: normToPdfRect(it.norm, _pageSizes[it.pageIndex]!),
            pngBytes: it.pngBytes,
          ),
      ];
      final dir = await ref.read(outputDirectoryProvider.future);
      final target = await editedOutputPath(dir, widget.path, EditKind.sign);
      out = await ref
          .read(pdfSignEngineProvider)
          .applySignatures(
            widget.path,
            placements,
            target,
            password: _password,
          );
    } catch (e) {
      progress.close();
      if (mounted) showEditorError(context, e);
      return;
    }
    progress.close();
    if (!mounted) return;
    setState(_items.clear);
    await showSavedDialog(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canApply = _doc != null;
    return UnsavedChangesGuard(
      hasChanges: _items.isNotEmpty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            p.basename(widget.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              key: const Key('apply'),
              tooltip: l.edit_applySignatures,
              icon: const Icon(Icons.check),
              onPressed: canApply ? _apply : null,
            ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = context.l10n;
    if (_opening) return const Center(child: CircularProgressIndicator());
    if (_openError != null || _doc == null) {
      final e = _openError;
      return EmptyState(
        title: e is AppError ? appErrorMessage(context, e) : l.edit_loadFailed,
        icon: Icons.error_outline,
        actionLabel: l.core_retry,
        onAction: _open,
      );
    }
    final count = _doc!.pageCount;
    return Column(
      children: [
        HintBanner(l.edit_signHint),
        Expanded(
          child: FutureBuilder<_PageData>(
            key: ValueKey(_pageIndex),
            future: _pageData(_pageIndex),
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(
                  title: snap.error is AppError
                      ? appErrorMessage(context, snap.error as AppError)
                      : l.edit_loadFailed,
                  icon: Icons.error_outline,
                  actionLabel: l.core_retry,
                  onAction: () => setState(() => _pages.remove(_pageIndex)),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildPageArea(context, snap.data!);
            },
          ),
        ),
        _PageNavigator(
          pageIndex: _pageIndex,
          pageCount: count,
          onPrevious: _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
          onNext: _pageIndex < count - 1
              ? () => _goToPage(_pageIndex + 1)
              : null,
        ),
        _SignatureBar(onNew: _drawNew, onPick: _addSaved, onDelete: _deleteSaved),
      ],
    );
  }

  Widget _buildPageArea(BuildContext context, _PageData data) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        const pad = kSignatureAreaPadding;
        final availW = (c.maxWidth - 2 * pad).clamp(1.0, double.infinity);
        final availH = (c.maxHeight - 2 * pad).clamp(1.0, double.infinity);
        final scale = [
          availW / data.size.width,
          availH / data.size.height,
        ].reduce((a, b) => a < b ? a : b);
        final box = Size(data.size.width * scale, data.size.height * scale);
        const origin = Offset(pad, pad);
        return Center(
          child: SizedBox(
            width: box.width + 2 * pad,
            height: box.height + 2 * pad,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fromRect(
                  rect: origin & box,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedId = null),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black26),
                        ],
                      ),
                      child: Image.memory(
                        data.image,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                for (final it in _items.where((e) => e.pageIndex == _pageIndex))
                  ...signatureOverlayWidgets(
                    context,
                    item: it,
                    pageBox: box,
                    pageOrigin: origin,
                    selected: it.id == _selectedId,
                    removeLabel: l.edit_removeSignature,
                    onSelect: () => setState(() => _selectedId = it.id),
                    onMove: (delta) => _update(
                      it.id,
                      (s) => s.copyWith(norm: moveNormRect(s.norm, delta)),
                    ),
                    onResize: (w) => _update(
                      it.id,
                      (s) => s.copyWith(
                        norm: resizeNormRect(s.norm, w, data.size, s.aspect),
                      ),
                    ),
                    onRemove: () => setState(() {
                      _items.removeWhere((e) => e.id == it.id);
                      _selectedId = null;
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageNavigator extends StatelessWidget {
  const _PageNavigator({
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('prevPage'),
          tooltip: l.edit_previousPage,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Text(l.edit_pageOf(pageIndex + 1, pageCount)),
        IconButton(
          key: const Key('nextPage'),
          tooltip: l.edit_nextPage,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Dải chữ ký đã lưu + ô "chữ ký mới".
class _SignatureBar extends ConsumerWidget {
  const _SignatureBar({
    required this.onNew,
    required this.onPick,
    required this.onDelete,
  });

  final VoidCallback onNew;
  final ValueChanged<SignatureEntry> onPick;
  final ValueChanged<SignatureEntry> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saved = ref.watch(savedSignaturesProvider);
    final list = saved.value ?? const <SignatureEntry>[];
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              _Tile(
                key: const Key('newSignature'),
                onTap: onNew,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.draw_outlined),
                    const SizedBox(height: 4),
                    Text(
                      l.edit_newSignature,
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (list.isEmpty && saved.hasValue)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 180,
                      child: Text(
                        l.edit_noSavedSignatures,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              for (final s in list)
                _Tile(
                  key: Key('saved_${s.saved.fileName}'),
                  onTap: () => onPick(s),
                  onLongPress: () => onDelete(s),
                  background: Colors.white,
                  badge: GestureDetector(
                    key: Key('delete_${s.saved.fileName}'),
                    onTap: () => onDelete(s),
                    child: const Icon(
                      Icons.cancel,
                      size: 20,
                      color: Colors.black45,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.memory(
                      s.png,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.background,
    this.badge,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? background;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 104,
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: background ?? theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: child,
                ),
              ),
            ),
            if (badge != null) Positioned(top: 0, right: 0, child: badge!),
          ],
        ),
      ),
    );
  }
}
