---
title: 11 tính năng offline mới (30/10) — nén, số trang, chèn trang, ảnh chữ ký, PPT↔PDF, thẻ ID, QR, tìm nội dung, đọc to, dàn chữ, dịch, mở file từ app khác, khoá app
type: module
updated: 2026-10-30
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
