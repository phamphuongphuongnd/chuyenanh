import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../image_to_pdf_providers.dart';
import '../models/image_item.dart';

/// Hiện ảnh đã áp chỉnh sửa (xem trước render trong isolate, có cache).
/// Khi chỉnh sửa đổi, ảnh cũ vẫn hiện (kèm vòng chờ) cho tới khi ảnh mới sẵn sàng — không nháy.
class EditedImage extends ConsumerStatefulWidget {
  const EditedImage({
    super.key,
    required this.path,
    required this.edit,
    this.maxSide = 1024,
    this.fit = BoxFit.contain,
  });

  final String path;
  final ops.ImageEdit edit;
  final int maxSide;
  final BoxFit fit;

  @override
  ConsumerState<EditedImage> createState() => _EditedImageState();
}

class _EditedImageState extends ConsumerState<EditedImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;
  String? _key;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EditedImage old) {
    super.didUpdateWidget(old);
    if (_currentKey() != _key) _load();
  }

  String _currentKey() => editKey(widget.path, widget.edit, widget.maxSide);

  void _load() {
    final key = _currentKey();
    _key = key;
    _loading = true;
    ref
        .read(previewCacheProvider)
        .get(widget.path, widget.edit, maxSide: widget.maxSide)
        .then(
          (bytes) {
            if (!mounted || _key != key) return;
            setState(() {
              _bytes = bytes;
              _loading = false;
              _failed = false;
            });
          },
          onError: (Object _) {
            if (!mounted || _key != key) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (bytes != null)
          Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          )
        else if (_failed)
          const Center(child: Icon(Icons.broken_image_outlined, size: 32)),
        if (_loading)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
