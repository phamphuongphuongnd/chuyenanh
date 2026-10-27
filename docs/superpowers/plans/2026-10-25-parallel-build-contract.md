# Hợp đồng chia việc song song — PDF Office

> Mọi agent **đọc file này + spec** `docs/superpowers/specs/2026-10-25-pdf-office-design.md` trước khi làm.
> Mục tiêu: nhiều agent chạy cùng lúc, mỗi agent **chỉ sửa file mình sở hữu**, ghép lại không xung đột.

## 0. Thông số chung

- Dự án Flutter ở `app/`, `name: pdf_office`, org `com.phuong` → applicationId `com.phuong.pdfoffice`, label "PDF Office".
- Flutter SDK: `C:/src/flutter/bin/flutter` (Git Bash: `/c/src/flutter/bin/flutter`). **Không** sửa PATH hệ thống.
- Android: minSdk 24, compileSdk 36, targetSdk 36. iOS: để mặc định của `flutter create`, không build.
- Dart: null-safety, `flutter_lints`. Không dùng `print` (dùng `debugPrint`).
- State: **Riverpod 3** (`flutter_riverpod`, viết provider tay, **không** dùng riverpod_generator).
- Router: `go_router`. DB: `drift` (+ `drift_flutter`), codegen bằng `build_runner` — **chỉ móng được chạy build_runner cho DB**.
- Lệnh kiểm (chạy trong `app/`):
  - `dart run tool/merge_arb.dart && /c/src/flutter/bin/flutter gen-l10n` — gộp & sinh chuỗi đa ngôn ngữ
  - `/c/src/flutter/bin/flutter analyze` — phải **0 error, 0 warning** trong file mình sở hữu
  - `/c/src/flutter/bin/flutter test test/<thư mục của mình>` — phải pass
- Flutter giữ "startup lock": nhiều agent chạy lệnh flutter cùng lúc sẽ phải chờ nhau — **gom lệnh, đừng chạy vặt**.
- **Không** chạy `flutter run`, `flutter build`, không cài app lên máy (người dùng tự chạy).
- **Không** tải file/asset từ Internet (font, model, traineddata). Cần asset thì code theo đường dẫn quy ước ở mục 5
  và ghi vào báo cáo "cần tải".
- **Không** đọc/sửa `.env*`, `*.key`, `*.pem`, `auth*.json`.
- Commit trong worktree của mình (message tiếng Việt không dấu, kết thúc bằng dòng
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). **Không push, không merge.**

## 1. Cấu trúc & quyền sở hữu file

| Đường dẫn | Chủ sở hữu |
|---|---|
| `app/pubspec.yaml`, `app/analysis_options.yaml`, `app/l10n.yaml`, `app/build.yaml` | MÓNG |
| `app/android/**` (Manifest, Gradle) | MÓNG — trừ `MainActivity.kt` + `ShortcutChannel.kt` thuộc **A3** |
| `app/lib/main.dart`, `app/lib/app.dart` | MÓNG |
| `app/lib/core/**` (theme, router, errors, utils, widgets, navigation, tools, l10n core) | MÓNG |
| `app/lib/data/db/**`, `app/lib/data/settings/**` | MÓNG |
| `app/lib/engines/pdf/pdf_security.dart` (+ impl) và **mọi file interface** `app/lib/engines/**/*_engine.dart` | MÓNG |
| `app/tool/merge_arb.dart` | MÓNG |
| `app/lib/features/<feature>/**`, `app/test/features/<feature>/**`, file impl engine của mình | agent tương ứng (mục 3) |
| `app/lib/l10n/**` | **sinh tự động, gitignore** — không ai sửa tay |

Agent **không được sửa file của chủ khác**. Thiếu gì ở MÓNG (một hàm tiện ích, một route, một quyền Manifest) →
**tự viết trong thư mục của mình** nếu được, nếu không thì ghi vào báo cáo mục "Cần MÓNG bổ sung" để người ghép làm.

## 2. Quy ước dùng chung (MÓNG cung cấp)

