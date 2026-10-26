# Giao việc 10 tính năng — PDF Office

> Dành cho người/agent nhận làm tính năng. Phần nền (móng `app/`, 4 thư viện `packages/`) **đã xong và đã kiểm**.
> Mỗi việc dưới đây **độc lập**, làm song song được, mỗi việc chỉ sửa thư mục của mình.

## A. Đọc trước khi nhận việc (bắt buộc)
1. Spec: `docs/superpowers/specs/2026-10-25-pdf-office-design.md` (chức năng, giao diện, xử lý lỗi).
2. Hợp đồng: `docs/superpowers/plans/2026-10-25-parallel-build-contract.md` — **mục 1 (sở hữu file), 2 (route, widget,
   tiện ích, DB, engine), 3 (đa ngôn ngữ), 7 (ghi chú khớp code thật)**.
3. README của thư viện mình dùng trong `packages/<tên>/README.md`.
4. Wiki: `lmm-wiki/index.md` → `decisions/`, `concepts/build-song-song-agent.md`, `modules/thu-vien-dart-thuan.md`.

## B. Quy tắc chung cho mọi việc
- **Nhánh:** tách từ `feat/pdf-office`, tên `feat/<feature>` (vd `feat/documents`). Không sửa nhánh khác.
- **Chỉ sửa file mình sở hữu** (cột "Sở hữu" bên dưới) + test của mình ở `app/test/features/<feature>/`.
  Cần sửa file chung (`app/pubspec.yaml`, `app/lib/core/**`, `app/lib/data/**`, interface `*_engine.dart`, Manifest)
  → **không tự sửa**, ghi vào mục "Cần MÓNG bổ sung" trong báo cáo/PR.
- **Engine:** viết impl cạnh interface hoặc trong thư mục feature, rồi sửa **đúng một dòng** provider trong
  `app/lib/features/<f>/<f>_providers.dart` để trỏ sang impl thật.
- **Chuỗi:** chỉ thêm vào `app/lib/features/<f>/l10n/<prefix>_<locale>.arb`, key bắt đầu bằng `<prefix>_`, **đủ 6
  ngôn ngữ** (vi, en, zh, ja, ko, id) — tiếng Thái đã bỏ hẳn 26/10. Dùng sẵn chuỗi `core_*` cho nút OK/Huỷ/Xoá…
- **Việc nặng** (PDF, ảnh, parse) chạy trong `Isolate.run` hoặc engine async, có `ProgressCallback` + `CancelToken`.
- **Không ghi đè file gốc:** dùng `uniqueOutputPath` + `writeAtomically`, thư mục lưu `outputDirectoryProvider`.
- **Lỗi:** ném/bắt `AppError`, hiển thị bằng `appErrorMessage(context, e)`.
- **TDD** cho logic thuần (test trước), widget test cho màn chính.
- **Lệnh** (Flutter ở `C:\src\flutter\bin`, Android SDK ở `C:\Android\sdk`), chạy trong `app/`:
  ```
  dart run tool/merge_arb.dart && flutter gen-l10n
  flutter analyze                       # phải "No issues found!"
  flutter test                          # phải pass toàn bộ, kể cả test cũ
  flutter build apk --debug             # trước khi mở PR
  ```
- **Commit thường xuyên** sau mỗi phần nhỏ xong (phòng bị ngắt giữa chừng). Message tiếng Việt không dấu.
- **Báo cáo khi xong** (theo hợp đồng mục 6): file đã sửa, kết quả analyze/test/build, phần chưa làm, "Cần MÓNG bổ
  sung", "Cần tải" (asset), checklist kiểm trên điện thoại thật (Samsung Galaxy A13).

## C. Thứ tự gợi ý & phụ thuộc
- Không phụ thuộc nhau: **cả 10 việc làm song song được**.
- Màn hình thật dùng lẫn nhau qua **route** (đã khai đủ trong `core/router/routes.dart`) — việc nào chưa xong thì
  route đó vẫn là `PlaceholderScreen`, không chặn việc khác.
