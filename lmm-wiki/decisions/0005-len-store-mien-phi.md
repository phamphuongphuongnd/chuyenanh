---
title: ADR 0005 — Lên Google Play + App Store, miễn phí; bản quyền trước, chính sách store sau
type: decision
updated: 2026-10-30
sources:
  - README.md
  - app/android/app/src/main/AndroidManifest.xml
  - app/ios/Runner/Info.plist
  - app/lib/features/settings/settings_logic.dart
---

# ADR 0005 — Lên store, miễn phí (30/10/2026)

**Bối cảnh:** app trước đây chỉ tự phát APK/IPA qua GitHub Release ([[phat-hanh-apk]], [[ios]]). Người dùng đối chiếu tài liệu
tiêu chuẩn `D:\Phuong\tieu-chuan-ban-app-toan-cau.md` và muốn lên store mà không bị từ chối / khoá vì vi phạm.

**Đã chốt với người dùng:**
- Phát hành **Google Play + App Store**, **miễn phí, không quảng cáo, không mua trong app, không tài khoản**
  ⇒ Apple chỉ cần thoả thuận Free Apps; không thuế/thanh toán.
- **Giai đoạn 1 = bản quyền** (đã xong, xem [[ban-quyen-giay-phep]]). **Giai đoạn 2 = chính sách store** (chưa làm).
- Khoá repo GitHub (private) **sau khi** không còn ai cần link tải APK GitHub; store không cần repo công khai.
- Tên nhà phát triển / Company khi đăng ký: **Phiotron** (cá nhân; App Store tài khoản cá nhân sẽ hiện tên thật).

**Giai đoạn 2 — đã chốt cách làm, chưa code:**
| Vấn đề (theo mức nguy hiểm) | Cách đã chốt |
|---|---|
| `MANAGE_EXTERNAL_STORAGE` (Play hạn chế "All files access") | **Bỏ**; Android làm như iOS: thư mục của app + file chọn bằng bộ chọn hệ thống + "Mở bằng"; Android 7–10 giữ quyền bộ nhớ cũ |
| `READ_MEDIA_IMAGES` + lưới ảnh `photo_manager` (chính sách Ảnh & Video) | **Chuyển sang Photo Picker** (`image_picker.pickMultiImage`) |
| Nút Chia sẻ gửi link APK GitHub + trang Sideloadly (`settings_logic.dart`) | Đổi sang link store; **bản iOS không nhắc Android** (Apple 2.3.10) |
| Chữ "không dùng mạng / không thu thập dữ liệu" sai với ML Kit + Play services (+ ML Kit Translation) | Viết lại đúng sự thật, khớp Data safety / App Privacy |
| Không có URL chính sách bảo mật / Support URL | `PRIVACY.md` (vi+en) — đặt ở chỗ công khai (repo public riêng / Pages) khi repo chính đã khoá |
| Release ký bằng khoá debug | `key.properties` + keystore **người dùng tự tạo** |
| iOS thiếu `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption` | Thêm privacy manifest; mã hoá = **YES** (khoá PDF AES) + **tắt storefront Pháp** + ghi nhớ báo cáo BIS hạn 01/02 |
| Bố cục iPad chưa thử | Đặt **chỉ iPhone** |
| Thư viện native chưa chắc đạt trang 16 KB | Kiểm `.so` trong AAB trước 01/02/2027 |

**Rủi ro còn lại dù làm hết:** Apple 4.3 (spam — nhóm app chuyển đổi PDF rất đông) và crash trên iPhone thật (chưa từng chạy) →
viết mô tả/ảnh store khác biệt, chạy TestFlight trước khi nộp. Play tài khoản cá nhân cần closed test ≥ 12 người × 14 ngày.

Liên quan: [[ban-quyen-giay-phep]], [[phat-hanh-apk]], [[ios]], [[documents]].
