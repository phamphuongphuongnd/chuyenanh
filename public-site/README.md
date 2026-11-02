# Trang công khai của Phiotron PDF (Hỗ trợ + Chính sách bảo mật)

Google Play và App Store bắt buộc có **URL Chính sách bảo mật**; App Store còn bắt **Support URL**. Hai URL đã ghi sẵn
trong app (`app/lib/features/settings/settings_logic.dart`):

- `kSupportUrl`       = `https://phamphuongphuongnd.github.io/phiotron-pdf/`
- `kPrivacyPolicyUrl` = `https://phamphuongphuongnd.github.io/phiotron-pdf/privacy`

Repo chính sẽ chuyển sang **riêng tư**, nên các trang này phải nằm ở một repo **công khai** riêng. Bạn tự làm (khoảng 5 phút):

1. Vào **github.com** (đã đăng nhập) → nút **+** góc trên phải → **New repository**.
2. **Repository name:** `phiotron-pdf` · chọn **Public** · bấm **Create repository**.
3. Trong repo mới bấm **uploading an existing file** → kéo 3 file `index.md`, `privacy.md`, `_config.yml` từ thư mục
   `public-site/` này vào → **Commit changes**. (Không cần file README.md này.)
4. **Settings** → **Pages** → *Build and deployment* → Source: **Deploy from a branch** → Branch: **main**, thư mục **/ (root)** → **Save**.
5. Chờ 1–3 phút rồi mở `https://phamphuongphuongnd.github.io/phiotron-pdf/privacy` — thấy trang chính sách là xong.
6. Dán hai URL trên vào Play Console (Chính sách ứng dụng → Chính sách quyền riêng tư) và App Store Connect (Privacy Policy URL, Support URL).

**Mỗi khi sửa** `privacy.md` hoặc `index.md` ở đây (ví dụ thêm tính năng mới, đổi quyền), tải lại file lên repo `phiotron-pdf`
và đổi **Ngày hiệu lực**. Nội dung phải luôn khớp với khai báo Data safety (Google) và App Privacy (Apple).