- Ưu tiên nếu ít người: **T1 → T2 → T3** (luồng chính: thấy file → ảnh ra PDF → mở PDF), rồi T4, T5, T10, T6, T7, T9, T8.

---

## T1 — Trang chủ Tài liệu + quét file
- **Sở hữu:** `app/lib/features/documents/**`, `app/lib/data/file_scanner/**` (tạo mới), `app/test/features/documents/**`. Prefix chuỗi `docs_`.
- **Route:** `Routes.home`, `search`, `recents`, `favorites`.
- **Làm:**
  1. Màn xin quyền: Android 11+ `Permission.manageExternalStorage` (mở Settings), Android 7–10 storage. Từ chối →
     chế độ chọn file (`file_picker`) + băng nhắc cấp quyền.
  2. Quét file trong `Isolate.run`: `dart:io` đệ quy từ `/storage/emulated/0`, bỏ `Android/data`, `Android/obb`, thư mục
     ẩn, symlink lặp; bắt lỗi từng thư mục. Đuôi: `documentExtensions`. Đồng bộ bảng `documents` (`upsertAll` +
     `deleteNotSeenSince`). Hiện skeleton + "đã tìm N file". Kéo xuống làm mới; quét lại khi app resume.
  3. Trang chủ: AppBar đỏ (☰ drawer · tên app · 🔍 · ⇅), tab **All · PDF · DOC · XLS · PPT · TXT** (màu AppBar theo
     `AppColors.forCategory`), lưới loại PDF/DOC/XLSX/PPT/Text/More, nút ＋ mở bottom sheet công cụ từ `tool_registry`.
  4. Dòng file: `FileTypeIcon` · tên · `formatFileInfoLine` · ⭐ (`FavoritesDao.toggle`) · ⋮ (Mở = `openDocument`,
     Đổi tên = `AppDatabase.renamePath` + đổi tên file thật, Chia sẻ = `share_plus`, Yêu thích, Thông tin, Xoá có
     `showConfirmDialog` + `forgetPath`). PDF bị khoá hiện 🔒 (`pdfSecurityProvider.isEncrypted`, cache kết quả).
  5. Sắp xếp tên/ngày/dung lượng tăng/giảm (lưu lựa chọn), tìm kiếm theo tên, màn Gần đây, Yêu thích.
  6. Drawer: Ngôn ngữ, Giao diện, Thư mục lưu, Giới thiệu → route của T10.
- **Test:** lọc theo tab, sắp xếp, bỏ thư mục khi quét (dùng thư mục tạm), đồng bộ DB, widget test đổi tab.
- **Ước lượng:** M (1,5–2 ngày).

## T2 — Ảnh → PDF
- **Sở hữu:** `app/lib/features/image_to_pdf/**`, impl `ImageToPdfEngine`, test tương ứng. Prefix `img2pdf_`.
- **Dùng:** `packages/image_ops` (`applyEdit`, `renderPreview`, `probe`, `placeImageOnPage`, `estimateJpegBytes`), `photo_manager`, `image_picker`, `image_cropper`, Syncfusion `PdfBitmap`.
- **Làm:**
  1. Chọn ảnh: lưới theo album (`photo_manager`), chọn nhiều có số thứ tự, nút camera. HEIC/WebP → JPEG trước
     (photo_manager `file`/`originFile` hoặc `image_ops.applyEdit`).
  2. Màn sửa: dải ảnh thu nhỏ kéo thả đổi thứ tự, xoay, cắt (`image_cropper`), bộ lọc (`ImageFilter`), xoá, thêm.
     Xem trước bằng `renderPreview` trong isolate.
  3. Tuỳ chọn: khổ A4/Letter/Vừa ảnh (`PageSizePreset`), hướng, lề (`MarginPreset`), chất lượng, tên file; hiện dung
     lượng ước tính.
  4. Engine Syncfusion: mỗi ảnh một trang theo `placeImageOnPage`, tiến độ + huỷ, `writeAtomically`.
  5. Màn kết quả: Mở / Chia sẻ / Đổi tên; thêm vào `documents` + `recents`.
