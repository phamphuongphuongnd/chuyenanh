# Phiotron PDF

App di động **Phiotron PDF** (`com.phuong.pdfoffice`): ảnh ↔ PDF, đọc PDF / Word / Excel / PowerPoint / TXT,
công cụ PDF, chỉnh sửa, chuyển đổi, máy quét + OCR. **Miễn phí, không quảng cáo, không mua trong ứng dụng, không cần
tài khoản; tệp được xử lý ngay trên máy.** Chạy trên Android và iOS; dự kiến phát hành lên Google Play và App Store.
Giao diện, logo, icon và tài nguyên do dự án tự thiết kế. Bản quyền: xem [mục 11](#11-bản-quyền--giấy-phép) và [`LICENSE`](LICENSE).

> Thiết kế đầy đủ: [`docs/superpowers/specs/2026-10-25-pdf-office-design.md`](docs/superpowers/specs/2026-10-25-pdf-office-design.md).
> Mục lục kiến thức dự án: [`lmm-wiki/index.md`](lmm-wiki/index.md).

## 1. Trạng thái hiện tại

| Phần | Trạng thái |
|---|---|
| Móng `app/` (theme, router, l10n, DB, interface engine, widget dùng chung) | Xong, có test |
| 4 thư viện Dart thuần trong `packages/` | Xong; `office_reader`, `pptx_reader` đã thử file thật |
| 10 tính năng T1…T10 | **Đã có code + UI và đã ghép vào nhánh `feat/pdf-office`** (kèm OCR cho PDF quét ảnh, mở hyperlink DOCX/PPTX) |
| Kiểm bằng máy | `flutter analyze` sạch · `flutter test` **692/692** · `flutter build apk --debug` thành công |
| **Chạy trên điện thoại thật** | **Chưa.** Mọi tính năng mới chỉ qua test tự động → cài thử trên Samsung Galaxy A13 và sửa lỗi lộ ra |

Chi tiết từng tính năng, hạn chế và việc còn lại: [`lmm-wiki/modules/tinh-nang-t1-t10.md`](lmm-wiki/modules/tinh-nang-t1-t10.md);
mô tả việc ban đầu: [`docs/superpowers/plans/2026-10-26-feature-tasks.md`](docs/superpowers/plans/2026-10-26-feature-tasks.md).

## 2. Chức năng (theo spec)

- **Tài liệu:** quét toàn máy (PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT), tab theo loại, tìm kiếm, sắp xếp, Gần đây, Yêu thích.
- **Ảnh → PDF:** chọn nhiều ảnh, xoay / cắt / lọc, đổi thứ tự, chọn khổ giấy.
- **Đọc:** PDF (tìm, bookmark, chế độ tối, mật khẩu, in, PDF → ảnh), DOCX, XLSX, PPTX, TXT.
- **Công cụ PDF:** gộp, tách, sắp xếp trang, khoá / mở khoá, watermark, tạo PDF trắng.
- **Chỉnh sửa PDF:** chú thích, chữ ký, điền form.
- **Chuyển đổi:** Text / Word / Excel → PDF; PDF → Text / Word / Excel.
- **Máy quét + OCR** (Google ML Kit).
- **Cài đặt:** ngôn ngữ, giao diện sáng / tối, thư mục lưu, giới thiệu.
- **6 ngôn ngữ:** vi, en, zh, ja, ko, id.

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

Lấy mã và thư viện (**code nằm ở nhánh `feat/pdf-office`, không phải `master`** — xem [mục 7](#7-git-nhánh-và-quy-trình)):

```bash
git clone -b feat/pdf-office https://github.com/phamphuongphuongnd/chuyenanh.git
cd chuyenanh/app
flutter pub get
bash tool/fetch_fonts.sh                               # font Noto ~39 MB, KHÔNG nằm trong git (cần cho chữ Việt/CJK khi xuất PDF)
dart run tool/merge_arb.dart && flutter gen-l10n       # lib/l10n/ bị gitignore, phải sinh trên máy mới
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

APK ra ở `build/app/outputs/flutter-apk/app-debug.apk` (~261 MB, đã gồm font Noto). Lần build đầu rất lâu (20–30 phút) vì Gradle tải NDK
và các platform còn thiếu. Thêm plugin mới thì **build thử APK ngay** — lỗi Gradle không lộ ra khi chỉ chạy analyze / test.
Các lỗi Gradle đã gặp và cách sửa: `lmm-wiki/concepts/build-android.md`.

## 7. Git: nhánh và quy trình

| Nhánh | Ý nghĩa |
|---|---|
| `feat/pdf-office` | **Nhánh làm việc chính.** Chứa toàn bộ code hiện tại (móng + 4 thư viện + 10 tính năng), luôn phải `analyze` sạch và test xanh. |
| `master` | **Chưa gộp**, hiện chỉ có bộ khung ban đầu (skill, wiki). Chỉ gộp `feat/pdf-office` vào đây khi app đã chạy ổn trên máy thật. GitHub hiển thị README của nhánh mặc định nên **README này chỉ thấy khi mở nhánh `feat/pdf-office`**. |
| `feat/t1-documents` … `feat/t10-settings` | **Lịch sử** từng tính năng (agent làm riêng rồi đã ghép vào `feat/pdf-office`). Không làm tiếp trên các nhánh này; có thể xoá khi không cần lịch sử. |

Quy trình sửa / thêm:

```bash
git fetch origin
git checkout feat/pdf-office && git pull
git checkout -b fix/<mo-ta-ngan>            # hoặc feat/<tên>, tách từ feat/pdf-office
# ... sửa code, viết test trước (TDD) ...
cd app && dart run tool/merge_arb.dart && flutter gen-l10n
flutter analyze && flutter test            # phải sạch
flutter build apk --debug                  # bắt buộc nếu đổi plugin / Manifest / Gradle
git add -A && git commit                   # message tiếng Việt không dấu, commit thường xuyên
git push -u origin fix/<mo-ta-ngan>        # rồi mở Pull Request vào feat/pdf-office
```

Quy ước:

- **Không push thẳng `master`.** Chỉ gộp `master` khi chủ dự án quyết định; không force-push các nhánh dùng chung.
- Mỗi người chỉ sửa thư mục `features/<f>` của mình + test tương ứng. Muốn đổi `pubspec.yaml`, `core/**`, `data/db/**`, Manifest hay
  interface `*_engine.dart` thì nêu rõ trong Pull Request để người giữ móng duyệt (đụng nhiều nhánh một lúc dễ xung đột).
- **Không commit** file sinh ra / nặng: `app/lib/l10n/`, `app/build/`, `app/assets/fonts/*.ttf`, `*.apk`, `.claude/worktrees/` (đã có trong `.gitignore`).
  File sinh bắt buộc có: `app/lib/data/db/app_database.g.dart` (drift) **được commit**.
- Gộp nhiều nhánh: merge vào một nhánh tạm, chạy `analyze` + `test` **một lần** cho bản ghép rồi mới đưa vào `feat/pdf-office`.
- Đọc `lmm-wiki/index.md` trước khi làm; cuối phiên cập nhật wiki (`/luu-wiki`) để người sau không phải làm lại.

## 8. Quyền Android

App quét toàn bộ bộ nhớ nên cần `MANAGE_EXTERNAL_STORAGE` (Android 11+) hoặc quyền đọc / ghi bộ nhớ (Android 7–10).
Từ chối quyền thì app chuyển sang chế độ chọn file thủ công (`file_picker`).
Ngoài ra: máy ảnh (máy quét), ảnh / media (chọn ảnh).

## 9. Kiểm thử trên máy thật

Máy thử mục tiêu: Samsung Galaxy A13. Hai cách:

- **Cắm cáp** (khuyên dùng — đọc được log lỗi): cài Samsung USB Driver, bật Gỡ lỗi USB, chọn Truyền tệp, bấm Cho phép; kiểm `adb devices`, rồi `flutter run`.
- **Không cáp:** chép `app/build/app/outputs/flutter-apk/app-debug.apk` (~261 MB, **không nằm trong git**) sang điện thoại, cho phép cài từ nguồn
  không rõ, rồi bật "Truy cập tất cả tệp" cho Phiotron PDF.

Checklist kiểm từng tính năng: `lmm-wiki/modules/tinh-nang-t1-t10.md`. Đặc biệt cần đo trên máy thật: quyền đọc file, camera, máy quét tự nhận viền,
**OCR tiếng Việt dấu chồng (ặ ỗ ữ ẫ ậ ề ở)**, lối tắt màn hình chính, tốc độ với file lớn.

## 10. Giới hạn đã biết

- **Chưa chạy trên điện thoại thật** (xem [mục 1](#1-trạng-thái-hiện-tại)); nhiều test dùng camera / viewer / ổ đĩa giả.
- Font Noto **không nằm trong git** — chạy `bash app/tool/fetch_fonts.sh`; thiếu font thì PDF xuất ra lỗi chữ Việt có dấu và CJK. Ba font CJK là bản biến thiên nên nét hơi mảnh.
- Gộp / tách PDF mất annotation, form, link ở file kết quả (Syncfusion không có API gộp). PDF → Word / Excel không giữ nguyên bố cục.
- `pptx_reader`: hình preset (mũi tên…) chưa vẽ đúng, gradient chỉ lấy màu đầu, SmartArt / media / WordArt chưa thử.
- `office_reader`: định dạng ngày kiểu Mỹ bị đảo, rich text trong ô Excel và `vAlign` bảng Word chưa xử lý; chữ Excel chưa tràn sang ô bên cạnh.
- OCR dùng Google ML Kit (Latin gồm tiếng Việt, Trung, Nhật, Hàn); độ chính xác tiếng Việt dấu chồng chưa đo.
- PDF từ máy quét có lớp chữ trong suốt để tìm kiếm / bôi chọn — chưa thử trên trình đọc ngoài.
- Ghi chú build Android thay đổi theo bản AGP / plugin — đọc `lmm-wiki/concepts/build-android.md` trước khi nâng cấp hoặc thêm plugin.

## 11. Bản quyền & giấy phép

- **Mã nguồn, logo, tên "Phiotron PDF":** độc quyền của tác giả — xem [`LICENSE`](LICENSE). Repo sẽ chuyển sang
  **riêng tư (private)** sau khi app có mặt trên store (GitHub → Settings → General → Danger Zone → Change visibility),
  vì lúc đó link tải APK/IPA trên GitHub Release không còn dùng. Lưu ý: repo private chỉ có 2.000 phút GitHub Actions
  miễn phí/tháng và runner macOS tính ×10 (≈200 phút) → build iOS trên CI bị giới hạn.
- **Thư viện bên thứ ba:** danh sách đầy đủ + mã SPDX ở [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md), sinh lại
  bằng `dart run tool/license_report.dart` (trong `app/`) **mỗi khi thêm/đổi thư viện**. Lệnh báo lỗi nếu có thư viện
  GPL / AGPL / LGPL hoặc chưa rõ giấy phép — không đưa những thư viện đó vào app phát hành trên store.
- **Trang "Giấy phép mã nguồn mở" trong app** (Cài đặt → Giới thiệu): Flutter tự liệt kê gói pub; phần không tự có
  (font Be Vietnam Pro, font Noto, thư viện Android uCrop) khai ở `app/lib/core/licenses/bundled_licenses.dart`.
  Thêm font hoặc thư viện native mới thì khai thêm ở đó.
- **Font:** Be Vietnam Pro (`app/assets/ui_fonts/OFL.txt`) và Noto Sans / SC / JP / KR (`app/assets/fonts/OFL-Noto.txt`)
  theo SIL Open Font License 1.1 — file giấy phép **phải đi kèm** font khi phát hành. Không dùng font của Windows/macOS
  (Arial, SimSun, Yu Gothic…) trong app hay trong repo.
- **Syncfusion Flutter (PDF, PDF Viewer, XlsIO, Signature Pad):** chỉ được dùng khi có Syncfusion Community License
  (miễn phí: doanh thu < 1 triệu USD/năm, ≤ 5 lập trình viên, ≤ 10 nhân viên). **Đã nộp đơn 30/10/2026 (cá nhân /
  Hobbyist), đang chờ duyệt.** Giữ email duyệt + chụp trang *License & Downloads* làm bằng chứng; gia hạn nếu
  Syncfusion yêu cầu. Bản Flutter **không cần** license key — không dán key vào code hay commit.
- **Trước khi phát hành:** tự tra tên "Phiotron" trên WIPO Global Brand Database và cổng Cục Sở hữu trí tuệ Việt Nam;
  tên, mô tả, icon và ảnh chụp trên store phải tự làm, không chép chữ / ảnh / tên của app khác.
