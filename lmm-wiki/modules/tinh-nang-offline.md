---
title: 11 tính năng offline mới (30/10) — nén, số trang, chèn trang, ảnh chữ ký, PPT↔PDF, thẻ ID, QR, tìm nội dung, đọc to, dàn chữ, dịch, mở file từ app khác, khoá app
type: module
updated: 2026-11-02
sources:
  - C:/Users/Admin/.claude/plans/cho-to-n-b-c-c-ticklish-scott.md
  - app/lib/core/tools/tool_registry.dart
  - app/lib/core/router/routes.dart
  - app/lib/data/db/app_database.dart
  - app/lib/app.dart
---

# 11 tính năng offline mới (30/10/2026)

## Yêu cầu gốc
Khảo sát 32 app Play (xem [[ui-app-goc]]) ra danh sách tính năng còn thiếu. Người dùng hỏi tính năng nào chạy offline được,
rồi chốt: **"bỏ 1 3 4 đi còn lại làm hết"**. Tức là **không làm** cloud/đồng bộ, sửa chữ gốc trong PDF, chèn chữ/vẽ/ảnh lên PDF.
AI tóm tắt/chat cũng không làm (cần mạng). Yêu cầu chia việc cho thật nhiều agent ([[build-song-song-agent]]).

## Làm được gì, nằm ở đâu
| Tính năng | Vị trí | Ghi chú |
|---|---|---|
| Nén PDF | `features/pdf_tools/engine/compress_pdf.dart`, `ui/compress_screen.dart` | mức nhẹ giữ chữ chọn được; mức vừa/mạnh render lại trang thành JPEG nên **mất chữ chọn được** (có cảnh báo) |
| Đánh số trang | `engine/page_numbers.dart`, `page_numbers_providers.dart`, `ui/page_numbers_screen.dart` | kiểu 1 · 1/n · "Trang 1", 6 vị trí, số bắt đầu |
| Chèn trang | `engine/insert_pages.dart`, `insert_pages_providers.dart`, `ui/insert_pages_screen.dart` | trang trắng / ảnh / trang từ PDF khác |
| Ảnh chữ ký | `features/editor/signature_image.dart` (`signaturePngFromPhoto`), ô "Nhập từ ảnh" trong `sign_screen.dart` | Otsu tách nền trắng → trong suốt |
| PPT→PDF, PDF→PPT | `features/ppt_convert/**`, `packages/pdf_layout/lib/src/pptx_writer.dart` | chỉ .pptx; PDF→PPT ra slide **ảnh** (không sửa chữ được) |
| Thẻ ID 2 mặt | `features/id_card/**`, `packages/image_ops/lib/src/id_card.dart` (`composeIdCard`) | 2 mặt cỡ 85,6×54mm lên A4 |
| Quét QR/mã vạch | `features/qr/**` (ML Kit barcode trên ảnh chụp/chọn) | mở link chỉ qua `url_safety.dart` |
| Tìm theo nội dung | `features/content_index/**`, `data/db/daos/document_texts_dao.dart`, SearchScreen trong `features/documents/list_screens.dart` | bảng mới `DocumentTexts` — xem [[co-so-du-lieu]] |
| Đọc to | `features/tts/**` (`flutter_tts`, giọng có sẵn của máy) | |
| Chế độ dàn chữ | `features/reading/**` (`ReflowScreen`), 3 mục ⋮ trong `pdf_reader_screen.dart` | |
| Dịch trên máy | `features/translate/**` (`google_mlkit_translation`) | 6 ngôn ngữ app; **cần mạng 1 lần** tải gói ~30MB |
| Mở file từ app khác | `features/system/incoming_*.dart`, `android/.../IncomingFilesChannel.kt`, `ios/Runner/SceneDelegate.swift` | Android VIEW/SEND/SEND_MULTIPLE (+ `image/*`), iOS "Mở trong"; chỉ nhận file trong `cache/incoming` (Android) / `Documents/Imported` (iOS) |
| Khoá app | `features/system/app_authenticator.dart`, `app_lock_gate.dart`, `AppSettings.appLock` | `local_auth`; lớp khoá ở `MaterialApp.router(builder:)` trong `app.dart` |

