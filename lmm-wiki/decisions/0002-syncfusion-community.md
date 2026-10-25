---
title: ADR 0002 — Syncfusion Community cho xử lý PDF
type: decision
updated: 2026-10-25
sources:
  - docs/superpowers/specs/2026-10-25-pdf-office-design.md
---

# ADR 0002 — Syncfusion Community cho xử lý PDF

**Quyết định:** dùng `syncfusion_flutter_pdf` / `_pdfviewer` / `_signaturepad` / `_xlsio` (Community License: doanh
thu < 1 triệu USD, ≤ 5 dev, ≤ 10 nhân viên; Flutter **không cần nhập license key**). Toàn bộ code PDF đặt sau
interface trong `app/lib/engines/` để đổi thư viện được.

**Đã kiểm (nghiên cứu pub.dev 2026-10-25) — gotcha quan trọng:**
- **Không có API merge/import/reorder trang** → tự làm bằng `page.createTemplate()`; mất annotation/form/link.
- Viewer có sẵn highlight, underline, strikethrough, squiggly, sticky note; **không có ink/chữ ký tay** → tự vẽ lớp phủ.
- **Không có night mode** → đảo màu bằng `ColorFiltered`.
- `PdfBitmap` chỉ nhận **JPEG/PNG** → WebP/HEIC phải đổi trước.
- Không có `isEncrypted` → mở không mật khẩu rồi bắt exception.
- `PdfTrueTypeFont` tự subset font → nhúng Noto không làm PDF to.
- Có thể đặt sai dấu tiếng Thái (shaping) → phải spike sớm.
- `pdfx` (render trang ra ảnh) trên Android dùng `PdfRenderer` gốc, **không mở được PDF có mật khẩu** → giải mã bằng Syncfusion trước.

Liên quan: [[0001-flutter-android-truoc]], [[0003-kien-truc-riverpod]].
