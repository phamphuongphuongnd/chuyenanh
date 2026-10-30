---
title: Phát hành APK — build release, link tải GitHub Release
type: concept
updated: 2026-10-30
sources:
  - app/android/app/build.gradle.kts
  - app/android/app/proguard-rules.pro
  - app/lib/features/settings/settings_logic.dart
---

# Phát hành APK (27/10/2026)

## Quy trình đã chạy được
1. Build: `flutter build apk --release --target-platform android-arm,android-arm64` trong `app/`
   → `app/build/app/outputs/flutter-apk/app-release.apk` (~110MB). Copy ra `dist/PDFOffice.apk` (`*.apk` bị `.gitignore`).
2. **Đưa lên GitHub Release, KHÔNG commit APK vào repo**: git chặn file >100MB, Release cho tới 2GB/file.
   Tag cố định `android-latest` + tên file `PDFOffice.apk` → link không đổi qua các bản:
   `https://github.com/phamphuongphuongnd/chuyenanh/releases/download/android-latest/PDFOffice.apk`
   (hằng `kAppDownloadUrl` trong `settings_logic.dart`; nút **Chia sẻ ứng dụng** ở Cài đặt gửi link này).
3. Cập nhật bản mới = sửa Release, xoá file cũ, tải file mới (link giữ nguyên).
4. Máy không có `gh`; đăng nhập GitHub **người dùng tự làm** (luật cố định không tự đăng nhập) nên tạo Release bằng trình duyệt:
   `github.com/<owner>/<repo>/releases/new` → tag `android-latest` (gõ **một từ, không dấu cách**) → kéo APK vào ô
   "Attach binaries" (không phải khung mô tả) → Publish.

## Gotcha
- **Galaxy A13 của người dùng là 32-bit (`armeabi-v7a`)**. APK chỉ có arm64 báo `Could not find 'libflutter.so'`
  và không mở. Phải build cả `android-arm` lẫn `android-arm64`. APK universal 137MB, arm+arm64 108–110MB.
- R8 (release) báo `Missing class ...mlkit.vision.text.chinese...`: plugin `google_mlkit_text_recognition` khai gói
  Trung/Nhật/Hàn ở dạng `compileOnly`. Đã thêm `implementation("com.google.mlkit:text-recognition-{chinese,japanese,korean}:16.0.1")`
  (APK chỉ tăng ~2MB) + `proguard-rules.pro` với `-dontwarn` (cho Devanagari). Không thêm gói thì OCR zh/ja/ko ném
  `NoClassDefFoundError` lúc chạy (bản debug cũng bị).
- **R8 làm hỏng ML Kit ở bản release (phát hiện 28/10)**: log app ghi `ComponentDiscovery: Could not instantiate
  com.google.mlkit.common.internal.CommonComponentRegistrar ... NoSuchMethodException <init>` → R8 xoá constructor các
  `ComponentRegistrar` (ML Kit khởi tạo bằng reflection). Hậu quả: **Quét tài liệu mất chế độ tự động** (plugin rơi về
  `cunning_document_scanner.fallback.DocumentScannerActivity` chỉ mở camera thường) và OCR hỏng. Bản debug (không thu gọn) vẫn chạy nên
  dễ tưởng không sao. Sửa: `-keep class com.google.mlkit.** { *; }` + `-keep class * implements ...ComponentRegistrar { <init>(); }`
  trong `proguard-rules.pro`. Sau sửa log sạch và hiện đúng màn Google "Chụp thủ công / Tự động chụp"
  (`com.google.android.gms.mlkit.docscan.ui.DocumentScanningActivity`).
  **Cách kiểm sau mỗi lần build release:** `adb logcat -d --pid=$(pidof com.phuong.pdfoffice) | grep ComponentDiscovery` phải rỗng; bấm
  Quét tài liệu phải thấy `DocumentScanningActivity` của Google, không phải `...fallback.DocumentScannerActivity`.