### 2.1 Route
- `app/lib/core/router/app_router.dart` gộp `List<RouteBase>` từ mỗi feature: mỗi feature có
  `app/lib/features/<f>/<f>_routes.dart` export `final List<RouteBase> <f>Routes = [...]`.
  MÓNG tạo sẵn file này với **màn hình giữ chỗ** (`PlaceholderScreen`); agent thay nội dung.
- Tên route là hằng trong `app/lib/core/router/routes.dart` (MÓNG định nghĩa hết, agent dùng, không đổi):

Path thật (tên nhiều chữ viết kebab-case): `/tools/create-blank`, `/edit/fill-form`, `/convert/text-to-pdf`,
`/convert/word-to-pdf`, `/convert/excel-to-pdf`, `/convert/pdf-to-text`, `/convert/pdf-to-word`, `/convert/pdf-to-excel`,
`/view/docx|xlsx|txt|pptx`. Luôn dùng hằng `Routes.xxx`, không gõ chuỗi. `rootNavigatorKey` ở `app_router.dart`.

| Hằng | Path | Tham số | Feature |
|---|---|---|---|
| `Routes.home` | `/` | — | documents |
| `Routes.search` | `/search` | — | documents |
| `Routes.recents` | `/recents` | — | documents |
| `Routes.favorites` | `/favorites` | — | documents |
| `Routes.imageToPdf` | `/image-to-pdf` | — | image_to_pdf |
| `Routes.pdfReader` | `/reader` | `extra: OpenFileArgs` | reader |
| `Routes.pdfToImage` | `/pdf-to-image` | `extra: String? path` | reader |
| `Routes.merge` `split` `organize` `lock` `unlock` `watermark` `createBlank` | `/tools/<tên>` | `extra: String? path` | pdf_tools |
| `Routes.annotate` `sign` `fillForm` | `/edit/<tên>` | `extra: String path` | editor |
| `Routes.textToPdf` `wordToPdf` `excelToPdf` `pdfToText` `pdfToWord` `pdfToExcel` | `/convert/<tên>` | `extra: String? path` | convert |
| `Routes.docxViewer` `xlsxViewer` `txtViewer` | `/view/<tên>` | `extra: String path` | office_viewer |
| `Routes.pptxViewer` | `/view/pptx` | `extra: String path` | office_pptx |
| `Routes.scanner` | `/scanner` | — | scanner |
| `Routes.settings` `language` `about` | `/settings`, `/settings/language`, `/settings/about` | — | settings |

### 2.2 Mở file theo loại
`app/lib/core/navigation/open_document.dart`: `Future<void> openDocument(BuildContext, String path, {String? password})`
— pdf → reader (`extra: OpenFileArgs`), docx/xlsx/pptx/txt → viewer tương ứng (`extra: String path`), doc/xls/ppt →
`open_filex` (chép vào cache trước). Ghi vào `recents`. Ném `CorruptFile` (file không tồn tại) / `UnsupportedFormat`.
Hàm thuần `String? routeForDocument(path)`. `OpenFileArgs(path, {password, initialPage})` ở `core/navigation/open_file_args.dart`
(`initialPage` 0-based).

### 2.3 Danh sách công cụ (lưới Công cụ, nút ＋)
`app/lib/core/tools/tool_registry.dart`: `const List<ToolSpec> allTools` — mỗi `ToolSpec(id, route, icon, labelKey,
group, inputType)`. MÓNG khai đủ mọi công cụ của spec (19 công cụ). Feature documents chỉ **hiển thị** registry.
`ToolGroup {create, convert, pdfTools, edit}`; `ToolInputType {none, pdf, multiplePdf, pdfRequired, word, excel, text,
images}` — `pdfRequired` (annotate/sign/fillForm): người gọi **chọn PDF trước** rồi push `extra: path`; các loại khác
push được với `extra: null`. Tên hiển thị: `toolLabel(context, tool)`; `toolById(id)`. Tên nhóm: `core_groupXxx`.

### 2.4 Lỗi
`app/lib/core/errors/app_error.dart`: `sealed class AppError implements Exception` với `WrongPassword`,
`PasswordRequired`, `CorruptFile`, `UnsupportedFormat`, `NoSpace`, `PermissionDenied`, `Cancelled`,
`Unknown(Object cause)` (thêm: `CorruptFile([detail])`, `UnsupportedFormat([extension])`). Hàm
`String appErrorMessage(BuildContext, AppError)` cùng file. `AppError.from(Object)` đổi exception bất kỳ
(FileSystemException ENOSPC → `NoSpace`, EACCES/EPERM → `PermissionDenied`, còn lại `Unknown`).

