---
title: Trạng thái 10 tính năng T1…T10 (bàn giao)
type: module
updated: 2026-10-26
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
  sạch, **660/660 test pass**, `flutter build apk --debug` thành công (APK 226 MB). **Chưa việc nào chạy trên điện thoại thật.**
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
| T6 Chuyển đổi | text/TXT/DOCX/XLSX→PDF; PDF→TXT/DOCX/XLSX (không giữ bố cục, UI có cảnh báo) | **cần font Noto** cho chữ Việt có dấu + CJK; PDF quét ảnh không OCR; DOCX→PDF gần đúng (bỏ ảnh không phải PNG/JPEG, chưa header/footer) |
| T7 Xem DOCX/XLSX/TXT | vẽ DOCX, lưới XLSX (ô gộp, freeze, nhiều sheet), TXT (tự nhận mã hoá) | hyperlink DOCX chỉ chép URL (chưa `url_launcher`); chữ Excel chưa tràn sang ô bên cạnh |
| T8 Xem PPTX | vuốt từng slide, zoom, thumbnail, ghi chú, slide ẩn | chỉ số trên/dưới chỉ thu nhỏ; flip group chưa áp; picture fill chưa vẽ ảnh; hyperlink chưa bấm; chưa thấy chữ thật trong golden (font test) |
| T9 Máy quét + OCR | chụp nhiều trang, tự nhận viền, kéo 4 góc thủ công, danh sách trang, xuất PDF/TXT/DOCX, OCR ML Kit | PDF xuất chỉ là ảnh (chưa lớp chữ tìm kiếm — cần Noto); **OCR tiếng Việt dấu chồng chưa từng đo**; chưa gọi `cleanCache()` |
| T10 Cài đặt + thương hiệu | Ngôn ngữ, Giao diện, Thư mục lưu, Khổ giấy, Giới thiệu, icon vector | màn con dùng `Navigator.push` (không có route riêng); icon chưa nhìn trên máy |

## Việc còn lại (theo thứ tự nên làm)
1. ~~Tải font Noto~~ **Xong 26/10**: `bash tool/fetch_fonts.sh` trong `app/` (font không nằm trong git) — xem [[xuat-chu-ra-pdf]]. T4/T6/T9 giờ có font thật; test 660/660 vẫn pass.
2. **Cài lên Samsung Galaxy A13** (cáp USB + Gỡ lỗi USB) và đi qua checklist từng tính năng trong báo cáo của agent; ghi lỗi → sửa.
   Đặc biệt: quyền "tất cả file", camera, máy quét, lối tắt, OCR tiếng Việt.
3. `composeVietnamese` bị nhân đôi (T4 `pdf_tools/logic/vi_nfc.dart`, T6 `convert/text/vietnamese_nfc.dart`) → gom vào `core/utils`.
4. Tuỳ chọn: `url_launcher` (mở hyperlink), `device_info_plus` (biết SDK để xin quyền đúng), `package_info_plus` (T10 đang hằng `kAppVersion`),
   OCR cho PDF quét ảnh ở T6, lớp chữ tìm kiếm cho PDF quét ở T9.
5. Gỡ các nhánh `feat/t*` trên origin khi không cần lịch sử nữa; quyết định có gộp `feat/pdf-office` → `master` không.

## Gotcha khi nhận việc
- Mọi thay đổi phải giữ `flutter analyze` sạch và `flutter test` xanh (660 test). Test dùng ổ đĩa thật có thể chập chờn khi máy tải nặng
  (đã thấy `settings_screens_test`: pass khi chạy riêng) — chạy lại riêng trước khi kết luận lỗi.
- Đổi gói (`pubspec.yaml`), Manifest, `core/**`, `data/db/**`, interface `*_engine.dart` là việc của người giữ nhánh
  `feat/pdf-office`; người nhận việc ghi vào "Cần MÓNG bổ sung" thay vì tự sửa (tránh xung đột khi ghép).
- Mọi việc cần chạy `dart run tool/merge_arb.dart && flutter gen-l10n` trong `app/` trước khi test (`lib/l10n/` bị gitignore).
- Thêm plugin mới → **build thử APK debug ngay** (lỗi Gradle chỉ lộ khi build Android) — xem [[build-android]].

Liên quan: [[build-song-song-agent]], [[0004-pham-vi-bam-app-goc]], [[documents]], [[kiem-thu-flutter]].
