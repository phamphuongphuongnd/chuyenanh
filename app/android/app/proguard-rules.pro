# ML Kit: các bộ nhận dạng chữ Hán/Nhật/Hàn/Devanagari là gói tuỳ chọn, app không đóng kèm.
# Bỏ cảnh báo để R8 (bản release) không dừng build vì "Missing class".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
