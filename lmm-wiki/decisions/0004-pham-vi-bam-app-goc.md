---
title: ADR 0004 — Phạm vi: chức năng theo app tham khảo
type: decision
updated: 2026-10-25
sources:
  - docs/superpowers/specs/2026-10-25-pdf-office-design.md
---

# ADR 0004 — Phạm vi: chức năng theo app tham khảo

**Quyết định:** làm **toàn bộ nhóm chức năng** của app tham khảo (một app chuyển đổi PDF phổ biến trên Google Play),
**phạm vi chỉ theo app tham khảo này** — người dùng nói rõ chỉ lấy app tham khảo đầu tiên làm phạm vi, không lấy thêm
tính năng từ app khác. Tham khảo các luồng chức năng phổ biến của nhóm app chuyển đổi PDF; giao diện, logo, icon và
tài nguyên do dự án tự thiết kế.

**7 phần:** (1) Tài liệu + Ảnh→PDF · (2) Trình đọc PDF + PDF→ảnh + lối tắt màn hình chính · (3) Công cụ PDF: gộp,
tách, sắp xếp trang, khoá/mở khoá, watermark, tạo tài liệu trắng · (4) Chỉnh sửa: annotation, chữ ký, **điền form**
· (5) Chuyển đổi text/TXT/DOCX/XLSX→PDF, PDF→TXT/DOCX/XLSX · (6) Đọc DOCX/XLSX/TXT/PPTX (doc/xls/ppt cũ → app ngoài)
· (7) Máy quét + OCR.

**Bố cục ban đầu (luồng phổ biến của nhóm app chuyển đổi PDF):** ☰ + tab All/PDF/DOC/XLS/PPT/TXT + lưới loại + nút ＋, **không bottom nav**; hộp thoại
thẻ bo góc, nút CANCEL viền + nút đỏ đặc; màu đỏ `#E5393B`.

**Ngoài phạm vi app tham khảo chỉ thêm:** chọn thư mục lưu file (đánh giá người dùng app tham khảo phàn nàn thiếu).
**Không làm:** quảng cáo, gói Turbo, EPUB/RTF/ODT/ZIP, bộ lọc màu PDF.

Liên quan: [[0001-flutter-android-truoc]].
