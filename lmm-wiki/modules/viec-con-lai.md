---
title: Việc còn lại — làm tiếp ngày 28/10/2026
type: module
updated: 2026-10-27
sources:
  - lmm-wiki/modules/tinh-nang-t1-t10.md
  - lmm-wiki/concepts/phat-hanh-apk.md
---

# Việc còn lại (chốt cuối ngày 27/10/2026)

Trạng thái lúc chốt: commit `04a7f96` đã **push + merge vào `master`** (`master` = `feat/pdf-office`). Gần 710 test pass, analyze sạch.
Máy dev: Windows, Flutter ở `C:\src\flutter\bin`, ADB `C:\Android\Sdk\platform-tools\adb.exe`, máy thử Galaxy A13 (**32-bit armeabi-v7a**).

## 0. Việc của người dùng (cần làm tay, ~2 phút)
- [ ] **Thay file trong GitHub Release** `android-latest`: link tải đang ra bản CŨ (113.497.671 byte), bản mới ở
  `dist/PDFOffice.apk` (~110MB, có sửa lỗi + gói OCR zh/ja/ko). Releases → Edit (biểu tượng bút) → xoá file cũ →
  kéo file mới → Update release. Sau đó kiểm `curl -sIL <link>` thấy `Content-Length: 115347192`. Chi tiết: [[phat-hanh-apk]].
- [ ] (Tuỳ chọn) đăng nhập `gh` để lần sau tạo Release bằng lệnh: `& "C:\Program Files\GitHub CLI\gh.exe" auth login --web`
  (phải **giữ nguyên cửa sổ terminal** cho tới khi in `Logged in as`; trang `login/device/success` chưa đủ chứng minh).

## 1. Tốc độ mở app — ĐÃ ĐO (28/10), không còn việc phải tối ưu
Đo bằng log trong chính app (`startupTrace` ở `app/lib/main.dart`, in khi build `--dart-define=STARTUP_TRACE=true`, đọc `adb logcat | grep STARTUP`):
`main()` chạy ~0,13–0,5s sau lệnh mở app; nạp ngày giờ 2ms; đọc `SharedPreferences` 9ms; **khung hình Flutter đầu tiên sau 0,1–0,35s** nữa;
OS báo `Displayed +0,75–1,2s`; chụp màn hình lúc 1,5s đã thấy đủ danh sách file. **Tổng ≈ 1 giây** trên Galaxy A13 (32-bit) bản release.
- Con số "4,5–5,8s" ghi trước đó là **sai do cách đo** (mỗi lần `uiautomator dump` + `pull` tự mất 1,5–3s). **Đừng đo thời gian mở app bằng `uiautomator`**;
  dùng `startupTrace`/logcat `Displayed`. Bản debug mới là >10s.
- Đã làm trước đó (vẫn hợp lý): chỉ nạp ngày giờ 6 locale, Trang chủ chỉ `stat` 5 file, mã hoá PDF ở isolate. Các "ứng viên nghi ngờ" (hoãn quét,
  dựng tab lười…) **không cần** vì Dart khởi động chỉ vài ms.
- Còn lại (tuỳ chọn): `favoriteItemsProvider`/`recentItemsProvider` còn `statSync` cả trăm hàng ở màn Gần đây/Yêu thích; `DocumentList` watch cả `scanControllerProvider`.

## 2. Lỗi đã biết, CHƯA sửa (do 5 agent đọc code, chưa tái hiện trên máy thật)
Ưu tiên theo mức gây hại thật cho người dùng:
1. **Máy quét bỏ trang ảnh hỏng im lặng** — `scan_exporter.dart` ~136-163 + `searchable_pdf.dart:92`: `ScanExportResult` không có số trang bỏ qua →
   báo "đã xuất" nhưng PDF thiếu trang; nếu bật "tìm kiếm được" còn mất cả lớp chữ (số trang ≠ số kết quả OCR). Sửa: thêm `skippedCount` + cảnh báo.
2. **Gộp nhiều PDF lớn** — `pdf_ops.dart` `mergeJob` mở tất cả `PdfDocument` cùng lúc → 10×30MB dễ OOM máy 32-bit. Sửa: mở tuần tự rồi `dispose`.
3. **Việc nặng trên UI isolate:** TXT lớn (`txt_viewer_page.dart` `splitLines`, `findHits` mỗi phím, dòng 20MB); ký PDF (`syncfusion_pdf_sign_engine.dart` parse
   lại cả file mỗi lần đổi trang, `_pages` giữ PNG mọi trang); `pdfx_render_engine.dart` giải mã PDF có mật khẩu; PDF ảnh→PDF `doc.save()`.