- **Test:** engine tạo PDF đúng số trang & khổ (mở lại bằng Syncfusion), huỷ giữa chừng không để file dở, đặt tên trùng.
- **Ước lượng:** M (1,5 ngày).

## T3 — Trình đọc PDF + PDF → ảnh + lối tắt
- **Sở hữu:** `app/lib/features/reader/**`, impl `PdfRenderEngine` (`pdfx`), `android/app/src/main/kotlin/com/phuong/pdfoffice/MainActivity.kt` + `ShortcutChannel.kt`. Prefix `reader_`.
- **Route:** `Routes.pdfReader` (`extra: OpenFileArgs`), `Routes.pdfToImage`.
- **Làm:**
  1. `SfPdfViewer.file`: tìm chữ, cuộn dọc/ngang, liên tục/từng trang, **chỉ số trang + nhập số để nhảy**, tổng trang,
     outline, zoom; PDF có mật khẩu → `showPasswordDialog` → truyền `password`.
  2. Đánh dấu trang & cả tài liệu (`BookmarksDao`, page 0-based, -1 = cả tài liệu), danh sách bookmark.
  3. Chế độ tối: `ColorFiltered` ma trận đảo màu. In: `printing` `Printing.layoutPdf`.
  4. Lối tắt màn hình chính: MethodChannel `ShortcutManagerCompat.requestPinShortcut` (Android 8+, ẩn trên 7), intent
     mang đường dẫn file; app đọc intent khi khởi động/`onNewIntent` (MainActivity `singleTask`) → mở reader.
  5. PDF→ảnh: chọn trang (tất cả/khoảng), JPG/PNG, DPI → `pdfx`. File có mật khẩu: `pdfSecurityProvider.decrypt` ra
     bytes rồi `openBytes`. Lưu vào thư mục con theo tên file.
- **Test:** parse khoảng trang ("1-3,5"), quy đổi DPI→pixel, bookmark DAO dùng đúng, widget test thanh trang.
- **Ước lượng:** M–L (2 ngày).

## T4 — Công cụ PDF
- **Sở hữu:** `app/lib/features/pdf_tools/**`, impl `PdfToolsEngine`. Prefix `tools_`.
- **Route:** `merge`, `split`, `organize`, `lock`, `unlock`, `watermark`, `createBlank`.
- **Làm:**
  1. Gộp: chọn nhiều PDF, sắp thứ tự, hộp thoại tên "A & B to PDF". Syncfusion **không có merge** → mỗi trang
     `page.createTemplate()` vẽ sang tài liệu mới (giữ khổ/xoay trang). Báo trước: mất annotation/form/link.
  2. Tách: theo khoảng, mỗi trang một file, mỗi N trang (`SplitMode`).
  3. Sắp xếp trang: lưới thumbnail (dùng `pdfRenderEngineProvider` nếu T3 đã xong, nếu chưa thì render bằng
     Syncfusion/placeholder) kéo thả, xoá, xoay, trích (`PageOp`).
  4. Khoá/Mở khoá: `pdfSecurityProvider` (AES-256). Mở khoá cần mật khẩu đúng.
  5. Watermark chữ/ảnh: độ mờ, góc, cỡ, vị trí, áp mọi trang (`WatermarkSpec`).
  6. Tạo tài liệu trắng: mẫu trắng/kẻ dòng/kẻ ô, tiêu đề, khổ, màu nền, danh mục, số trang 1–1000 (`BlankDocSpec`).
- **Test:** mỗi thao tác engine trên PDF tự sinh trong test (đếm trang, khổ, có chữ watermark qua `PdfTextExtractor`,
  mã hoá/giải mã), validate khoảng trang, số trang ≤ 1000.
- **Ước lượng:** M–L (2 ngày).

