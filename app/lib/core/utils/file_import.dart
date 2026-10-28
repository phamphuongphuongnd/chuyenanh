import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/app_platform.dart';

/// Tên thư mục con của Documents chứa file người dùng chọn từ ngoài vào (iOS).
const String importedFolderName = 'Imported';

/// iOS: `file_picker` trả bản sao TẠM (bị hệ thống dọn). Chép vào `Documents/Imported` để file
/// còn mãi, hiện trong app Tệp và nằm trong vùng app quét. Android/khác: trả nguyên [path].
Future<String> importIntoAppDocuments(
  String path, {
  AppPlatform? platform,
  Directory? documentsDir,
}) async {
  if ((platform ?? detectPlatform()) != AppPlatform.ios) return path;
  final docs = documentsDir ?? await getApplicationDocumentsDirectory();
  if (p.isWithin(docs.path, path)) return path;
  final source = File(path);
  if (!await source.exists()) return path;

  final dir = Directory(p.join(docs.path, importedFolderName));
  await dir.create(recursive: true);
  final base = p.basenameWithoutExtension(path);
  final ext = p.extension(path);
  final length = await source.length();
  for (var i = 0; ; i++) {
    final name = i == 0 ? '$base$ext' : '$base ($i)$ext';
    final target = File(p.join(dir.path, name));
    if (!await target.exists()) {
      await source.copy(target.path);
      return target.path;
    }
    // Cùng tên và cùng dung lượng: coi như đã nhập trước đó, dùng lại.
    if (await target.length() == length) return target.path;
  }
}
