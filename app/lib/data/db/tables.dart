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

/// `page` 0-based; `-1` = đánh dấu cả tài liệu.
@DataClassName('Bookmark')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  IntColumn get page => integer()();
  IntColumn get createdAtMs => integer()();
}
