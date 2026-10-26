# PDF Office — Thiết kế tổng thể

- **Ngày:** 2026-10-25
- **Trạng thái:** đã duyệt qua brainstorming (4 mục), chờ người dùng xem lại bản viết
- **App mẫu:** "Chuyển đổi hình ảnh sang PDF" / "Image to PDF: PDF Converter" — TrustedOffice,
  `com.readpdf.pdfreader.pdfviewer`, v4.0.3, Android 7.0+, phát hành 11/2020.
  **Nguyên tắc: bám đúng app gốc này**, không lấy tính năng từ các app khác cùng nhà phát triển.

## 1. Mục tiêu & phạm vi

App Flutter **PDF Office** (`com.phuong.pdfoffice`) có chức năng, bố cục, luồng màn hình và màu chủ đạo giống app mẫu.

| Hạng mục | Quyết định |
|---|---|
| Mục đích | Dùng cá nhân, cài trực tiếp (sideload), **không lên store** |
| Kiếm tiền | Không: không quảng cáo, không mua trong app, không gói "Turbo" |
| Mạng | Không dùng — chạy offline hoàn toàn |
| Nền tảng | Android trước (minSdk 24, compileSdk 36). Code sẵn cho iOS nhưng chưa build/test (máy phát triển là Windows) |
| Ngôn ngữ UI | Việt, Anh, Trung, Nhật, Hàn, Indonesia (6; **bỏ tiếng Thái** 26/10) — mặc định theo máy, đổi tức thì trong app |
| Thương hiệu | Tên, logo, biểu tượng file, hình minh hoạ **tự vẽ**, không chép tài nguyên của app mẫu |
| Ngoài app mẫu | Chỉ thêm **chọn thư mục lưu file** (người dùng app mẫu phàn nàn thiếu) |

**Không làm:** quảng cáo, thanh toán, đăng nhập, đồng bộ đám mây, bottom navigation (app gốc không có),
đọc EPUB/RTF/ODT/ZIP, bộ lọc màu cho PDF.

## 2. Chức năng — 7 phần, làm lần lượt

Mỗi phần có kế hoạch, code, test riêng; xong phần nào app chạy được phần đó.

### Phần 1 — Khung app + Tài liệu + Ảnh→PDF
- **Lần đầu mở:** màn xin quyền "Truy cập tất cả file" (Android 11+; Android 7–10 dùng READ/WRITE_EXTERNAL_STORAGE).
  Từ chối → app vẫn chạy ở chế độ chọn file, có thanh nhắc cấp quyền.
- **Trang chủ:** thanh tiêu đề đỏ (☰ · tên app · 🔍 tìm · ⇅ sắp xếp theo tên/ngày/dung lượng, tăng/giảm);
  tab **All · PDF · DOC · XLS · PPT · TXT**, màu thanh tiêu đề đổi theo tab; lưới loại
  **PDF · DOC · XLSX · PPT · Text · More**; nút ＋ mở nhanh (Ảnh→PDF; các công cụ phần sau thêm dần).
- **Dòng file:** biểu tượng màu theo loại · tên · `4,35 MB • 07:23 • Download` · ⭐ yêu thích ·
  ⋮ (Mở, Đổi tên, Chia sẻ, Yêu thích, Thông tin, Xoá — xoá luôn hỏi lại). Kéo xuống để làm mới.
- **Quét file:** chạy nền trong isolate bằng `dart:io`, bỏ qua `Android/data`, `Android/obb`, thư mục ẩn
  (bắt đầu bằng `.`), symlink lặp; lỗi một thư mục không dừng cả lượt quét. Kết quả đệm trong bảng `documents`.
- **Ảnh→PDF:**
  1. Chọn ảnh: lưới theo album (`photo_manager`), chọn nhiều có số thứ tự, nút chụp camera (`image_picker`).
  2. Sửa: dải ảnh thu nhỏ kéo thả đổi thứ tự; cắt, xoay (`image_cropper`); đổi kích thước; hiệu ứng
     (gốc / đen trắng / xám / tăng tương phản / sáng hơn) bằng gói `image` trong isolate; xoá; thêm ảnh.
  3. Tuỳ chọn: khổ A4 / Letter / Vừa ảnh, hướng giấy, lề (không/nhỏ/lớn), chất lượng nén, tên file.
  4. Xuất có tiến độ → màn kết quả: Mở / Chia sẻ / Đổi tên.
  - Định dạng vào: JPG, PNG, WebP, HEIC. WebP/HEIC đổi sang JPEG trước (Syncfusion chỉ nhận JPEG/PNG).
    Ảnh thu nhỏ về cạnh dài tối đa 3000px bằng codec native trước khi xử lý.
