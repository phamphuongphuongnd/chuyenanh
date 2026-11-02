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