## T5 — Chỉnh sửa PDF: annotation, chữ ký, điền form
- **Sở hữu:** `app/lib/features/editor/**`, impl `PdfSignEngine`. Prefix `edit_`.
- **Route:** `annotate`, `sign`, `fillForm` (`extra: String path`).
- **Làm:**
  1. Annotation trong `SfPdfViewer` (bản 35.x có sẵn): tô sáng, gạch chân, gạch ngang, gạch sóng, ghi chú dán; chọn
     màu; lưu bằng `saveDocument()` ra file mới.
  2. Chữ ký: `SfSignaturePad` (màu, độ dày), lưu chữ ký PNG vào thư mục app để dùng lại; lớp phủ kéo/đổi cỡ trên
     trang; `viewRectToPdfRect` (hàm thuần, test kỹ) → `applySignatures`.
  3. Điền form: viewer bật form filling (text, checkbox, radio, combo), lưu file mới.
- **Test:** `viewRectToPdfRect` với zoom/cuộn/trang xoay, `applySignatures` đặt ảnh đúng trang, lưu/đọc chữ ký.
- **Ước lượng:** M–L (2 ngày).

## T6 — Chuyển đổi
- **Sở hữu:** `app/lib/features/convert/**`, impl `ConvertEngine`. Prefix `conv_`.
- **Dùng:** `packages/office_reader` (đọc DOCX/XLSX — qua `docxEngineProvider`/`xlsxEngineProvider` hoặc gọi thẳng
  thư viện), `packages/pdf_layout` (`rebuildDocument`, `detectSheets`, `writeDocx`), Syncfusion `PdfTextElement`
  (paginate), `PdfGrid`, `PdfTextExtractor.extractTextLines()`, `syncfusion_flutter_xlsio` (ghi XLSX).
- **Route:** `textToPdf`, `wordToPdf`, `excelToPdf`, `pdfToText`, `pdfToWord`, `pdfToExcel`.
- **Làm:**
  1. Chữ gõ / TXT / DOCX / XLSX → PDF; font theo ngôn ngữ nội dung từ `assets/fonts/` (Noto). **Font chưa có trong
     repo** → code phải chạy khi thiếu (rơi về font chuẩn + log) và ghi "Cần tải" trong báo cáo.
  2. PDF → TXT; PDF → DOCX (`TextLine` Syncfusion → `LayoutPage` → `rebuildDocument` → `writeDocx`); PDF → XLSX
     (`detectSheets` → xlsio).
  3. Màn chọn file + tuỳ chọn (khổ, cỡ chữ, lề) + tiến độ + kết quả; ghi rõ "không giữ nguyên bố cục" với PDF→Word/Excel.
- **Test:** chuyển đổi TextLine→LayoutLine, đủ số trang khi paginate, PDF→DOCX ra zip hợp lệ, PDF→XLSX đúng số ô.
- **Lưu ý (spike đã xong — đọc `lmm-wiki/concepts/xuat-chu-ra-pdf.md`):** (1) **chuẩn hoá NFC trước khi vẽ** — chữ NFD bị lệch dấu; dùng/đưa `composeVietnamese()` từ `app/test/spikes/vi_nfc.dart` vào `app/lib/core/utils/` kèm test; (2) **không có font nào đủ Việt + CJK** → fallback theo script (Latin/Việt → Noto Sans, Hán/kana → Noto Sans SC/JP, Hangul → Noto Sans KR), cộng bề rộng dấu cách cuối đoạn vì `measureString` cắt nó; (3) font tự subset nên PDF nhỏ.
- **Ước lượng:** L (2–3 ngày).

## T7 — Xem DOCX / XLSX / TXT
- **Sở hữu:** `app/lib/features/office_viewer/**`, impl `DocxEngine`, `XlsxEngine`. Prefix `office_`.
- **Dùng:** `packages/office_reader` (`readDocx`, `readXlsx`) — gói `excel` **đã bị bỏ** (xung đột `xml`).
- **Route:** `docxViewer`, `xlsxViewer`, `txtViewer`.
- **Làm:**
  1. DOCX: vẽ từ `DocxDocument` bằng widget (đoạn, heading, list có nhãn, bảng có gộp ô, ảnh, hyperlink), zoom, tìm
     chữ. Có thể thử `docx_file_viewer` làm phương án nhanh, nhưng ưu tiên model của `office_reader` để thống nhất.
  2. XLSX: tab sheet (ẩn sheet hidden), lưới `two_dimensional_scrollables` có ô gộp, freeze panes, độ rộng cột/cao
     hàng, style (đậm, màu nền, căn).
  3. TXT: tự nhận UTF-8/UTF-16 (BOM), cỡ chữ đổi được, tìm chữ.
  4. Nút "Chuyển sang PDF" → route T6.
