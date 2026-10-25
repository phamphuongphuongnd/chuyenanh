---
description: Lưu kiến thức phiên hiện tại vào lmm-wiki (Ingest), hoặc dọn dẹp (lint)
argument-hint: "[lint]"
---

Bạn đang vận hành **LLM Wiki** tại `lmm-wiki/` của project này. Đọc luật ở `lmm-wiki/SCHEMA.md`.

Tham số: `$ARGUMENTS`
- Nếu là `lint` → chạy thao tác **LINT** (mục 3 dưới).
- Ngược lại (rỗng) → chạy thao tác **INGEST** (mục dưới).

---

## INGEST — nạp phiên hiện tại vào wiki

CHỈ chạy khi code đã được xác nhận hoạt động tốt (test pass / người dùng đã kiểm thử).
Nếu chưa rõ, hỏi người dùng trước.

Thực hiện đúng 6 bước trong `lmm-wiki/SCHEMA.md` → thao tác INGEST:

1. **Đọc `lmm-wiki/index.md` trước** để biết trang nào đã tồn tại (đừng đọc lại toàn bộ code).
2. **Chắt lọc** từ phiên đang làm, đúng 6 nhóm:
   - Yêu cầu người dùng nhập (requirement gốc).
   - Quyết định đã chốt (đã hỏi & được đồng ý) → `decisions/NNNN-*.md`.
   - File đã sửa/tạo (đường dẫn + ý nghĩa) → `modules/` / `entities/`.
   - Pattern dùng lại được → `concepts/`.
   - Gotcha / rủi ro → `concepts/` hoặc trang liên quan.
   - Preference cách làm việc mới → `preferences.md`.
3. **Cập nhật/ tạo đúng trang.** Gộp vào trang sẵn có nếu chủ đề đã có; khử trùng lặp;
   **KHÔNG dump nguyên transcript** — chỉ giữ kết luận tái sử dụng được. Giữ song ngữ (giải thích tiếng Việt, code/tên tiếng Anh).
   Mỗi trang có frontmatter `title/type/updated/sources` như các trang hiện có.
4. **Bảo trì liên kết chéo `[[slug]]`** giữa các trang vừa đụng; cập nhật `lmm-wiki/index.md` nếu có trang mới.
5. **Append 1 dòng vào `lmm-wiki/log.md`**:
   `- YYYY-MM-DD HH:MM — <tóm tắt 1 dòng> → [[trang-a]] [[trang-b]]`
   (Lấy ngày giờ thật.)
6. Nếu phiên có file `planhistory/*.md`, thêm đường dẫn đó vào `sources:` của (các) trang liên quan.

Cuối cùng, **báo cáo ngắn**: đã tạo/cập nhật trang nào, thêm liên kết gì, dòng log vừa ghi.

---

## LINT — dọn dẹp wiki

Rà soát toàn bộ `lmm-wiki/` và **báo cáo + đề xuất sửa** (không tự xoá lớn nếu chưa hỏi người dùng):
- Mâu thuẫn giữa các trang.
- Claim lỗi thời — đối chiếu code hiện tại (kiểm tra các đường dẫn `path:line` trong `sources` còn đúng không).
- Trang mồ côi (không trang nào `[[link]]` tới) và liên kết `[[...]]` bị gãy (trỏ tới file không tồn tại).
- Thiếu liên kết giữa các trang liên quan.
- Lỗ hổng kiến thức (vùng code quan trọng chưa có trang).
