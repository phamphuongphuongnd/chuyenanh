import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Xoá ảnh quét / ảnh cắt tay còn sót trong thư mục tạm quá [maxAge] (ví dụ người dùng
/// bỏ phiên quét): ảnh giấy tờ không nên nằm lại trong cache. Trả về số file đã xoá.
Future<int> cleanupStaleScanFiles(
  Directory? temp, {
  Duration maxAge = const Duration(hours: 12),
}) async {
  var removed = 0;
  try {
    final base = temp ?? await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(maxAge);
    final candidates = <File>[];
    final pages = Directory(p.join(base.path, 'scan_pages'));
    if (await pages.exists()) {
      await for (final e in pages.list()) {
        if (e is File) candidates.add(e);
      }
    }
    await for (final e in base.list()) {
      if (e is File && p.basename(e.path).startsWith('crop_')) {
        candidates.add(e);
      }
    }
    for (final f in candidates) {
      try {
        if ((await f.lastModified()).isBefore(cutoff)) {
          await f.delete();
          removed++;
        }
      } on FileSystemException {
        // file đang dùng / đã mất: bỏ qua
      }
    }
  } on FileSystemException {
    // thư mục tạm không đọc được: không làm gì
  }
  return removed;
}
