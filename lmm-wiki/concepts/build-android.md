---
title: Build Android — môi trường và các lỗi đã gặp
type: concept
updated: 2026-10-26
sources:
  - app/android/build.gradle.kts
  - app/android/gradle.properties
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# Build Android — môi trường và các lỗi đã gặp

**Môi trường (máy người dùng, Windows):** Flutter 3.47.8 ở `C:\src\flutter` (không có trong PATH → gọi đường dẫn đầy
đủ), Android SDK dạng dòng lệnh ở `C:\Android\sdk` (không Android Studio, không emulator; `flutter config
--android-sdk` đã trỏ), JDK 21 (`JAVA_HOME="C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot"`). Template Flutter:
AGP **9.1.0**, Kotlin 2.4.0, Gradle 9.3.1, `android.newDsl=false`, `android.builtInKotlin=false`.

**Lệnh:** trong `app/`: `flutter build apk --debug` (ghi log ra file để đọc lỗi đầy đủ — `| tail` dễ cắt mất lỗi đầu).

**Lần build đầu rất lâu (20–30 phút):** Gradle tự tải NDK `28.2.13676358` (~2 GB) và các Platform 34/35/37.0 mà plugin
đòi (license đã chấp nhận nên tự cài). Lần sau nhanh.

**Lỗi đã gặp & cách sửa:**
1. `flutter_tesseract_ocr` 0.4.31 — `'kotlin-android' plugin requires one of the Android Gradle plugins`: gói cũ
   (AGP 7.1, `jcenter`, `lintOptions`) không chạy với AGP 9 → **không dùng, đã gỡ khỏi pubspec** (OCR chỉ dùng ML Kit).
2. `Failed to find target with hash string 'android-37'`: plugin đặt `compileSdk = 37`, SDK Android 17 cài tên
   `android-37.0`, AGP 9.1 không khớp.
   - `permission_handler` 13.x (`permission_handler_android` 14.1.0) **thật sự dùng API 37** (`ACCESS_LOCAL_NETWORK`,
     `VERSION_CODES.CINNAMON_BUN`) → ép SDK 36 thì javac lỗi `cannot find symbol` → **hạ `permission_handler` về
     `^12.0.1`** (android 13.0.1, compileSdk 35). Đủ quyền app cần (storage, manageExternalStorage, photos, camera).
   - Plugin khác đòi 37 nhưng không dùng API 37 (vd `receive_sharing_intent` 1.9.0): `app/android/build.gradle.kts`
     ép mọi plugin có `compileSdkVersion == "android-37"` về `compileSdk = 36` bằng `afterEvaluate`.
   - Bỏ cả hai khi nâng AGP hỗ trợ API 37.
3. `android_file_picker:compileDebugKotlin` — `Could not close incremental caches`: dự án ở ổ **D:**, mã nguồn plugin
   ở ổ **C:** (pub cache) → Kotlin incremental trên Windows lỗi. Sửa: `kotlin.incremental=false` trong
   `app/android/gradle.properties` + xoá `app/build/<plugin>` bị hỏng.
4. `org.gradle.jvmargs` mặc định `-Xmx8G` — giảm còn `-Xmx4G -XX:MaxMetaspaceSize=1G` cho nhẹ laptop 16 GB.

**Quy tắc:** thêm plugin mới → build thử APK debug ngay, vì lỗi Gradle chỉ lộ ra khi build Android (analyze/test không bắt được).

Liên quan: [[0001-flutter-android-truoc]], [[build-song-song-agent]].

## Cài APK lên điện thoại & phát hành (hỏi nhiều ở phiên 26/10)
- File build: `app/build/app/outputs/flutter-apk/app-debug.apk` (~261 MB, đã gồm font Noto). **Không nằm trong git** — chép sang điện thoại bằng
  cáp USB (Truyền tệp), Drive hoặc Telegram. Mở file → cho phép "Cài ứng dụng không rõ nguồn gốc" → Play Protect "Cài đặt vẫn tiếp tục" →
  bật "Truy cập tất cả tệp" trong Cài đặt app.
