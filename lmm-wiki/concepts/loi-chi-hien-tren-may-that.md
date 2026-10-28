---
title: Lỗi chỉ lộ trên máy thật / bản release (bài học 28/10/2026)
type: concept
updated: 2026-10-28
sources:
  - app/lib/features/scanner/export/scan_export_providers.dart
  - app/android/app/build.gradle.kts
  - app/android/app/proguard-rules.pro
  - app/test/features/scanner/scan_exporter_provider_test.dart
---

# Lỗi chỉ lộ trên máy thật / bản release

Test tự động (~740 test, dùng engine giả) **đều xanh** nhưng 3 lỗi nặng vẫn lọt tới người dùng. Cả ba chỉ lộ khi chạy bản release thật trên Galaxy A13.

| Lỗi | Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|---|
| ML Kit không khởi động (R8) | Quét tài liệu chỉ mở camera thường, OCR hỏng | R8 xoá constructor `ComponentRegistrar` (log: `ComponentDiscovery ... NoSuchMethodException`) | keep rule, rồi **tắt R8** (xem [[phat-hanh-apk]]) |
| Google quét xong báo `Failed to handle result` | "Đã xảy ra lỗi" sau khi chụp | R8 thu gọn làm hỏng bước nhận kết quả của ML Kit | tắt `isMinifyEnabled` |
| **Xuất PDF/TXT/DOCX sau khi quét báo "Đã xảy ra lỗi"** | cả 3 định dạng hỏng ngay, không tạo file | `scanExporterProvider` là `FutureProvider.autoDispose` chỉ bị `ref.read(...future)` (không ai `watch`) → tự huỷ giữa lúc `await` → `Cannot use the Ref ... after it has been disposed` | bỏ `autoDispose`, đọc `ref.watch(engine)` **trước** mọi `await`; có test `scan_exporter_provider_test.dart` |

## Quy tắc rút ra
- Provider bất đồng bộ chỉ được **`read`** (không `watch`) thì **không dùng `autoDispose`**; và mọi `ref.watch/read` phải đứng trước `await` đầu tiên.
  Test: `ProviderContainer` không listener + override phụ thuộc bằng future có `Future.delayed` → phải dựng xong, không ném lỗi.
- Lỗi bị `catch` rồi chỉ hiện "Đã xảy ra lỗi. Vui lòng thử lại." (`AppError.Unknown`) **không để lại log** ở bản release. Đã thêm `debugPrint('scan: ... lỗi: $e | $st')` ở màn quét;
  đọc bằng `adb logcat -d --pid=$(pidof com.phuong.pdfoffice) | grep "scan:"`. Khi gặp lỗi chung chung, thêm log kèm stack trước khi đoán.
- Mọi build release phải thử **luồng thật**: Quét (chụp → Áp dụng → Tiếp theo) → Xuất PDF/Word → kiểm file ở `/storage/emulated/0/Download/Pdf`. Kiểm log:
  `ComponentDiscovery` phải rỗng; màn quét phải là `com.google.android.gms.mlkit.docscan.ui.DocumentScanningActivity`.
- Tái hiện bằng ADB không cần ảnh riêng tư: `uiautomator dump` đọc chữ/`bounds`; tạo xong **xoá file thử** do mình tạo (`adb shell rm`). Bấm theo nhịp có chờ + kiểm `mCurrentFocus`
  (kịch bản bấm cố định dễ lệch nhịp khi màn Google chậm; `GmsDocumentScanningDelegateActivity` thuộc package app nên đừng dùng package để nhận biết đã về app).
- Máy thử RAM thấp (3,8GB, trống ~380MB): nhiều app nền bị `lmkd` tắt khi bật camera; chat nổi Zalo có thể đè lên màn hình khi chụp ảnh — **không đọc/giữ ảnh chụp màn hình có nội dung riêng tư**.

Liên quan: [[phat-hanh-apk]], [[kiem-thu-flutter]], [[0003-kien-truc-riverpod]], [[tinh-nang-t1-t10]], [[viec-con-lai]].
