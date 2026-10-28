# Thiết kế: kiểm thử iOS bằng simulator trên CI — Đợt 1

Ngày: 2026-10-28 · Trạng thái: **BẢN NHÁP, chờ người dùng duyệt** (chưa có code)

## 1. Vì sao làm
Máy dev là Windows, không có iOS Simulator (cần macOS + Xcode). Chưa có iPhone thật để thử. Cần cách tự thấy app chạy
trên iOS: dùng simulator trên runner macOS của GitHub, chạy test tự động và chụp ảnh màn hình để người dùng tải về xem.

Mục tiêu lớn (người dùng chọn): **test và chụp tất cả chức năng**. Chia 3 đợt, mỗi đợt có spec/plan riêng, CI xanh rồi mới sang đợt sau:
- **Đợt 1 (tài liệu này):** hạ tầng simulator + khởi động + 5 tab + Cài đặt.
- Đợt 2: mở/xem PDF, DOCX, XLSX, PPTX, TXT và 7 công cụ PDF (dùng file mẫu).
- Đợt 3: chuyển đổi, ảnh→PDF, quét + OCR (ảnh mẫu), chỉnh sửa PDF, chia sẻ.

## 2. Phạm vi đợt 1
Làm: bật simulator, chạy app, đi qua các màn dưới đây, chụp ảnh từng màn, đăng ảnh thành artifact; CI đỏ nếu app crash / có exception chưa bắt.
Không làm: mở file thật, công cụ PDF, chuyển đổi, camera/OCR (để đợt 2, 3); không đổi workflow build IPA và Android.

Các màn đi qua (route có sẵn trong `lib/core/router/routes.dart`):

| # | Màn | Cách tới | Ảnh |
|---|---|---|---|
| 1 | Trang chủ `/` (tab Home) | khởi động | `01-home` |
| 2 | Tab Files | bấm `NavigationDestination` thứ 2 | `02-files` |
| 3 | Tab Tools (lưới công cụ) | bấm tab thứ 4 | `03-tools` |
| 4 | Tab Settings | bấm tab thứ 5 | `04-settings` |
| 5 | Ngôn ngữ `/settings/language` | bấm mục Ngôn ngữ | `05-language` |
| 6 | Giao diện (theme) | bấm mục Giao diện | `06-theme` |
| 7 | Khổ giấy | bấm mục Khổ giấy | `07-page-size` |
| 8 | Quyền riêng tư | bấm mục tương ứng | `08-privacy` |
| 9 | Giới thiệu `/settings/about` | bấm mục Giới thiệu | `09-about` |
| 10 | Đổi sang tiếng Việt rồi chụp lại Home | chọn Tiếng Việt | `10-home-vi` |
| 11 | Chế độ tối | bật Dark ở Giao diện | `11-home-dark` |

Ghi chú: tab giữa (nút tròn, label rỗng) là nút Quét: **không bấm** ở đợt 1 vì cần camera. Mục "Thư mục lưu" bị ẩn trên iOS (đã xử lý trong code) nên test **kiểm nó không có mặt**.

## 3. Kiến trúc

| File mới | Việc làm | Phụ thuộc |
|---|---|---|
| `app/integration_test/app_test.dart` | Kịch bản trong bảng mục 2, chụp ảnh sau mỗi bước | `integration_test` |
| `app/integration_test/support/boot.dart` | `pumpApp(tester, {locale})` dựng `PdfOfficeApp` với `appDatabaseProvider` = DB trong bộ nhớ, `sharedPreferencesProvider` sạch, 3 stream tài liệu giả rỗng (y hệt `test/app_smoke_test.dart`) | `PdfOfficeApp` |
| `app/integration_test/support/shots.dart` | `shot(binding, tester, name)`: `convertFlutterSurfaceToImage()` + `takeScreenshot(name)`, lưu PNG vào thư mục ảnh | binding |
| `app/test_driver/integration_test.dart` | Driver nhận ảnh từ test và ghi ra `screenshots/<name>.png` trên runner | `integration_driver` |
| `.github/workflows/ios-sim.yml` | Chạy trên `macos-latest`: sinh l10n (như `ios-build.yml`), bật iPhone simulator, `flutter drive`, upload `screenshots/` làm artifact | xem mục 4 |

Thay đổi khác:
- `app/pubspec.yaml`: thêm `integration_test: sdk: flutter` vào **dev_dependencies** (không vào bản release).
- `lib/`: không đổi. Nếu test không tìm được widget bằng chữ/icon thì mới thêm `Key` tối thiểu, và ghi rõ từng chỗ vào kế hoạch trước khi làm.
- Tìm widget theo **icon + vị trí** (ví dụ `find.byType(NavigationDestination).at(1)`), không theo chữ, vì app có 6 ngôn ngữ.

## 4. Workflow `ios-sim.yml` (phác thảo)
Kích hoạt: `workflow_dispatch` và tag `ios-sim-*` (không chạy mỗi lần push, vì mỗi lần mất 15–30 phút macOS).
Các bước, theo đúng thứ tự đã rút ra từ lỗi trước (merge_arb trước pub get):
1. `actions/checkout@v4`, `subosito/flutter-action@v2` (stable, cache).
2. `dart tool/merge_arb.dart` → `flutter pub get` → `flutter gen-l10n` → `bash tool/fetch_fonts.sh`.
3. Tạo/bật simulator: `xcrun simctl list devices available` chọn iPhone mới nhất có sẵn trên runner, `xcrun simctl boot <udid>`, đợi `bootstatus`.
4. `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d <udid>`.
5. `actions/upload-artifact@v4` thư mục `app/screenshots` (luôn chạy, kể cả khi test đỏ, `if: always()`).
Thời gian dự kiến: 15–25 phút.

## 5. Xử lý lỗi
- Test dùng `FlutterError.onError` để **bắt exception trong lúc dựng màn** và làm test đỏ (không nuốt lỗi).
- Mỗi màn có `pumpAndSettle` với timeout; nếu quá hạn thì chụp ảnh trạng thái hiện tại rồi báo đỏ (để vẫn có ảnh chẩn đoán).
- Bước upload ảnh `if: always()` để thấy được màn lỗi.
- Không tự đăng nhập hay cần secret nào; chỉ dùng `GITHUB_TOKEN` mặc định.

## 6. Cách kiểm chứng đợt 1 xong
1. Workflow chạy xanh trên tag `ios-sim-test1`.
2. Artifact có đủ 11 ảnh; tôi xem từng ảnh và báo cho người dùng chỗ nào trông lỗi (chữ cắt, icon vỡ, đè safe-area/notch…).
3. `flutter analyze` và `flutter test` (764 test) vẫn xanh; Android/APK không đổi.

## 7. Giới hạn đã biết
- Simulator không có camera thật, không có ảnh trong thư viện: quét/OCR không thử được ở đợt 1 (đợt 3 dùng ảnh mẫu).
- Simulator ≠ iPhone thật: không bắt được lỗi riêng của thiết bị (hiệu năng, quyền, sideload). Vẫn cần cài thử IPA lên máy thật.
- `integration_test` trên iOS đôi khi cần vài lần thử đầu mới ổn định (simulator khởi động chậm); sẽ thêm bước đợi `bootstatus` thay vì `sleep`.

## 8. Rủi ro / câu hỏi mở
- Tên thiết bị simulator có sẵn trên `macos-latest` thay đổi theo bản image → chọn động bằng `simctl`, không gõ cứng.
- Nếu `fetch_fonts.sh` chậm/lỗi mạng làm hỏng cả job → dùng lại cơ chế đã chạy được ở `ios-build.yml`.
