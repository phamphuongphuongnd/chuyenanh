import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_error.dart';

/// Máy không dùng được trình quét tự động (không có Google Play Services, plugin lỗi…)
/// → UI chuyển sang chụp ảnh + kéo bốn góc thủ công.
class ScannerUnavailable implements Exception {
  const ScannerUnavailable([this.cause]);
  final Object? cause;
  @override
  String toString() => 'ScannerUnavailable($cause)';
}

/// Nguồn ảnh trang quét. Bọc plugin để test bằng fake (plugin chỉ chạy trên máy thật).
abstract interface class DocumentCapture {
  /// Quét tối đa [maxPages] trang bằng trình quét tự nhận viền. `null` = người dùng huỷ.
  /// Ném [PermissionDenied] (thiếu quyền camera) hoặc [ScannerUnavailable].
  Future<List<String>?> scanPages({int maxPages = 100});

  /// Chụp một ảnh thô bằng camera (cho chế độ kéo góc thủ công). `null` = huỷ.
  /// Ném [PermissionDenied] nếu bị từ chối quyền camera.
  Future<String?> takePhoto();
}

/// Cài đặt thật: `cunning_document_scanner` + `image_picker`.
class PluginDocumentCapture implements DocumentCapture {
  const PluginDocumentCapture();

  @override
  Future<List<String>?> scanPages({int maxPages = 100}) async {
    try {
      final pics = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        scannerSource: ScannerSource.cameraAndGallery,
      );
      if (pics == null) return null;
      return await _keep(pics);
    } on CunningDocumentScannerException catch (e) {
      if (e.code == 'permission_denied') throw const PermissionDenied();
      throw ScannerUnavailable(e);
    } on PlatformException catch (e) {
      throw ScannerUnavailable(e);
    } on MissingPluginException catch (e) {
      throw ScannerUnavailable(e);
    }
  }

  @override
  Future<String?> takePhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      );
      if (x == null) return null;
      return (await _keep([x.path])).single;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') throw const PermissionDenied();
      throw AppError.from(e);
    }
  }

  /// Plugin để file trong cache của nó (bị `cleanCache` xoá) → chép sang thư mục tạm của app.
  Future<List<String>> _keep(List<String> paths) async {
    final base = await getTemporaryDirectory();
    final dir = await Directory(p.join(base.path, 'scan_pages')).create();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = <String>[];
    for (var i = 0; i < paths.length; i++) {
      final ext = p.extension(paths[i]).isEmpty
          ? '.jpg'
          : p.extension(paths[i]);
      final dest = p.join(dir.path, 'p${stamp}_$i$ext');
      await File(paths[i]).copy(dest);
      out.add(dest);
    }
    return out;
  }
}

final documentCaptureProvider = Provider<DocumentCapture>(
  (ref) => const PluginDocumentCapture(),
);