- **Không cần cáp để chạy thử**, nhưng cắm cáp (Gỡ lỗi USB) mới đọc được log lỗi → sửa nhanh hơn nhiều.
- **Build không cần gộp vào `master`**: build chỉ đọc thư mục `app/` đang checkout; tên nhánh không liên quan. Repo chưa có CI. Chỉ gộp `master`
  khi muốn người khác clone thấy code (nhánh mặc định) — nên đợi test máy thật ổn.
- Bản **debug** to và chậm; bản chính thức: `flutter build apk --release` (làm sau khi ổn). App không có máy chủ/DB ngoài: chỉ SQLite trong máy
  ([[co-so-du-lieu]]) + `shared_preferences`; hoàn toàn offline.
- Thêm plugin → build lại: `url_launcher` (L1) build sạch lần đầu (438 s), không cần vá Gradle.
- Font Noto **không commit**: `bash app/tool/fetch_fonts.sh` ([[xuat-chu-ra-pdf]]).

## Môi trường đổi — build Android 29/10/2026 (đã gặp, tạm xử lý)
Chỉ dẫn "Môi trường" ở trên đã cũ: **không còn** JDK 21 và `C:/Android/sdk`. Hiện có JDK 17 (`C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot`, đặt `JAVA_HOME`),
Android SDK ở `%LOCALAPPDATA%/Android/Sdk` (đúng `local.properties`), Android Studio JBR. Gradle 9.3.1-all (dự án ghim) **không có trong cache**.
- **Tải Gradle từ GitHub CDN chỉ ~41 KB/s** (~80 phút cho 200 MB; file `.part` đứng ở 0 byte), còn `dl.google.com` ~560 KB/s. Máy có sẵn `gradle-9.4.1-bin` → tạm đổi
  `gradle-wrapper.properties` sang `gradle-9.4.1-bin.zip` (chỉ cục bộ, KHÔNG commit, khôi phục sau).
- **Gói `:jni` (phụ thuộc gián tiếp) tự đòi NDK 28.2** (`flutter.ndkVersion`) bất kể `ndkVersion` của app; thư mục NDK 28.2 rỗng do tải dở → lỗi `CXX1101 ... did not have a source.properties`.
  Đã xử lý tạm: chép NDK 27.1 vào thư mục `ndk/28.2.13676358` (trong SDK) và sửa `Pkg.Revision`/`Pkg.BaseRevision` trong `source.properties` (xoá thư mục đó là về như cũ).
- Flutter chỉ in `Gradle task assembleRelease failed with exit code 1` mà không nói lý do → chạy `flutter build apk --release -v` rồi `grep "What went wrong|Caused by"`.
- **`integration_test` trong `pubspec.yaml` làm hỏng build APK release** (`package dev.flutter.plugins.integration_test does not exist` trong `GeneratedPluginRegistrant.java`):
  registrant Android liệt kê plugin dev mà bản release không có. Vì vậy gói này KHÔNG nằm trong pubspec; workflow `ios-sim.yml` chạy `flutter pub add --dev integration_test --sdk=flutter` ngay trên CI.
  `analysis_options.yaml` loại `integration_test/**` và `test_driver/**`. Test chặn hồi quy: `test/core/ios_simulation_test.dart`.
- **Khoá ký debug đã đổi (29/10/2026):** `~/.android/debug.keystore` được tạo mới lúc build (máy bị đặt lại môi trường) → APK ký bằng khoá MỚI (SHA-256 cert `fa9b88c7…`), khác bản cũ (`865ee5c7…`).
  Người đã cài bản cũ phải gỡ rồi cài lại. **Hãy sao lưu `~/.android/debug.keystore` ra nơi an toàn** để các bản sau cài đè được (không đọc/chép nội dung file này vào chat).
- Hai thay đổi tạm (đổi Gradle sang 9.4.1-bin và `ndkVersion`) đã khôi phục bằng `git checkout`; thư mục `ndk/28.2.13676358` trong SDK (bản chép từ NDK 27.1) VẪN CÒN và cần giữ nếu build lại. Build mới cần đặt lại 2 thay đổi tạm nếu mạng tới GitHub vẫn chậm.
