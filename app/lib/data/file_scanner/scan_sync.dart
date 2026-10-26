import '../db/app_database.dart';
import 'file_scanner.dart';

/// Đồng bộ kết quả quét vào bảng `documents`: `upsertAll` rồi `deleteNotSeenSince`.
///
/// Chỉ xoá file "không còn thấy" khi mọi thư mục gốc đều đọc được — nếu thiếu quyền,
/// kết quả rỗng không được phép xoá sạch bộ đệm.
/// [scanStartedMs] = thời điểm bắt đầu lượt quét (dùng làm `scannedAtMs`).
Future<void> syncScanToDatabase(
  AppDatabase db,
  ScanResult result,
  int scanStartedMs,
) async {
  final dao = db.documentsDao;
  await dao.upsertAll([
    for (final f in result.files)
      DocumentsCompanion.insert(
        path: f.path,
        name: f.name,
        ext: f.ext,
        size: f.size,
        modifiedMs: f.modifiedMs,
        folder: f.folder,
        scannedAtMs: scanStartedMs,
      ),
  ]);
  if (result.allRootsReadable) {
    await dao.deleteNotSeenSince(scanStartedMs);
  }
}
