---
title: iOS — cách app chạy trên iPhone, build bằng CI, cài bằng Sideloadly
type: concept
updated: 2026-10-28
sources:
  - app/lib/core/platform/app_platform.dart
  - app/lib/core/utils/file_import.dart
  - app/lib/features/documents/documents_providers.dart
  - app/ios/Runner/Info.plist
  - .github/workflows/ios.yml
---

# iOS (28/10/2026)

**Nguyên tắc:** chỉ THÊM, Android giữ nguyên. Mọi nhánh iOS khoá bằng `appPlatformProvider == ios` (hoặc `detectPlatform()`); Android/khác trả hành vi cũ. Test đủ 764 pass sau khi thêm.

## Khác Android (đã xử lý trong code)
- **Chọn file:** `file_picker` trên iOS trả bản sao TẠM → `importIntoAppDocuments` chép vào `Documents/Imported` (trùng tên khác nội dung → `a (1).pdf`, giống hệt → dùng lại). Gọi ở `pickAndOpenDocument`, `launchTool`, `SystemPdfFilePicker`, `pdfFilePickerProvider`.
- **Danh sách tài liệu:** không quét toàn máy. `platformScanRootsProvider` → thư mục Documents của app, dùng khi `scanRootsProvider` rỗng (Android không bao giờ rỗng).
- **Thư mục lưu:** iOS không cho chọn thư mục tuỳ ý → ẩn mục trong Cài đặt; file xuất vào `Documents/PDF Office` (`resolveOutputDirectory` đã có sẵn), hiện trong app Tệp nhờ `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`.
- **Chia sẻ:** iPad bắt buộc có vị trí popover → `defaultShareOrigin()` (null trên Android). Chia sẻ app trên iOS không kèm link APK (`appShareMessage(withLink: false)`).
- **Cấu hình:** deployment target 15.5 (ML Kit), `CFBundleDocumentTypes` PDF/Office/TXT, icon sinh từ `assets/branding/logo.png` (nền trắng, không alpha).

## Build (không có Mac)
Windows không build được iOS. Dùng `.github/workflows/ios.yml` (macOS runner): chạy tay (Actions → ios-build → Run workflow) hoặc đẩy tag `ios-*`. Ra `PDFOffice-ios.ipa` không ký, đăng lên Release `ios-latest`.

## Cài lên iPhone
1. Tải `PDFOffice-ios.ipa` từ Release `ios-latest` về PC.
2. Cài Sideloadly, cắm iPhone, đăng nhập Apple ID (miễn phí), kéo `.ipa` vào, Start.
3. iPhone: Cài đặt → Cài đặt chung → VPN & quản lý thiết bị → tin cậy Apple ID.
4. Apple ID miễn phí: app hết hạn sau **7 ngày**, phải cài lại. TestFlight cần tài khoản Developer 99 USD/năm.

## Chưa kiểm
- CI chưa chạy lần nào; chưa thử trên iPhone thật (Quét tài liệu VisionKit, ML Kit OCR, quyền camera/ảnh). Lỗi chỉ lộ trên máy thật → xem [[loi-chi-hien-tren-may-that]].
- Lối tắt màn hình chính không có trên iOS; `receive_sharing_intent` còn trong pubspec (không dùng), bỏ nếu CI iOS báo lỗi.

Liên quan: [[phat-hanh-apk]], [[build-android]].
