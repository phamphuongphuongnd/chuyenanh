# ML Kit: các bộ nhận dạng chữ Hán/Nhật/Hàn/Devanagari là gói tuỳ chọn, app không đóng kèm.
# Bỏ cảnh báo để R8 (bản release) không dừng build vì "Missing class".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit khởi tạo các `ComponentRegistrar` bằng reflection (constructor không tham số). R8 coi
# constructor là "không dùng" và xoá → `NoSuchMethodException` lúc chạy: quét tự động của Google
# và OCR đều hỏng ở bản release. Phải giữ lại.
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.firebase.components.** { *; }
