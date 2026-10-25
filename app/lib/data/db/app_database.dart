import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daos/bookmarks_dao.dart';
import 'daos/documents_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/recents_dao.dart';
import 'tables.dart';

export 'daos/bookmarks_dao.dart';
export 'daos/documents_dao.dart';
export 'daos/favorites_dao.dart';
export 'daos/recents_dao.dart';
export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Documents, Favorites, Recents, Bookmarks],
  daos: [DocumentsDao, FavoritesDao, RecentsDao, BookmarksDao],
)
class AppDatabase extends _$AppDatabase {
  /// Mặc định: file `pdf_office.sqlite` trong thư mục app. Test: truyền executor riêng.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'pdf_office'));

  @override
  int get schemaVersion => 1;

  /// Đổi tên/di chuyển file: cập nhật path trong mọi bảng (một transaction).
  Future<void> renamePath(
    String oldPath,
    String newPath, {
    String? newName,
    String? newFolder,
  }) {
    return transaction(() async {
      await (update(documents)..where((t) => t.path.equals(oldPath))).write(
        DocumentsCompanion(
          path: Value(newPath),
          name: newName == null ? const Value.absent() : Value(newName),
          folder: newFolder == null ? const Value.absent() : Value(newFolder),
        ),
      );
      await (update(favorites)..where((t) => t.path.equals(oldPath))).write(
        FavoritesCompanion(path: Value(newPath)),
      );
      await (update(recents)..where((t) => t.path.equals(oldPath))).write(
        RecentsCompanion(path: Value(newPath)),
      );
      await (update(bookmarks)..where((t) => t.path.equals(oldPath))).write(
        BookmarksCompanion(path: Value(newPath)),
      );
    });
  }

  /// File bị xoá: bỏ khỏi mọi bảng.
  Future<void> forgetPath(String path) {
    return transaction(() async {
      await (delete(documents)..where((t) => t.path.equals(path))).go();
      await (delete(favorites)..where((t) => t.path.equals(path))).go();
      await (delete(recents)..where((t) => t.path.equals(path))).go();
      await (delete(bookmarks)..where((t) => t.path.equals(path))).go();
    });
  }
}

/// DB dùng chung toàn app. Test: override bằng `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
