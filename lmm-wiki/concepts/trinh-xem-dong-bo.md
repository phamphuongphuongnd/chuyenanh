---
title: Trình xem tài liệu đồng bộ (tìm kiếm + zoom) và chọn PDF trong app
type: concept
updated: 2026-10-28
sources:
  - app/lib/core/widgets/app_search_field.dart
  - app/lib/features/office_viewer/widgets/office_common.dart
  - app/lib/features/reader/widgets/reader_search_bar.dart
  - app/lib/features/office_pptx/slide_view.dart
  - app/lib/features/office_pptx/pptx_search.dart
  - app/lib/features/office_viewer/logic/xlsx_search.dart
  - app/lib/features/pdf_tools/ui/pdf_pick_screen.dart
  - planhistory/2026-10-28-dong-bo-trinh-xem.md
---

# Trình xem đồng bộ: cả 5 định dạng cùng một kiểu

Yêu cầu 28/10: PDF · DOCX · XLSX · PPTX · TXT phải **giống nhau** — thanh tiêu đề có `🔍 Tìm · zoom ➖ · zoom ➕`,
bấm 🔍 thì hiện thanh tìm ngay **dưới** thanh tiêu đề, nền = màu loại file, chữ trắng, có "n/m", ‹ ›, ✕.

## Các mảnh dùng chung
- `AppSearchField` (`core/widgets/`): `TextField` trong suốt, chữ/hint trắng, `filled: false`. **Gotcha:** `inputDecorationTheme` toàn app
  (`app_theme.dart`) đặt `filled: true` nền vàng nhạt `#FFF8E1` → ô nhập nào không tắt `filled` sẽ thành chữ trắng trên nền vàng (khó đọc).
- `OfficeSearchBar(color: AppColors.<loại>)` (`office_common.dart`): thanh tìm cho Word/Excel/PPT/TXT. PDF dùng `ReaderSearchBar`
  (cùng kiểu, nhưng kết quả từ `PdfTextSearchResult` của Syncfusion). Trước đây PDF thay hẳn AppBar bằng thanh tìm nên **che mất nút zoom** → đã bỏ.
- Màu: `AppColors.pdf/doc/xls/ppt/txt`. Icon zoom: `Icons.zoom_out/zoom_in`, tooltip `office_zoomOut/zoomIn` (TXT đổi cỡ chữ nhưng dùng cùng icon).

## Tìm kiếm từng định dạng
| Định dạng | Cách tìm | File |
|---|---|---|
| PDF | `PdfViewerController.searchText`; zoom `controller.zoomLevel` bước 0,25 (1,0–3,0) | `reader/screens/pdf_reader_screen.dart` |
| DOCX/TXT | tìm trong khối chữ, tô nền | `docx_view.dart`, `txt_viewer_page.dart` |
| XLSX | `findXlsxHits` trên chuỗi hiển thị `cell.display`, qua mọi sheet hiện; nhảy tới ô, tô vàng nhạt / cam (ô hiện tại) | `logic/xlsx_search.dart`, `xlsx_view.dart` |
| PPTX | `findPptxHits` trên văn bản khung/bảng/nhóm; nhảy slide; tô vàng bằng `PptxSearchHighlight` (InheritedWidget) + `highlightSpans` trong `ParagraphWidget` (bảng dùng chung) | `pptx_search.dart`, `slide_view.dart` |

Nút zoom PPTX: `_ZoomablePageState.zoomBy` trên `TransformationController`, kẹp 1,0–4,0; về 1,0 thì bỏ khoá vuốt (`_zoomed`).
PPTX chưa tô riêng kết quả hiện tại (tất cả chỗ khớp cùng màu vàng).

## Khoá / Mở khoá PDF chọn trong app
Trước: picker hệ thống (`FilePicker`). Giờ: `PdfPickScreen(mode)` (`pdf_tools/ui/pdf_pick_screen.dart`) liệt kê PDF từ `documentsProvider`,
`unlockedOnly` cho Khoá PDF, `lockedOnly` cho Mở khoá PDF; có ô tìm + nút thư mục dự phòng. Lọc khoá: `pdfHasEncryptMarker` (dò `/Encrypt`)
rồi `pdfSecurityProvider.isEncrypted` xác nhận. `inAppPdfPickerProvider` đi thẳng qua `PdfFilePicker` khi picker bị override (test không cần đổi).
`SinglePdfToolState.pickMode` (mặc định null) bật chế độ này cho `LockScreen`. `pdfLockedProvider` giờ `autoDispose` (hết lỗi biểu tượng khoá sai sau khi khoá/mở khoá).

## Giảm dựng lại (28/10)
`DocumentList` chỉ `select` `(isScanning, needsPermission)`, số file đã tìm do `_LiveScanBar` tự theo dõi; `DocumentTile` `select` theo sao của chính nó;
`HomeScreen` chỉ `setState` khi chỉ số tab đổi; `MainShell` dựng tab lười và đọc `scanControllerProvider` sau khung hình đầu;
`categoryDocumentsProvider` autoDispose, sắp xếp một lần qua `_sortedDocumentsProvider` rồi mỗi tab chỉ lọc; `SearchScreen` debounce 200ms;
Gần đây/Yêu thích kiểm tồn tại bằng `File.exists` bất đồng bộ, dùng dữ liệu bảng `documents` nếu có.
**Chưa đo trước/sau** (cold start `am start -W` ~0,7–1,05s, nhưng không có mốc cũ để so).

## Gotcha khi làm / test phần này
- Test widget có drift stream (`favoritePathsProvider`, `documentsProvider`): override bằng stream cố định (`Stream.value`/`StreamController`), không dùng `AppDatabase(NativeDatabase.memory())` → tránh "A Timer is still pending". Xem [[kiem-thu-flutter]].
- Đóng màn bằng `Navigator.pop` cần `pump(1s)` hai lần mới hết hiệu ứng chuyển trang trước khi `expect(find…, findsNothing)`.
- `dart format <thư mục>` đổi cả file không liên quan → format đúng file mình sửa.
- Đã thử trên A13 (28/10): Word, Excel, PPT, PDF, **TXT** (tìm "hello" ra 1/2, kết quả hiện tại cam + còn lại vàng, zoom đổi cỡ chữ), Khoá/Mở khoá. Bố cục nút PDF/PPT lệch so với Word/Excel/TXT (PDF/PPT: 🔍 ở x≈391, Word/Excel/TXT: 🔍 ở x≈503) → toạ độ chạm khác nhau.

Liên quan: [[documents]], [[kiem-thu-flutter]], [[viec-con-lai]], [[tinh-nang-t1-t10]].
