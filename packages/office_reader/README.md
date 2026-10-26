# office_reader

Thư viện Dart thuần (không phụ thuộc Flutter) đọc `.docx` và `.xlsx` thành model dữ liệu,
để app vẽ bằng widget hoặc chuyển sang PDF. Tự parse OOXML bằng `archive` + `xml`.

```dart
import 'package:office_reader/office_reader.dart';

final doc = await Isolate.run(() => readDocx(bytes));   // DocxDocument
final wb  = await Isolate.run(() => readXlsx(bytes));   // XlsxWorkbook
// File hỏng / không phải OOXML -> OfficeFormatException
```

## DOCX
- `DocxDocument(blocks, page)`; block là `DocxParagraph`, `DocxTable`, `DocxPageBreak`.
- Style: docDefaults, chuỗi `basedOn`, style ký tự (`rStyle`), run override; `Heading 1..6`
  (theo tên style hoặc `outlineLvl`) -> `headingLevel`.
- List từ `numbering.xml`: `listLevel`, `listOrdered`, `listLabel` ("1.", "a)", "1.b.i", "•"),
  thụt lề lấy từ level nếu đoạn không tự đặt.
- Bảng: `columnWidthsTwips`, `gridSpan`, `vMergeContinue` + `rowSpan` (đã tính sẵn), `shadingArgb`,
  `bordered`, bảng lồng nhau.
- Inline: `DocxRun` (bold/italic/underline/strike/super/sub, cỡ, màu, highlight, font, hyperlink;
  `w:caps`/`w:smallCaps` -> text in HOA, `smallCaps` = true; `w:vanish` bị bỏ),
  `DocxImage` (inline + anchor, bytes thật), `DocxBreak`. `w:tab` -> `\t`.
- `w:br type="page"` được tách thành block `DocxPageBreak` (đoạn bị chia đôi).
- Field code bị ẩn, giữ kết quả hiển thị; bỏ qua header/footer, footnote, textbox, text đã xoá (`w:del`).
- Đơn vị: twips (1/20 pt), EMU (1/914400 inch), pt.

## XLSX
- Thứ tự sheet theo `workbook.xml`, tên, `hidden` (cả `veryHidden`).
- Toạ độ **0-based**: `cells[(row, col)]`, `A1 = (0, 0)`; `maxRow`/`maxCol` là số hàng/cột dùng
  (biên loại trừ, tính cả vùng merge).
- Chuỗi shared/rich/inline (bỏ phiên âm `rPh`), số, bool, lỗi, ngày (`t="d"`), công thức (lấy giá trị
  cache `<v>`, text công thức ở `formula`; công thức shared được bung ra từ ô gốc, tham chiếu tương đối dịch theo vị trí).
- `display` đã định dạng theo numFmt: General, `0.00`, `#,##0`, `%`, `E+`, phân số, nhiều section,
  màu/locale `[Red]`/`[$₫-42A]`, ngày/giờ (`d/m/yyyy`, `yyyy-mm-dd`, `h:mm AM/PM`, `[h]:mm:ss`...).
  Serial 1900 có lỗi năm nhuận 1900; hỗ trợ `date1904`.
- Style: font (đậm/nghiêng/gạch/cỡ/màu/tên), fill, có viền hay không, căn ngang/dọc, wrap;
  màu rgb/theme(+tint)/indexed.
- `merges`, `columnWidthsChars`, `rowHeightsPt` (0 = ẩn), độ rộng/cao mặc định, `frozenRows/Cols`.

## Giới hạn
- Dấu thập phân kiểu en-US (`1,234.50`); tên tháng/thứ tiếng Anh; mã 14/22 hiển thị `d/m/yyyy`.
- Chưa có: style bảng (màu theo table style), viền chi tiết từng cạnh, rich text từng đoạn trong ô
  Excel, conditional formatting, ảnh/biểu đồ trong xlsx, hyperlink dạng field `HYPERLINK`,
  textbox/shape, header/footer, footnote, công thức không có cache (hiện rỗng).
- Bộ đếm list theo `numId` (không chia sẻ giữa các num cùng abstractNum).
- DOM XML toàn phần: file rất lớn tốn RAM tương ứng.

## Phát triển
```
dart pub get && dart analyze && dart test
```
Fixture dựng bằng code trong `test/helpers/ooxml.dart`; ngoài ra `test/fixtures/real/*` là file do
Microsoft Word/Excel thật tạo (`tool/make_real_fixtures.ps1`, `tool/make_real_fixtures_extra.ps1`, cần Office
cài sẵn; chạy lại bằng `powershell -File tool\make_real_fixtures.ps1`). `dart run tool/dump.dart <file>` in model để soi.
