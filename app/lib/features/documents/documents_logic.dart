import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/doc_type.dart';
import '../../core/utils/file_paths.dart';
import '../../data/db/app_database.dart';

/// Một tài liệu hiển thị trong danh sách (từ bảng `documents` hoặc đọc trực tiếp từ đĩa).
class DocItem {
  const DocItem({
    required this.path,
    required this.name,
    required this.ext,
    required this.size,
    required this.modified,
    required this.folder,
  });

  factory DocItem.fromDocument(Document d) => DocItem(
    path: d.path,
    name: d.name,
    ext: d.ext,
    size: d.size,
    modified: DateTime.fromMillisecondsSinceEpoch(d.modifiedMs),
    folder: d.folder,
  );

  /// Đọc thông tin từ đĩa; `null` nếu file không còn.
  static DocItem? fromFileSync(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final stat = file.statSync();
      return DocItem(
        path: path,
        name: p.basename(path),
        ext: extensionOf(path),
        size: stat.size,
        modified: stat.modified,
        folder: parentFolderName(path),
      );
    } on FileSystemException {
      return null;
    }
  }

  final String path;

  /// Tên đầy đủ có đuôi.
  final String name;
  final String ext;
  final int size;
  final DateTime modified;
  final String folder;

  DocType get type => docTypeFromExtension(ext);
  DocCategory? get category => type.category;
}

/// Cách sắp xếp danh sách.
enum DocSort {
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc,
  sizeDesc,
  sizeAsc;

  /// Đọc từ tên đã lưu; sai/thiếu → mới sửa trước.
  static DocSort fromName(String? name) => DocSort.values.firstWhere(
    (e) => e.name == name,
    orElse: () => DocSort.dateDesc,
  );
}

/// Lọc theo tab ([category] null = tất cả) và theo từ khoá trong tên (không phân biệt hoa thường).
List<DocItem> filterDocuments(
  Iterable<DocItem> items, {
  DocCategory? category,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final d in items)
      if ((category == null || d.category == category) &&
          (q.isEmpty || d.name.toLowerCase().contains(q)))
        d,
  ];
}

/// Trả danh sách mới đã sắp xếp; bằng nhau thì xếp theo tên để thứ tự ổn định.
List<DocItem> sortDocuments(Iterable<DocItem> items, DocSort sort) {
  int byName(DocItem a, DocItem b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  int Function(DocItem, DocItem) cmp = switch (sort) {
    DocSort.nameAsc => byName,
    DocSort.nameDesc => (a, b) => byName(b, a),
    DocSort.dateDesc => (a, b) => b.modified.compareTo(a.modified),
    DocSort.dateAsc => (a, b) => a.modified.compareTo(b.modified),
    DocSort.sizeDesc => (a, b) => b.size.compareTo(a.size),
    DocSort.sizeAsc => (a, b) => a.size.compareTo(b.size),
  };
  final primary = cmp;
  return items.toList()..sort((a, b) {
    final c = primary(a, b);
    return c != 0 ? c : byName(a, b);
  });
}

/// Kiểm tên mới khi đổi tên. `null` = hợp lệ; ngược lại trả mã lỗi.
enum RenameProblem { empty, exists }

/// [newBaseName] là phần tên không đuôi người dùng gõ; [exists] kiểm file đích.
RenameProblem? validateRename({
  required String oldPath,
  required String newBaseName,
  required bool Function(String path) exists,
}) {
  final trimmed = newBaseName.trim();
  if (trimmed.isEmpty) return RenameProblem.empty;
  final target = renameTarget(oldPath, trimmed);
  if (p.equals(target, oldPath)) return null; // không đổi gì
  if (exists(target)) return RenameProblem.exists;
  return null;
}

/// Đường dẫn đích khi đổi tên: cùng thư mục, giữ nguyên đuôi, tên đã làm sạch ký tự cấm.
String renameTarget(String oldPath, String newBaseName) {
  final ext = p.extension(oldPath);
  return p.join(p.dirname(oldPath), '${sanitizeFileName(newBaseName)}$ext');
}

/// Dò nhanh dấu `/Encrypt` trong file PDF (không phân tích cấu trúc).
/// Không thấy ⇒ chắc chắn chưa khoá; thấy ⇒ cần engine xác nhận.
Future<bool> pdfHasEncryptMarker(String path) async {
  const marker = [0x2F, 0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74]; // /Encrypt
  RandomAccessFile? raf;
  try {
    raf = await File(path).open();
    const chunk = 256 * 1024;
    var carry = <int>[];
    while (true) {
      final data = await raf.read(chunk);
      if (data.isEmpty) return false;
      final buf = carry.isEmpty ? data : [...carry, ...data];
      if (_indexOf(buf, marker) >= 0) return true;
      carry = buf.length >= marker.length - 1
          ? buf.sublist(buf.length - (marker.length - 1))
          : buf;
    }
  } on FileSystemException {
    return false;
  } finally {
    await raf?.close();
  }
}

int _indexOf(List<int> data, List<int> pattern) {
  final last = data.length - pattern.length;
  for (var i = 0; i <= last; i++) {
    if (data[i] != pattern[0]) continue;
    var j = 1;
    while (j < pattern.length && data[i + j] == pattern[j]) {
      j++;
    }
    if (j == pattern.length) return i;
  }
  return -1;
}
