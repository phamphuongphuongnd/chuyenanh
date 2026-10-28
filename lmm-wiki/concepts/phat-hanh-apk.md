---
title: Phát hành APK — build release, link tải GitHub Release
type: concept
updated: 2026-10-27
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
- Gradle mới từ chối `getDefaultProguardFile("proguard-android.txt")`; dùng `proguard-android-optimize.txt`.
- Bản release ký bằng khoá debug (cùng khoá với bản debug nên cài đè được, không cần gỡ).
- Bản debug mở >10s; **release ≈ 1s** tới màn hình chính có đủ nội dung (đo bằng `startupTrace`, xem [[viec-con-lai]]). Con số 4,5–5,8s
  từng ghi là do đo bằng `uiautomator` (tự tốn 1,5–3s mỗi lần). Đánh giá tốc độ bằng release trên máy thật, không dùng debug.

Liên quan: [[build-android]], [[tinh-nang-t1-t10]], [[documents]].
