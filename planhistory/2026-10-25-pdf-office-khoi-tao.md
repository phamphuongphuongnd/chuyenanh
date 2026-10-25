# Phiên 2026-10-25 — PDF Office: thiết kế + build song song nhiều agent

> **Đọc file này trước khi làm tiếp ở phiên mới.** Mục "Trạng thái / checkpoint" được cập nhật sau mỗi mốc.
> Thiết kế: `docs/superpowers/specs/2026-10-25-pdf-office-design.md` · Hợp đồng chia việc:
> `docs/superpowers/plans/2026-10-25-parallel-build-contract.md` · Wiki: `lmm-wiki/index.md`.

## Yêu cầu gốc
Làm app giống app Google Play "Chuyển đổi hình ảnh sang PDF" (TrustedOffice, `com.readpdf.pdfreader.pdfviewer`),
**y hệt chức năng và bố cục**, bám đúng app gốc này. Người dùng cần gấp → tách tối đa agent song song.
Phải test trước khi commit; test trên điện thoại thật (Samsung Galaxy A13) để sau.

## Quyết định đã chốt
Flutter · Android trước (minSdk 24) · Syncfusion Community · Riverpod + go_router + drift · 7 ngôn ngữ
(vi, en, zh, ja, ko, th, id) · dùng cá nhân, không store, không quảng cáo, offline · quét toàn máy
(MANAGE_EXTERNAL_STORAGE) · thêm "chọn thư mục lưu" · tên PDF Office `com.phuong.pdfoffice`. Chi tiết: wiki
`decisions/0001-…` → `0004-…`.

## Môi trường đã dựng
| Thứ | Vị trí | Ghi chú |
|---|---|---|
| Flutter 3.47.8 / Dart 3.13.7 | `C:\src\flutter` (người dùng tự clone) | Không có trong PATH → gọi `/c/src/flutter/bin/flutter` |
| Android SDK (cmdline-tools, platform-tools, platform 36, build-tools 36) | `C:\Android\sdk` | Người dùng đã tự chấp nhận license; `flutter config --android-sdk` đã trỏ vào |
| JDK 21 | `C:\Program Files\Microsoft\jdk-21…` | có sẵn |
| Android Studio | người dùng đang cài bằng winget | không bắt buộc |
| Điện thoại | Samsung Galaxy A13 | **chưa cắm** — cần Samsung USB Driver + bật Gỡ lỗi USB |

## Kế hoạch build song song
- **Đợt 0 — MÓNG** (1 agent, làm trên `feat/pdf-office` trong checkout chính): `app/` Flutter, pubspec, Manifest,
  core (theme/router/l10n/errors/utils/widgets), drift DB, interface engine, khung 10 feature.
- **Thư viện Dart thuần** (4 agent, worktree riêng, thư mục `packages/`): `pptx_reader`, `office_reader`,
  `pdf_layout`, `image_ops`.
- **Đợt 1 — 10 agent tính năng** (worktree riêng, mỗi agent chỉ sửa `app/lib/features/<f>/**`): documents,
  image_to_pdf (cần image_ops), reader, pdf_tools, editor, convert (cần office_reader + pdf_layout),
  office_viewer (cần office_reader), office_pptx (cần pptx_reader), scanner (cần image_ops), settings.
- **Đợt 2 — ghép**: merge các nhánh, `merge_arb` + `gen-l10n`, `flutter analyze` sạch, `flutter test` pass,
  `flutter build apk --debug` thành công, review → mới commit cuối.
- **Đợt 3 — điện thoại**: cài lên A13, chụp màn hình, báo cáo review.

## Trạng thái / checkpoint (cập nhật liên tục)
| Thời điểm | Việc | Trạng thái | Nhánh / commit |
|---|---|---|---|
| 22:5x | Spec + khung wiki + .gitignore | ✅ | `feat/pdf-office` @ `df60f88` |
| 23:20 | Flutter SDK + Android SDK | ✅ | — |
| 23:2x | `office_reader` (DOCX/XLSX → model) | ✅ 45/45 test, analyze sạch (đã tự chạy lại) | `worktree-agent-ae3f956b808ba2302` @ `393e8ee` — **chưa merge** |
| 23:2x | `pptx_reader` (PPTX → model) | ✅ 30/30 test (đã chạy lại) | `worktree-agent-adb1786fc69ad74ab` @ `7af6df3` — **chưa merge** |
| 23:3x | `pdf_layout` (dòng → đoạn/heading/bảng, ghi DOCX) | ✅ 31/31 test (đã chạy lại); DOCX mở được bằng Word | `worktree-agent-ad7481913ea186f0c` @ `f4e3eed` — **chưa merge** |
| 23:34 | `image_ops` (lọc ảnh, xoay, cắt, nén, bố cục trang, viền giấy) | ✅ 252 test (243 + 9 perf), analyze sạch (đã chạy lại `dart test -x perf`) | `worktree-agent-ae83a622eee04d4e8` @ `c2a8d3e` — **chưa merge** |
| 23:33 | H1: thử `office_reader` với file Word/Excel thật (COM) | ⏳ đang chạy | worktree mới (đã merge nhánh office_reader vào) |
| 23:33 | H2: thử `pptx_reader` với file PowerPoint thật (COM) | ⏳ đang chạy | worktree mới |
| 23:33 | S1: spike chữ Việt/Thái + mật khẩu trong Syncfusion PDF | ⏳ đang chạy | worktree mới, thư mục `spikes/pdf_text/` |
| — | MÓNG `app/` | ⏳ đang chạy, chưa commit (file chưa track trong checkout chính) | `feat/pdf-office` |
| — | Đợt 1 (10 agent) | chờ MÓNG | — |

**Ghi chú:** H1/H2 sửa trên nhánh riêng tách từ nhánh thư viện → khi ghép, merge nhánh H1/H2 (đã bao gồm nhánh
thư viện gốc) thay vì merge nhánh thư viện gốc. Lần đầu gọi Agent tạo worktree từng lỗi rỗng — gọi lại là được.

### Nếu phiên bị ngắt — làm tiếp thế nào
1. `git -C D:/Phuong/project/chuyenanh worktree list` và `git log --all --oneline -20` để xem nhánh nào đã có.
2. Nhánh thư viện đã xong mà chưa merge → `git merge --no-ff <nhánh>` vào `feat/pdf-office` (chỉ chạm `packages/`).
3. Nếu MÓNG chưa commit: kiểm `app/` bằng `dart run tool/merge_arb.dart && flutter gen-l10n && flutter analyze && flutter test` trong `app/`, sạch thì commit.
4. Tung agent đợt 1 theo bảng phân công ở hợp đồng mục 4 (prompt mẫu: đọc hợp đồng + spec, chỉ sửa thư mục của mình, TDD, analyze/test sạch, commit trong worktree).

## Rủi ro / lưu ý
- Flutter giữ "startup lock" → nhiều agent chạy lệnh flutter cùng lúc phải chờ nhau.
- `.claude/worktrees/` đã thêm vào `.gitignore` để commit `git add -A` không kéo worktree vào.
- Thư viện mới chỉ test bằng fixture dựng bằng code — chưa thử file Office/PDF thật.
- Chưa build Android lần nào → lỗi Gradle giữa ~30 plugin có thể xuất hiện ở đợt 2.
