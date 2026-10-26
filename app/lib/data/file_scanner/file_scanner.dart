import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/utils/doc_type.dart';

/// Một file tài liệu tìm thấy khi quét. Chỉ chứa kiểu cơ bản nên gửi qua isolate được.
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.name,
    required this.ext,
    required this.size,
    required this.modifiedMs,
    required this.folder,
  });

  final String path;

  /// Tên đầy đủ có đuôi.
  final String name;

  /// Đuôi chữ thường, không dấu chấm.
  final String ext;
  final int size;
  final int modifiedMs;

  /// Tên thư mục cha.
  final String folder;
}

/// Kết quả một lượt quét.
class ScanResult {
  const ScanResult({
    required this.files,
    this.unreadableRoots = const [],
    this.skippedDirectories = 0,
  });

  final List<ScannedFile> files;

  /// Thư mục gốc không liệt kê được (chưa cấp quyền / không tồn tại).
  final List<String> unreadableRoots;

  /// Số thư mục con bị lỗi khi liệt kê (bỏ qua, không dừng cả lượt quét).
  final int skippedDirectories;

  /// Mọi thư mục gốc đều đọc được ⇒ kết quả đủ tin cậy để xoá file không còn thấy.
  bool get allRootsReadable => unreadableRoots.isEmpty;
}

/// Thư mục có bị bỏ qua khi quét không: ẩn (bắt đầu bằng `.`), `Android/data`, `Android/obb`.
bool shouldSkipDirectory(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name =
      normalized.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
  if (name.startsWith('.')) return true;
  final lower = '${normalized.toLowerCase()}/';
  return lower.contains('/android/data/') || lower.contains('/android/obb/');
}

/// Quét đệ quy [roots] (chạy ngay trong isolate hiện tại — dùng [scanInIsolate] ở UI).
///
/// - Bỏ thư mục ẩn, `Android/data`, `Android/obb`; không đi theo symlink (tránh vòng lặp).
/// - Lỗi một thư mục (không đủ quyền…) chỉ bỏ thư mục đó.
/// - [onProgress] được gọi định kỳ với số file đã tìm.
Future<ScanResult> scanRoots(
  List<String> roots, {
  Set<String> extensions = documentExtensions,
  void Function(int found)? onProgress,
}) async {
  final files = <ScannedFile>[];
  final unreadable = <String>[];
  var skipped = 0;

  for (final root in roots) {
    final pending = <String>[root];
    var isRoot = true;
    while (pending.isNotEmpty) {
      final dirPath = pending.removeLast();
      final listingRoot = isRoot;
      isRoot = false;
      try {
        await for (final entity in Directory(
          dirPath,
        ).list(followLinks: false)) {
          if (entity is Link) continue;
          final base = p.basename(entity.path);
          if (entity is Directory) {
            if (!shouldSkipDirectory(entity.path)) pending.add(entity.path);
          } else if (entity is File) {
            if (base.startsWith('.')) continue;
            final ext = extensionOf(entity.path);
            if (!extensions.contains(ext)) continue;
            try {
              final stat = entity.statSync();
              files.add(
                ScannedFile(
                  path: entity.path,
                  name: base,
                  ext: ext,
                  size: stat.size,
                  modifiedMs: stat.modified.millisecondsSinceEpoch,
                  folder: p.basename(p.dirname(entity.path)),
                ),
              );
              if (files.length % 50 == 0) onProgress?.call(files.length);
            } on FileSystemException {
              skipped++;
            }
          }
        }
      } on FileSystemException {
        if (listingRoot) {
          unreadable.add(root);
        } else {
          skipped++;
        }
      }
    }
  }
  onProgress?.call(files.length);
  return ScanResult(
    files: files,
    unreadableRoots: unreadable,
    skippedDirectories: skipped,
  );
}

/// Quét trong một isolate riêng để UI không giật; vẫn nhận tiến độ qua [onProgress].
Future<ScanResult> scanInIsolate(
  List<String> roots, {
  Set<String> extensions = documentExtensions,
  void Function(int found)? onProgress,
}) async {
  final port = ReceivePort();
  final done = Completer<ScanResult>();
  final sub = port.listen((Object? message) {
    if (done.isCompleted) return;
    if (message is int) {
      onProgress?.call(message);
    } else if (message is ScanResult) {
      done.complete(message);
    } else if (message is List) {
      done.completeError(Unknown(message.first.toString()));
    } else if (message == null) {
      // Isolate thoát mà chưa trả kết quả.
      done.completeError(const Unknown('scan isolate exited'));
    }
  });
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn<_ScanRequest>(
      _scanEntry,
      _ScanRequest(port.sendPort, roots, extensions),
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    return await done.future;
  } finally {
    await sub.cancel();
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}

class _ScanRequest {
  const _ScanRequest(this.sendPort, this.roots, this.extensions);
  final SendPort sendPort;
  final List<String> roots;
  final Set<String> extensions;
}

Future<void> _scanEntry(_ScanRequest request) async {
  try {
    final result = await scanRoots(
      request.roots,
      extensions: request.extensions,
      onProgress: request.sendPort.send,
    );
    request.sendPort.send(result);
  } catch (e) {
    request.sendPort.send([e.toString()]);
  }
}

/// Cách quét (để test thay bằng giả).
abstract interface class FileScanner {
  Future<ScanResult> scan(
    List<String> roots, {
    void Function(int found)? onProgress,
  });
}

/// Quét thật bằng isolate.
class IsolateFileScanner implements FileScanner {
  const IsolateFileScanner();

  @override
  Future<ScanResult> scan(
    List<String> roots, {
    void Function(int found)? onProgress,
  }) => scanInIsolate(roots, onProgress: onProgress);
}
