---
title: Module documents — Trang chủ Tài liệu (T1)
type: module
updated: 2026-10-27
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

## Fix đã áp dụng (27/10/2026, 693 test pass)

### 1. Permission fallback Android ≤10 (`documents_providers.dart`)
`manageExternalStorage` trả `RESTRICTED` trên Android < API 30 (không tồn tại trước Android 11).
Sửa thành hai bước: thử `manageExternalStorage` trước; nếu không được thì fallback `Permission.storage`:
```dart
if (await Permission.manageExternalStorage.request().isGranted) return true;
return (await Permission.storage.request()).isGranted;
```

### 2. skippedDirectories check (`documents_providers.dart`)
`ScanResult` có field `skippedDirectories > 0` nghĩa là có thư mục bị từ chối đọc → set `needsPermission`:
```dart
if (result.files.isEmpty && result.skippedDirectories > 0) {
  state = state.copyWith(phase: ScanPhase.needsPermission);
  return;
}
```

### 3. Flaky tearDown Windows (`settings_screens_test.dart`)
`deleteSync` trên Windows khi file handle chưa release → bọc `try/catch FileSystemException`.

### 4. `sharedPreferencesProvider` override (`scanner_screen_test.dart`)
Test pump thiếu override → thêm `sharedPreferencesProvider.overrideWithValue(prefs)`.

### 5. Import ordering (`scanner_screen.dart`)
`data/settings/settings_providers.dart` nằm giữa hai import `core/` → chuyển sau tất cả `core/`.

### 6. Stale test name (`ml_kit_ocr_engine_test.dart`)
Tên test còn tham chiếu tiếng Thái (đã bỏ) → đổi thành tên mô tả đúng hành vi thật.

## Chưa kiểm
- Quyền trên Android thật: Android 11/12 với chỉ `READ_EXTERNAL_STORAGE` được cấp sẽ **quét một phần** (chỉ media) mà vẫn báo
  "có quyền" — cần biết SDK (gợi ý cho MÓNG: `device_info_plus`). Máy thử Galaxy A13 (Android 12+) đi đường `manageExternalStorage`.
- `PermissionHandlerStorage.request()` gọi `manageExternalStorage.request()` (mở Cài đặt) — chưa xem hành vi khi quay lại app.
- Hiệu năng quét toàn bộ bộ nhớ trong, đổi tên/xoá file thật, chia sẻ, mở file Office cũ bằng app ngoài.

Liên quan: [[co-so-du-lieu]], [[0003-kien-truc-riverpod]], [[tinh-nang-t1-t10]], [[kiem-thu-flutter]].

## Khung 5 nút dưới (27/10/2026) — thay Hamburger + FAB
- `MainShell` (`main_shell.dart`, route `Routes.home`): `NavigationBar` 5 mục **Trang chủ · Tập tin · ⇄ · Công cụ · Cài đặt**,
  `IndexedStack` 4 trang (`HomeTab`, `HomeScreen`, `ToolsPage`, `SettingsScreen`). Nút ⇄ giữa **không phải trang**: bấm là
  `launchTool(imageToPdf)` (vào thẳng chọn ảnh → PDF). `PopScope`: Back ở tab khác về Trang chủ.
- `HomeTab`: ô tìm kiếm, 3 ô tính năng (Ảnh sang PDF đỏ lớn, Quét tài liệu xanh, PDF sang ảnh cam), mục **Yêu thích** và
  **Gần đây** (mỗi mục tối đa 5, "Xem tất cả" → `Routes.favorites`/`recents`). Dùng `homeFavoriteItemsProvider` /
  `homeRecentItemsProvider` (chỉ `stat` tối đa 5 file thay vì cả trăm).
- `HomeScreen` (tab Tập tin) bỏ FAB, thêm nút ⭐ và 🕘 trên AppBar; vẫn còn drawer.
- `tools_sheet.dart` tách `_toolSections` dùng chung cho bottom sheet và `ToolsPage`.
- Test: `main_shell_test.dart`; test có `HomeTab` phải override **cả** `homeRecentItemsProvider`/`homeFavoriteItemsProvider`
  (stream drift để timer treo → "A Timer is still pending").
- Sửa: `ScanController._scan` có cờ `_scanning` (refresh/resume/request trước đó có thể quét trùng); `pdfHasEncryptMarker`
  chỉ đọc 128KB đầu + 128KB cuối; `resolveOutputDirectory` thử ghi file thật; `main.dart` chỉ nạp ngày giờ 6 locale.

Liên quan: [[ui-app-goc]], [[phat-hanh-apk]].
