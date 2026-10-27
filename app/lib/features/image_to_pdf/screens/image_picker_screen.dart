import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../image_to_pdf_paths.dart';
import '../image_to_pdf_providers.dart';
import '../models/ordered_selection.dart';
import '../models/picked_image.dart';
import '../services/gallery_service.dart';
import '../widgets/gallery_thumb.dart';

/// Bước 1: chọn ảnh — lưới theo album, chọn nhiều có số thứ tự, nút chụp camera.
///
/// [addMode] = đang thêm ảnh từ màn sửa: xong thì trả về `List<String>` đường dẫn
/// (`context.pop`) thay vì mở màn sửa. [remaining] là số ảnh còn thêm được (mặc định tối đa).
class ImagePickerScreen extends ConsumerStatefulWidget {
  const ImagePickerScreen({super.key, this.addMode = false, this.remaining});

  final bool addMode;
  final int? remaining;

  @override
  ConsumerState<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends ConsumerState<ImagePickerScreen> {
  static const int _pageSize = 90;

  GalleryAccess? _access;
  AppError? _error;
  List<GalleryAlbum> _albums = const [];
  GalleryAlbum? _album;
  final List<GalleryAsset> _assets = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loadingPage = false;
  bool _resolving = false;
  late final OrderedSelection<PickedImage> _selection = OrderedSelection(
    limit: widget.remaining ?? maxImagesPerPdf,
  );
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (!widget.addMode) {
      // Bắt đầu lượt mới: dọn file tạm của lượt trước.
      unawaited(ref.read(workDirCleanerProvider)());
    }
    unawaited(_init());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _access = null;
      _error = null;
    });
    try {
      final gallery = ref.read(galleryServiceProvider);
      final access = await gallery.requestAccess();
      if (!mounted) return;
      if (access == GalleryAccess.denied) {
        setState(() => _access = access);
        return;
      }
      final albums = await gallery.albums();
      if (!mounted) return;
      setState(() {
        _access = access;
        _albums = albums;
        _album = albums.isEmpty ? null : albums.first;
        _assets.clear();
        _page = 0;
        _hasMore = _album != null;
      });
      await _loadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppError.from(e);
        _access = GalleryAccess.granted;
      });
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 600) unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingPage || !_hasMore) return;
    _loadingPage = true;
    try {
      final list = await ref
          .read(galleryServiceProvider)
          .assets(album, page: _page, pageSize: _pageSize);
      if (!mounted || _album != album) return;
      setState(() {
        _assets.addAll(list);
        _page += 1;
        _hasMore = list.length >= _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppError.from(e));
    } finally {
      _loadingPage = false;
      // Đổi album giữa lúc đang tải: lượt tải cũ bị bỏ, phải tải lại cho album mới.
      if (mounted && _album != album) unawaited(_loadMore());
    }
  }

  void _selectAlbum(GalleryAlbum album) {
    if (album == _album) return;
    setState(() {
      _album = album;
      _assets.clear();
      _page = 0;
      _hasMore = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_loadMore());
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggle(GalleryAsset asset) {
    final ok = _selection.toggle(PickedImage.fromAsset(asset));
    if (!ok) _snack(context.l10n.img2pdf_maxImages(_selection.limit));
    setState(() {});
  }

  Future<void> _camera() async {
    try {
      final path = await ref.read(cameraServiceProvider).capture();
      if (path == null || !mounted) return;
      if (!_selection.add(PickedImage.fromFile(path))) {
        _snack(context.l10n.img2pdf_maxImages(_selection.limit));
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  Future<void> _next() async {
    final entries = _selection.items;
    if (entries.isEmpty || _resolving) return;
    final l = context.l10n;
    _resolving = true;
    final needsResolve = entries.any((e) => e.asset != null);
    final ctrl = needsResolve
        ? showProgressDialog(context, title: l.img2pdf_preparing)
        : null;
    final paths = <String>[];
    var failed = 0;
    try {
      final gallery = ref.read(galleryServiceProvider);
      final workDir = await ref.read(workDirProvider)();
      for (var i = 0; i < entries.length; i++) {
        ctrl?.cancelToken.throwIfCancelled();
        final e = entries[i];
        String? path = e.filePath;
        if (path == null) {
          try {
            path = await gallery.resolveFile(e.asset!, workDir);
          } catch (_) {
            path = null;
          }
        }
        if (path != null) {
          paths.add(path);
        } else {
          failed++;
        }
        ctrl?.update((i + 1) / entries.length);
      }
    } on Cancelled {
      return;
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
      return;
    } finally {
      ctrl?.close();
      _resolving = false;
    }
    if (!mounted) return;
    if (failed > 0) _snack(l.img2pdf_skippedImages(failed));
    if (paths.isEmpty) return;
    if (widget.addMode) {
      context.pop(paths);
    } else {
      unawaited(context.push(img2pdfEditPath, extra: paths));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = _access;
    return Scaffold(
      appBar: AppBar(title: _buildTitle(l), titleSpacing: 0),
      body: switch (access) {
        null => const Center(child: CircularProgressIndicator()),
        GalleryAccess.denied => _buildDenied(l),
        _ => _error != null ? _buildError() : _buildGrid(l, access),
      },
      bottomNavigationBar: _selection.isEmpty ? null : _buildSelectionBar(l),
    );
  }

  Widget _buildTitle(AppLocalizations l) {
    final album = _album;
    if (album == null || _albums.length < 2) {
      return Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(album?.name ?? l.img2pdf_pickTitle),
      );
    }
    return PopupMenuButton<GalleryAlbum>(
      tooltip: l.img2pdf_pickTitle,
      onSelected: _selectAlbum,
      itemBuilder: (_) => [
        for (final a in _albums)
          PopupMenuItem(value: a, child: Text('${a.name} (${a.count})')),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                album.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).appBarTheme.titleTextStyle ??
                    Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildDenied(AppLocalizations l) {
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.photo_library_outlined,
            title: l.img2pdf_permissionTitle,
            message: l.img2pdf_permissionMessage,
            actionLabel: l.img2pdf_allowAccess,
            onAction: _init,
          ),
        ),
        TextButton(
          onPressed: () => ref.read(galleryServiceProvider).openSettings(),
          child: Text(l.img2pdf_openSettings),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildError() {
    return EmptyState(
      icon: Icons.error_outline,
      title: appErrorMessage(context, _error!),
      actionLabel: context.l10n.core_retry,
      onAction: _init,
    );
  }

  Widget _buildGrid(AppLocalizations l, GalleryAccess access) {
    final children = <Widget>[];
    if (access == GalleryAccess.limited) {
      children.add(
        MaterialBanner(
          content: Text(l.img2pdf_limitedAccess),
          actions: [
            TextButton(
              onPressed: () => ref.read(galleryServiceProvider).openSettings(),
              child: Text(l.img2pdf_openSettings),
            ),
          ],
        ),
      );
    }
    children.add(
      Expanded(
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: _assets.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _cameraTile(l);
            return _assetTile(_assets[index - 1]);
          },
        ),
      ),
    );
    if (_assets.isEmpty && !_loadingPage && !_hasMore) {
      children.insert(
        access == GalleryAccess.limited ? 1 : 0,
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.img2pdf_noImages,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return Column(children: children);
  }

  Widget _cameraTile(AppLocalizations l) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('camera_tile'),
      onTap: _camera,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, size: 36, color: colors.primary),
            const SizedBox(height: 6),
            Text(l.img2pdf_camera, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _assetTile(GalleryAsset asset) {
    final number = _selection.numberOf(PickedImage.fromAsset(asset));
    final selected = number != null;
    return GestureDetector(
      key: ValueKey('asset_${asset.id}'),
      onTap: () => _toggle(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GalleryThumb(asset: asset),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black26,
                border: Border.all(color: AppColors.primary, width: 3),
              ),
            ),
          Positioned(top: 6, right: 6, child: _NumberBadge(number: number)),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(AppLocalizations l) {
    final entries = _selection.items;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _selectedThumb(entries[i], i + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.img2pdf_selectedCount(entries.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('next_button'),
                    onPressed: _resolving ? null : _next,
                    child: Text(l.img2pdf_next.toUpperCase()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedThumb(PickedImage entry, int number) {
    final Widget image = entry.asset != null
        ? GalleryThumb(asset: entry.asset!, size: 128)
        : Image.file(
            File(entry.filePath!),
            fit: BoxFit.cover,
            cacheWidth: 160,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          );
    return GestureDetector(
      key: ValueKey('selected_${entry.key}'),
      onTap: () => setState(() => _selection.remove(entry)),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(1),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
            Positioned(
              left: 3,
              bottom: 2,
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vòng tròn góc ảnh: trống = chưa chọn, đỏ + số = đã chọn.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    final n = number;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: n == null ? Colors.black26 : AppColors.primary,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: n == null
          ? null
          : Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
