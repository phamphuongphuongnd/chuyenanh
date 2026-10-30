import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
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
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                album.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Symbols.arrow_drop_down_rounded, color: context.tokens.text),
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
            icon: Symbols.photo_library_rounded,
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
      icon: Symbols.error_rounded,
      title: appErrorMessage(context, _error!),
      actionLabel: context.l10n.core_retry,
      onAction: _init,
    );
  }

  /// Băng "quyền giới hạn": nền `primarySoft` bo 16, chữ + nút Mở cài đặt.
  Widget _buildLimitedBanner(AppLocalizations l) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Symbols.photo_library_rounded, size: 22, color: t.primaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.img2pdf_limitedAccess,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: t.text,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(galleryServiceProvider).openSettings(),
            child: Text(l.img2pdf_openSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(AppLocalizations l, GalleryAccess access) {
    final children = <Widget>[];
    if (access == GalleryAccess.limited) {
      children.add(_buildLimitedBanner(l));
    }
    children.add(
      Expanded(
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.tokens.textMuted,
            ),
          ),
        ),
      );
    }
    return Column(children: children);
  }

  Widget _cameraTile(AppLocalizations l) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(_tileRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('camera_tile'),
        onTap: _camera,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.photo_camera_rounded,
                size: 26,
                fill: 1,
                color: t.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                l.img2pdf_camera,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetTile(GalleryAsset asset) {
    final number = _selection.numberOf(PickedImage.fromAsset(asset));
    final selected = number != null;
    final radius = BorderRadius.circular(_tileRadius);
    return GestureDetector(
      key: ValueKey('asset_${asset.id}'),
      onTap: () => _toggle(asset),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GalleryThumb(asset: asset),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
              ),
            Positioned(top: 6, right: 6, child: _NumberBadge(number: number)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(AppLocalizations l) {
    final entries = _selection.items;
    final t = context.tokens;
    // Thanh dưới: nền `surface`, kẻ trên `line`, không bóng.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _selectedThumb(entries[i], i + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.img2pdf_selectedCount(entries.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const ValueKey('next_button'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 50),
                    ),
                    onPressed: _resolving ? null : _next,
                    child: Text(l.img2pdf_next),
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
    final t = context.tokens;
    final Widget image = entry.asset != null
        ? GalleryThumb(asset: entry.asset!, size: 128)
        : Image.file(
            File(entry.filePath!),
            fit: BoxFit.cover,
            cacheWidth: 160,
            errorBuilder: (_, _, _) => ColoredBox(
              color: t.surface2,
              child: Icon(Symbols.broken_image_rounded, color: t.textMuted),
            ),
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
            ClipRRect(borderRadius: BorderRadius.circular(10), child: image),
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Symbols.close_rounded,
                  size: 13,
                  weight: 700,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 3,
              bottom: 3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bo góc ô ảnh trong lưới.
const double _tileRadius = 10;

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
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
