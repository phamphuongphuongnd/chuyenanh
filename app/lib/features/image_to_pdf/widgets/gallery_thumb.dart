import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../image_to_pdf_providers.dart';
import '../services/gallery_service.dart';

/// Ảnh thu nhỏ của một ảnh trong thư viện (tải qua [GalleryService], giữ cache theo id).
class GalleryThumb extends ConsumerStatefulWidget {
  const GalleryThumb({super.key, required this.asset, this.size = 256});

  final GalleryAsset asset;
  final int size;

  @override
  ConsumerState<GalleryThumb> createState() => _GalleryThumbState();
}

/// Cache nhỏ theo (id, size) để cuộn lưới không phải gọi lại plugin.
final Map<String, Future<Uint8List?>> _thumbCache = {};
const int _thumbCacheLimit = 400;

class _GalleryThumbState extends ConsumerState<GalleryThumb> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(GalleryThumb old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id || old.size != widget.size) {
      _future = _fetch();
    }
  }

  Future<Uint8List?> _fetch() {
    final key = '${widget.asset.id}@${widget.size}';
    final hit = _thumbCache.remove(key);
    if (hit != null) {
      _thumbCache[key] = hit;
      return hit;
    }
    final f = ref
        .read(galleryServiceProvider)
        .thumbnail(widget.asset, size: widget.size);
    _thumbCache[key] = f;
    while (_thumbCache.length > _thumbCacheLimit) {
      _thumbCache.remove(_thumbCache.keys.first);
    }
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data != null && data.isNotEmpty) {
          return Image.memory(
            data,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          );
        }
        // Chờ tải / lỗi: nền `surface2` (giống skeleton), lỗi thì thêm icon ảnh hỏng.
        return ColoredBox(
          color: t.surface2,
          child: snap.connectionState == ConnectionState.done
              ? Icon(Symbols.broken_image_rounded, color: t.textMuted)
              : null,
        );
      },
    );
  }
}