- **Menu ☰:** Ngôn ngữ, Giao diện sáng/tối, Thư mục lưu file, Giới thiệu. Mục Gần đây và Yêu thích.
- Thư mục lưu mặc định: `Documents/PDF Office/`.

### Phần 2 — Trình đọc PDF + PDF→ảnh
- `SfPdfViewer`: cuộn, phóng to, tìm chữ, cuộn dọc/ngang, liên tục/từng trang, **chỉ số trang + nhập số trang để
  nhảy**, tổng số trang, mục lục (outline).
- Đánh dấu trang và cả tài liệu; file gần đây; in (`printing`).
- Chế độ đọc tối: đảo màu bằng `ColorFiltered` (ảnh trong trang cũng bị đảo — chấp nhận).
- Mở PDF có mật khẩu (hộp thoại nhập mật khẩu).
- **Lối tắt màn hình chính** cho một file: MethodChannel tự viết gọi `ShortcutManagerCompat.requestPinShortcut`
  (Android 8.0+; Android 7 ẩn tính năng này). App đọc intent khi khởi động để mở đúng file.
- **PDF→ảnh:** chọn trang (tất cả/khoảng), định dạng JPG/PNG, độ phân giải (pixel = point / 72 × DPI) bằng `pdfx`.
  `pdfx` trên Android không mở được file có mật khẩu → Syncfusion giải mã ra bytes tạm trong bộ nhớ trước.

### Phần 3 — Công cụ PDF
- **Gộp** nhiều PDF (hộp thoại đặt tên "A & B to PDF"), **tách** theo khoảng/từng trang, **sắp xếp lại / xoá / xoay /
  trích trang**. Syncfusion không có API merge/import → tự viết bằng `page.createTemplate()` vẽ sang tài liệu mới;
  **chấp nhận mất annotation, form, link** ở file kết quả.
- **Đặt mật khẩu** (AES-256) và **gỡ mật khẩu**; file bị khoá hiện biểu tượng ổ khoá. Phát hiện file khoá bằng cách
  mở không mật khẩu và bắt exception.
- **Watermark** chữ hoặc ảnh, có độ mờ và góc xoay, áp mọi trang.
- **Tạo tài liệu trắng:** mẫu trắng / kẻ dòng / kẻ ô, tiêu đề, khổ giấy, màu nền, danh mục, số trang (1–1000).

### Phần 4 — Chỉnh sửa PDF
- Tô sáng, gạch chân, gạch ngang, gạch sóng, ghi chú dán — có sẵn trong `SfPdfViewer`, lưu bằng `saveDocument()`.
- **Chữ ký:** vẽ bằng `SfSignaturePad`, lưu lại để dùng tiếp; lớp đặt vị trí tự viết (kéo, đổi cỡ), đổi toạ độ
  màn hình → toạ độ PDF, vẽ bằng `PdfBitmap`.
- **Điền form PDF** (ô chữ, checkbox, radio, danh sách chọn) trong viewer.

### Phần 5 — Chuyển đổi
- **→ PDF:** chữ gõ, TXT, DOCX, XLSX. Văn bản dùng `PdfTextElement` + `PdfLayoutType.paginate`; bảng dùng `PdfGrid`.
  Nhúng font Noto (OFL 1.1): Noto Sans (Latin/Việt/Indonesia), Noto Sans SC/JP/KR — Syncfusion
  tự subset nên PDF vẫn nhỏ; APK tăng khoảng 20MB do font CJK (chấp nhận).
- **PDF →** TXT (`PdfTextExtractor`), DOCX (gom dòng thành đoạn theo khoảng cách dọc, lề trái, cỡ chữ; cỡ chữ lớn
  hơn trung vị → heading), XLSX (gom từ theo trục y thành hàng, mép trái theo trục x thành cột; ≥3 hàng liên tiếp
  cùng số cột → bảng; ghi bằng `syncfusion_flutter_xlsio`). Kết quả **không giữ nguyên bố cục** gốc.

### Phần 6 — Đọc file Office
- DOCX: `docx_file_viewer` (cần thử với file thật; dự phòng tự parse bằng `archive` + `xml`).
- XLSX: đọc bằng `excel`, lưới tự vẽ (`two_dimensional_scrollables`) có ô gộp, nhiều sheet.
- TXT: hiển thị trực tiếp, tự nhận mã hoá UTF-8/UTF-16.
- PPTX: tự render — đọc `presentation.xml` (kích thước slide), từng `slideN.xml` (`p:sp`, `p:pic`,
  `p:graphicFrame`, vị trí `a:off`/`a:ext` đổi từ EMU), vẽ bằng `Stack` + `Positioned`, kế thừa vị trí placeholder
  từ layout/master. Công sức lớn (3–4 tuần).
