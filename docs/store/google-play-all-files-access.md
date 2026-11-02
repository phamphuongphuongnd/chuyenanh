# Tờ khai "Truy cập tất cả tệp" (All files access) — Google Play

App đang giữ quyền `MANAGE_EXTERNAL_STORAGE` trên Android 11+ để **tìm và liệt kê mọi tài liệu PDF / Word / Excel /
PowerPoint / TXT trên máy** (trang chủ Tài liệu). Google Play coi đây là quyền nhạy cảm: phải khai trong
**Play Console → Nội dung ứng dụng (App content) → Quyền nhạy cảm → All files access** trước khi phát hành. Google
**có thể từ chối**; khi đó phải bỏ quyền (cách làm đã có sẵn trong lịch sử git, commit `6352ec7`).

Nhóm được Google chấp nhận gần nhất: **Document management / File management** (ứng dụng quản lý tài liệu).

## Câu trả lời soạn sẵn (dán vào form, tiếng Anh)

**Core functionality that requires All files access**

> Phiotron PDF is an offline document reader and manager. Its main screen (Documents) shows every PDF, Word (DOC/DOCX),
> Excel (XLS/XLSX), PowerPoint (PPT/PPTX) and TXT file stored on the device, grouped by type, with search, sort,
> favorites and recent files, so users can open, rename, delete, share, convert and edit their documents in one place.
> Building this library requires reading the whole shared storage: on Android 11+ documents created or downloaded by
> other apps (browser, messaging, email, file transfer) are not exposed through MediaStore, and the Storage Access
> Framework only grants access to files the user picks one by one, which cannot provide a device-wide document list.
> All processing happens on the device; no file is uploaded or shared with us or third parties.

**Why a less invasive alternative is not enough**

> We already use the system file picker and "Open with / Share to" for single files, and the system Photo Picker for
> images. These cover one-off actions but cannot discover documents the user has not opened yet, which is the core
> purpose of the app's Documents screen (a document manager). Without the permission the app still works in a reduced
> mode where users pick files manually.

## Video minh hoạ (Google yêu cầu, quay màn hình 30–60 giây, đăng YouTube "Không công khai")

1. Mở app lần đầu → màn **Tài liệu** hiện thông báo giải thích ("Phiotron PDF cần quyền truy cập tất cả file để tìm
   tài liệu trên thiết bị") + nút **Chọn tệp** dự phòng.
2. Bấm cấp quyền → trang Cài đặt hệ thống "Truy cập tất cả tệp" → bật → quay lại app.
3. Danh sách hiện tài liệu ở nhiều thư mục (Download, Zalo/Messenger, Documents…), lọc theo tab PDF/Word/Excel.
4. Mở một PDF, một DOCX; tìm kiếm; đổi tên / chia sẻ / chuyển đổi một tệp.

## Điều kiện phải đúng trong app (kiểm trước khi nộp)

- [ ] Có màn **giải thích trước** khi mở trang cấp quyền (`PermissionGate`, chuỗi `docs_permissionMessage`).
- [ ] **Từ chối quyền vẫn dùng được** (nút "Chọn tệp", "Mở bằng / Chia sẻ" từ app khác).
- [ ] Không xin quyền ngay lúc khởi động mà chỉ khi người dùng bấm.
- [ ] Chính sách bảo mật (`public-site/privacy.md`) và Data safety ghi rõ quyền này, tệp không rời máy.
- [ ] Mô tả trên store nói rõ app là **trình quản lý tài liệu** (quét cả máy), khớp với tờ khai.

Nếu bị từ chối: gửi kháng nghị một lần với video rõ hơn; vẫn bị từ chối thì bỏ quyền (Android làm như iOS: thư mục của
app + tệp chọn / mở bằng app) rồi nộp lại.
