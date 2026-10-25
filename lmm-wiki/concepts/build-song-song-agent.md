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

Liên quan: [[0003-kien-truc-riverpod]], [[thu-vien-dart-thuan]].
