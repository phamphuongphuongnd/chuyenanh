# Nguồn gốc bộ skill `superpowers`

14 skill dưới đây được chép vào project ngày **2026-08-19**, KHÔNG cài qua hệ thống plugin:

| | |
|---|---|
| Nguồn | https://github.com/obra/superpowers.git |
| Commit đã ghim | `6fd4507659784c351abbd2bc264c7162cfd386dc` |
| Giấy phép | xem `SUPERPOWERS-LICENSE` |
| Cách cài | chép tay thư mục `skills/`, **chỉ project này** |

## Vì sao chép tay thay vì `/plugin install`

`/plugin install superpowers@claude-plugins-official` đặt file vào `~/.claude/plugins`
(**dùng chung mọi project**) và đăng ký một hook `SessionStart` ở mức tài khoản.
Người dùng muốn phạm vi gói gọn trong project này nên chọn cách chép tay:
không đụng gì vào `~/.claude`, không hook nào được đăng ký.

## Những gì CỐ Ý KHÔNG chép

- `hooks/` — hook `SessionStart` (chỉ nạp sẵn nội dung skill `using-superpowers` vào đầu phiên).
  **Hệ quả**: Claude không được nhắc trước về bộ skill này; vẫn dùng được nhưng phải gọi tên.
- `scripts/`, `tests/`, `docs/`, `assets/`, `package.json`, các manifest `.claude-plugin` /
  `.codex-plugin` / `.cursor-plugin`.

## 14 skill

brainstorming · dispatching-parallel-agents · executing-plans · finishing-a-development-branch ·
receiving-code-review · requesting-code-review · subagent-driven-development ·
systematic-debugging · test-driven-development · using-git-worktrees · using-superpowers ·
verification-before-completion · writing-plans · writing-skills

## ⚠️ File thực thi đi kèm — biết trước để không bất ngờ

Skill không chỉ có Markdown. Những file sau nằm trong `skills/` và **chỉ chạy khi skill tương ứng
được dùng**, không có gì tự chạy nền:

| File | Việc nó làm |
|---|---|
| `brainstorming/scripts/server.cjs` + `start-server.sh` / `stop-server.sh` | Dựng **HTTP server cục bộ** cho giao diện brainstorm: bind `127.0.0.1`, cổng ngẫu nhiên 49152–65535, chỉ dùng module có sẵn của Node (`http`/`fs`/`path`/`crypto`), **không gọi ra ngoài mạng**. Ghi file phiên vào `/tmp/brainstorm-*` hoặc `<project>/.superpowers/brainstorm/`. |
| `brainstorming/scripts/helper.js`, `frame-template.html` | Giao diện của server trên. |
| `systematic-debugging/find-polluter.sh` | Dò test gây nhiễu (chạy test lặp). |
| `systematic-debugging/condition-based-waiting-example.ts` | File ví dụ, không chạy. |
| `writing-skills/render-graphs.js`, `graphviz-conventions.dot` | Vẽ sơ đồ bằng graphviz. |

## Cập nhật / gỡ bỏ

- **Cập nhật**: không tự động. Muốn nâng cấp thì lấy commit mới từ repo gốc rồi chép đè, và sửa
  SHA ghi ở trên.
- **Gỡ**: xoá 14 thư mục skill + `SUPERPOWERS-LICENSE` + file này. Không còn dấu vết ở đâu khác.
