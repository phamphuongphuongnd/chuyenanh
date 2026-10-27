---
title: Trạng thái 10 tính năng T1…T10 (bàn giao)
type: module
updated: 2026-10-27
sources:
  - docs/superpowers/plans/2026-10-26-feature-tasks.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
  - app/lib/features/
---

# Trạng thái 10 tính năng T1…T10 (đã ghép 26/10/2026)

Chi tiết từng việc (sở hữu file, thư viện dùng, việc cần làm, test, ước lượng) ở
`docs/superpowers/plans/2026-10-26-feature-tasks.md` — **mục E là bảng trạng thái bàn giao**. Trang này tóm tắt.

## Tóm tắt (cập nhật 26/10 ~16:00)
- **Cả 10 tính năng đã có code và đã ghép vào `feat/pdf-office`** (merge `77a9828`, push lên origin). Tự kiểm bằng máy: `flutter analyze`
  sạch, **693/693 test pass** (cập nhật 27/10 sau các fix T1/T9), `flutter build apk --debug` thành công. **Chưa việc nào chạy trên điện thoại thật.**
  Build APK debug 27/10 xác nhận compile OK, đang cài lên Samsung Galaxy A13 để test thủ công.
- Nền: [[0003-kien-truc-riverpod]] + [[thu-vien-dart-thuan]] (4 thư viện, đã thử file thật 2/4) + build Android ([[build-android]]) +
  spike chữ ([[xuat-chu-ra-pdf]]). Trang chủ chi tiết: [[documents]]; cách kiểm thử: [[kiem-thu-flutter]].
- Cách làm đã chạy: 2 đợt agent (đợt 1: T2, T3, T4, T5, T10; đợt 2: T6, T7, T8, T9; T1 do Claude làm), mỗi agent 1 worktree, sau đó ghép
  vào nhánh tạm `integrate` rồi merge vào `feat/pdf-office`. 10 nhánh `feat/t1-…` … `feat/t10-…` còn trên origin (chứa lịch sử từng việc,
  **không còn cần** — mọi thứ đã nằm trong `feat/pdf-office`).
- `master` **chưa** gộp (vẫn `fbb7d78`); chỉ gộp khi người dùng quyết định.

| Việc | Trạng thái (đã ghép) | Hạn chế đã biết |
|---|---|---|
| T1 Trang chủ Tài liệu | UI xong: quyền, quét file, tab, danh sách, ⋮, ⭐, Gần đây, Yêu thích | cần thử quyền "tất cả file" trên Android thật |
| T2 Ảnh → PDF | engine + UI chọn/sửa/xuất | chưa thử camera, photo_manager, cropper thật |
| T3 Trình đọc PDF | viewer (tìm, mục lục, tối, in, mật khẩu, bookmark), PDF→ảnh, lối tắt (đã nối `shortcutLaunchProvider` vào `app.dart`) | **Kotlin `MainActivity`/`ShortcutChannel` mới được biên dịch trong build APK, chưa chạy**; viewer thật chỉ test bằng viewer giả |
| T4 Công cụ PDF | 7 màn + engine (gộp, tách, sắp xếp, khoá/mở khoá, watermark, trang trắng) | watermark/tiêu đề cần font Noto (chưa tải, rơi về Helvetica); gộp/tách mất annotation/form/link |
| T5 Chỉnh sửa PDF | annotation, chữ ký, điền form | `SfPdfViewer` chỉ test bằng viewer giả |
| T6 Chuyển đổi | text/TXT/DOCX/XLSX→PDF; PDF→TXT/DOCX/XLSX (không giữ bố cục, UI có cảnh báo) | **cần font Noto** cho chữ Việt có dấu + CJK; PDF quét ảnh đã OCR được (chưa thử máy thật); DOCX→PDF gần đúng (bỏ ảnh không phải PNG/JPEG, chưa header/footer) |
| T7 Xem DOCX/XLSX/TXT | vẽ DOCX, lưới XLSX (ô gộp, freeze, nhiều sheet), TXT (tự nhận mã hoá), mở hyperlink DOCX | chữ Excel chưa tràn sang ô bên cạnh |
| T8 Xem PPTX | vuốt từng slide, zoom, thumbnail, ghi chú, slide ẩn | chỉ số trên/dưới chỉ thu nhỏ; flip group chưa áp; picture fill chưa vẽ ảnh; hyperlink bấm mở được (chưa thử máy thật); chưa thấy chữ thật trong golden (font test) |
| T9 Máy quét + OCR | chụp nhiều trang, tự nhận viền, kéo 4 góc thủ công, danh sách trang, xuất PDF/TXT/DOCX, OCR ML Kit | PDF xuất có lớp chữ tìm kiếm (chưa thử máy thật); **OCR tiếng Việt dấu chồng chưa từng đo**; chưa gọi `cleanCache()` |
| T10 Cài đặt + thương hiệu | Ngôn ngữ, Giao diện, Thư mục lưu, Khổ giấy, Giới thiệu, icon vector | màn con dùng `Navigator.push` (không có route riêng); icon chưa nhìn trên máy |

## Đã sửa thêm sau khi ghép (26/10 ~17:00, 692 test, build APK OK)
- **L1 — hyperlink:** DOCX và PPTX mở link bằng `url_launcher` (thêm gói + `<queries>` Manifest). Chỉ cho http/https/mailto/tel (`core/utils/url_safety.dart`,
  `link_opener.dart`); chạm link hiện SnackBar URL đích. Chưa thử link thật trên máy; hyperlink trong bảng PPTX/shape đặc biệt chưa kiểm.
