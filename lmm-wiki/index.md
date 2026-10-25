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

## Modules
*(chưa có)*

## Entities
*(chưa có)*

## Concepts (pattern dùng lại được)
*(chưa có)*

## Decisions (ADR)
*(chưa có)*
