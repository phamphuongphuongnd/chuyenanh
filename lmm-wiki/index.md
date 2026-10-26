---
title: Index — Mục lục wiki
type: index
updated: 2026-10-22
---

# Index — Mục lục LLM Wiki

> **Luôn đọc trang này đầu tiên** khi cần kiến thức project (xem `[[SCHEMA]]` → thao tác QUERY).
> Wiki vận hành theo phương pháp Karpathy "LLM Wiki". Quy tắc đầy đủ ở [[SCHEMA]].

## Tổng quan dự án
- **Tên:** PDF Office (`com.phuong.pdfoffice`)
- **Mục đích:** app dùng cá nhân, giống app mẫu Google Play "Image to PDF: PDF Converter" (TrustedOffice,
  `com.readpdf.pdfreader.pdfviewer`): ảnh↔PDF, đọc PDF/Office, công cụ PDF, chỉnh sửa, chuyển đổi, máy quét + OCR.
  Offline, không quảng cáo, không lên store. Thiết kế: `docs/superpowers/specs/2026-10-25-pdf-office-design.md`.
- **Loại dự án:** app di động (Android trước, iOS sau)
- **Ngôn ngữ & stack:** Dart · Flutter · Riverpod · go_router · drift · Syncfusion Flutter PDF (Community) · pdfx
- **Thư mục chính:** `app/` (dự án Flutter), `docs/superpowers/specs/`, `docs/superpowers/plans/`
- **Lệnh** (chạy trong `app/`): chạy `flutter run` · test `flutter test` · kiểm tra biên dịch `flutter analyze`

## Bộ luật & nhật ký
- [[SCHEMA]] — quy ước trang + 3 thao tác Ingest / Query / Lint.
- [[log]] — nhật ký phiên (append-only).
- [[preferences]] — cách làm việc người dùng muốn tôi tuân theo.

## Đang làm dở — đọc trước khi tiếp tục
- `planhistory/2026-10-25-pdf-office-khoi-tao.md` — **checkpoint tiến độ** build song song (nhánh nào xong, nhánh nào
  chưa merge, cách làm tiếp nếu phiên bị ngắt).
- `docs/superpowers/plans/2026-10-25-parallel-build-contract.md` — hợp đồng chia việc (sở hữu file, route, DB, engine,
  đa ngôn ngữ; **mục 7 = ghi chú khớp code thật**).
- `docs/superpowers/plans/2026-10-26-feature-tasks.md` — **giao việc 10 tính năng T1…T10** cho người khác làm
  (mỗi việc tự đủ: sở hữu file, thư viện dùng, việc cần làm, test, ước lượng).

## Modules
- [[thu-vien-dart-thuan]] — 4 thư viện Dart thuần trong `packages/` (office_reader, pptx_reader, pdf_layout, image_ops).

## Entities
*(chưa có — bảng drift `documents/favorites/recents/bookmarks` sẽ thêm khi MÓNG được kiểm)*

## Concepts (pattern dùng lại được)
- [[build-song-song-agent]] — chia việc cho nhiều agent song song bằng hợp đồng + worktree, không dẫm chân nhau.
- [[xuat-chu-ra-pdf]] — kết quả spike: chữ Việt phải chuẩn hoá NFC, CJK phải fallback font theo script, lỗi mật khẩu PDF.
- [[build-android]] — môi trường build (Flutter/SDK/JDK ở đâu), build đầu lâu, các lỗi Gradle đã gặp và cách sửa.

## Decisions (ADR)
- [[0001-flutter-android-truoc]] — Flutter, Android trước, dùng cá nhân, test trên Samsung A13.
- [[0002-syncfusion-community]] — Syncfusion cho PDF + các gotcha đã kiểm.
- [[0003-kien-truc-riverpod]] — feature-first + Riverpod + drift + engine interface.
- [[0004-pham-vi-bam-app-goc]] — phạm vi: toàn bộ chức năng, chỉ theo app gốc.