### 2.5 Widget dùng chung (`app/lib/core/widgets/`)
`AppDialog` (thẻ bo góc, tiêu đề đậm, nút CANCEL viền + nút đỏ đặc), `AppTextField` (nền vàng nhạt `#FFF8E1`),
`showConfirmDialog` → `Future<bool>`, `showPasswordDialog({title, message, errorText})` → `Future<String?>`,
`showProgressDialog(context, {title, cancelToken, cancellable})` → `ProgressDialogController` (`update(0..1)`, `close()`,
`cancelToken`), `EmptyState`, `FileTypeIcon(type, {size, locked})` / `FileTypeIcon.forPath(path)` (CustomPaint: trang gập
góc + nhãn màu, `locked` vẽ ổ khoá), `PlaceholderScreen(title, detail)`. Import gộp: `core/widgets/widgets.dart`.
Theme: `core/theme/app_theme.dart` (`AppTheme.light()/dark()`, `AppColors.primary`, `AppColors.forDocType(type)`,
`AppColors.forCategory(cat)` cho màu thanh tiêu đề theo tab).

### 2.6 Tiện ích thuần (`app/lib/core/utils/`) — có unit test
`DocType docTypeFromPath(String)` (`enum DocType {pdf, doc, docx, xls, xlsx, ppt, pptx, txt, image, other}` +
`DocCategory {pdf, doc, xls, ppt, txt}` cho tab), `formatFileSize(int bytes, String locale)`,
`formatFileInfoLine(size, modified, folder, locale)` → `4,35 MB • 07:23 • Download`,
`Future<String> uniqueOutputPath(String dir, String baseName, String ext)` (thêm ` (1)`…),
`Future<File> writeAtomically(String path, List<int> bytes)` (ghi `.tmp` rồi rename),
thư mục lưu: **`await ref.read(outputDirectoryProvider.future)`** (dùng được với `Ref` và `WidgetRef`; theo cài đặt,
mặc định `/storage/emulated/0/Documents/PDF Office`, không tạo được → `<app documents>/PDF Office`) — thay cho
`outputDirectory(ref)` ban đầu, `CancelToken` (`cancel()`, `isCancelled`, `throwIfCancelled()` ném `Cancelled`,
`onCancel(cb)`) + `typedef ProgressCallback = void Function(double)`.
File: `doc_type.dart` (+ `extensionOf`, `DocType.category/isLegacyOffice/label`, `documentExtensions`),
`file_format.dart` (+ `formatDateTime`; cần `initializeDateFormatting()` — `main()` đã gọi, test tự gọi),
`file_paths.dart` (+ `sanitizeFileName`, `parentFolderName`, `baseNameWithoutExtension`), `output_directory.dart`,
`cancel_token.dart`, `page_size.dart` (`enum PageSizeOption {a4, letter, fit}` dùng chung, `pointsToPixels`).

### 2.7 Dữ liệu
- `AppDatabase` (drift) + provider `appDatabaseProvider`. Bảng:
  `documents(path PK, name, ext, size, modifiedMs, folder, scannedAtMs)`,
  `favorites(path PK, addedAtMs)`, `recents(path PK, openedAtMs)`,
  `bookmarks(id PK auto, path, page, createdAtMs)` (page **0-based**; `wholeDocumentPage = -1` là đánh dấu cả tài liệu).
  Data class: `Document`, `Favorite`, `Recent`, `Bookmark`. Import một file: `data/db/app_database.dart`.
  DAO (truy cập `db.documentsDao`…): `DocumentsDao` (`watchAll/getAll({exts})`, `getByPath`, `watchByPath`, `upsert`,
  `upsertAll`, `deleteByPath`, `deleteNotSeenSince(scanStartedMs)`, `clear`), `FavoritesDao` (`watchAll`, `watchPaths`,
  `watchIsFavorite`, `isFavorite`, `add`, `remove`, `toggle`), `RecentsDao` (`watchRecent/getRecent({limit})`, `touch`,
  `remove`, `clear`), `BookmarksDao` (`watchAll`, `watchForPath`, `getForPath`, `add` (không trùng), `removeById`,
  `removePage`, `removeForPath`). `AppDatabase.renamePath(old, new, {newName, newFolder})`, `forgetPath(path)` cập nhật
  mọi bảng. Test: `AppDatabase(NativeDatabase.memory())` (import `package:drift/native.dart`).
