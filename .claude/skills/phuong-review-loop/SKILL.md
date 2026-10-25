---
name: phuong-review-loop
description: Use when the user types /phuong-review-loop, or asks to review the current changes and fix every NEW defect repeatedly until a review finds none — e.g. "code-review high rồi sửa lỗi mới, lặp lại tới khi hết lỗi", "review tới sạch".
---

# Review lặp tới sạch (`/phuong-review-loop [mức]`)

## Tổng quan
Lặp: `/code-review <mức>` (mặc định `high`) → sửa mọi lỗi **MỚI** → review lại… cho tới khi một lượt review **không còn lỗi
MỚI**. Lỗi **CŨ** chỉ ghi nhận, không sửa (trừ khi người dùng bảo).

**Chỉ được dừng sau một lượt review sạch.** Sửa xong mà chưa review lại = chưa xong.

## Mỗi vòng
1. **Review** — gọi Skill `code-review` với args = mức. Kết quả tiếng Việt, mỗi mục ghi rõ **[MỚI]** (do / lộ ra từ thay đổi
   đang review) hay **[CŨ]** (có từ trước — đối chiếu bản HEAD / `git log -L`).
   **Phạm vi = thay đổi chưa commit của MỌI repo bị đụng.** Workspace có thể chứa repo git LỒNG riêng (vd BE/FE/DB mỗi thư
   mục một repo) — `git diff` ở repo gốc KHÔNG thấy chúng (sẽ báo "sạch" giả). Vòng đầu dò hết repo:
   `find . -maxdepth 3 -name .git -not -path '*/node_modules/*'`, rồi lấy diff từng repo: `git -C <repo> status --short` +
   `git -C <repo> diff HEAD`, kể cả file chưa track. Không có repo git nào ⇒ hỏi người dùng danh sách file cần review.
2. **Không còn [MỚI]** → sang *Kết thúc*.
3. **Kiểm từng lỗi MỚI trước khi sửa** (đọc code, đọc mã nguồn thư viện, đo thật). Finding sai ⇒ `no_change_needed` kèm bằng
   chứng — không sửa cho có, gỡ luôn phần đã sửa thừa.
4. **Sửa theo TDD** (REQUIRED: test-driven-development): test đỏ trước → sửa → xanh → **kiểm chiều ngược** (gỡ bản sửa ⇒ test
   phải đỏ). Không sửa lỗi CŨ, không tiện tay sửa thứ khác.
5. **Kiểm chứng** phần bị đụng (REQUIRED: verification-before-completion): test toàn repo liên quan, lint, kiểm kiểu, build;
   thay đổi giao diện ⇒ kiểm trên trình duyệt thật.
6. **ReportFindings lại** các mục của lượt vừa rồi với `outcome` (fixed / no_change_needed / skipped).
7. Báo 3–5 dòng (vòng N: sửa gì, bác bỏ gì, còn gì) rồi **tự quay lại bước 1** — không chờ người dùng gõ lệnh.

## Dừng giữa chừng và hỏi
- Bản sửa cần **migration**: chỉ viết file migration, báo lệnh, **DỪNG** chờ người dùng tự chạy; chạy xong mới kiểm tiếp.
- Một lỗi **quay lại** sau khi đã sửa (sửa A sinh B, sửa B sinh lại A) hoặc **quá 8 vòng** ⇒ dừng, trình bày, hỏi hướng.
- Lỗi cần **quyết định nghiệp vụ** / đổi thứ người dùng thấy / có đánh đổi ⇒ AskUserQuestion trước khi sửa.
- Người dùng nhắn giữa chừng (vd "sửa luôn lỗi cũ") ⇒ làm theo rồi tiếp vòng lặp.

## Kết thúc
Báo: số vòng; bảng lỗi đã sửa / bác bỏ (kèm lý do); lỗi CŨ còn lại (chờ duyệt); kết quả kiểm chứng (số test, lint, kiểu,
build, trình duyệt); những gì **chưa** kiểm được. **Không commit.** Project có lệnh lưu wiki (vd `/luu-wiki`) ⇒ gợi ý chạy
khi người dùng xác nhận code chạy tốt.

## Luật chung (luôn giữ)
- Không commit. Không tự chạy migration.
- Thử có ghi DB thì chỉ dùng dữ liệu thử do mình tạo (đặt tiền tố nhận ra được) và xoá ngay.
- Không sửa `node_modules/`, `dist/`, `build/`, `.git/`.
- **Luật riêng của project** (trang không được mở, dữ liệu không được đụng, quy ước dữ liệu thử…): đọc `CLAUDE.md` và
  wiki/preferences của project (nếu có) ở vòng đầu, giữ suốt vòng lặp.

## Dấu hiệu đang làm sai
| Ý nghĩ | Thực tế |
|---|---|
| "Sửa xong rồi, chắc sạch" | Chưa review lại thì chưa biết — chạy vòng tiếp |
| "Tiện sửa luôn lỗi cũ" | Chỉ sửa MỚI; CŨ để người dùng duyệt |
| "Finding nói vậy chắc đúng" | Kiểm trước — finding có thể sai |
| "Test xanh là xong" | Phải thấy đỏ trước + kiểm chiều ngược |
| "Chờ người dùng gõ /code-review tiếp" | Skill tự lặp tới khi sạch |
