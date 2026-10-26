---
title: Build song song nhiều agent không dẫm chân nhau
type: concept
updated: 2026-10-25
sources:
  - docs/superpowers/plans/2026-10-25-parallel-build-contract.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# Build song song nhiều agent không dẫm chân nhau

Pattern đã dùng khi người dùng muốn "tách nhiều agent nhất có thể" (xem [[preferences]]).

1. **Hợp đồng trước, agent sau.** Viết `docs/superpowers/plans/…-parallel-build-contract.md`: bảng **sở hữu file**
   (ai được sửa gì), route/hằng/interface dùng chung, quy ước chuỗi dịch, lệnh kiểm, mẫu báo cáo.
2. **Đợt 0 — MÓNG tuần tự** (1 agent): mọi file dùng chung (pubspec, Manifest, router, DB, interface engine,
   placeholder cho từng feature: `<f>_routes.dart`, `<f>_providers.dart`, `l10n/<prefix>_*.arb`).
3. **Song song ngay từ đầu những gì không phụ thuộc MÓNG**: thư viện **Dart thuần** trong `packages/` (ngoài `app/`),
   mỗi agent một **git worktree** (`isolation: worktree`). Dart thuần → test bằng `dart test`, không vướng Flutter lock.
4. **Đợt 1 — agent tính năng**, mỗi agent một worktree, chỉ sửa `app/lib/features/<f>/**` + file impl engine của mình.
   Agent nào cần thư viện thì **chờ thư viện được merge** rồi mới tung (đừng code theo API đoán).
5. **Đợt 2 — ghép:** merge từng nhánh, gộp `.arb`, `flutter analyze` + `flutter test` + `flutter build apk --debug`.

**Gotcha:**
- Flutter có **startup lock** — nhiều agent chạy lệnh `flutter` cùng lúc sẽ xếp hàng. Gom lệnh.
- Thêm `.claude/worktrees/` vào `.gitignore` trước khi ai đó `git add -A`.
- Đừng merge vào checkout chính khi agent MÓNG còn đang làm ở đó (tránh đua `git index.lock`).
- **Tự chạy lại test của agent** trước khi tin báo cáo (agent có thể báo sai).
- Ghi checkpoint vào `planhistory/` sau mỗi mốc để phiên mới làm tiếp được.

**Bài học 26/10 (đắt giá):**
- **10 agent cùng lúc → cả 10 cùng chạm giới hạn lượt dùng** khi mỗi agent mới được ~1 commit (logic + engine, chưa có UI). Tổng
  khối lượng không đổi dù chạy song song; chạy song song chỉ làm cạn lượt nhanh hơn. **Chia đợt ~5 agent**, ưu tiên luồng chính
  (T1 trang chủ, T3 đọc PDF, T2 ảnh→PDF…) để có app xem được sớm, đừng để 10 thứ dở dang.
- Agent bị cắt vẫn **giữ được việc** nếu đã commit; file chưa commit nằm ở worktree (`.claude/worktrees/agent-<id>`) → commit WIP
  thủ công rồi `git push origin <nhánh-worktree>:refs/heads/feat/...` (đã làm cho T1…T10).
- `SendMessage` tới agent đã dừng để chạy tiếp cần người dùng đồng ý; người dùng có thể từ chối và chọn bàn giao cho người khác. Khi được phép,
  agent **giữ nguyên ngữ cảnh** và chạy tiếp từ worktree cũ (đợt 2 T6–T9 làm theo cách này, xong trong ~15 phút/agent).
- **Ghép nhiều nhánh**: tạo nhánh tạm `integrate` trong worktree riêng, merge lần lượt, chạy `analyze` + `test` MỘT lần cho cả bản ghép, sửa lỗi xuyên
  nhánh (tên trùng như `PdfFilePicker`, test cũ đòi màn giữ chỗ), rồi mới merge vào nhánh chính. Thư mục worktree có `build/` dài làm `git worktree remove`
  lỗi "Filename too long" → làm rỗng bằng `robocopy <thư-mục-rỗng> <đích> /MIR` rồi xoá.
- Không gộp tới khi cả hai agent xong và kiểm một lần → tiết kiệm lượt dùng so với kiểm riêng từng nhánh.
- Worktree của agent **có thể bắt đầu từ commit cũ** (đã gặp 4 lần) → bước 0 của mọi prompt: `git merge --ff-only feat/pdf-office`.
- Agent tạo file thử nghiệm tạm (`probe_*`, `exp_test`) — đừng commit lên nhánh bàn giao.

Liên quan: [[0003-kien-truc-riverpod]], [[thu-vien-dart-thuan]], [[tinh-nang-t1-t10]].
