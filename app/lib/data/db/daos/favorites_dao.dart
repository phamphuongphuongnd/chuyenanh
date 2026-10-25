import 'package:drift/drift.dart';

import '../app_database.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [Favorites])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.attachedDatabase);

  /// Mới thêm trước.
  Stream<List<Favorite>> watchAll() => (select(
    favorites,
  )..orderBy([(t) => OrderingTerm.desc(t.addedAtMs)])).watch();

  Future<List<Favorite>> getAll() => (select(
    favorites,
  )..orderBy([(t) => OrderingTerm.desc(t.addedAtMs)])).get();

  /// Tập path yêu thích (để tô ⭐ trong danh sách).
  Stream<Set<String>> watchPaths() =>
      select(favorites).watch().map((rows) => {for (final r in rows) r.path});

  Stream<bool> watchIsFavorite(String path) =>
      (select(favorites)..where((t) => t.path.equals(path)))
          .watchSingleOrNull()
          .map((r) => r != null);

  Future<bool> isFavorite(String path) async =>
      await (select(
        favorites,
      )..where((t) => t.path.equals(path))).getSingleOrNull() !=
      null;

  Future<void> add(String path, {DateTime? at}) =>
      into(favorites).insertOnConflictUpdate(
        FavoritesCompanion.insert(
          path: path,
          addedAtMs: (at ?? DateTime.now()).millisecondsSinceEpoch,
        ),
      );

  Future<int> remove(String path) =>
      (delete(favorites)..where((t) => t.path.equals(path))).go();

  /// Trả về trạng thái mới (true = đã thêm).
  Future<bool> toggle(String path) async {
    if (await isFavorite(path)) {
      await remove(path);
      return false;
    }
    await add(path);
    return true;
  }
}
