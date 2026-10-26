---
title: Thư viện Dart thuần trong packages/
type: module
updated: 2026-10-25
sources:
  - packages/office_reader/README.md
  - packages/pptx_reader/README.md
  - packages/pdf_layout/README.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# Thư viện Dart thuần trong `packages/`

Không phụ thuộc Flutter, an toàn chạy trong `Isolate.run`. App dùng qua **path dependency** trong `app/pubspec.yaml`
(`office_reader`, `pptx_reader`, `pdf_layout`, `image_ops` → `../packages/<tên>`). Mọi package phải dùng **`xml ^7`**
và `archive ^4` cho khớp Syncfusion 35 (gói `excel` bị bỏ vì kẹt `xml <7`). Kiểm bằng
`/c/src/flutter/bin/dart analyze && /c/src/flutter/bin/dart test` trong thư mục package.
Trạng thái 26/10/2026: tất cả đã qua test. **Đã thử file thật (Office 16 qua COM):** `office_reader` (Word/Excel),
`pptx_reader` (PowerPoint). **Chưa thử file thật:** `pdf_layout` (cần PDF thật), `image_ops` (cần ảnh chụp thật).
**Chưa kiểm trên điện thoại.** File mẫu thật + script tạo nằm ở `packages/<tên>/test/fixtures/real/` và `tool/make_real_fixtures*.ps1`
(mỗi lần chạy script Word mất ~5 phút; COM đôi khi thoát -1 lúc khởi động, chạy lại là được).

| Package | Làm gì | API chính | Test |
|---|---|---|---|
| `office_reader` | DOCX → `DocxDocument` (đoạn, heading từ style, list có nhãn, bảng gộp ô, ảnh, hyperlink, caps/smallCaps, khổ trang); XLSX → `XlsxWorkbook` (sheet, ô đã định dạng, merges, style, cột/hàng, frozen, công thức shared, 1904). **Đã thử file Word/Excel thật** | `readDocx(bytes)`, `readXlsx(bytes)` | 80 |
| `pptx_reader` | PPTX → `PptxDeck` (slide, text/ảnh/bảng/group, kế thừa placeholder layout/master, màu theme, nền kể cả texture từ theme, notes, table style, `customPaths` cho hình tự vẽ, bullet font/màu/cỡ). **Đã thử với file PowerPoint thật** | `readPptx(bytes)` | 59 (+2 skip) |
| `pdf_layout` | Dòng chữ PDF → đoạn/heading/list/bảng; bảng cho Excel; **ghi DOCX** (mở được bằng Word) | `rebuildDocument`, `detectSheets`, `writeDocx` | 31 |
| `image_ops` | Bộ lọc ảnh (original, grayscale, blackWhite Bradley/Otsu, enhance, brighten, magicColor), xoay, cắt, đổi cỡ, nén JPEG/PNG, bố cục ảnh trên trang PDF, nắn phối cảnh, phát hiện viền giấy | `applyEdit`, `renderPreview`, `probe`, `perspectiveWarp`, `detectDocumentCorners`, `placeImageOnPage`, `estimateJpegBytes` | 252 |

**Gotcha đã biết:**
- `office_reader` (đã thử file thật): toạ độ XLSX **0-based** `(row, col)`; số hiển thị kiểu en-US; định dạng ngày 14/22 luôn hiện
  `d/m/yyyy` (**file Excel kiểu Mỹ `m/d/yyyy` sẽ bị đảo ngày/tháng**); bỏ qua header/footer/footnote/textbox/comment; công
  thức không có cache thì `display` rỗng; Excel ghi xuống dòng là CRLF thật → đã chuẩn hoá về `
` ở `OoxmlPackage.xml()`;
  công thức **shared** (`t="shared"`) chỉ ô gốc có text → đã bung bằng `shiftFormula`; rich text từng đoạn trong ô chỉ lấy chữ
  ghép lại (ô có đoạn đậm xen thường có thể bị coi cả ô đậm); `vAlign` ô bảng Word chưa có trong model; `ht` hàng có thể
  lỗi thời với ô wrap; `columnWidthsChars` giữ nguyên giá trị file (20 ký tự ra 20.78).
- `pptx_reader` (đã thử file thật): `tint/shade` tính trên **linear RGB** (không phải sRGB — PowerPoint làm vậy); hình preset ngoài rect/roundRect/ellipse/triangle/line (vd `rightArrow`) chỉ trả `other` + tên, **chưa có đường vẽ**; `custGeom` dùng guide formula (`gdLst`) bị bỏ qua; `fontScale` autofit chưa thử với file thật; script `tool/make_real_fixtures.ps1` đôi khi thoát -1 lúc khởi động PowerPoint, chạy lại là được, và để lại tiến trình `POWERPNT /AUTOMATION -Embedding` (tắt thủ công). `fontSizePt` luôn có (mặc định 18pt × fontScale); chart/SmartArt/OLE → khung rỗng có `unsupportedKind`;
  xoay/lật của group **không** áp vào con (app phải xoay cả group); gradient lấy màu stop đầu.
- `pdf_layout`: đoạn văn qua trang không nối (luôn chèn `DocPageBreak`); hàng bảng chỉ 1 ô làm đứt bảng; list 1 cấp.
  Hằng số heuristic nằm trong `RebuildOptions` — cần tinh chỉnh với PDF thật.
- `image_ops`: xoay theo chiều kim đồng hồ; brightness/contrast trong -1..1; ảnh ra bị xoá EXIF/GPS. Ảnh 12MP mất
  ~1,5–2,8 s trên máy bàn (giải mã JPEG thuần Dart chiếm ~1 s) → trên điện thoại chậm hơn: **luôn gọi trong
  `Isolate.run`**, dùng `renderPreview` khi đang chỉnh. Gói `image` 4.12 tự xoay theo EXIF khi giải mã — nâng phiên
  bản thì chạy lại test EXIF. `detectDocumentCorners` trả `null` khi không chắc hoặc giấy chiếm > 95% khung.

Liên quan: [[build-song-song-agent]], [[0003-kien-truc-riverpod]].