- `SettingsRepository` (shared_preferences) + provider (`data/settings/settings_providers.dart`):
  `settingsProvider` (`NotifierProvider<SettingsNotifier, AppSettings>`) — đọc `ref.watch(settingsProvider).locale`
  (null = theo máy) / `.themeMode` / `.defaultPageSize` (`PageSizeOption`) / `.outputDir`; ghi
  `ref.read(settingsProvider.notifier).setLocale/setThemeMode/setDefaultPageSize/setOutputDir(...)` (UI đổi tức thì).
  `sharedPreferencesProvider` được override trong `main()`; test: `SharedPreferences.setMockInitialValues({})` rồi override.

### 2.8 Engine — interface do MÓNG viết, agent viết impl
| Interface (MÓNG) | Impl (agent) | Provider |
|---|---|---|
| `engines/pdf/pdf_security.dart`: `abstract interface class PdfSecurityEngine` — `Future<bool> isEncrypted(bytes)`, `Future<Uint8List> decrypt(bytes, pw)`, `Future<Uint8List> encrypt(bytes, userPw, {ownerPassword})` (AES-256; ném `WrongPassword`/`PasswordRequired`/`CorruptFile`) | MÓNG `syncfusion_pdf_security.dart` (đã có test) | `pdfSecurityProvider` (trong `pdf_security.dart`) |
| `engines/pdf/image_to_pdf_engine.dart` | A2 `syncfusion_image_to_pdf_engine.dart` | `imageToPdfEngineProvider` |
| `engines/pdf/pdf_render_engine.dart` (pageCount, renderPage → bytes PNG/JPG theo DPI) | A3 `pdfx_render_engine.dart` | `pdfRenderEngineProvider` |
| `engines/pdf/pdf_tools_engine.dart` (merge, split, organize, watermark, createBlank) | A4 `syncfusion_pdf_tools_engine.dart` | `pdfToolsEngineProvider` |
| `engines/pdf/pdf_sign_engine.dart` (đặt ảnh chữ ký lên trang/toạ độ) | A5 | `pdfSignEngineProvider` |
| `engines/convert/convert_engine.dart` (text/docx/xlsx→pdf, pdf→txt/docx/xlsx) | A6 | `convertEngineProvider` |
| `engines/office/docx_engine.dart`, `xlsx_engine.dart` (parse → model) | A7 | … |
| `engines/office/pptx_engine.dart` (parse → `PptxDeck` model) | A8 | … |
| `engines/ocr/ocr_engine.dart` (recognize(imagePath, script) → `OcrResult` có block/line/bounds) | A9 | … |

MÓNG đặt provider trỏ tới **impl giữ chỗ** ném `UnimplementedError`; agent viết impl thật trong file của mình và
**override provider bằng cách sửa đúng một dòng trong file `<f>_providers.dart` của mình** — MÓNG tạo sẵn
`app/lib/features/<f>/<f>_providers.dart` chứa provider của engine tương ứng để agent sửa mà không đụng core.