- .doc / .xls / .ppt đời cũ: mở bằng app khác (`open_filex`, copy vào cache trước).
- Nhận file app khác gửi/mở sang (`receive_sharing_intent` + intent-filter cho PDF/DOCX/XLSX/PPTX/TXT).

### Phần 7 — Máy quét + OCR
- `cunning_document_scanner`: tự nhận viền và chỉnh vuông góc (ML Kit qua Play Services); máy không có Play Services →
  kéo viền thủ công. iOS dùng VisionKit qua cùng gói.
- OCR `google_mlkit_text_recognition` (model đóng sẵn, offline): Latin (gồm tiếng Việt), Trung, Nhật, Hàn.
- Xuất PDF / DOCX / TXT.

## 3. Kiến trúc

Feature-first + Riverpod. Code Flutter nằm ở `app/`.

```
app/lib/
  main.dart, app.dart          MaterialApp.router, theme, locale
  core/
    theme/                     màu đỏ chủ đạo, màu theo loại file, sáng/tối
    router/                    go_router
    l10n/                      app_{vi,en,zh,ja,ko,id}.arb
    errors/                    AppError (sealed)
    utils/                     hàm thuần: định dạng dung lượng/ngày, tên file không trùng, ánh xạ đuôi → loại…
  data/
    db/                        drift: documents, favorites, recents, bookmarks
    settings/                  shared_preferences: ngôn ngữ, giao diện, khổ giấy mặc định, thư mục lưu
    file_scanner/              quét file trong isolate
  engines/
    pdf_engine.dart            interface PdfEngine
    syncfusion_pdf_engine.dart
    pdf_rasterizer.dart        pdfx
    ocr_engine.dart            ML Kit
    office/                    docx, xlsx, pptx parser
  features/
    documents/ image_to_pdf/ reader/ pdf_tools/ editor/ convert/ office_viewer/ scanner/ settings/
app/test/
  unit/ widget/ fixtures/
```

- **UI không gọi thẳng** Syncfusion, pdfx, ML Kit — luôn qua `engines/`. Đổi thư viện chỉ thay lớp cài đặt.
- Logic tách thành **hàm thuần** để unit test.
- Gói chính: `flutter_riverpod` 3.x, `go_router`, `drift`, `shared_preferences`, `syncfusion_flutter_pdf` /
  `_pdfviewer` / `_signaturepad` / `_xlsio` 35.x, `pdfx`, `printing`, `photo_manager`, `image_picker`,
  `image_cropper`, `image`, `permission_handler`, `share_plus`, `open_filex`, `receive_sharing_intent`, `excel`,
  `docx_file_viewer`, `archive`, `xml`, `cunning_document_scanner`, `google_mlkit_text_recognition`,
  `intl`. Phiên bản cụ thể chốt trong kế hoạch từng phần.

## 4. Giao diện chung

- **Điều hướng** đúng ảnh app gốc: ☰ (menu bên) + tab loại file + lưới loại/công cụ + nút ＋. Không có bottom nav.
- **Hộp thoại:** thẻ bo góc giữa màn hình, tiêu đề đậm, ô nhập nền vàng nhạt, nút **CANCEL** (viền) và nút đỏ đặc
  (OK / Merge / Accept).
- **Màu:** chủ đạo đỏ `#E5393B`. Theo loại file: PDF `#E53935`, DOC `#1E88E5`, XLS `#43A047`, PPT `#F4511E`,
  TXT `#78909C`, ảnh `#8E24AA`. Giao diện tối nền `#121212`, giữ màu loại file.
- **Chữ:** UI dùng font hệ thống; Noto chỉ nhúng khi xuất PDF.
- **Biểu tượng:** Material Symbols cho chức năng; biểu tượng loại file (trang gập góc + nhãn) tự vẽ SVG.
- **Định dạng** ngày, dung lượng theo ngôn ngữ đang chọn.
- **Trạng thái:** danh sách trống có hình + chữ + nút hành động; đang quét có skeleton + số file đã tìm;
  việc lâu có hộp thoại tiến độ % + nút huỷ.

## 5. Xử lý lỗi

- `AppError` thống nhất: `WrongPassword`, `CorruptFile`, `UnsupportedFormat`, `NoSpace`, `PermissionDenied`,
  `Cancelled`. UI đổi mã lỗi thành câu thông báo theo ngôn ngữ.
- Việc nặng (tạo PDF, gộp, OCR, chuyển đổi, quét file) chạy isolate, có tiến độ, huỷ được.
- **Không ghi đè file gốc:** kết quả là file mới (`ten_merged.pdf`, `ten_locked.pdf`…). Ghi ra `.tmp` rồi đổi tên.
  Trùng tên → thêm ` (1)`, ` (2)`…
