import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_type.dart';
import '../../../core/utils/file_paths.dart';
import '../../../data/db/app_database.dart';

/// Thêm file PDF vừa tạo vào bảng `documents` (để hiện ngay ở Trang chủ, không cần quét lại)
/// và `recents`.
Future<void> registerOutputDocument(AppDatabase db, String path) async {
  final stat = await File(path).stat();
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.documentsDao.upsert(
    DocumentsCompanion.insert(
      path: path,
      name: p.basename(path),
      ext: extensionOf(path),
      size: stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
      folder: parentFolderName(path),
      scannedAtMs: now,
    ),
  );
  await db.recentsDao.touch(path);
}

/// Đổi tên file đã tạo (cùng thư mục, không đè file khác) và cập nhật DB.
/// Trả về đường dẫn mới. [newBaseName] không gồm đuôi.
Future<String> renameOutputDocument(
  AppDatabase db,
  String oldPath,
  String newBaseName,
) async {
  final dir = p.dirname(oldPath);
  final ext = p.extension(oldPath);
  final wanted = p.join(dir, '${sanitizeFileName(newBaseName)}$ext');
  if (wanted == oldPath) return oldPath;
  final target = await uniqueOutputPath(dir, newBaseName, ext);
  await File(oldPath).rename(target);
  await db.renamePath(
    oldPath,
    target,
    newName: p.basename(target),
    newFolder: parentFolderName(target),
  );
  return target;
}