Provider thực tế (code MÓNG):
| Provider | File | Interface |
|---|---|---|
| `imageToPdfEngineProvider` | `features/image_to_pdf/image_to_pdf_providers.dart` | `ImageToPdfEngine.createPdf({imagePaths, outputPath, options: ImageToPdfOptions, onProgress, cancelToken})` → `ImageToPdfResult` |
| `pdfRenderEngineProvider` | `features/reader/reader_providers.dart` | `PdfRenderEngine.openFile(path, {password})` / `openBytes` → `PdfRenderDocument` (`pageCount`, `pageSize(i)`, `renderPage(i, {dpi, format: RenderFormat, jpgQuality})`, `renderThumbnail`, `close`) |
| `pdfToolsEngineProvider` | `features/pdf_tools/pdf_tools_providers.dart` | `PdfToolsEngine` (`merge`, `split(SplitMode)`, `organize(List<PageOp>)`, `watermark(WatermarkSpec)`, `createBlank(BlankDocSpec)`, `pageCount`) |
| `pdfSignEngineProvider` | `features/editor/editor_providers.dart` | `PdfSignEngine.applySignatures(path, List<SignaturePlacement>, out, {password})`, `pageSize`; hàm thuần `viewRectToPdfRect` |
| `convertEngineProvider` | `features/convert/convert_providers.dart` | `ConvertEngine` (`textToPdf`, `txtFileToPdf`, `docxToPdf`, `xlsxToPdf`, `pdfToText`, `pdfToDocx`, `pdfToXlsx`; `ToPdfOptions`) |
| `docxEngineProvider`, `xlsxEngineProvider` | `features/office_viewer/office_viewer_providers.dart` | `DocxEngine`/`XlsxEngine` `.parseFile/parseBytes` → `DocxDocument` / `XlsxWorkbook` |
| `pptxEngineProvider` | `features/office_pptx/office_pptx_providers.dart` | `PptxEngine.parseFile/parseBytes` → `PptxDeck` |
| `ocrEngineProvider` | `features/scanner/scanner_providers.dart` | `OcrEngine.recognize(imagePath, OcrScript)` → `OcrResult`, `dispose()`; `ocrScriptForLanguage` |

Model dữ liệu nằm ngay trong file `*_engine.dart` (MÓNG sở hữu). Thiếu field → ghi "Cần MÓNG bổ sung", trong lúc chờ
có thể dùng model nội bộ trong thư mục feature của mình. Lưu ý A6 (convert) dùng `DocxEngine`/`XlsxEngine` của A7 qua
provider — test bằng fake/mocktail, không phụ thuộc impl A7. File impl engine: đặt cạnh interface
(`lib/engines/<nhóm>/<tên_impl>.dart`) hoặc trong thư mục feature — tên file do agent sở hữu.

## 3. Đa ngôn ngữ

- Locale: `vi, en, zh, ja, ko, id` — **6 ngôn ngữ**. Template = `en`.
- Mỗi chủ sở hữu viết chuỗi của mình ở `.../l10n/<prefix>_<locale>.arb` (core: `app/lib/core/l10n/core_<locale>.arb`;
  feature: `app/lib/features/<f>/l10n/<prefix>_<locale>.arb` — **tên file theo prefix**, vd. `img2pdf_vi.arb`,
  không phải `image_to_pdf_vi.arb`). **Key bắt đầu bằng prefix** của mình
  (`core_`, `docs_`, `img2pdf_`, `reader_`, `tools_`, `edit_`, `conv_`, `office_`, `pptx_`, `scan_`, `settings_`).
  MÓNG đã tạo sẵn 6 file mỗi feature với key `<prefix>_title`. Placeholder chỉ khai `@key.placeholders` ở file `en`.
- `tool/merge_arb.dart` gộp mọi file `*_<locale>.arb` → `lib/l10n/app_<locale>.arb`: **lỗi** nếu trùng key, key sai
  prefix (phải trùng prefix tên file), `@@locale` khác tên file, locale khác 6 ngôn ngữ, hoặc key có ở locale khác mà
  không có ở `en`; **cảnh báo** nếu thiếu bản dịch (`--strict` biến cảnh báo thành lỗi). Rồi `flutter gen-l10n` sinh
  `AppLocalizations` vào `lib/l10n/` (gitignore) — truy cập `context.l10n.<key>` (import `core/l10n/l10n.dart`, file này
  cũng export `AppLocalizations`, `appLocales`, `localeNativeNames`).
- Chuỗi core có sẵn: nút (`core_ok/cancel/delete/rename/share/open/save/close/retry/done/yes/no/info`), `core_favorite`,
  `core_removeFavorite`, `core_selectFile`, `core_fileName`, `core_password`, `core_passwordDialogTitle`,
  `core_passwordDialogMessage(name)`, `core_confirmDeleteTitle`, `core_confirmDeleteMessage(name)`, `core_processing`,
  `core_progressPercent(percent)`, `core_comingSoon`, `core_emptyTitle`, `core_errorXxx` (8 lỗi), `core_groupXxx`,
  `core_toolXxx` (19 công cụ), `core_appName`.