4. **PDF→ảnh trần 16MP** (`kMaxRenderPixels`) → bitmap 64MB có thể OOM 32-bit: hạ ~8MP.
5. **Lối tắt PDF nhận path tuỳ ý** — `ShortcutChannel.kt:85-88` + `AndroidManifest` `MainActivity exported=true`; Dart chỉ kiểm đuôi `.pdf` + tồn tại. Thấp: không có đường lấy dữ liệu ra ngoài.
6. Khác: `writeAtomically` xoá đích trước khi `rename` (không atomic); tên file tách không giới hạn độ dài (ENAMETOOLONG với tên tiếng Việt ~240 byte);
   XLSX→PDF `mergeCovering` O(ô×vùng gộp); PPTX/DOCX một phần XML hỏng làm hỏng cả file (nên bắt theo slide/phần); `_fieldStack` DOCX không reset giữa đoạn;
   watermark/gộp/tách **mất mật khẩu** file gốc không cảnh báo; chọn font watermark một font cho cả chuỗi (Việt+CJK); `pdfLockedProvider` cache vĩnh viễn (biểu tượng khoá sai sau khi khoá/mở khoá);
   ảnh quét `scan_pages` đã có dọn theo tuổi (12h) nhưng chưa dọn ngay khi bấm Huỷ; `ImagePicker` camera không `retrieveLostData`.
- **Giới hạn đã biết khác:** "Thêm tiện ích" (widget màn hình chính) của app mẫu chưa làm; `composeVietnamese` còn nhân đôi (T4 `vi_nfc.dart`, T6 `vietnamese_nfc.dart`) → gom vào `core/utils`;
  OCR tiếng Việt dấu chồng chưa đo trên máy thật; các cảnh báo Kotlin Gradle Plugin của `pdfx`/`photo_manager` sẽ làm build hỏng ở bản Flutter tương lai.

## 3. Lưu ý khi làm tiếp
- Chạy lệnh Flutter **tuần tự** (xem [[kiem-thu-flutter]]); agent chỉ nên đọc. Test đĩa thật `settings_screens_test` đã sửa chờ có điều kiện (tối đa 5s).
- Đổi code → `dart run tool/merge_arb.dart && flutter gen-l10n` nếu đụng `.arb`; mọi thay đổi giao diện phải thử bằng **release** trên A13.
- Build APK để chia sẻ: `flutter build apk --release --target-platform android-arm,android-arm64` (bắt buộc kèm 32-bit).
- Lượt `flutter test` toàn bộ chạy lúc chốt chưa báo kết quả (đang chạy ở 03:31/~284 test, chưa lỗi); chạy lại để xác nhận.

Liên quan: [[tinh-nang-t1-t10]], [[phat-hanh-apk]], [[documents]], [[kiem-thu-flutter]], [[preferences]].

## 4. Cập nhật 28/10 (phiên song song — chat khác cùng sửa repo)
- **Đã sửa:** máy quét báo số trang bị bỏ (`ScanExportResult.skippedCount`, thông báo dùng chuỗi `img2pdf_skippedImages`; kết quả OCR của trang bị bỏ cũng bị loại để lớp chữ không lệch số trang);
  tên file xuất giới hạn 150 byte UTF-8 (`uniqueOutputPath`); `writeAtomically` đổi tên đè trực tiếp (fallback xoá+đổi tên cho Windows).
- **Cố ý KHÔNG sửa:** *gộp PDF mở lần lượt* — sai: `createTemplate()` tham chiếu tài liệu nguồn nên **mọi file nguồn phải còn mở tới lúc `save()`**, đóng sớm sẽ hỏng PDF gộp
  (chỉ giảm RAM được bằng cách giới hạn tổng dung lượng/cảnh báo người dùng). *Lối tắt PDF nhận path tuỳ ý* — chặn thư mục `/data/` sẽ làm hỏng lối tắt PDF mở từ chia sẻ (file nằm trong cache app); mức nguy cơ thấp.
- **Chat khác đang làm song song** (đừng sửa trùng): tìm kiếm (`app_search_field.dart`), khoá/mở khoá PDF (`pdf_pick_screen.dart`, `lock_screen`/`unlock_screen`), trình xem TXT,
  `home_screen` (giảm dựng lại AppBar), `pdfLockedProvider.autoDispose`. Khi hai chat cùng chạy: chỉ `git add` đúng file của mình, `git fetch` trước khi push, đừng chạy `flutter test` cùng lúc (tranh khoá).
