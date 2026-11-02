import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/app_platform.dart';

/// Tên thư mục con của Documents (của app) chứa file người dùng chọn từ ngoài vào.
const String importedFolderName = 'Imported';

/// iOS/Android: `file_picker` trả bản sao TẠM (bị hệ thống / "Xoá bộ nhớ đệm" dọn). Chép vào
/// `<app documents>/Imported` để file còn mãi và nằm trong vùng app quét (iOS: hiện cả trong app
/// Tệp). Nền tảng khác: trả nguyên [path].
Future<String> importIntoAppDocuments(
  String path, {
  AppPlatform? platform,
  Directory? documentsDir,
}) async {
  final current = platform ?? detectPlatform();
  if (current != AppPlatform.ios && current != AppPlatform.android) return path;
  final docs = documentsDir ?? await getApplicationDocumentsDirectory();
  if (p.isWithin(docs.path, path)) return path;
  final source = File(path);
  if (!await source.exists()) return path;

  final dir = Directory(p.join(docs.path, importedFolderName));
  await dir.create(recursive: true);
  final base = p.basenameWithoutExtension(path);
  final ext = p.extension(path);
  for (var i = 0; ; i++) {
    final name = i == 0 ? '$base$ext' : '$base ($i)$ext';
    final target = File(p.join(dir.path, name));
    if (!await target.exists()) {
      await source.copy(target.path);
      return target.path;
    }
    // Cùng tên và nội dung giống hệt: đã nhập trước đó, dùng lại.
    if (await isSameFileContent(source, target)) return target.path;
  }
}

/// `true` khi [a] và [b] giống hệt từng byte: so dung lượng trước, rồi so nội dung theo khối
/// (không đọc cả file to vào bộ nhớ).
Future<bool> isSameFileContent(File a, File b) async {
  if (await a.length() != await b.length()) return false;
  const chunkSize = 64 * 1024;
  final ra = await a.open();
  try {
    final rb = await b.open();
    try {
      while (true) {
        final ca = await ra.read(chunkSize);
        final cb = await rb.read(chunkSize);
        if (ca.length != cb.length) return false;
        if (ca.isEmpty) return true;
        for (var i = 0; i < ca.length; i++) {
          if (ca[i] != cb[i]) return false;
        }
      }
    } finally {
      await rb.close();
    }
  } finally {
    await ra.close();
  }
}
