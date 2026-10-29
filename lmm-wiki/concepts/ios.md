---
title: iOS — cách app chạy trên iPhone, build bằng CI, cài bằng Sideloadly
type: concept
updated: 2026-10-28
sources:
  - app/lib/core/platform/app_platform.dart
  - app/lib/core/utils/file_import.dart
  - app/lib/features/documents/documents_providers.dart
  - app/ios/Runner/Info.plist
  - .github/workflows/ios-build.yml
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
Windows không build được iOS. Dùng `.github/workflows/ios-build.yml` (macOS runner): chạy tay (Actions → ios-build → Run workflow, chỉ hiện khi file đã có trên `master`) hoặc đẩy tag `ios-*` (`git tag ios-testN; git push origin ios-testN`). Ra `PDFOffice-ios.ipa` không ký, đăng lên Release `ios-latest`. **Đã chạy thành công** trên tag `ios-test2` (28/10).

**Gotcha CI:**
- `app/lib/l10n/` bị gitignore, mà `flutter pub get` tự sinh gói l10n và cần thư mục này → phải chạy `dart tool/merge_arb.dart` **TRƯỚC** `flutter pub get` (dùng `dart` thuần, không `dart run`). Lỗi cũ: `arb-dir ... does not exist`, `pub get` thoát mã 1. Tái hiện bằng clone sạch + `flutter pub get`.
- Bản Flutter stable CI trùng máy dev (3.47.8 / Dart 3.13.7) → không phải lỗi lệch phiên bản.
- Đẩy file trong `.github/workflows/` cần token có scope `workflow`; token OAuth cũ của Git Credential Manager thiếu → xoá credential `git:https://github.com` rồi đăng nhập lại qua trình duyệt (người dùng tự làm). Máy chưa cài `gh`.
- Log job GitHub không tải được khi chưa đăng nhập (API trả 403); chỉ xem được trạng thái từng bước qua `/actions/runs/<id>/jobs`.
- PowerShell 5.1 không có `&&` → dùng `;`.

## Cài lên iPhone
1. Tải `PDFOffice-ios.ipa` từ Release `ios-latest` về PC.
2. Cài Sideloadly, cắm iPhone, đăng nhập Apple ID (miễn phí), kéo `.ipa` vào, Start.
3. iPhone: Cài đặt → Cài đặt chung → VPN & quản lý thiết bị → tin cậy Apple ID.
4. Apple ID miễn phí: app hết hạn sau **7 ngày**, phải cài lại. TestFlight cần tài khoản Developer 99 USD/năm.

## Simulator iPhone trên CI + Appetize (29/10/2026)
Windows không có iOS Simulator → dùng runner macOS của GitHub. Xem được app chạy trên iPhone ảo mà không cần Mac/iPhone.
- **`ios-sim.yml`** (tag `ios-sim-*`, chạy tay cũng được): `macos-15-intel` + chọn **Xcode 26.3**, bật iPhone simulator, `flutter drive` 2 bộ test
  (`integration_test/app_test.dart`: 5 tab + Cài đặt, 11 ảnh; `app_features_test.dart`: xem PDF/DOCX/XLSX/TXT, Ảnh→PDF, chuyển đổi, PDF→ảnh), ảnh đăng lên
  Release công khai **`ios-sim-latest`** (xem được không cần đăng nhập). Test sinh file mẫu bằng code (`integration_test/support/fixtures.dart`) và mở route bằng đường dẫn
  qua `extra` vì bộ chọn file hệ thống không điều khiển được trên simulator.
- **Vì sao `macos-15-intel` + Xcode 26.3:** ML Kit (GoogleMLKit/MLKitVision/MLKitCommon/MLImage) **không có arm64 cho simulator** → runner Apple Silicon link lỗi
  `Framework 'Pods_Runner' not found`. `device_info_plus` 13.3 gọi `isiOSAppOnVision` chỉ có từ SDK iOS 26; image Intel mặc định Xcode 16.4.