- **Quyết định 28/10: TẮT R8 cho bản release** (`isMinifyEnabled = false`, `isShrinkResources = false` trong `build.gradle.kts`).
  Giữ ML Kit bằng keep rule chưa đủ: khởi tạo được nhưng Google báo `GmsDocScanDelAct: Failed to handle result` sau khi chụp
  (bản thu gọn hỏng ở bước nhận kết quả). Tắt R8 thì Quét tài liệu (tự động + thủ công) chạy đúng như bản debug; APK 110→114MB.
  Đây là app cá nhân nên đổi vài MB lấy độ tin cậy là hợp lý. Đừng bật lại R8 nếu chưa thử đủ quét/OCR/PDF trên máy thật.
  `proguard-rules.pro` vẫn giữ (vô hại khi R8 tắt).
- Gradle mới từ chối `getDefaultProguardFile("proguard-android.txt")`; dùng `proguard-android-optimize.txt`.
- Bản release ký bằng khoá debug (cùng khoá với bản debug nên cài đè được, không cần gỡ).
- Bản debug mở >10s; **release ≈ 1s** tới màn hình chính có đủ nội dung (đo bằng `startupTrace`, xem [[viec-con-lai]]). Con số 4,5–5,8s
  từng ghi là do đo bằng `uiautomator` (tự tốn 1,5–3s mỗi lần). Đánh giá tốc độ bằng release trên máy thật, không dùng debug.

Liên quan: [[build-android]], [[tinh-nang-t1-t10]], [[documents]].

## Cập nhật 29/10/2026
- APK trên Release `android-latest` đã được thay bằng bản build 29/10 (96.360.245 byte, SHA-256 `6ef26eb1…8d4917`, gồm hỗ trợ iPhone và sửa nhãn OCR), ký bằng khoá debug MỚI (xem [[build-android]]).
  Bản cũ (119.651.285 byte, khoá cũ) được lưu ở `dist/backup/PDFOffice.apk` (gitignore) — tải lên lại bằng `gh release upload android-latest dist/backup/PDFOffice.apk --clobber` nếu cần quay lại.
- Máy đã có `gh` (người dùng tự đăng nhập): tải lên Release bằng `gh release upload <tag> <file> --clobber`, kiểm bằng `gh release view <tag> --json assets` (trường `digest` là SHA-256 để đối chiếu).

## Cập nhật 30/10/2026
- **Gotcha:** bản 29/10 (96MB) **thiếu font Noto** (máy build không có `app/assets/fonts/*.ttf` vì font bị gitignore) → PDF xuất lỗi chữ có dấu.
  Luôn chạy `bash tool/fetch_fonts.sh` trước khi build release; bản có đủ Noto ≈ 114MB, không có ≈ 92MB — **nhìn dung lượng để biết thiếu font**.
- Release `android-latest` thay 2 lần: bản Nhóm 1 (120.039.890 byte, `dist/backup/PDFOffice-2026-10-30-nhom1.apk`) rồi bản giao diện mới
  Phiotron PDF (120.000.714 byte, sha256 `3f719ff0…aa517`). Bản 29/10 lưu `dist/backup/PDFOffice-2026-10-29.apk`. Quy trình: kiểm sha của bản
  online = `dist/PDFOffice.apk` → sao lưu → chép bản mới → `gh release upload --clobber` → `curl -sIL` thấy đúng `Content-Length`.
- Người dùng cho phép thay link khi nói rõ ("thay cho tôi", "Thay link tải"); mỗi lần build mới vẫn hỏi lại. Xem [[giao-dien-phiotron]].

## Cập nhật 30/10/2026 — lên store
- Sắp lên Google Play + App Store ([[0005-len-store-mien-phi]]): Play nhận **`.aab`** (`flutter build appbundle --release`), không phải APK; release phải ký bằng keystore riêng (đang ký khoá debug).
- Các APK/IPA đã đăng trên Release **thiếu giấy phép font Noto** và còn tên "PDF Office" → thay bằng bản mới hoặc gỡ ([[ban-quyen-giay-phep]]).
- Khi khoá repo (private) thì link `kAppDownloadUrl` / `kIosDownloadUrl` trong nút Chia sẻ chết với người khác → đổi sang link store trước.
