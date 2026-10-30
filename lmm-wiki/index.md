---
title: Index — Mục lục wiki
type: index
updated: 2026-10-30
---

# Index — Mục lục LLM Wiki

> **Luôn đọc trang này đầu tiên** khi cần kiến thức project (xem `[[SCHEMA]]` → thao tác QUERY).
> Wiki vận hành theo phương pháp Karpathy "LLM Wiki". Quy tắc đầy đủ ở [[SCHEMA]].

## Tổng quan dự án
- **Tên:** Phiotron PDF (đổi từ "PDF Office" ngày 30/10/2026; package id vẫn `com.phuong.pdfoffice`, thư mục lưu đổi thành `Documents/Phiotron PDF`, file cũ ở `Documents/PDF Office` vẫn đọc được)
- **Mục đích:** app dùng cá nhân, có các nhóm chức năng phổ biến của app chuyển đổi PDF (tham khảo luồng chức năng
  phổ biến; giao diện, logo, icon và tài nguyên do dự án tự thiết kế): ảnh↔PDF, đọc PDF/Office, công cụ PDF, chỉnh sửa, chuyển đổi, máy quét + OCR.
  Miễn phí, không quảng cáo, không mua trong app; **dự kiến lên Google Play + App Store** (xem [[0005-len-store-mien-phi]]). Thiết kế: `docs/superpowers/specs/2026-10-25-pdf-office-design.md`.
- **Loại dự án:** app di động (Android trước, iOS sau)
- **Ngôn ngữ & stack:** Dart · Flutter · Riverpod · go_router · drift · Syncfusion Flutter PDF (Community) · pdfx
- **Thư mục chính:** `app/` (dự án Flutter), `docs/superpowers/specs/`, `docs/superpowers/plans/`
- **Lệnh** (chạy trong `app/`): chạy `flutter run` · test `flutter test` · kiểm tra biên dịch `flutter analyze`

## Bộ luật & nhật ký
- [[SCHEMA]] — quy ước trang + 3 thao tác Ingest / Query / Lint.
- [[log]] — nhật ký phiên (append-only).
- [[preferences]] — cách làm việc người dùng muốn tôi tuân theo.

## Đang làm dở — đọc trước khi tiếp tục
- **[[viec-con-lai]] — danh sách việc làm tiếp (đọc trước tiên)**.
- `planhistory/2026-10-25-pdf-office-khoi-tao.md` — **checkpoint tiến độ** build song song (nhánh nào xong, nhánh nào
  chưa merge, cách làm tiếp nếu phiên bị ngắt).
- `docs/superpowers/plans/2026-10-25-parallel-build-contract.md` — hợp đồng chia việc (sở hữu file, route, DB, engine,
  đa ngôn ngữ; **mục 7 = ghi chú khớp code thật**).
- `docs/superpowers/plans/2026-10-26-feature-tasks.md` — **giao việc 10 tính năng T1…T10** cho người khác làm
  (mỗi việc tự đủ: sở hữu file, thư viện dùng, việc cần làm, test, ước lượng). **Mục E = bảng bàn giao + cách nhận việc.**
- **Đủ 10 tính năng đã ghép vào `feat/pdf-office`** (707 test, đã thử trên Galaxy A13, có bản release + link tải) — xem [[tinh-nang-t1-t10]]. Các nhánh `feat/t1-…` … `feat/t10-…` trên origin chỉ còn là lịch sử.
- `README.md` ở thư mục gốc = hướng dẫn dự án (GitHub chỉ hiện README của nhánh mặc định `master`).

## Modules
- [[thu-vien-dart-thuan]] — 4 thư viện Dart thuần trong `packages/` (office_reader, pptx_reader, pdf_layout, image_ops).
- [[tinh-nang-t1-t10]] — **trạng thái 10 tính năng (đã ghép)**: từng tính năng làm được gì, hạn chế, việc còn lại (font, thử máy thật).
- [[viec-con-lai]] — **việc còn lại / làm tiếp** (chốt 27/10): thay file Release, tối ưu khởi động, lỗi đã biết chưa sửa.
- [[documents]] — T1 Trang chủ Tài liệu: màn, provider quét + quyền, quyết định thiết kế, phần chưa kiểm trên máy thật.
- [[giao-dien-phiotron]] — **giao diện mới Phiotron PDF (30/10)**: quy trình Claude Design → `design-mobile/`, tên/logo, token, `app_sheet.dart`, AppBar sáng, tablet, gotcha icon iOS/Material Symbols.

## Entities
- [[co-so-du-lieu]] — 4 bảng drift (`documents`, `favorites`, `recents`, `bookmarks`) + DAO + quy ước (page 0-based, -1 = cả tài liệu).

## Concepts (pattern dùng lại được)
- [[build-song-song-agent]] — chia việc cho nhiều agent song song bằng hợp đồng + worktree, không dẫm chân nhau.
- [[xuat-chu-ra-pdf]] — kết quả spike: chữ Việt phải chuẩn hoá NFC, CJK phải fallback font theo script, lỗi mật khẩu PDF.
- [[kiem-thu-flutter]] — dựng Flutter trên máy mới, cạm bẫy test widget (pumpAndSettle, drift timer, override provider).
- [[build-android]] — môi trường build (Flutter/SDK/JDK ở đâu), build đầu lâu, các lỗi Gradle đã gặp và cách sửa.
- [[trinh-xem-dong-bo]] — 5 định dạng cùng thanh tìm kiếm + zoom, tô vàng chữ tìm, Khoá/Mở khoá chọn PDF trong app, giảm dựng lại danh sách.
- [[ui-app-goc]] — khảo sát luồng chức năng app tham khảo (lịch sử; từ 30/10 giao diện tự thiết kế, xem [[giao-dien-phiotron]]).
- [[loi-chi-hien-tren-may-that]] — 3 lỗi chỉ lộ trên máy thật (R8/ML Kit, provider autoDispose khi `read`), cách tái hiện bằng ADB, quy tắc rút ra.
- [[ban-quyen-giay-phep]] — **bản quyền & giấy phép (30/10)**: trang Giấy phép trong app (Noto, uCrop), `THIRD_PARTY_LICENSES.md` + script, đổi tên "PDF Office", Syncfusion đang chờ duyệt (#886739), khoá repo.
- [[phat-hanh-apk]] — build release, vì sao phải kèm 32-bit, R8/ML Kit, đưa APK lên GitHub Release + link chia sẻ.
- [[ios]] — chạy trên iPhone: khác Android, build bằng CI macOS, cài bằng Sideloadly (7 ngày), việc chưa kiểm.

## Decisions (ADR)
- [[0001-flutter-android-truoc]] — Flutter, Android trước, dùng cá nhân, test trên Samsung A13.
- [[0002-syncfusion-community]] — Syncfusion cho PDF + các gotcha đã kiểm.
- [[0003-kien-truc-riverpod]] — feature-first + Riverpod + drift + engine interface.
- [[0004-pham-vi-bam-app-goc]] — phạm vi: toàn bộ nhóm chức năng, chỉ theo app tham khảo.
- [[0005-len-store-mien-phi]] — lên Play + App Store miễn phí; bản quyền xong, chính sách store (bỏ All files access, Photo Picker, PRIVACY.md, ký release, xcprivacy…) đã chốt cách làm.
