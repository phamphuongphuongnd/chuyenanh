import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/errors/app_error.dart';
import '../../core/utils/file_paths.dart';
import '../../engines/pdf/pdf_sign_engine.dart';
import 'signature_math.dart';

/// [PdfSignEngine] dùng Syncfusion PDF (`PdfBitmap`).
///
/// Quy ước toạ độ: `SignaturePlacement.bounds` và `pageSize()` ở hệ **nhìn thấy** (đã tính
/// xoay trang `/Rotate`), gốc trên-trái, đơn vị point. Engine tự đổi sang hệ chưa xoay của trang
/// (`visualRectToRawRect`) và xoay ảnh ngược chiều để chữ ký hiện thẳng.
class SyncfusionPdfSignEngine implements PdfSignEngine {
  const SyncfusionPdfSignEngine();

  @override
  Future<String> applySignatures(
    String inputPath,
    List<SignaturePlacement> placements,
    String outputPath, {
    String? password,
  }) async {
    final Uint8List input;
    try {
      input = await File(inputPath).readAsBytes();
    } on FileSystemException catch (e) {
      throw AppError.from(e);
    }
    // Chuyển sang dữ liệu thuần để gửi qua Isolate.
    final jobs = [
      for (final p in placements)
        (
          p.pageIndex,
          p.bounds.left,
          p.bounds.top,
          p.bounds.right,
          p.bounds.bottom,
          p.pngBytes,
        ),
    ];
    final Uint8List output;
    try {
      output = await Isolate.run(() => _apply(input, jobs, password));
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    }
    try {
      await writeAtomically(outputPath, output);
    } on FileSystemException catch (e) {
      throw AppError.from(e);
    }
    return outputPath;
  }

  /// Cache kích thước (đã tính xoay) của TẤT CẢ trang, theo đường dẫn + thời gian sửa + dung lượng.
  /// Chỉ parse file một lần (trong isolate nền), không giữ bytes của file.
  static final Map<String, Future<List<Size>>> _sizeCache = {};
  static int _parseCount = 0;
  static const _maxCachedFiles = 4;

  @visibleForTesting
  static int get debugPageSizeParseCount => _parseCount;

  @visibleForTesting
  static void debugClearPageSizeCache() {
    _sizeCache.clear();
    _parseCount = 0;
  }

  @override
  Future<Size> pageSize(
    String inputPath,
    int pageIndex, {
    String? password,
  }) async {
    final String key;
    try {
      final stat = await File(inputPath).stat();
      if (stat.type == FileSystemEntityType.notFound) {
        throw const FileSystemException('not found');
      }
      key = '$inputPath|${stat.modified.microsecondsSinceEpoch}|${stat.size}';
    } on FileSystemException catch (e) {
      throw AppError.from(e);
    }
    var future = _sizeCache.remove(key);
    if (future == null) {
      _parseCount++;
      future = _readAllSizes(inputPath, password);
      future.then<void>((_) {}, onError: (_) => _sizeCache.remove(key));
    }
    _sizeCache[key] = future; // đưa về cuối = mới dùng nhất
    while (_sizeCache.length > _maxCachedFiles) {
      _sizeCache.remove(_sizeCache.keys.first);
    }
    final sizes = await future;
    if (pageIndex < 0 || pageIndex >= sizes.length) {
      throw CorruptFile('page $pageIndex out of range');
    }
    return sizes[pageIndex];
  }

  static Future<List<Size>> _readAllSizes(
    String inputPath,
    String? password,
  ) async {
    final Uint8List input;
    try {
      input = await File(inputPath).readAsBytes();
    } on FileSystemException catch (e) {
      throw AppError.from(e);
    }
    try {
      final raw = await Isolate.run(() => _allSizes(input, password));
      return [for (final (w, h) in raw) Size(w, h)];
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    }
  }
}

List<(double, double)> _allSizes(Uint8List input, String? password) {
  final doc = _open(input, password);
  try {
    final out = <(double, double)>[];
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final v = visualPageSize(
        Size(page.size.width, page.size.height),
        _rotationDegrees(page),
      );
      out.add((v.width, v.height));
    }
    return out;
  } finally {
    doc.dispose();
  }
}

typedef _Job = (int, double, double, double, double, Uint8List);

Future<Uint8List> _apply(
  Uint8List input,
  List<_Job> jobs,
  String? password,
) async {
  final doc = _open(input, password);
  try {
    for (final (pageIndex, l, t, r, b, png) in jobs) {
      final page = _page(doc, pageIndex);
      final rotation = _rotationDegrees(page);
      final rawSize = Size(page.size.width, page.size.height);
      final visual = visualPageSize(rawSize, rotation);
      final inside = clampRectInside(
        Rect.fromLTRB(l, t, r, b),
        Size(visual.width, visual.height),
      );
      final rawRect = visualRectToRawRect(inside, rawSize, rotation);
      final upright = rotation == 0 ? png : rotatePngCounterClockwise(png, rotation);
      page.graphics.drawImage(sf.PdfBitmap(upright), rawRect);
    }
    return Uint8List.fromList(await doc.save());
  } finally {
    doc.dispose();
  }
}

/// Xoay ảnh PNG ngược chiều kim đồng hồ [degrees] (90/180/270) để sau khi trang xoay thuận
/// [degrees] khi hiển thị, chữ ký hiện thẳng. Giữ nền trong suốt.
Uint8List rotatePngCounterClockwise(Uint8List png, int degrees) {
  final d = normalizeRotation(degrees);
  if (d == 0) return png;
  final decoded = img.decodePng(png);
  if (decoded == null) throw const CorruptFile('signature png');
  // `copyRotate` quay thuận chiều kim đồng hồ → quay ngược = 360 - d.
  final rotated = img.copyRotate(decoded, angle: 360 - d);
  return Uint8List.fromList(img.encodePng(rotated));
}

sf.PdfDocument _open(Uint8List bytes, String? password) {
  try {
    return sf.PdfDocument(inputBytes: bytes, password: password);
  } on ArgumentError catch (e) {
    if (e.name == 'password' ||
        (e.message?.toString().toLowerCase().contains('password') ?? false)) {
      throw password == null || password.isEmpty
          ? const PasswordRequired()
          : const WrongPassword();
    }
    throw CorruptFile(e.toString());
  } catch (e) {
    throw CorruptFile(e.toString());
  }
}

sf.PdfPage _page(sf.PdfDocument doc, int index) {
  if (index < 0 || index >= doc.pages.count) {
    throw CorruptFile('page $index out of range');
  }
  return doc.pages[index];
}

int _rotationDegrees(sf.PdfPage page) => switch (page.rotation) {
  sf.PdfPageRotateAngle.rotateAngle90 => 90,
  sf.PdfPageRotateAngle.rotateAngle180 => 180,
  sf.PdfPageRotateAngle.rotateAngle270 => 270,
  _ => 0,
};
