# PDF Office

App di động dùng cá nhân (`com.phuong.pdfoffice`), mô phỏng app Google Play "Image to PDF: PDF Converter"
(TrustedOffice): ảnh ↔ PDF, đọc PDF / Word / Excel / PowerPoint / TXT, công cụ PDF, chỉnh sửa, chuyển đổi,
máy quét + OCR. **Chạy offline, không quảng cáo, không lên store.** Android làm trước, iOS để sau.

> Thiết kế đầy đủ: [`docs/superpowers/specs/2026-10-25-pdf-office-design.md`](docs/superpowers/specs/2026-10-25-pdf-office-design.md).
> Mục lục kiến thức dự án: [`lmm-wiki/index.md`](lmm-wiki/index.md).

## 1. Trạng thái hiện tại

| Phần | Trạng thái |
|---|---|
| Móng `app/` (theme, router, l10n, DB, interface engine, widget dùng chung) | Xong, có test |
| 4 thư viện Dart thuần trong `packages/` | Xong; `office_reader`, `pptx_reader` đã thử file thật |
| Build APK debug | Đã build được (xem [mục 6](#6-build-apk)) |
| 10 tính năng T1…T10 | **Mới có logic/engine + test, UI hầu như chưa có** — mỗi việc nằm trên nhánh `feat/t1-documents` … `feat/t10-settings` |

Chi tiết từng tính năng, file sở hữu và việc còn lại: [`docs/superpowers/plans/2026-10-26-feature-tasks.md`](docs/superpowers/plans/2026-10-26-feature-tasks.md)
(mục E là bảng bàn giao) và [`lmm-wiki/modules/tinh-nang-t1-t10.md`](lmm-wiki/modules/tinh-nang-t1-t10.md).

## 2. Chức năng (theo spec)

- **Tài liệu:** quét toàn máy (PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT), tab theo loại, tìm kiếm, sắp xếp, Gần đây, Yêu thích.
- **Ảnh → PDF:** chọn nhiều ảnh, xoay / cắt / lọc, đổi thứ tự, chọn khổ giấy.
- **Đọc:** PDF (tìm, bookmark, chế độ tối, mật khẩu, in, PDF → ảnh), DOCX, XLSX, PPTX, TXT.
- **Công cụ PDF:** gộp, tách, sắp xếp trang, khoá / mở khoá, watermark, tạo PDF trắng.
- **Chỉnh sửa PDF:** chú thích, chữ ký, điền form.
- **Chuyển đổi:** Text / Word / Excel → PDF; PDF → Text / Word / Excel.
- **Máy quét + OCR** (Google ML Kit).
- **Cài đặt:** ngôn ngữ, giao diện sáng / tối, thư mục lưu, giới thiệu.
- **6 ngôn ngữ:** vi, en, zh, ja, ko, id (đã bỏ tiếng Thái).

## 3. Công nghệ

Dart ≥ 3.13.7 · Flutter 3.47.8 · Riverpod 3 · go_router · drift (SQLite) · Syncfusion Flutter PDF (Community) · pdfx ·
`image` · `file_picker` · `photo_manager` · `google_mlkit_text_recognition`. Danh sách đầy đủ: [`pubspec.yaml`](app/pubspec.yaml).

Quyết định kiến trúc và lý do: `lmm-wiki/decisions/0001…0004`.

## 4. Cấu trúc thư mục

```
app/
  lib/
    main.dart, app.dart        khởi động, MaterialApp.router
    core/                      theme, router (routes.dart), errors (AppError), utils, widgets dùng chung,
                               tools/tool_registry.dart, navigation/open_document.dart, l10n core
    data/                      db/ (drift: documents, favorites, recents, bookmarks), settings/, file_scanner/
    engines/                   interface + impl xử lý nặng (pdf, convert, office, ocr)
    features/<tên>/            documents, image_to_pdf, reader, pdf_tools, editor, convert,
                               office_viewer, office_pptx, scanner, settings
                               (mỗi feature: *_routes.dart, *_providers.dart, l10n/<prefix>_<locale>.arb)
    l10n/                      SINH TỰ ĐỘNG (gitignore) — không sửa tay
  test/                        phản chiếu cấu trúc lib/
  tool/merge_arb.dart          gộp các file .arb của core + từng feature
  android/, ios/
packages/                   office_reader · pptx_reader · pdf_layout · image_ops (Dart thuần, có test riêng)
```

Quy ước chính:

- Mỗi người / agent **chỉ sửa thư mục `features/<f>` của mình** + test tương ứng. Muốn đổi `pubspec.yaml`, `core/**`,
  `data/db/**`, Manifest hay file interface `*_engine.dart` thì ghi vào "Cần MÓNG bổ sung" thay vì tự sửa.
- Màn hình gọi nhau qua **route** (`Routes.*` trong `lib/core/router/routes.dart`), không import chéo feature.
- Việc nặng (PDF, ảnh, quét file) chạy trong isolate / engine async, có `ProgressCallback` + `CancelToken`.
- Không ghi đè file gốc: dùng `uniqueOutputPath` + `writeAtomically`; thư mục lưu lấy từ `outputDirectoryProvider`.
- Lỗi ném / bắt bằng `AppError`, hiện bằng `appErrorMessage(context, e)`.
- Chuỗi giao diện: key bắt đầu bằng prefix của feature (`docs_`, `img2pdf_`, `reader_`, `tools_`, `edit_`, `conv_`,
  `office_`, `pptx_`, `scan_`, `settings_`), **đủ 6 ngôn ngữ**.
- Chữ Việt khi xuất PDF phải chuẩn hoá NFC, CJK phải fallback font theo hệ chữ (xem `lmm-wiki/concepts/xuat-chu-ra-pdf.md`).

## 5. Chuẩn bị môi trường

Cần (Windows):

1. **Flutter 3.47.8.** Cách dự án đang dùng: clone vào `C:\src\flutter` và gọi bằng đường dẫn đầy đủ, không sửa PATH.
   ```bash
   git clone --depth 1 -b 3.47.8 https://github.com/flutter/flutter.git C:/src/flutter
   ```
   Trong Git Bash: `export PATH="/c/src/flutter/bin:$PATH"`. Lần chạy đầu Flutter tự tải Dart SDK.
2. **Chỉ khi build APK:** JDK 21 và Android SDK dạng dòng lệnh (platform 36, build-tools 36). Bạn phải tự chấp nhận
   license Android (`flutter doctor --android-licenses`) và trỏ `flutter config --android-sdk <thư mục SDK>`.

Lấy mã và thư viện:

```bash
git clone https://github.com/phamphuongphuongnd/chuyenanh.git
cd chuyenanh/app
flutter pub get
```

## 6. Lệnh hằng ngày

Chạy trong `app/`:

```bash
dart run tool/merge_arb.dart && flutter gen-l10n   # gộp .arb rồi sinh lib/l10n/ (làm lại mỗi khi sửa .arb)
flutter analyze                                    # phải "No issues found!"
flutter test                                       # phải pass toàn bộ
flutter test test/features/<tên>                   # chỉ test một feature
flutter run                                        # chạy trên máy / emulator đã kết nối
```

Sửa schema drift hoặc thêm bảng thì sinh lại code (việc của người giữ móng):

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Build APK

```bash
flutter build apk --debug > build.log 2>&1   # ghi ra file để đọc lỗi đầy đủ
```

APK ra ở `build/app/outputs/flutter-apk/app-debug.apk` (~212 MB). Lần build đầu rất lâu (20–30 phút) vì Gradle tải NDK
và các platform còn thiếu. Thêm plugin mới thì **build thử APK ngay** — lỗi Gradle không lộ ra khi chỉ chạy analyze / test.
Các lỗi Gradle đã gặp và cách sửa: `lmm-wiki/concepts/build-android.md`.

## 7. Làm một tính năng (T1…T10)

```bash
git fetch origin
git checkout -b feat/t1-documents origin/feat/t1-documents   # đổi tên nhánh theo bảng bàn giao
cd app
flutter pub get
dart run tool/merge_arb.dart && flutter gen-l10n
flutter analyze && flutter test        # phải sạch TRƯỚC khi làm tiếp (phần agent làm dở chưa kiểm lại)
```

1. Đọc spec, hợp đồng chia việc (`docs/superpowers/plans/2026-10-25-parallel-build-contract.md`, mục 1, 2, 3, 7) và
   mô tả việc của bạn trong `feature-tasks.md`.
2. Viết test trước cho logic thuần (TDD), widget test cho màn chính.
3. Commit thường xuyên, message tiếng Việt không dấu.
4. Xong: `flutter analyze`, `flutter test`, `flutter build apk --debug` đều sạch → mở Pull Request vào `feat/pdf-office`.

## 8. Quyền Android

App quét toàn bộ bộ nhớ nên cần `MANAGE_EXTERNAL_STORAGE` (Android 11+) hoặc quyền đọc / ghi bộ nhớ (Android 7–10).
Từ chối quyền thì app chuyển sang chế độ chọn file thủ công (`file_picker`).
Ngoài ra: máy ảnh (máy quét), ảnh / media (chọn ảnh).

## 9. Kiểm thử trên máy thật

Máy thử mục tiêu: Samsung Galaxy A13. Cần Samsung USB Driver và bật Gỡ lỗi USB, sau đó `flutter run` hoặc cài APK
debug. Checklist kiểm từng tính năng nằm trong báo cáo của mỗi việc T1…T10.

## 10. Giới hạn đã biết

- 10 tính năng chủ yếu chưa có UI (xem [mục 1](#1-trạng-thái-hiện-tại)).
- Font Noto cho CJK / tiếng Việt khi xuất PDF (`assets/fonts/`) chưa được tải vào repo.
- `pptx_reader`: hình preset (mũi tên…) chưa có đường vẽ, gradient chỉ lấy stop đầu, SmartArt / media / WordArt chưa thử.
- `office_reader`: định dạng ngày kiểu Mỹ bị đảo, rich text trong ô Excel và `vAlign` bảng Word chưa xử lý.
- OCR dùng Google ML Kit (không còn tiếng Thái; `flutter_tesseract_ocr` đã gỡ vì không chạy với AGP 9).
- Tài liệu cũ: ghi chú build Android thay đổi theo bản AGP / plugin — đọc `build-android.md` trước khi nâng cấp.
