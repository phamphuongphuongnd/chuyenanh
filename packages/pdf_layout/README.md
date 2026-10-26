# pdf_layout

Thư viện Dart thuần (không Flutter, không Syncfusion) cho PDF Office:

1. `rebuildDocument(pages)` — dựng lại tiêu đề / đoạn văn / danh sách / bảng / ngắt trang từ các dòng chữ
   trích ra từ PDF.
2. `detectSheets(pages)` — mỗi trang một lưới để xuất Excel; dòng ngoài bảng nằm ở cột A,
   `tableRanges` cho biết vùng bảng.
3. `writeDocx(blocks)` — ghi file `.docx` tối thiểu (A4, Arial / Noto Sans, Heading1..3, bảng có viền,
   danh sách bằng `numbering.xml`).

Mọi hàm đều đồng bộ, không tác dụng phụ, chỉ nhận dữ liệu thuần → chạy được trong `Isolate.run`.

## Đầu vào

Toạ độ điểm PDF, gốc trên-trái, `y` tăng xuống. App tự chuyển từ Syncfusion
`PdfTextExtractor.extractTextLines()`:

```dart
LayoutPage(index: i, width: w, height: h, lines: [
  for (final l in textLines)
    LayoutLine(
      pageIndex: l.pageIndex,
      text: l.text,
      bounds: LayoutRect(left: l.bounds.left, top: l.bounds.top,
          width: l.bounds.width, height: l.bounds.height),
      fontSize: l.fontSize,
      words: [for (final w in l.wordCollection) LayoutWord(text: w.text,
          bounds: /* w.bounds */, fontSize: w.fontSize,
          bold: w.fontStyle.contains(PdfFontStyle.bold))],
    ),
]);
```

## Heuristic

Hằng số nằm trong `RebuildOptions` (header/footer, gom đoạn, heading, 2 cột, bảng). Kết quả **không giữ
nguyên bố cục** gốc — chỉ là dựng lại cấu trúc gần đúng.

## Lệnh

```sh
dart pub get && dart analyze && dart test
```