- Ảnh hỏng → bỏ qua và báo số ảnh bị bỏ. Hết dung lượng/lỗi ghi → báo lý do, không để file dở.
- File tạm dọn khi mở app.

## 6. Test & kiểm chứng

- **TDD** cho hàm thuần và engine: lọc/sắp xếp, định dạng dòng thông tin file, ánh xạ đuôi → loại, bố cục ảnh trên
  trang (khổ + lề + hướng), tên file không trùng, gom dòng thành đoạn, đoán bảng, parse DOCX/XLSX/PPTX,
  đổi toạ độ chữ ký.
- **Fixtures** `app/test/fixtures/`: PDF thường, có mật khẩu, có form; DOCX/XLSX/PPTX; văn bản 6 thứ tiếng.
- **Widget test** cho màn hình chính của mỗi phần.
- **Kiểm biên dịch:** `flutter analyze`. Không tự chạy app; người dùng chạy emulator/máy thật theo checklist.
- **Spike đầu Phần 1 (~1 ngày), làm trước khi dựng màn hình:**
  1. Xuất đoạn tiếng Việt (dấu chồng) ra PDF bằng Syncfusion + Noto, kiểm dấu đặt đúng chỗ.
  2. PDF có mật khẩu: Syncfusion giải mã → `pdfx` render ra ảnh.
  Hỏng → báo người dùng và chốt cách xử lý trước khi đi tiếp.

## 7. Môi trường (người dùng tự cài)

Flutter SDK stable; Android Studio (Android SDK 36, emulator Android 14, JDK 17 đi kèm);
`flutter doctor --android-licenses`; `flutter doctor` không còn ✗ ở mục Android;
đăng ký Syncfusion Community License (Flutter không cần nhập key vào code).

## 8. Rủi ro

| Rủi ro | Ảnh hưởng | Cách xử lý |
|---|---|---|
| Syncfusion đặt sai dấu chồng tiếng Việt | Phần 5 | Spike đầu Phần 1; chuẩn hoá NFC hoặc đổi cách vẽ chữ |
| OCR dấu chồng tiếng Việt chưa được đo | Phần 7 | Đo trên 20–30 mẫu thật |
| Máy quét cần Play Services | Phần 7 | Chế độ kéo viền thủ công |
| Font CJK làm APK +~20MB | Phần 5 | Chấp nhận (dùng cá nhân) |
| `docx_file_viewer` còn non, 1 tác giả | Phần 6 | Dự phòng tự parse |
| PPTX tự viết, công sức lớn | Phần 6 | Làm sau cùng trong phần 6, chấp nhận hiển thị gần đúng |
| PDF→DOCX/XLSX không giữ bố cục | Phần 5 | Nói rõ trong UI |
| Gộp/tách mất annotation, form, link | Phần 3 | Chấp nhận, ghi chú trong UI |
| Lối tắt màn hình chính cần Android 8.0+ | Phần 2 | Ẩn trên Android 7 |
| Điều khoản Syncfusion Community thay đổi | Toàn app | Code PDF sau `PdfEngine` để đổi được |

## 9. Nguồn

- App mẫu: [Google Play (vi)](https://play.google.com/store/apps/details?id=com.readpdf.pdfreader.pdfviewer&hl=vi),
  [Google Play (en)](https://play.google.com/store/apps/details?id=com.readpdf.pdfreader.pdfviewer&hl=en_US)
  (mô tả, 8 ảnh chụp màn hình, danh sách quyền, đánh giá người dùng),
  [Uptodown](https://com-readpdf-pdfreader-pdfviewer.en.uptodown.com/android),
  [AppGoblin](https://www.appgoblin.info/apps/com.readpdf.pdfreader.pdfviewer).
- Thư viện: [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf),
  [syncfusion_flutter_pdfviewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer),
  [Syncfusion Community License](https://www.syncfusion.com/products/communitylicense),
  [pdfx](https://pub.dev/packages/pdfx), [printing](https://pub.dev/packages/printing),
  [docx_file_viewer](https://pub.dev/packages/docx_file_viewer), [excel](https://pub.dev/packages/excel),
  [open_filex](https://pub.dev/packages/open_filex), [receive_sharing_intent](https://pub.dev/packages/receive_sharing_intent),
  [photo_manager](https://pub.dev/packages/photo_manager), [image](https://pub.dev/packages/image),
  [cunning_document_scanner](https://pub.dev/packages/cunning_document_scanner),
  [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition),
  [ML Kit languages](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages),
  [drift](https://pub.dev/packages/drift), [flutter_riverpod](https://pub.dev/packages/flutter_riverpod).
