---
title: Trạng thái 10 tính năng T1…T10 (bàn giao)
type: module
updated: 2026-10-26
sources:
  - docs/superpowers/plans/2026-10-26-feature-tasks.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
  - app/lib/features/
---

# Trạng thái 10 tính năng T1…T10 (bàn giao 26/10/2026)

Chi tiết từng việc (sở hữu file, thư viện dùng, việc cần làm, test, ước lượng) ở
`docs/superpowers/plans/2026-10-26-feature-tasks.md` — **mục E là bảng trạng thái bàn giao**. Trang này tóm tắt.

## Tóm tắt
- **Nền đã xong và đã kiểm:** [[0003-kien-truc-riverpod]] + [[thu-vien-dart-thuan]] (4 thư viện, đã thử file thật 2/4) + build Android
  ([[build-android]]) + spike chữ ([[xuat-chu-ra-pdf]]).
- **Tính năng: ~10–15%.** 10 agent đã viết **logic thuần + engine + test** cho mỗi việc rồi bị **dừng do hết lượt dùng**.
  **Màn hình (UI) hầu như chưa có** → app hiện chỉ là khung, chưa có gì để xem trên điện thoại.
- Phần đã làm nằm ở **10 nhánh trên git** (xuất phát từ `feat/pdf-office`):

| Việc | Nhánh | Mức |
|---|---|---|
| T1 Trang chủ Tài liệu | `feat/t1-documents` | logic quét/lọc/sắp xếp xong, UI chưa |
| T2 Ảnh → PDF | `feat/t2-image-to-pdf` | engine (dở), UI chưa |
| T3 Trình đọc PDF | `feat/t3-reader` | engine pdfx xong, UI + lối tắt Kotlin chưa |
| T4 Công cụ PDF | `feat/t4-pdf-tools` | engine (dở), UI chưa |
| T5 Chỉnh sửa PDF | `feat/t5-editor` | toán chữ ký + engine (dở), UI chưa |
| T6 Chuyển đổi | `feat/t6-convert` | hàm thuần NFC/fallback font xong, engine chưa |
| T7 Xem DOCX/XLSX/TXT | `feat/t7-office-viewer` | engine bọc office_reader xong, UI chưa |
| T8 Xem PPTX | `feat/t8-pptx` | logic bố cục xong, widget vẽ slide chưa |
| T9 Máy quét + OCR | `feat/t9-scanner` | OCR engine + model xong, UI chưa |
| T10 Cài đặt + thương hiệu | `feat/t10-settings` | màn Ngôn ngữ xong, phần còn lại + icon chưa |

## Gotcha khi nhận việc
- **Chưa chạy lại `flutter analyze`/`test` sau khi agent bị ngắt** — chạy trước khi làm tiếp. Mỗi nhánh có commit `WIP(Tn)`
  chứa file làm dở; file thử nghiệm tạm (`probe`, `exp_test`) cố ý **không** đưa lên git.
- Đổi gói (`pubspec.yaml`), Manifest, `core/**`, `data/db/**`, interface `*_engine.dart` là việc của người giữ nhánh
  `feat/pdf-office`; người nhận việc ghi vào "Cần MÓNG bổ sung" thay vì tự sửa (tránh xung đột khi ghép).
- Mọi việc cần chạy `dart run tool/merge_arb.dart && flutter gen-l10n` trong `app/` trước khi test (`lib/l10n/` bị gitignore).
- Thêm plugin mới → **build thử APK debug ngay** (lỗi Gradle chỉ lộ khi build Android) — xem [[build-android]].

Liên quan: [[build-song-song-agent]], [[0004-pham-vi-bam-app-goc]].
