---
title: Module documents — Trang chủ Tài liệu (T1)
type: module
updated: 2026-10-26
sources:
  - app/lib/features/documents/
  - app/lib/data/file_scanner/
  - app/test/features/documents/
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# Module `documents` — Trang chủ Tài liệu (T1)

Nhánh `feat/t1-documents`. **Đã kiểm trên máy dev:** `flutter analyze` sạch, `flutter test` toàn bộ pass (102 test, 40 test
là của T1). **Chưa kiểm trên điện thoại thật** (không có thiết bị / Android SDK ở máy này) — xem "Chưa kiểm" cuối trang.

## Màn hình & route
| Route | Màn | File |
|---|---|---|
| `Routes.home` | `HomeScreen` — AppBar đổi màu theo tab (`AppColors.forCategory`), 6 tab All/PDF/DOC/XLS/PPT/TXT, ⇅ sắp xếp, 🔍, ☰ drawer, ＋ bottom sheet công cụ | `home_screen.dart` |
| `Routes.search` | `SearchScreen` — lọc theo tên trên mọi tài liệu | `list_screens.dart` |
| `Routes.recents` / `favorites` | `RecentsScreen` / `FavoritesScreen` (`SimpleDocListScreen`) | `list_screens.dart` |

Widget con (`widgets/`): `DocumentList` (đủ trạng thái: skeleton, "đã tìm N file", trống, lỗi, kéo để quét lại, lưới loại file
ở đầu tab All), `DocumentTile` (⭐, ⋮ Mở/Đổi tên/Chia sẻ/Yêu thích/Thông tin/Xoá, 🔒 cho PDF có mật khẩu), `PermissionGate`/
`PermissionBanner`/`PickFileButton`, `tools_sheet.dart` (từ `allTools`), `home_drawer.dart`, `sort_menu.dart`.
Thao tác file ở `document_actions.dart`: `openDocumentWithFeedback`, `renameDocument`, `deleteDocument`, `shareDocument`,
`showDocumentInfo`, `launchTool`, `pickAndOpenDocument`.

## Trạng thái & provider (`documents_providers.dart`, Riverpod 3 viết tay)
- `scanControllerProvider` (`ScanController`, phase `idle/scanning/done/needsPermission/failed`): tự quét một lần khi được đọc
  lần đầu; `refresh({force})` (resume app dùng `force:false` → bỏ qua nếu vừa quét < 30 s); `requestPermissionAndScan()`.
- `StoragePermissionService` (interface để test thay giả): `PermissionHandlerStorage` hỏi `manageExternalStorage` trước rồi
  `storage`. `scanRootsProvider` = `['/storage/emulated/0']` chỉ trên Android (máy khác → không quét).
- `documentsProvider` (stream từ bảng `documents`), `categoryDocumentsProvider(category)` (lọc + sắp xếp bằng
  `documents_logic.dart`), `docSortProvider` (lưu `documents.sort` trong shared_preferences), `favoritePathsProvider`,
  `favoriteItemsProvider`, `recentItemsProvider` (file không còn trên đĩa bị bỏ qua), `pdfLockedProvider(path)` (dò nhanh
  `/Encrypt` rồi mới nhờ `pdfSecurityProvider`, cache theo path).

## Quyết định thiết kế đáng nhớ
- **Thư mục gốc đọc được 0/1 ⇒ coi như chưa có quyền** (`unreadableRoots.length == roots.length` → `needsPermission`) và
  **không** đụng bảng `documents`: kết quả rỗng do thiếu quyền không được xoá sạch bộ đệm (`syncScanToDatabase` chỉ
  `deleteNotSeenSince` khi `allRootsReadable`).
- Mục "Giao diện" và "Thư mục lưu" của drawer đều trỏ `Routes.settings` vì `routes.dart` chỉ có `settings/language/about`
  (T10 làm các màn đó thành màn con, không có route riêng).
- Công cụ cần PDF bắt buộc (`ToolInputType.pdfRequired`) → `launchTool` chọn PDF bằng `FilePicker.pickFile` rồi mới
  `push(route, extra: path)`; các công cụ còn lại tự chọn file ở màn của chúng (push không `extra`).
- API `file_picker` 13 là static: `FilePicker.pickFile(...)` trả `PlatformFile?` (không còn `FilePicker.platform`).
  Chia sẻ: `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.

## Chuỗi
Prefix `docs_` (40 key, đủ vi/en/zh/ja/ko/id) ở `app/lib/features/documents/l10n/`. Tên tab PDF/DOC/XLS/PPT/TXT không dịch;
chỉ `docs_tabAll` dịch.

## Chưa kiểm
- Quyền trên Android thật: Android 11/12 với chỉ `READ_EXTERNAL_STORAGE` được cấp sẽ **quét một phần** (chỉ media) mà vẫn báo
  "có quyền" — cần biết SDK (gợi ý cho MÓNG: `device_info_plus`). Máy thử Galaxy A13 (Android 12+) đi đường `manageExternalStorage`.
- `PermissionHandlerStorage.request()` gọi `manageExternalStorage.request()` (mở Cài đặt) — chưa xem hành vi khi quay lại app.
- Hiệu năng quét toàn bộ bộ nhớ trong, đổi tên/xoá file thật, chia sẻ, mở file Office cũ bằng app ngoài.

Liên quan: [[co-so-du-lieu]], [[0003-kien-truc-riverpod]], [[tinh-nang-t1-t10]], [[kiem-thu-flutter]].
