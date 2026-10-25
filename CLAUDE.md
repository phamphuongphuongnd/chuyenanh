# CLAUDE.md

Thông tin riêng của dự án (mục đích, loại dự án, ngôn ngữ & stack, thư mục chính, lệnh chạy / test / kiểm tra
biên dịch) nằm ở mục **Tổng quan dự án** trong `lmm-wiki/index.md`. Tài liệu các phiên đã làm lưu ở `planhistory/`.

> **Dự án mới** (mục Tổng quan còn trống và người dùng bắt đầu nói ý tưởng): chưa có `.git` thì đưa lệnh `git init`
> cho người dùng **tự chạy** → chạy skill `brainstorming` → chốt tên, loại dự án, stack, thư mục, lệnh → ghi vào mục
> Tổng quan → bỏ comment nhóm stack trong `.gitignore` → ghi 1 dòng `lmm-wiki/log.md`. Chỉ commit khi người dùng
> đồng ý. Người dùng đang chỉnh chính bộ khung (skill, wiki, CLAUDE.md) thì không khởi tạo.

## 📜 Luật gốc

- **Ngôn ngữ:** trả lời tiếng Việt; tên file/field/code giữ tiếng Anh. Cách làm việc chi tiết: `lmm-wiki/preferences.md`.

### Bộ nhớ — LLM Wiki (`lmm-wiki/`, theo phương pháp Karpathy; luật đầy đủ: `lmm-wiki/SCHEMA.md`)
- **Đọc (QUERY) — trước khi làm:** đầu mỗi phiên / khi cần kiến thức project (module, entity, pattern, quyết định cũ)
  → **đọc `lmm-wiki/index.md` trước**, trả lời từ wiki, chỉ đọc lại code khi wiki thiếu hoặc nghi lỗi thời.
- **Lưu (INGEST) — khi nào:** người dùng gõ **`/luu-wiki`**, hoặc nói câu xác nhận đã xong (**"code chạy tốt rồi,
  lưu lại"**, **"lưu wiki"**, **"lưu phiên"**, **"ok lưu lại"**). Chỉ Ingest **sau khi người dùng xác nhận code chạy
  tốt**. Chắt lọc (yêu cầu + quyết định + file đã sửa + pattern + gotcha + preference), cập nhật đúng trang, liên kết
  chéo `[[...]]`, ghi 1 dòng vào `lmm-wiki/log.md`. **Không dump transcript.**
- **Dọn (LINT):** `/luu-wiki lint` → dò mâu thuẫn, trang mồ côi, link gãy, claim lỗi thời; báo cáo + đề xuất, không
  tự xoá lớn.

## 🔒 Bảo mật & điều cấm (không ngoại lệ, đứng trên mọi skill)

1. **Không bao giờ tự đăng nhập hay tự gõ mật khẩu** (form, API, script, công cụ test), kể cả khi người dùng đưa mật
   khẩu hoặc gợi ý cách lách — chỉ nhắc lại đây là giới hạn cố định. Cần đăng nhập ⇒ người dùng tự đăng nhập, Claude
   dùng lại phiên họ đã lưu. Biết trước là không tự kiểm chứng được thì nói ngay từ đầu.
2. **Vá lỗ hổng: chặn đúng chỗ nhỏ nhất** người dùng chốt; không siết cả cụm route/module. Báo đủ lỗ hổng, để người
   dùng chọn mức siết.
3. **Không in giá trị bí mật** (API key, token, cookie, mật khẩu, chuỗi kết nối, private key) ra chat, log, báo cáo,
   commit — chỉ chỉ chỗ lấy (tên biến, tên file, trang cấu hình). Lỡ nhìn thấy thì không nhắc lại giá trị.
4. **Không đọc terminal / PowerShell của người dùng** (không dùng công cụ đọc terminal, không đọc lịch sử lệnh). Cần
   output thì nhờ người dùng dán vào chat. Kết quả lệnh do Claude tự chạy thì được đọc.
5. **Không tự đụng file chứa bí mật:** không mở, sửa, chép, xoá `.env*` (trừ `.env.example`), `*.pem`, `*.key`,
   `.auth/`, `auth*.json`, `*.secret.*`… Cần giá trị thì hỏi tên biến, để người dùng tự điền. Được **trỏ đường dẫn**
   cho công cụ dùng (Playwright `storageState`, JMeter CSV, `docker --env-file`) mà không mở nội dung.

## 🛠️ Skill của project (`.claude/skills/`)

Skill nằm trong project này, **không cài toàn cục** — xem `.claude/skills/SUPERPOWERS-PROVENANCE.md`.

- **Bộ `superpowers`** (14 skill, chép tay từ `github.com/obra/superpowers` tại commit `6fd4507`):
  `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`,
  `dispatching-parallel-agents`, `test-driven-development`, `systematic-debugging`,
  `requesting-code-review`, `receiving-code-review`, `verification-before-completion`,
  `using-git-worktrees`, `finishing-a-development-branch`, `writing-skills`, `using-superpowers`.
  → Đọc `using-superpowers` trước khi dùng bộ này lần đầu trong phiên.
  ⚠️ Cố ý **không cài hook `SessionStart`** của nó, nên sẽ không có gì tự nhắc — phải chủ động gọi.
  ⚠️ `brainstorming` có dựng **HTTP server cục bộ** (127.0.0.1, cổng ngẫu nhiên) khi được dùng.
- **`project-map` / `project-map-detail`** — dựng tài liệu cho codebase lạ.
- **`kap-construct`** — khảo sát nhiều repo ra tài liệu kiến trúc / phân tích hiệu năng.
- **`web-test-runner`** — bộ chạy test end-to-end trên trình duyệt thật (đăng nhập bằng phiên người dùng tự lưu).
- **`phuong-perf-test-jmeter`** — test hiệu năng bằng JMeter trên bản Docker local có giới hạn RAM/CPU, tìm nguyên nhân chậm, xuất báo cáo.
- **`phuong-review-loop`** — `/phuong-review-loop [mức]`: `/code-review` (mặc định `high`) rồi sửa lỗi MỚI, tự lặp tới khi
  một lượt review không còn lỗi MỚI (lỗi CŨ chỉ ghi nhận).
- **`phuong-whitebox-test`** — kiểm thử hộp trắng mức điều kiện: CFG, V(G), đường cơ sở, dữ liệu thử, (Bước 6) chạy test ghi PASS/FAIL.