- **`flutter drive` TREO nếu test ném lỗi** (không kết thúc, mất hết ảnh) → bộ 2 bắt lỗi từng kịch bản (`scenario(...)`), chụp `FAIL-<tên>`, in `SCENARIO FAIL` ra log, bước cuối workflow đọc log để báo đỏ SAU khi đã đăng ảnh. Mỗi bộ test một bước riêng có `timeout-minutes`.
- **Ảnh→PDF:** bấm "Tạo PDF" mở **bảng tuỳ chọn** (BottomSheet), phải bấm xác nhận mới tạo. `tester.pageBack()` tìm tooltip tiếng Anh "Back" → dùng `find.byType(BackButton)`.
  `scrollUntilVisible` chỉ cuộn xuống → kéo về đầu danh sách trước.
- **`ios-sim-app.yml`** (tag `ios-sim-app-*`): dựng `Runner.app` cho simulator, nén `PDFOffice-simulator.zip` (~103 MB, bản debug) lên Release `ios-sim-app`. `flutter build ios --simulator` nhắm mọi kiến trúc
  (kể cả arm64) nên phải ép `ARCHS = x86_64` bằng `XCODE_XCCONFIG_FILE`. Tải file về rồi **Upload App** ở appetize.io (iOS nhận `.zip` chứa `.app`) → iPhone ảo trong trình duyệt.
  Gói free Appetize ~30 phút/tháng (đặt lại 1/11); đóng tab để dừng tính phút. Đã chạy được trên Appetize.
- **Trạng thái test iPhone ảo (29/10, tag ios-sim-test10):** 13/13 kịch bản đạt trên iPhone 16 Pro ảo. Simulator mặc định là iPhone SE (667pt) → thẻ kết quả của PDF/Text nằm dưới màn hình, danh sách chưa dựng nên test không thấy: chọn iPhone bản Pro trong workflow, dùng `find.byIcon(..., skipOffstage: false)` + `ensureVisible`. Muốn thử tay: Appetize (iPhone ảo trong trình duyệt), Expo Go KHÔNG dùng được (app Flutter).
- **Tag:** `ios-*` build IPA nhưng loại `ios-sim-*`; `ios-sim-*` chạy test nhưng loại `ios-sim-app-*`. Mỗi workflow có test chặn hồi quy trong `test/core/ios_simulation_test.dart`.
- **Đọc log CI:** đã cài `gh` (người dùng tự `gh auth login`); `gh run view <id> --log` đọc được log đầy đủ sau khi chạy xong. Log bước đang chạy thì chưa đọc được.
- **Nút Chia sẻ (29/10):** gửi cả hai link trên MỌI nền tảng: `<lời giới thiệu>` + `Android: <link APK>` + `iPhone: <link trang Release ios-latest>` (`appShareMessage(intro)` trong `settings_logic.dart`). Không trỏ thẳng file .ipa vì IPA không ký không cài được bằng cách bấm tải.
- **Cài IPA bắt buộc cắm cáp** (Sideloadly) lần đầu; không tải thẳng trên iPhone. Muốn khỏi cắm hằng tuần: AltStore; muốn bỏ hẳn: TestFlight/App Store (99 USD/năm).
- **Lỗi giao diện sửa:** nhãn "Text language for scanned pages" (PDF→Word/Text/Excel) bị ép thành cột dọc vì Dropdown chữ dài cùng hàng → nhãn trên, Dropdown `isExpanded` (test `convert_screen_test.dart`).

## Chưa kiểm
- `integration_test` không nằm trong pubspec (xem [[build-android]]); CI tự `flutter pub add` lúc chạy.
- **OCR trên iOS đã kiểm chứng (ios-sim-test10):** ảnh chữ "HELLO OCR 12345" → PDF chỉ chứa ảnh → PDF→Text ra đúng nguyên văn. "No text found" ở PDF→Word chỉ do ảnh thử không có chữ. Chưa thử: Quét tài liệu bằng camera, iPhone thật.
- Windows không có iOS Simulator (cần macOS + Xcode). "Giả lập iOS" ở commit `2b67b11` chỉ là test ép platform ở mức code. Hướng thay thế đang làm: simulator trên runner macOS của GitHub CI + `integration_test` + ảnh chụp màn hình (không có camera/ảnh thật nên quét/OCR chỉ thử bằng dữ liệu mẫu).
- Lối tắt màn hình chính không có trên iOS; `receive_sharing_intent` còn trong pubspec (không dùng), bỏ nếu CI iOS báo lỗi.

Liên quan: [[phat-hanh-apk]], [[build-android]].