Đăng ký chung: `Routes` mới (`/tools/compress`, `/tools/page-numbers`, `/tools/insert-pages`, `/convert/ppt-to-pdf`,
`/convert/pdf-to-ppt`, `/reader/reflow`, `/scanner/id-card`, `/qr`), `ToolSpec` + `toolLabelFor` + chuỗi `core_tool*` 6 ngôn ngữ.

## Quyết định
- Plugin mới: `flutter_tts`, `local_auth`, `google_mlkit_barcode_scanning`, `google_mlkit_translation`; bỏ `receive_sharing_intent`
  (tự viết kênh native).
- Thêm quyền `INTERNET` **chỉ để tải gói dịch**. Chuỗi Giới thiệu/Bảo mật trong Cài đặt đã sửa cho đúng sự thật ("không dùng mạng,
  trừ khi bạn tự tải gói dịch").
- DB lên `schemaVersion 2` kèm `MigrationStrategy` giữ Yêu thích/Gần đây (có `test/data/db/migration_test.dart`).

## Gotcha
- `local_auth` cần `MainActivity : FlutterFragmentActivity` **và** theme AppCompat (`Theme.AppCompat.Light.NoActionBar` /
  `Theme.AppCompat.NoActionBar` trong `styles.xml`). Thiếu một trong hai thì crash khi gọi xác thực.
- `SwitchListTile` đặt trên ô có nền (ToolCard) phải bọc `Material(type: MaterialType.transparency)`, nếu không hiệu ứng
  bấm bị nền che và test báo lỗi "No Material widget".
- Provider Riverpod 3 không có ai nghe sẽ bị tạm dừng: test dùng `container.listen`, không chỉ `read` ([[kiem-thu-flutter]]).
- Chạy nhiều `flutter test` cùng lúc trong một thư mục làm kẹt `sqlite3.dll`/build cache. Dùng khoá `mkdir app/.test_lock`
  để chạy lần lượt ([[build-song-song-agent]]).

## Trạng thái và hạn chế
- 1072 test xanh, `flutter analyze` chỉ còn 2 dòng *info* cũ trong `test/core/ios_simulation_test.dart`, build APK release được
  (174,6MB, `app/build/app/outputs/flutter-apk/app-release.apk`). **Chưa thay link tải** `android-latest`.
- **Chưa thử trên Galaxy A13**, iOS chưa build; Kotlin/Swift mới chỉ qua build Android release.
- Chỉ mục nội dung chỉ chạy khi đang mở màn Tìm; chưa OCR trang ảnh.
- Samsung có thể thiếu giọng đọc tiếng Việt. PPTX xuất ra chưa mở thử bằng PowerPoint thật.
- Kiểm thử hộp trắng toàn hệ thống (19 agent, kết quả `test-output/whitebox/`) **bị dừng giữa chừng vì hết hạn mức phiên**.
  Các file `app/test/whitebox/**` còn dở, chưa chạy được, nên **không commit**. Muốn làm tiếp thì nhắn lại từng agent.

Liên quan: [[viec-con-lai]], [[giao-dien-phiotron]], [[phat-hanh-apk]], [[co-so-du-lieu]].

## Cập nhật 02/11 — thử máy thật, kiểm thử hộp trắng, sửa lỗi
- **Thử trên Galaxy A13 (bản release):** Nén (2,44→1,27MB), Đánh số trang, Dàn chữ, Tìm theo nội dung, PDF→PPT chạy đúng; Dịch mở được (chưa tải gói); Đọc to báo "Máy chưa có giọng đọc Tiếng Việt" vì app dùng bộ đọc Samsung (máy có Google TTS nhưng chưa tự chuyển). Một lần thấy cả app bị phủ xám sau khi đóng bảng Dịch, không tái hiện lại.
- **Quyền bộ nhớ:** commit `6352ec7` (chat khác) đã bỏ "Truy cập tất cả file", tab Tập tin chỉ còn 3–4 file của app. Chủ dự án chọn **trả lại** (02/11): `MANAGE_EXTERNAL_STORAGE` + `READ_EXTERNAL_STORAGE` (tới API 32, kèm `tools:replace` vì `open_filex` khai 32), `PermissionHandlerStorage` API ≥30 dùng manageExternalStorage, `androidScanRoots(storageRoot: /storage/emulated/0)`. Sau khi tự bật quyền trong Cài đặt Android, tab Tập tin thấy 44 tài liệu. Hệ quả: Play có thể từ chối — xem [[0005-len-store-mien-phi]].
- **Kiểm thử hộp trắng toàn hệ thống** (`/phuong-whitebox-test`, 19 agent chia theo nhóm file, kết quả `test-output/whitebox/`, sổ tổng `tong-hop.md`; test mới ở `app/test/whitebox/**` và `packages/*/test/whitebox/`): 177 file, 4437 PASS / 51 FAIL ở lần chạy đầu. Mọi FAIL đều là lỗi thật, đã sửa (xem từng `buoc-6` mục "Sau khi sửa code"): xử lý chữ (NFC hai dấu thanh, Hangul nửa độ rộng, dò UTF-16), gói `pdf_layout` (6), PPT/ký PDF (3), công cụ PDF (nén ghi đè file gốc, thiếu font Noto, so đường dẫn hoa/thường), ảnh→PDF (giới hạn 100 ảnh, `maxLongSide ≤ 0`), nhập file (so nội dung thay vì chỉ dung lượng), Mục lục (named destination), đổi tên (dispose controller), thẻ ID, **khoá app (lỗi plugin không còn mở khoá)**, chuyển đổi (chạy nền treo, ảnh trong ô DOCX, ô gộp XLSX), gói `office_reader` (11 lỗi: vanish, VML, định dạng số Excel), chỉ mục (đoạn trích, file bị xoá giữa lúc quét). Kết quả: 4020 test app + 4 gói xanh, analyze sạch.
- **Chưa sửa / chờ quyết:** nút "Thử lại" riêng ở màn khoá (cần ARB 6 ngôn ngữ); `insert_pages` có thể so đường dẫn hoa/thường; `pdf_extract` báo lỗi lập trình thành `CorruptFile`; phát hiện mức thấp trong từng `buoc-6`; nhiều hàm lớn chưa kiểm vì khối lượng (ghi trong `buoc-1`: `_makeRun`, `_parseSection`, `_formatDate`, `_sheet` của office_reader, ~280 nút của pptx_reader reader); các màn hình lớn (`pdf_reader_screen`) chưa kiểm.
- **Lưu ý quy trình hộp trắng:** mỗi agent tự làm cả 6 bước cho nhóm file của mình, không có người kiểm chéo; vài file (ảnh→PDF, chuyển đổi) bị viết test trước tài liệu bước 5 do bị ngắt giữa chừng → bước 5 có nguy cơ bám theo test. Test chạy song song phải qua khoá `mkdir app/.test_lock`.
- **Giao diện Công cụ:** "PowerPoint sang PDF" chuyển lên nhóm Tạo PDF; mỗi công cụ có màu riêng (`_toolColor` trong `features/documents/widgets/tools_sheet.dart`), không còn toàn đỏ.

## Cập nhật 02/11 (chiều) — thử máy thật lần 2, giao diện, lỗi mở file ngoài
- **Lỗi thật tìm ra khi thử máy:** mở file từ app khác (giả lập `am start -a VIEW -d file://…`) báo "Page Not Found / GoException: no routes for location file://…" vì Flutter coi địa chỉ intent là route. Sửa: thêm `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>` vào `MainActivity` trong `AndroidManifest.xml` (iOS đã có `FlutterDeepLinkingEnabled=false`). Sau khi sửa, `deck_extras.pptx` mở đúng 4 slide. Zalo/Files cũng sẽ gặp lỗi này nếu thiếu dòng đó.
- **Trang chủ** (`features/documents/home_tab.dart`): bỏ 3 ô (Ảnh sang PDF, Quét tài liệu, PDF sang ảnh) và widget `_FeatureTiles/_PrimaryTile/_SmallTile…`; chỉ còn logo, ô tìm kiếm, Yêu thích, Gần đây. Công cụ nằm ở tab Công cụ và nút ⇄ giữa.
- **Tab Công cụ:** mỗi công cụ một màu (`_toolColor` trong `widgets/tools_sheet.dart`, cả nhóm Công cụ PDF và Chỉnh sửa PDF); "PowerPoint sang PDF" chuyển sang nhóm Tạo PDF (`core/tools/tool_registry.dart`).
- **Sửa nốt các lỗi nhỏ:** nút "Thử lại" ở màn khoá khi plugin lỗi (`settings_appLockRetry`, 6 ngôn ngữ); `guessLanguageCode` nhận tiếng Indonesia (≥2 từ phổ biến); lỗi `speak` đưa controller sang tạm dừng + báo lỗi; tên giọng có gạch (Ana-Maria) và `network_required` dạng `true`; `insert_pages` so đường dẫn hoa/thường; `extractLayoutPages` chỉ đổi lỗi lấy dữ liệu trang/chữ thành `CorruptFile`; tên ảnh xuất ra và tên file tách bị cắt 150 byte (`capFileNameBytes` trong `core/utils/file_paths.dart`); `planSplit` n ≤ 0 ném `ArgumentError`.
- **Chưa thử trên máy thật:** PowerPoint→PDF (xem kết quả), Chèn trang, QR, Thẻ ID, Ảnh chữ ký (cần camera/ảnh), Khoá app (cần vân tay/PIN), Đọc to tiếng Việt (Samsung thiếu giọng; máy có Google TTS nhưng app dùng bộ đọc Samsung). iOS chưa build bản có tính năng mới.
- **Còn mở:** lỗi Syncfusion trong `pdf_extract` vẫn đổi hết thành `CorruptFile`; nhiều phát hiện mức thấp trong các `test-output/whitebox/**/buoc-6` (thư mục này bị `.gitignore`, chỉ nằm trên máy dev).
- Kiểm tra cuối 02/11 14:37: analyze sạch, 4032 test app + 4 gói xanh; APK 182.754.715 byte đã lên `android-latest`.
- **Thử máy thật 02/11 15:25 (bản 14:37):** PowerPoint→PDF (`deck_extras.pptx`, 4 slide → 4 trang PDF, trang 1 khớp slide, lưu `Documents/Phiotron PDF`) và Chèn trang (thêm 1 trang trắng cuối, 4 → 5 trang, hiện "1 / 5") đều chạy đúng, không crash. Dòng lỗi native lúc 15:01 trong logcat là của tiến trình hệ thống `com.android.externalstorage` (trình chọn file Android, fdsan abort), không phải của app.

## Cập nhật 02/11 (tối) — nhẹ APK, Đọc to chọn bộ đọc, không chép Imported
- **Dung lượng APK 174 MB → 94,7 MB (99.280.203 byte):** `android/app/build.gradle.kts` — `ndk.abiFilters` chỉ `armeabi-v7a` + `arm64-v8a` (ML Kit kéo theo thư viện x86_64 ~35 MB, ABI này không chạy được vì không có libflutter/libapp x86_64) và `packaging.jniLibs.useLegacyPackaging = true` (nén `.so`, ước ~35–45 MB). Đổi lại cài xong chiếm thêm chỗ, khởi động có thể chậm hơn chút (chưa đo). KHÔNG bỏ 32-bit (A13 là armeabi-v7a), không đổi R8/proguard. Còn lại nặng: libtranslate_jni ~28 MB (2 ABI), libapp, libflutter, font Noto SC/JP/KR ~22 MB (chưa cắt vì rủi ro thiếu chữ khi xuất PDF — cần người dùng quyết).
- **Đọc to:** `features/tts/` — khi bộ đọc hiện tại không có ngôn ngữ, `ReadAloudController._ensureLanguage` thử các bộ đọc đã cài (`engines()/currentEngine()/useEngine()` trong `TtsEngine`) và giữ bộ đầu tiên có ngôn ngữ đó; không bộ nào có mới báo "Máy chưa có giọng". Trên A13 (Samsung TTS không có tiếng Việt, có Google TTS): tự chuyển sang Google TTS `vi-VN`, thanh hiện "Đoạn 1/154", có luồng âm thanh thật.
- **File trùng:** `core/utils/file_import.dart` (`hasFullStorageAccess`, `sharedStorageRoot`): khi Android đã có quyền "Truy cập tất cả file" và đường dẫn nằm dưới `/storage/emulated/0` thì mở thẳng, KHÔNG chép vào `Imported`; bản tạm trong cache, chưa có quyền, hoặc iOS vẫn chép. **Quyết định của chủ dự án: không ẩn bất kỳ file nào** (đã làm rồi gỡ `hideImportedDuplicates`) — hai file giống hệt do người dùng tự chép vẫn phải hiện đủ. Bộ quét vẫn bỏ thư mục ẩn (tên bắt đầu `.`), `Android/data`, `Android/obb`; chỉ lấy đuôi tài liệu.
- **Thử máy thật (A13, bản 94,7 MB):** cài và chạy, 49 tài liệu trong tab Tập tin; QR vẫn quét được sau khi nén thư viện; không crash.
- **Bài học quy trình:** xin ý kiến người dùng trước khi thêm luật "ẩn/lọc" dữ liệu của họ; công cụ hộp trắng & agent từng đề xuất ẩn trùng mà không hỏi.

## Cập nhật 02/11 (tối muộn) — chỉ Việt + Anh, sửa theo đánh giá khách khó tính
- **Ngôn ngữ:** chủ dự án chốt **chỉ giữ tiếng Việt và tiếng Anh**. Đã xoá 96 file ARB zh/ja/ko/id, `appLocales` = vi, en (`tool/merge_arb.dart` cũng chỉ 2 locale); ngôn ngữ đã lưu không thuộc vi/en ⇒ về "Theo máy". Dịch chỉ vi ↔ en. OCR chỉ Latin (`OcrScript.latin`), gỡ 3 gói ML Kit zh/ja/ko trong `build.gradle.kts`. Font: bỏ NotoSans SC/JP/KR (assets/fonts 13,7 → 1,67 MB); chữ CJK khi xuất PDF ⇒ `?`. `fetch_fonts.sh`, `bundled_licenses.dart`, `OFL-Noto.txt`, `THIRD_PARTY_LICENSES.md`, `README.md` đã bỏ nhắc CJK.
- **Nén PDF:** Vừa/Mạnh dựng trang ảnh + lớp chữ vô hình (chữ vẫn chọn/tìm được, `compress_text_layer.dart`); giữ link URI/nội bộ, highlight, ghi chú (`compress_annotations.dart`); KHÔNG BAO GIỜ ra file to hơn gốc: > 95% gốc ⇒ thử Nhẹ ⇒ vẫn không giảm ≥ 5% (`kMinSavingRatio`) ⇒ báo "Tệp đã được tối ưu" và không ghi file. Ô biểu mẫu, hình vẽ có thể mất (có cảnh báo).
- **PowerPoint ↔ PDF:** PPT→PDF thêm lớp chữ vô hình (`ppt_text_layer.dart`), ảnh slide nén JPEG trong isolate (ghép 4 trang 2,8 s → 0,1 s trên máy dev). PDF→PPT: chữ ẩn `solidFill` alpha 0 (hết "chữ ma"), thêm chế độ **"Chữ sửa được"** (`text_eraser.dart`: tô hộp chữ bằng màu nền lấy mẫu rồi đặt hộp chữ thật) — mặc định vẫn "Giữ nguyên hình"; nền phức tạp có thể còn vệt.
- **Đọc to / dàn chữ:** bấm "Đọc to" một lần là tự đọc; đệm dàn chữ JSON theo (đường dẫn, cỡ, ngày sửa); gộp ô bảng bị xuống dòng (`analysis.dart`).
- **Quyền file:** hộp thoại giải thích trước khi xin, biểu ngữ tắt được 14 ngày, dòng "Quyền truy cập file" trong Cài đặt.
- **Google Play:** targetSdk 36 đạt, 8/8 `.so` arm64 căn 16 KB, giữ `useLegacyPackaging = true`; rủi ro cao duy nhất là tờ khai All files access.
- **Lớp phủ xám:** CHƯA tìm ra nguyên nhân (8 test tái hiện đều không ra); chỉ gia cố `translate_sheet.dart`. Cần tái hiện trên máy thật.
- **Hộp trắng — kiểm chéo:** `test-output/whitebox/_kiem-cheo/` cho thấy Bước 5 của `pdf_builders` bị viết theo test có sẵn (39/125 bộ nghi bám code); image-to-pdf đáng tin. Câu hỏi còn mở: Word justify vẽ thành căn trái; lưu trùng tên tự thêm " (1)" khác brief §3.3.

## Cập nhật 03/11 — thử bản 71,4 MB trên A13
- **PPT→PDF chậm 41 s/4 slide** (trước 15 s): gói `image` Dart thuần (`compositeImage` + `encodeJpg`) rất chậm trên máy 32-bit. Sửa: nén JPEG bằng Android qua kênh `com.phuong.pdfoffice/image_codec` (`android/.../ImageCodecChannel.kt`, `Bitmap.compress`, 2 luồng); Dart chỉ còn đường dự phòng (iOS/test) với trộn nền trắng viết tay. Kết quả **2 s/4 slide**.
- **Gạch chân vàng đôi dưới số/dấu đầu dòng trong PDF xuất từ PPT** (lỗi cũ): slide chụp trong overlay gốc, ngoài `Scaffold` ⇒ thiếu `Material` ⇒ Flutter dùng kiểu chữ báo lỗi. Sửa: bọc `SlideView` trong `Material(type: transparency)` (`slide_rasterizer.dart`). Gotcha chung: widget dựng trong `Overlay.of(rootOverlay: true)` phải tự có `Material`.
- Đã thử máy thật: Nén Vừa 712 KB → 140 KB (−80 %, 6 s) giữ chữ, link, highlight; PDF→PPT "Chữ sửa được" 3 trang 9 s, chữ thành hộp chữ thật, ảnh nền đã xoá chữ; OCR Latin bản release (sau khi gỡ gói zh/ja/ko) đọc đúng, không lỗi R8.
- Chưa thử được trên máy: hộp thoại xin quyền file (máy đã cấp quyền; chủ dự án tự thu hồi nếu muốn thử), lớp phủ xám.

## Cập nhật 03/11 (trưa) — chuẩn bị Google Play
- **Hộp giải thích trước khi xin quyền camera:** `lib/core/permissions/camera_permission.dart` (`ensureCameraPermission`, `cameraPermissionProvider`), gọi ở Ảnh→PDF, Quét QR, Ký PDF (chụp chữ ký), Quét tài liệu/Thẻ 2 mặt chế độ chụp tay. "Để sau" ⇒ dừng không báo lỗi; bị chặn vĩnh viễn ⇒ `PermissionDenied` như cũ. `cunning_document_scanner` (ML Kit qua Play services) không cần quyền camera của app nên không hỏi.
- **PDF tạo bằng MuPDF báo "File bị hỏng":** CMap ToUnicode có đích bfrange 5 chữ số hex (`<0f0d> <0f1a> <1df00>`, lệch chuẩn) làm Syncfusion 35.1.41 ném `RangeError` trong `FontStructure.getCharacterMapTable`. Sửa: `lib/features/convert/engine/tounicode_repair.dart` — khi trích chữ một trang bị lỗi, sửa CMap trong bộ nhớ (bung thành bfchar UTF-16 surrogate) rồi thử lại đúng 1 lần (`extractPageTextLines` trong `pdf_extract.dart`, dùng ở reflow_loader, compress_text_layer). Dùng lớp nội bộ Syncfusion (`implementation_imports`) ⇒ nâng Syncfusion phải chạy lại `test/features/convert/tounicode_repair_test.dart`. Fixture `test/fixtures/pdf/tounicode_5digit_bfrange.pdf`.
- **Tên gói Google Play** đổi thành `com.phiotron.phiotronpdf` — xem [[phat-hanh-apk]].
- **Lớp phủ xám (tái hiện được 1 lần, bản debug, 03/11 11:08):** cả cửa sổ app tối đều ×0,9 (245→221, 255→230), thanh hệ thống không đổi; app vẫn nhận chạm; chỉ hết khi force-stop. Đã loại trừ: cây widget (không `ModalBarrier` có màu, không Opacity/ColorFiltered), cây layer Flutter (không OpacityLayer/ColorFilterLayer), View gốc Android (chỉ FlutterView/FlutterSurfaceView), theme cửa sổ, Dim layer của SurfaceFlinger (alpha 0). Flutter vẽ vào SurfaceView z=-2 dưới cửa sổ Activity ⇒ nghi tầng ghép hình Android/Samsung. Lần sau gặp: **chưa force-stop**, chạy `adb shell dumpsys SurfaceFlinger > sf.txt` và `dumpsys window` ngay, đọc alpha/color từng layer của app; với bản debug lấy VM service URI trong logcat để `ext.flutter.debugDumpApp` / `debugDumpLayerTree` (script mẫu: WebSocket JSON-RPC `getVM` → gọi extension theo isolateId).
- Ảnh store ở `docs/store/graphics/`, bản soạn Play Console ở `docs/store/google-play-listing.md`; chính sách bảo mật đã ghi rõ ML Kit gửi dữ liệu chẩn đoán qua Internet (web + trong app).

## Cập nhật 03/11 (chiều) — bản 1.0.1 (2), thử máy thật bản tên gói mới
- **ANR khi quét QR từ ảnh camera 50 MP (Galaxy A13):** `google_mlkit_*` gọi `InputImage.fromFilePath` (giải mã + xoay bitmap) **trên luồng UI Android** ⇒ treo > 10 s. Sửa: `ImagePicker.pickImage(maxWidth/maxHeight)` để plugin thu nhỏ ở luồng nền — QR `kQrMaxImageSide = 2000` (`qr/barcode_reader.dart`), chụp tay cho OCR `kScanMaxImageSide = 3000` (`scanner/capture/document_capture.dart`); ký PDF (2400) và thẻ ID (3000) đã có sẵn. Đã thử lại trên máy: hết ANR. Gotcha chung: mọi ảnh đưa vào ML Kit phải giới hạn kích thước trước.
- **Thanh đọc to:** ô "Đoạn 2 / 37" bị FittedBox thu nhỏ/cắt ⇒ chỉ hiện `2/37` (chữ số đều cỡ 13, không bọc Flexible), nhãn đầy đủ để cho trình đọc màn hình (`Semantics`).
- **Word căn đều hai bên → PDF căn đều:** `FlowAlign.justify` + `justifyLine` (`convert/text/line_wrap.dart`, `engine/flow_writer.dart`), chia phần dư đều cho dấu cách, bỏ qua dòng cuối đoạn và dòng `<w:br/>`; vẽ bằng `PdfStringFormat(wordSpacing:)`. Hạn chế: bảng vẫn căn trái, tab bị giãn như dấu cách.
- Đã thử trên máy (bản `com.phiotron.phiotronpdf` 1.0.1, cài song song bản cũ): hộp giải thích quyền camera (Để sau / Tiếp tục → hộp hệ thống / từ chối → báo lỗi, Chọn ảnh vẫn dùng được), Đọc to PDF MuPDF.
- Máy test dùng chung với app khác (Ví Gọn) — trước khi bấm bằng adb phải kiểm `dumpsys window | grep -a mCurrentFocus`.