- **Đủ 6 ngôn ngữ cho mọi key** (dịch máy được, giữ placeholder `{x}` đúng tên).

## 4. Phân công đợt 1 (song song)

| Agent | Feature/thư mục | Việc chính (chi tiết ở spec) |
|---|---|---|
| A1 | `features/documents`, `data/file_scanner` | Trang chủ (☰ drawer, tab, lưới loại, ＋), xin quyền, quét file isolate + đồng bộ bảng `documents`, tìm, sắp xếp, ⭐, ⋮ (đổi tên/chia sẻ/thông tin/xoá), Gần đây, Yêu thích, kéo làm mới, ổ khoá trên PDF bị khoá |
| A2 | `features/image_to_pdf`, impl image_to_pdf_engine | Chọn ảnh album/camera, sửa (cắt/xoay/đổi cỡ/hiệu ứng), tuỳ chọn khổ/hướng/lề/chất lượng, xuất, màn kết quả |
| A3 | `features/reader`, impl pdf_render_engine, `MainActivity.kt`/`ShortcutChannel.kt` | Viewer (tìm, cuộn dọc/ngang, liên tục/từng trang, chỉ số trang + nhảy trang, outline, bookmark, tối, in, mật khẩu, lối tắt), PDF→ảnh |
| A4 | `features/pdf_tools`, impl pdf_tools_engine | Gộp, tách, sắp xếp/xoá/xoay/trích trang, khoá, mở khoá, watermark, tạo tài liệu trắng |
| A5 | `features/editor`, impl pdf_sign_engine | Annotation (tô sáng, gạch chân, gạch ngang, gạch sóng, ghi chú), chữ ký (vẽ, lưu, đặt), điền form |
| A6 | `features/convert`, impl convert_engine | Text/TXT/DOCX/XLSX→PDF (font Noto theo mục 5), PDF→TXT/DOCX/XLSX |
| A7 | `features/office_viewer`, impl docx/xlsx engine | Xem DOCX, XLSX (nhiều sheet, ô gộp), TXT |
| A8 | `features/office_pptx`, impl pptx_engine | Xem PPTX: chữ, ảnh, hình cơ bản, kế thừa placeholder layout/master |
| A9 | `features/scanner`, impl ocr_engine | Quét tài liệu (cunning_document_scanner), OCR ML Kit, xuất PDF/DOCX/TXT |
| A10 | `features/settings`, `assets/branding/**` | Màn Cài đặt, Ngôn ngữ (đổi tức thì), Giao diện, Thư mục lưu (file_picker chọn thư mục), Giới thiệu; logo/launcher icon vẽ vector |

Mỗi agent: **TDD cho logic thuần** (test trước), widget test cho màn chính, `flutter analyze` sạch.

## 5. Asset quy ước (không tải — chỉ code theo đường dẫn, người ghép tải sau khi người dùng đồng ý)

- Font: `app/assets/fonts/NotoSans-Regular.ttf`, `NotoSans-Bold.ttf`,
  `NotoSansSC-Regular.ttf`, `NotoSansJP-Regular.ttf`, `NotoSansKR-Regular.ttf`. Code phải chạy được khi file
  **chưa có** (bắt lỗi, rơi về font chuẩn và báo trong log).

## 6. Báo cáo khi xong (mỗi agent trả về)

1. Danh sách file đã tạo/sửa. 2. Kết quả `flutter analyze` và `flutter test` (dán dòng tổng kết).
3. Phần chưa làm/giới hạn. 4. "Cần MÓNG bổ sung" (nếu có). 5. "Cần tải" (asset). 6. Hash commit cuối.
7. Checklist để người dùng kiểm trên điện thoại thật.

## 7. Ghi chú từ MÓNG (khớp code thật — đọc kỹ)