- **L2 — OCR PDF quét ảnh (T6):** trang PDF không có chữ → render 200 dpi (cạnh dài ≤ 2560px) → ML Kit → `LayoutPage`; có chọn "Ngôn ngữ nhận dạng".
  **Lớp chữ tìm kiếm được (T9):** chữ trong suốt (`setTransparency(0)`, Syncfusion không có render mode 3) bằng font Noto + NFC; công tắc mặc định BẬT.
  Giả định ảnh nằm giữa trang, không lề (nếu đổi khổ/lề của `ImageToPdfOptions` phải sửa `searchable_pdf.dart`). Chưa thử ML Kit/pdfx thật.
- **Chưa làm được bằng code:** đo OCR tiếng Việt dấu chồng — cần máy thật (checklist ở báo cáo L2: chuyển ảnh quét có `ặ ỗ ữ ẫ ậ ề ở`, xem TXT/DOCX giữ dấu không).

## Việc còn lại (theo thứ tự nên làm)
1. ~~Tải font Noto~~ **Xong 26/10**: `bash tool/fetch_fonts.sh` trong `app/` (font không nằm trong git) — xem [[xuat-chu-ra-pdf]]. T4/T6/T9 giờ có font thật; test 693/693 vẫn pass.
2. **Cài lên Samsung Galaxy A13** — đang làm 27/10 (ADB kết nối R58TC12SRZW, build APK debug xong). Đi qua checklist từng tính năng; ghi lỗi → sửa.
   Đặc biệt: quyền "tất cả file", camera, máy quét, lối tắt, OCR tiếng Việt.
3. `composeVietnamese` bị nhân đôi (T4 `pdf_tools/logic/vi_nfc.dart`, T6 `convert/text/vietnamese_nfc.dart`) → gom vào `core/utils`.
4. Tuỳ chọn: `device_info_plus` (biết SDK để xin quyền đúng), `package_info_plus` (T10 đang hằng `kAppVersion`),
5. Gỡ các nhánh `feat/t*` trên origin khi không cần lịch sử nữa; quyết định có gộp `feat/pdf-office` → `master` không.

## Gotcha khi nhận việc
- Mọi thay đổi phải giữ `flutter analyze` sạch và `flutter test` xanh (660 test). Test dùng ổ đĩa thật có thể chập chờn khi máy tải nặng
  (đã thấy `settings_screens_test`: pass khi chạy riêng) — chạy lại riêng trước khi kết luận lỗi.
- Đổi gói (`pubspec.yaml`), Manifest, `core/**`, `data/db/**`, interface `*_engine.dart` là việc của người giữ nhánh
  `feat/pdf-office`; người nhận việc ghi vào "Cần MÓNG bổ sung" thay vì tự sửa (tránh xung đột khi ghép).
- Mọi việc cần chạy `dart run tool/merge_arb.dart && flutter gen-l10n` trong `app/` trước khi test (`lib/l10n/` bị gitignore).
- Thêm plugin mới → **build thử APK debug ngay** (lỗi Gradle chỉ lộ khi build Android) — xem [[build-android]].

Liên quan: [[build-song-song-agent]], [[0004-pham-vi-bam-app-goc]], [[documents]], [[kiem-thu-flutter]].

## Thử máy thật + rà lỗi toàn hệ thống (27/10/2026)
Thử trên Galaxy A13 (32-bit): trang chủ, 6 tab, ⋮, tìm kiếm, ngôn ngữ, cài đặt, đọc PDF, DOCX, XLSX đều chạy. 5 agent đọc code song song
(chỉ đọc) rồi mới kiểm chứng và sửa — **báo cáo agent là giả thuyết, phải kiểm lại đúng dòng code**: một mục sai (nói ném lỗi ở
`formatNumber` nhưng thật ra ném ở lần đổi `DateTime` sau đó).
**Đã sửa (có test đỏ→xanh):** quét trùng; hộp thoại chuyển đổi không đóng khi lỗi; TXT UTF-8 có byte rác thành 1252; `Uri.decodeFull`
làm hỏng cả DOCX/XLSX; ô Excel số lớn làm hỏng cả file; vùng gộp XLSX `A1:XFD1048576` phình triệu hàng (kẹp +200 hàng/+50 cột);
slide PPTX kích thước 0; zoom PPTX kẹt; tách PDF ghi đè file có sẵn; đổi album ảnh làm lưới trống; thụt lề DOCX; ảnh DOCX giải mã
full-res (`cacheWidth`); máy quét huỷ để lại PDF dở; ảnh quét tạm không dọn (`cleanupStaleScanFiles`); mã hoá/giải mã PDF chạy
trên isolate nền; OCR zh/ja/ko thiếu gói ML Kit.
**Còn lại (chưa làm):** TXT rất lớn (tách dòng/tìm trên UI isolate, dòng 20MB); gộp nhiều PDF lớn giữ hết trong RAM; ký PDF parse
lại mỗi trang; PDF→ảnh trần 16MP có thể OOM 32-bit; trang ảnh hỏng khi xuất máy quét bị bỏ im lặng; lối tắt PDF nhận path tuỳ ý
(`ShortcutChannel.extractPath`, exported); `writeAtomically` xoá trước khi đổi tên; XLSX→PDF O(ô×vùng gộp); file Office hỏng một
phần làm hỏng cả file; ghi đè mật khẩu: watermark/gộp/tách làm mất mã hoá file gốc mà không cảnh báo; đo kỹ khởi động (3–4s sau splash).
