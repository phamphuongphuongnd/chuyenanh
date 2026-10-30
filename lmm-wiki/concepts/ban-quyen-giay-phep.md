---
title: Bản quyền & giấy phép — kiểm trước khi lên store
type: concept
updated: 2026-10-30
sources:
  - app/lib/core/licenses/bundled_licenses.dart
  - app/tool/license_report.dart
  - app/test/tool/license_report_test.dart
  - app/assets/fonts/OFL-Noto.txt
  - app/lib/core/utils/output_directory.dart
  - THIRD_PARTY_LICENSES.md
  - LICENSE
  - README.md
---

# Bản quyền & giấy phép (30/10/2026, commit `32f40a0`)

Đối chiếu Lớp 6 "Sở hữu trí tuệ và giấy phép nguồn mở" của tài liệu tiêu chuẩn `D:\Phuong\tieu-chuan-ban-app-toan-cau.md`
(ngoài repo). Quyết định phát hành: [[0005-len-store-mien-phi]]. Đã kiểm: 1084 test xanh, analyze sạch; **chưa xem trên máy thật**.

## Đã làm
| Việc | Ở đâu | Ghi chú |
|---|---|---|
| Trang "Giấy phép mã nguồn mở" có Be Vietnam Pro, Noto Sans/SC/JP/KR, uCrop | `registerBundledLicenses()` trong `app/lib/core/licenses/bundled_licenses.dart`, gọi ở `main.dart` | Flutter **chỉ tự gom gói pub**; font trong `assets/` và thư viện native phải khai tay. Apache-2.0 nhúng thành `const` để khỏi sửa pubspec |
| Giấy phép font Noto (OFL-1.1) | `app/assets/fonts/OFL-Noto.txt` (commit; `*.ttf` vẫn gitignore) | OFL bắt **kèm văn bản giấy phép** khi phát hành font. Bản APK/IPA cũ trên GitHub Release **thiếu** cái này |
| Bảng kê giấy phép (SPDX) | `app/tool/license_report.dart` → `THIRD_PARTY_LICENSES.md` | 212 gói: BSD-3 130, MIT 49, Apache 15, Syncfusion 11; **không GPL/AGPL/LGPL**. `dbus` MPL-2.0 chỉ qua `file_picker_linux`. Lệnh trả mã lỗi nếu có GPL/UNKNOWN |
| Đổi "PDF Office" → "Phiotron PDF" ("Office" = nhãn hiệu Microsoft) | `appFolderName` trong `output_directory.dart`, `settings_outputDirDefault` 6 ngôn ngữ, mô tả pubspec | Giữ `legacyAppFolderName = 'PDF Office'`; package id `com.phuong.pdfoffice` giữ nguyên |
| Xoá kết quả spike nhúng font Windows | `spikes/pdf_text/out/*.pdf|png` + `.gitignore` | Font Microsoft (Malgun, SimSun, Yu Gothic, Arial…) không được nằm trong repo/app |
| Trung lập hoá tài liệu | `docs/`, `lmm-wiki/`, `planhistory/` | Bỏ tên/package/link app tham khảo; ghi rõ giao diện tự thiết kế |
| Quyền sở hữu | `LICENSE` (All rights reserved), README mục 11 | |

## Gotcha
- **Classifier giấy phép:** văn bản MPL-2.0 có nhắc "GNU Affero" → phải kiểm `Mozilla Public License` **trước** các mẫu GNU; LGPL trước GPL.
  `sky_engine` là file gộp 1.608 thông báo → phân loại theo từng đoạn (`MULTIPLE`).
- **Syncfusion Flutter không có key**: app chạy được dù chưa đăng ký, nhưng giấy phép cấm dùng khi chưa có Community License.
  Đơn đã nộp 30/10 (cá nhân / Hobbyist, ticket **#886739**, xác minh bằng hồ sơ Xing vì LinkedIn bị chặn ở VN). Email "7-day trial key" bỏ qua;
  chờ email duyệt → sửa README mục 11 thành "đã có giấy phép". Không dán key vào code/commit. Xem [[0002-syncfusion-community]].
- **Lịch sử git còn bản cũ** (tài liệu nhắc app tham khảo, PDF nhúng font Windows từ commit `ffc6558`) → cách xử lý là **khoá repo (private)**,
  không viết lại lịch sử. Store không cần repo công khai; chỉ cần URL công khai cho Chính sách bảo mật + Support URL (đặt chỗ khác).
- Commit khi **chat khác đang sửa cùng file**: stage riêng dòng của mình bằng `git show HEAD:file` → thay chuỗi → `git hash-object -w` →
  `git update-index --cacheinfo`, kiểm `git diff --cached` chỉ còn dòng đó.

## Còn lại (chưa làm)
- Chờ Syncfusion duyệt; khoá repo khi không còn ai cần link APK GitHub; thay/gỡ APK cũ trên Release.
- Người dùng tự: so icon/màu/bố cục với app tham khảo, tra nhãn hiệu "Phiotron" (WIPO, Cục SHTT), tự viết/chụp trang store.
- Khi thêm thư viện: chạy lại `dart run tool/license_report.dart` trong `app/`; font/thư viện native mới → khai thêm ở `bundled_licenses.dart`.
- ML Kit Translation (thêm 30/10 bởi phiên khác) tải mô hình từ máy chủ Google → kiểm điều khoản/ghi nguồn ở giai đoạn store.

Liên quan: [[0005-len-store-mien-phi]], [[phat-hanh-apk]], [[0002-syncfusion-community]], [[giao-dien-phiotron]].
