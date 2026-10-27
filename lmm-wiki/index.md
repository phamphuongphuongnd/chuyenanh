---
title: Index — Mục lục wiki
type: index
updated: 2026-10-27
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
  (mỗi việc tự đủ: sở hữu file, thư viện dùng, việc cần làm, test, ước lượng). **Mục E = bảng bàn giao + cách nhận việc.**
- **Đủ 10 tính năng đã ghép vào `feat/pdf-office`** (692 test, build APK debug OK, chưa chạy máy thật) — xem [[tinh-nang-t1-t10]]. Các nhánh `feat/t1-…` … `feat/t10-…` trên origin chỉ còn là lịch sử.
- `README.md` ở thư mục gốc = hướng dẫn dự án (GitHub chỉ hiện README của nhánh mặc định `master`).

## Modules
- [[thu-vien-dart-thuan]] — 4 thư viện Dart thuần trong `packages/` (office_reader, pptx_reader, pdf_layout, image_ops).
- [[tinh-nang-t1-t10]] — **trạng thái 10 tính năng (đã ghép)**: từng tính năng làm được gì, hạn chế, việc còn lại (font, thử máy thật).
- [[documents]] — T1 Trang chủ Tài liệu: màn, provider quét + quyền, quyết định thiết kế, phần chưa kiểm trên máy thật.

## Entities
- [[co-so-du-lieu]] — 4 bảng drift (`documents`, `favorites`, `recents`, `bookmarks`) + DAO + quy ước (page 0-based, -1 = cả tài liệu).

## Concepts (pattern dùng lại được)
- [[build-song-song-agent]] — chia việc cho nhiều agent song song bằng hợp đồng + worktree, không dẫm chân nhau.
- [[xuat-chu-ra-pdf]] — kết quả spike: chữ Việt phải chuẩn hoá NFC, CJK phải fallback font theo script, lỗi mật khẩu PDF.
- [[kiem-thu-flutter]] — dựng Flutter trên máy mới, cạm bẫy test widget (pumpAndSettle, drift timer, override provider).
- [[build-android]] — môi trường build (Flutter/SDK/JDK ở đâu), build đầu lâu, các lỗi Gradle đã gặp và cách sửa.
- [[ui-app-goc]] — cấu trúc giao diện app mẫu: bottom nav 5 item, 3 tile tính năng, badge màu loại file, PDF viewer.

## Decisions (ADR)
- [[0001-flutter-android-truoc]] — Flutter, Android trước, dùng cá nhân, test trên Samsung A13.
- [[0002-syncfusion-community]] — Syncfusion cho PDF + các gotcha đã kiểm.
- [[0003-kien-truc-riverpod]] — feature-first + Riverpod + drift + engine interface.
- [[0004-pham-vi-bam-app-goc]] — phạm vi: toàn bộ chức năng, chỉ theo app gốc.
