---
title: Schema — Bộ luật của LLM Wiki
type: schema
updated: 2026-10-22
---

# SCHEMA — Bộ luật của wiki này

> Wiki này theo phương pháp **"LLM Wiki"** của Andrej Karpathy
> (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
> Mục tiêu: sau mỗi phiên làm việc **được người dùng xác nhận code chạy tốt**, kiến thức được
> **chắt lọc & tích luỹ** vào đây (gộp, khử trùng lặp, liên kết chéo) thay vì đọc lại code từ đầu mỗi lần.

## 3 lớp (3 layers)

1. **Raw sources** (bất biến — *không bao giờ sửa*): code thật của project (các thư mục chính ghi ở mục Tổng quan dự án trong `index.md`), và các file trong `planhistory/`.
2. **Wiki** (LLM sở hữu & bảo trì): chính thư mục `lmm-wiki/` này.
3. **Schema** (cấu hình): file này.

## Cấu trúc thư mục

| Đường dẫn | Nội dung |
|-----------|----------|
| `index.md` | Mục lục mọi trang + bản đồ liên kết. **Luôn đọc đầu tiên.** |
| `log.md` | Nhật ký append-only, mỗi phiên 1 dòng có timestamp. |
| `preferences.md` | Preference cách làm việc của người dùng. |
| `modules/*.md` | 1 trang / module hoặc thành phần chức năng (vd module `user`, màn hình đăng nhập, lệnh CLI `import`, package `parser`). |
| `entities/*.md` | 1 trang / kiểu dữ liệu chính (vd bảng/model/class `User`). |
| `concepts/*.md` | Pattern/kỹ thuật xuyên suốt (vd cách thêm một tính năng theo đúng cấu trúc, setup test). |
| `decisions/NNNN-*.md` | ADR ngắn — quyết định đã chốt với người dùng. |

## Quy ước trang (page conventions)

- **Ngôn ngữ: song ngữ** — tiêu đề & giải thích tiếng Việt; tên file/field/thuật ngữ/code giữ tiếng Anh.
- Tên file: `kebab-case.md`.
- Frontmatter nhẹ ở đầu mỗi trang:
  ```yaml
  ---
  title: <tiêu đề tiếng Việt>
  type: module | entity | concept | decision | preferences
  updated: YYYY-MM-DD
  sources:            # trỏ tới raw-source (bất biến)
    - <thư-mục>/...       # đường dẫn code
    - planhistory/....md  # file phiên
  ---
  ```
- **Liên kết chéo** giữa các trang bằng `[[slug]]` (slug = tên file không đuôi, vd `[[user]]`).
  Mở được bằng **Obsidian** như một vault.
- Trích dẫn code dạng `path/to/file.ts:line` để click mở được.

---

## Thao tác 1 — INGEST (nạp phiên mới)

**Khi nào chạy:** người dùng gõ `/luu-wiki`, **hoặc** nói câu xác nhận như
*"code chạy tốt rồi, lưu lại"*, *"lưu wiki"*, *"lưu phiên"*, *"ok lưu lại"*.

**Các bước (bắt buộc theo thứ tự):**
1. **Đọc `index.md` trước** để biết trang nào đã có → tránh đọc lại toàn bộ code.
2. **Chắt lọc** từ phiên đang làm, đúng 6 nhóm:
   - *Yêu cầu người dùng nhập* (requirement gốc).
   - *Quyết định đã chốt* (đã hỏi & người dùng đồng ý) → tạo/cập nhật `decisions/`.
   - *File đã sửa/tạo* (đường dẫn + ý nghĩa) → `modules/` / `entities/`.
   - *Pattern dùng lại được* → `concepts/`.
   - *Gotcha / rủi ro / cạm bẫy* → `concepts/` hoặc trang liên quan.
   - *Preference cách làm việc* mới lộ ra → `preferences.md`.
3. **Cập nhật/ tạo đúng trang.** GỘP vào trang sẵn có nếu chủ đề đã tồn tại; **khử trùng lặp**;
   **KHÔNG dump nguyên transcript** — chỉ giữ kết luận tái sử dụng được.
4. **Bảo trì liên kết chéo `[[...]]`** giữa các trang vừa đụng; cập nhật `index.md` (thêm dòng nếu có trang mới).
5. **Append 1 dòng vào `log.md`**:
   `- YYYY-MM-DD HH:MM — <tóm tắt 1 dòng> → [[trang-a]] [[trang-b]]`
6. Nếu phiên có file `planhistory/*.md`, thêm nó vào `sources:` của (các) trang liên quan.

**Nguyên tắc:** chỉ lưu cái **tái sử dụng được ở phiên sau**. Nghi ngờ thì hỏi người dùng
*"điều gì ở đây là không hiển nhiên, đáng lưu?"* rồi lưu đúng cái đó.

---

## Thao tác 2 — QUERY (trả lời từ wiki)

Khi cần kiến thức về project (module/entity/pattern/quyết định):
1. Đọc `index.md` → mở (các) trang liên quan.
2. Trả lời **từ wiki**, kèm trích dẫn `[[...]]` và/hoặc đường dẫn code `path:line`.
3. Chỉ đọc lại code thật khi wiki thiếu hoặc nghi ngờ đã lỗi thời (rồi cân nhắc Lint).

---

## Thao tác 3 — LINT (dọn dẹp định kỳ)

**Khi nào chạy:** người dùng gõ `/luu-wiki lint`, hoặc định kỳ.
Rà soát và **báo cáo + đề xuất sửa** (không tự ý xoá lớn nếu chưa hỏi):
- **Mâu thuẫn** giữa các trang.
- **Claim lỗi thời** — đối chiếu với code hiện tại (path:line còn đúng không).
- **Trang mồ côi** — không trang nào `[[link]]` tới.
- **Thiếu liên kết** — chủ đề liên quan nhưng chưa nối.
- **Lỗ hổng kiến thức** — vùng code quan trọng chưa có trang.
