---
title: Cơ sở dữ liệu drift (documents, favorites, recents, bookmarks)
type: entity
updated: 2026-10-26
sources:
  - app/lib/data/db/app_database.dart
  - app/lib/data/db/daos/
  - docs/superpowers/plans/2026-10-25-parallel-build-contract.md
---

# Cơ sở dữ liệu drift

`AppDatabase` (SQLite qua `drift` + `drift_flutter`), provider `appDatabaseProvider`. File `pdf_office.sqlite` trong thư mục app.
Import một file: `app/lib/data/db/app_database.dart`. File sinh `app_database.g.dart` **được commit**.
Test: `AppDatabase(NativeDatabase.memory())` (import `package:drift/native.dart`).

| Bảng | Cột | Ghi chú |
|---|---|---|
| `documents` | `path` (PK), `name`, `ext`, `size`, `modifiedMs`, `folder`, `scannedAtMs` | **Bộ đệm kết quả quét file** (T1). `ext` chữ thường không dấu chấm; `folder` = tên thư mục cha (hiện trong dòng thông tin) |
| `favorites` | `path` (PK), `addedAtMs` | ⭐ yêu thích |
| `recents` | `path` (PK), `openedAtMs` | file mở gần đây (`openDocument` tự ghi) |
| `bookmarks` | `id` (PK tự tăng), `path`, `page`, `createdAtMs` | `page` **0-based**; `wholeDocumentPage = -1` là đánh dấu cả tài liệu |

**DAO** (`db.documentsDao`…): `DocumentsDao` (`watchAll/getAll({exts})`, `getByPath`, `upsert`, `upsertAll`, `deleteByPath`,
`deleteNotSeenSince(scanStartedMs)`, `clear`), `FavoritesDao` (`watchAll`, `watchPaths`, `isFavorite`, `add`, `remove`, `toggle`),
`RecentsDao` (`watchRecent/getRecent({limit})`, `touch`, `remove`, `clear`), `BookmarksDao` (`watchForPath`, `add` không trùng,
`removeById`, `removePage`, `removeForPath`). Đổi tên / xoá file: `AppDatabase.renamePath(old, new, {newName, newFolder})`,
`forgetPath(path)` cập nhật **mọi bảng**.

**Cài đặt người dùng** không nằm trong DB mà ở `shared_preferences` (`settingsProvider`: locale, themeMode, defaultPageSize, outputDir).

Liên quan: [[0003-kien-truc-riverpod]], [[tinh-nang-t1-t10]].
