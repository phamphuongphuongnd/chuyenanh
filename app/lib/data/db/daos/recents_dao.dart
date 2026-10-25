import 'package:drift/drift.dart';

import '../app_database.dart';

part 'recents_dao.g.dart';

@DriftAccessor(tables: [Recents])
class RecentsDao extends DatabaseAccessor<AppDatabase> with _$RecentsDaoMixin {
  RecentsDao(super.attachedDatabase);

  /// Mới mở trước, tối đa [limit] mục.
  Stream<List<Recent>> watchRecent({int limit = 100}) =>
      (select(recents)
            ..orderBy([(t) => OrderingTerm.desc(t.openedAtMs)])
            ..limit(limit))
          .watch();

  Future<List<Recent>> getRecent({int limit = 100}) =>
      (select(recents)
            ..orderBy([(t) => OrderingTerm.desc(t.openedAtMs)])
            ..limit(limit))
          .get();

  /// Ghi nhận vừa mở [path] (thêm mới hoặc cập nhật giờ mở).
  Future<void> touch(String path, {DateTime? at}) =>
      into(recents).insertOnConflictUpdate(
        RecentsCompanion.insert(
          path: path,
          openedAtMs: (at ?? DateTime.now()).millisecondsSinceEpoch,
        ),
      );

  Future<int> remove(String path) =>
      (delete(recents)..where((t) => t.path.equals(path))).go();

  Future<int> clear() => delete(recents).go();
}
