import 'dart:io';

import 'package:path/path.dart' as p;

/// Tên file không trùng trong [dir]: `base.ext`, `base (1).ext`, `base (2).ext`…
/// [ext] có hoặc không có dấu chấm đều được. Ký tự cấm trong tên file được thay bằng `_`.
Future<String> uniqueOutputPath(String dir, String baseName, String ext) async {
  final e = ext.isEmpty ? '' : (ext.startsWith('.') ? ext : '.$ext');
  final base = sanitizeFileName(baseName);
  var candidate = p.join(dir, '$base$e');
  var i = 1;
  while (await File(candidate).exists() ||
      await Directory(candidate).exists()) {
    candidate = p.join(dir, '$base ($i)$e');
    i++;
  }
  return candidate;
}

/// Bỏ ký tự không hợp lệ trong tên file (`\ / : * ? " < > |` và ký tự điều khiển).
/// Tên rỗng sau khi lọc → `untitled`.
String sanitizeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return cleaned.isEmpty ? 'untitled' : cleaned;
}

/// Tên file bỏ đuôi: `/a/b/report.pdf` → `report`.
String baseNameWithoutExtension(String path) =>
    p.basenameWithoutExtension(path);

/// Ghi an toàn: ghi `<path>.tmp` rồi đổi tên thành [path] (ghi đè nếu đã có).
/// Lỗi giữa chừng → xoá file `.tmp`, ném lại lỗi. Tạo thư mục cha nếu thiếu.
Future<File> writeAtomically(String path, List<int> bytes) async {
  final target = File(path);
  await target.parent.create(recursive: true);
  final tmp = File('$path.tmp');
  try {
    await tmp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    return await tmp.rename(path);
  } catch (_) {
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
    rethrow;
  }
}

/// Tên thư mục cha (dùng cho dòng thông tin file): `/storage/.../Download/a.pdf` → `Download`.
String parentFolderName(String path) => p.basename(p.dirname(path));
