import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/image_item.dart';

/// Xử lý ảnh nặng (đọc thông tin, xem trước, áp chỉnh sửa) — chạy ngoài isolate chính.
/// Tách interface để widget test dùng bản giả.
abstract interface class ImageProcessor {
  /// Thông tin ảnh (sau EXIF); `null` nếu file hỏng / không phải ảnh.
  Future<ops.ImageInfoLite?> probe(String path);

  /// Ảnh xem trước (JPEG) đã áp [edit], cạnh dài ≤ [maxSide].
  Future<Uint8List> renderPreview(
    String path,
    ops.ImageEdit edit, {
    int maxSide = 1024,
  });

  /// Áp [edit] rồi ghi ra file mới trong [outDir] (JPEG, hoặc PNG nếu có alpha).
  /// Trả về đường dẫn file. Ném lỗi nếu ảnh hỏng.
  Future<String> bake(
    String path,
    ops.ImageEdit edit, {
    required Directory outDir,
    required String name,
    int jpegQuality = 95,
  });
}

/// Thư mục tạm của Ảnh→PDF (ảnh HEIC đã đổi, ảnh đã cắt, ảnh đã áp chỉnh sửa).
Future<Directory> img2pdfWorkDir() async {
  final tmp = await getTemporaryDirectory();
  return Directory(p.join(tmp.path, 'img2pdf'));
}

/// Xoá toàn bộ file tạm của lượt trước (gọi khi bắt đầu một lượt Ảnh→PDF mới).
Future<void> clearImg2pdfWorkDir() async {
  try {
    final dir = await img2pdfWorkDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // File tạm — lỗi dọn dẹp không ảnh hưởng người dùng.
  }
}

class _ProbeArgs {
  const _ProbeArgs(this.path);
  final String path;
}

class _PreviewArgs {
  const _PreviewArgs(this.path, this.edit, this.maxSide);
  final String path;
  final ops.ImageEdit edit;
  final int maxSide;
}

class _BakeArgs {
  const _BakeArgs(this.path, this.edit, this.quality);
  final String path;
  final ops.ImageEdit edit;
  final int quality;
}

ops.ImageInfoLite? _probeSync(_ProbeArgs a) {
  try {
    final info = ops.probe(File(a.path).readAsBytesSync());
    return info.width > 0 && info.height > 0 ? info : null;
  } catch (_) {
    return null;
  }
}

Uint8List _previewSync(_PreviewArgs a) => ops.renderPreview(
  File(a.path).readAsBytesSync(),
  a.edit,
  maxSide: a.maxSide,
);

Uint8List _bakeSync(_BakeArgs a) => ops.applyEdit(
  File(a.path).readAsBytesSync(),
  a.edit.copyWith(
    maxLongSide:
        a.edit.maxLongSide != null && a.edit.maxLongSide! < embeddedLongSide
        ? a.edit.maxLongSide
        : embeddedLongSide,
  ),
  jpegQuality: a.quality,
);

/// Impl bằng `image_ops` trong `Isolate.run`.
class IsolateImageProcessor implements ImageProcessor {
  const IsolateImageProcessor();

  @override
  Future<ops.ImageInfoLite?> probe(String path) {
    final args = _ProbeArgs(path);
    return Isolate.run(() => _probeSync(args));
  }

  @override
  Future<Uint8List> renderPreview(
    String path,
    ops.ImageEdit edit, {
    int maxSide = 1024,
  }) {
    final args = _PreviewArgs(path, edit, maxSide);
    return Isolate.run(() => _previewSync(args));
  }

  @override
  Future<String> bake(
    String path,
    ops.ImageEdit edit, {
    required Directory outDir,
    required String name,
    int jpegQuality = 95,
  }) async {
    final args = _BakeArgs(path, edit, jpegQuality);
    final bytes = await Isolate.run(() => _bakeSync(args));
    // PNG bắt đầu bằng 0x89 (ảnh có độ trong suốt); còn lại là JPEG.
    final ext = bytes.isNotEmpty && bytes[0] == 0x89 ? 'png' : 'jpg';
    await outDir.create(recursive: true);
    final out = File(p.join(outDir.path, '$name.$ext'));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }
}

/// Cache xem trước: cùng (file, chỉnh sửa, cỡ) chỉ render một lần. Giữ tối đa [capacity] mục.
class PreviewCache {
  PreviewCache(this._processor, {this.capacity = 60});

  final ImageProcessor _processor;
  final int capacity;
  final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> get(String path, ops.ImageEdit edit, {int maxSide = 1024}) {
    final key = editKey(path, edit, maxSide);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // đưa lên cuối (LRU)
      return hit;
    }
    final future = _processor.renderPreview(path, edit, maxSide: maxSide);
    _cache[key] = future;
    // Lỗi không được giữ trong cache để lần sau thử lại.
    future.catchError((_) {
      _cache.remove(key);
      return Uint8List(0);
    });
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  void clear() => _cache.clear();
}