**Gói đã resolve** (`app/pubspec.yaml`, ràng buộc `^`): flutter_riverpod 3.4.3, go_router 18.1.1, drift 2.35.3,
drift_flutter 0.3.1, path_provider 2.1.6, path 1.9.1, shared_preferences 2.5.6, intl 0.20.3 (ghim theo
flutter_localizations), syncfusion_flutter_pdf / _pdfviewer / _signaturepad / _xlsio 35.1.41, pdfx 2.11.0,
printing 5.15.1, permission_handler 12.0.1 (hạ từ 13.0.2 — bản 13 cần API 37, xem lmm-wiki/concepts/build-android.md), photo_manager 3.12.0, image_picker 1.2.4, image_cropper 13.0.0,
image 4.12.0, file_picker 13.2.0, share_plus 13.3.1, open_filex 5.0.0, receive_sharing_intent 1.9.0,
docx_file_viewer 1.0.5, archive 4.5.2, xml 7.1.0, two_dimensional_scrollables 0.5.5, cunning_document_scanner 3.0.4,
google_mlkit_text_recognition 0.17.1, collection 1.19.1 (OCR chỉ dùng ML Kit); path dependency: office_reader, pptx_reader, pdf_layout, image_ops (`../packages/`). Dev: build_runner 2.17.1,
drift_dev 2.35.2, mocktail 1.0.5, flutter_lints 6.0.0. **Không thêm gói** (pubspec thuộc MÓNG) — cần gói → báo.

**Gói bị bỏ:** `excel` (mọi bản yêu cầu `xml <7`, xung đột Syncfusion 35 + docx_file_viewer 1.x cần `xml ^7`);
`spreadsheet_decoder` cũng kẹt `xml 6`. ⇒ A7 đọc XLSX bằng `archive` + `xml` tự parse (sharedStrings, styles,
sheetN.xml, mergeCells) sau `XlsxEngine`. Archive 4.x: API `ZipDecoder().decodeBytes(bytes)`, file `.readBytes()`.

**Lệch so với bản đầu:** interface bảo mật tên `PdfSecurityEngine` (tránh trùng `PdfSecurity` của Syncfusion — impl
nào import Syncfusion nên `import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;`); `outputDirectoryProvider` thay
`outputDirectory(ref)`; file ARB feature đặt theo prefix; bookmark `page` 0-based.

**Android:** namespace + applicationId `com.phuong.pdfoffice` ⇒ `MainActivity.kt` nằm ở
`android/app/src/main/kotlin/com/phuong/pdfoffice/` (package `com.phuong.pdfoffice`) — A3 đặt `ShortcutChannel.kt`
cùng package. MainActivity `launchMode="singleTask"` (cho receive_sharing_intent). Manifest đã có: quyền bộ nhớ/ảnh/
camera, intent-filter VIEW (pdf/docx/xlsx/pptx/doc/xls/ppt/txt), SEND (thêm image/*), SEND_MULTIPLE (image/*, pdf),
`UCropActivity` cho image_cropper, `<queries>` VIEW `*/*` (open_filex) và IMAGE_CAPTURE. Không có INTERNET.

**Gotcha:**
- `sqlite3` 3.x (qua drift_flutter) có build hook **tự tải** `sqlite3.dll`/`.so` đã ghim hash từ GitHub releases
  khi `dart run` / `flutter test` / `flutter build` lần đầu. Máy MÓNG đã tải bản Windows vào `app/.dart_tool/` (không
  commit). Worktree mới sẽ tự tải lại khi chạy test — bình thường, không phải tải asset tay.
- `flutter analyze` của MÓNG: 0 issue (kể cả info) — giữ như vậy; lint `use_null_aware_elements` (Dart 3.8+) có bật.
- Trước `flutter test` ở worktree mới: `dart run tool/merge_arb.dart && flutter gen-l10n` (thư mục `lib/l10n/` bị
  gitignore nên worktree không có sẵn).
- Test của MÓNG nằm ở `app/test/core/`, `app/test/data/`, `app/test/engines/`, `app/test/app_smoke_test.dart`.
- `app_smoke_test.dart` kiểm mọi hằng `Routes` đều được đăng ký là `GoRoute` **cấp cao nhất** với đúng path — nếu
  agent settings lồng `/settings/language` thành route con, sửa test đó là việc của người ghép (báo trong báo cáo).