- **Test:** engine bọc thư viện (file mẫu dựng bằng code), map ô gộp → vùng vẽ, nhận mã hoá TXT.
- **Ước lượng:** M (1,5–2 ngày).

## T8 — Xem PPTX
- **Sở hữu:** `app/lib/features/office_pptx/**`, impl `PptxEngine`. Prefix `pptx_`.
- **Dùng:** `packages/pptx_reader` (`readPptx` → `PptxDeck`).
- **Route:** `pptxViewer`.
- **Làm:** vẽ slide theo tỉ lệ `slideWidthEmu/HeightEmu` bằng `Stack` + `Positioned` (EMU → logical px), text shape
  (đoạn, run, bullet, căn, anchor, insets, autofit đã tính sẵn cỡ chữ), ảnh (crop), bảng, group (xoay cả group),
  hình rect/ellipse/roundRect/line bằng `CustomPaint`, nền slide; `unsupportedKind` → khung "Không hỗ trợ". Chế độ
  xem từng slide (vuốt) + dải thumbnail; ghi chú; ẩn slide hidden (tuỳ chọn).
- **Test:** quy đổi EMU, layout text cơ bản (golden test tuỳ chọn), widget test chuyển slide.
- **Ước lượng:** L (2–3 ngày).

## T9 — Máy quét + OCR
- **Sở hữu:** `app/lib/features/scanner/**`, impl `OcrEngine`. Prefix `scan_`.
- **Dùng:** `cunning_document_scanner` (tự nhận viền; máy không Play Services → kéo viền tay bằng
  `image_ops.detectDocumentCorners` + `perspectiveWarp`), `image_ops` bộ lọc, `google_mlkit_text_recognition`
  (Latin gồm tiếng Việt, Indonesia, Anh; Trung; Nhật; Hàn). (Gói `flutter_tesseract_ocr` đã gỡ — app không còn tiếng Thái.)
- **Route:** `Routes.scanner`.
- **Làm:** chụp nhiều trang → danh sách trang (sắp xếp, xoá, chụp lại, bộ lọc) → xuất PDF (dùng engine của T2 qua
  `imageToPdfEngineProvider` hoặc Syncfusion trực tiếp) / TXT / DOCX (`pdf_layout.writeDocx` từ kết quả OCR).
- **Test:** `ocrScriptForLanguage`, ghép block OCR → DocBlock, widget test danh sách trang.
- **Ước lượng:** M–L (2 ngày).

## T10 — Cài đặt + thương hiệu
- **Sở hữu:** `app/lib/features/settings/**`, `app/assets/branding/**`. Prefix `settings_`.
- **Route:** `settings`, `language`, `about`.
- **Làm:** màn Cài đặt; Ngôn ngữ (6 + "Theo máy", `localeNativeNames`, đổi tức thì qua `settingsProvider`); Giao diện
  sáng/tối/theo máy; Thư mục lưu (`file_picker` chọn thư mục, kiểm quyền ghi, nút về mặc định); Khổ giấy mặc định;
  Giới thiệu (phiên bản, giấy phép mã nguồn mở `showLicensePage`, ghi chú Syncfusion Community). Logo + launcher icon
  vẽ vector (adaptive icon Android: nền đỏ `#E5393B`, biểu tượng trang giấy gập góc + mũi tên).
- **Lưu ý:** `app_smoke_test.dart` yêu cầu mọi route là `GoRoute` cấp cao nhất — đừng lồng route con.
- **Test:** đổi locale/theme cập nhật `AppSettings`, kiểm thư mục không ghi được thì báo lỗi.
- **Ước lượng:** S–M (1 ngày).

---

## D. Asset còn thiếu (cần người dùng đồng ý tải)
- Font Noto (OFL 1.1): `NotoSans-Regular/Bold.ttf`, `NotoSansSC/JP/KR-Regular.ttf` → `app/assets/fonts/`.
