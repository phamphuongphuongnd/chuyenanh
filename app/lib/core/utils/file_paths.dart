import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Tên file không trùng trong [dir]: `base.ext`, `base (1).ext`, `base (2).ext`…
/// [ext] có hoặc không có dấu chấm đều được. Ký tự cấm trong tên file được thay bằng `_`.
Future<String> uniqueOutputPath(String dir, String baseName, String ext) async {
  final e = ext.isEmpty ? '' : (ext.startsWith('.') ? ext : '.$ext');
  final base = _capUtf8(sanitizeFileName(baseName), _maxNameBytes);
  var candidate = p.join(dir, '$base$e');
  var i = 1;
  while (await File(candidate).exists() ||
      await Directory(candidate).exists()) {
    candidate = p.join(dir, '$base ($i)$e');
    i++;
  }
  return candidate;
}

/// Hệ thống file giới hạn 255 byte/tên; chừa chỗ cho ` (n)`, đuôi và `.tmp`.
const int _maxNameBytes = 150;

/// Cắt [s] sao cho UTF-8 không quá [maxBytes] byte, không cắt giữa một ký tự.
String _capUtf8(String s, int maxBytes) {
  if (utf8.encode(s).length <= maxBytes) return s;
  final out = StringBuffer();
  var bytes = 0;
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final n = utf8.encode(ch).length;
    if (bytes + n > maxBytes) break;
    out.write(ch);
    bytes += n;
  }
  final cut = out.toString().trim();
  return cut.isEmpty ? 'untitled' : cut;
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
    try {
      // POSIX: rename đè lên file đích trong một bước, không có lúc nào mất file.
      return await tmp.rename(path);
    } on FileSystemException {
      // Windows không cho đè: xoá đích rồi đổi tên.
      if (await target.exists()) await target.delete();
      return await tmp.rename(path);
    }
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
