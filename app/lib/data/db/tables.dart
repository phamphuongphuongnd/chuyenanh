import 'package:drift/drift.dart';

/// Bộ đệm kết quả quét file. Data class: `Document`.
@DataClassName('Document')
class Documents extends Table {
  TextColumn get path => text()();
  TextColumn get name => text()();

  /// Đuôi chữ thường, không dấu chấm (`pdf`, `docx`…).
  TextColumn get ext => text()();
  IntColumn get size => integer()();
  IntColumn get modifiedMs => integer()();

  /// Tên thư mục cha (hiện trong dòng thông tin file).
  TextColumn get folder => text()();

  /// Lần quét gần nhất thấy file này (dùng để xoá file đã mất).
  IntColumn get scannedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DataClassName('Favorite')
class Favorites extends Table {
  TextColumn get path => text()();
  IntColumn get addedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DataClassName('Recent')
class Recents extends Table {
  TextColumn get path => text()();
  IntColumn get openedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Chữ đã trích của một tài liệu (để tìm theo nội dung). Data class: `DocumentText`.
///
/// Dòng có `content` rỗng = đã thử trích nhưng không có chữ (PDF ảnh, có mật khẩu, lỗi đọc):
/// vẫn giữ để không trích lại cho tới khi file đổi (`sourceModifiedMs` / `sourceSize`).
@DataClassName('DocumentText')
class DocumentTexts extends Table {
  TextColumn get path => text()();

  /// Chữ gốc đã gộp NFC + gọn khoảng trắng, tối đa ~200k ký tự.
  TextColumn get content => text()();

  /// [content] chữ thường, bỏ dấu (`đ→d`), khoảng trắng → dấu cách; dài đúng bằng [content]
  /// (từng ký tự đổi 1:1) nên vị trí khớp trong cột này cũng là vị trí trong [content].
  TextColumn get normalized => text()();

  /// `modifiedMs` / `size` của file lúc trích (khác bảng `documents` ⇒ trích lại).
  IntColumn get sourceModifiedMs => integer()();
  IntColumn get sourceSize => integer()();
  IntColumn get extractedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// `page` 0-based; `-1` = đánh dấu cả tài liệu.
@DataClassName('Bookmark')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  IntColumn get page => integer()();
  IntColumn get createdAtMs => integer()();
}
