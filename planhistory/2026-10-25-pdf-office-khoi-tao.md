# Phiên 2026-10-25 — PDF Office: thiết kế + build song song nhiều agent

> **Đọc file này trước khi làm tiếp ở phiên mới.** Mục "Trạng thái / checkpoint" được cập nhật sau mỗi mốc.
> Thiết kế: `docs/superpowers/specs/2026-10-25-pdf-office-design.md` · Hợp đồng chia việc:
> `docs/superpowers/plans/2026-10-25-parallel-build-contract.md` · Wiki: `lmm-wiki/index.md`.

## Yêu cầu gốc
Làm app giống app Google Play "Chuyển đổi hình ảnh sang PDF" (TrustedOffice, `com.readpdf.pdfreader.pdfviewer`),
**y hệt chức năng và bố cục**, bám đúng app gốc này. Người dùng cần gấp → tách tối đa agent song song.
Phải test trước khi commit; test trên điện thoại thật (Samsung Galaxy A13) để sau.

## Quyết định đã chốt
Flutter · Android trước (minSdk 24) · Syncfusion Community · Riverpod + go_router + drift · 6 ngôn ngữ
(vi, en, zh, ja, ko, id — bỏ tiếng Thái 26/10) · dùng cá nhân, không store, không quảng cáo, offline · quét toàn máy
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
| 23:2x | `office_reader` (DOCX/XLSX → model) | ✅ 45/45 test | merge vào `feat/pdf-office` (`6d62eca`) |
| 23:2x | `pptx_reader` (PPTX → model) | ✅ 30/30 test | merge (`c5f4ff2`) |
| 23:3x | `pdf_layout` (dòng → đoạn/heading/bảng, ghi DOCX) | ✅ 31/31 test; DOCX mở được bằng Word | merge (`fce549e`); 26/10 nâng `xml ^6.5` → `^7.1` cho khớp app, 31/31 vẫn pass |
| 23:34 | `image_ops` | ✅ 252 test | merge (`1b2d063`) |
| 23:33 | H1/H2 (thử file Office thật) + S1 (spike chữ Việt/Thái + mật khẩu) | ❌ **bị ngắt** do hết lượt dùng (rate limit 429) — chỉ còn script dở trong worktree, chưa commit | worktree `agent-aafcd39…`, `agent-a7aee67…`, `agent-a14c345…` — **làm lại sau** |
| 23:39 | MÓNG `app/` | ✅ commit `1c04c84`; 26/10 08:4x tự chạy lại: analyze sạch, **50/50 test** | `feat/pdf-office` |
| 23:39 | Wiki + checkpoint | ✅ người dùng tự commit `0e185ac` | — |
| 26/10 08:5x | Nối 4 thư viện vào `app/pubspec.yaml` (path dependency) | ✅ `pub get` giải được | chưa commit |
| 26/10 10:14 | Build `flutter build apk --debug` | ✅ **THÀNH CÔNG** sau 5 lần (xem `lmm-wiki/concepts/build-android.md`): gỡ `flutter_tesseract_ocr`, hạ `permission_handler` 13→12, ép plugin đòi API 37 về SDK 36, tắt Kotlin incremental. APK 212 MB ở `app/build/app/outputs/flutter-apk/app-debug.apk` | chưa commit |
| 26/10 | **Bỏ hẳn tiếng Thái** (UI, font, OCR) → 6 ngôn ngữ; xoá 11 file `*_th.arb`, sửa `l10n.dart`, `merge_arb.dart`, test | ✅ | chưa commit |
| 26/10 | Dọn: 7 worktree + 7 nhánh agent (đã gộp hết), zip SDK, cache gói không dùng | ✅ | — |
| 26/10 | **Push** `feat/pdf-office` lên `origin` (github.com/phamphuongphuongnd/chuyenanh) | ✅ `3452e68` | `origin/feat/pdf-office` |
| 26/10 10:3x | Làm lại 3 việc kiểm chứng bị ngắt (lần này commit từng bước): H1 `office_reader` với Word/Excel thật · H2 `pptx_reader` với PowerPoint thật · S1 chữ Việt/CJK + mật khẩu trong Syncfusion PDF | ⏳ đang chạy, mỗi agent 1 worktree mới | nhánh `worktree-agent-*` — **khi xong: merge vào `feat/pdf-office`, chạy lại test, push** |
| 26/10 10:4x | **S1 xong** (spike chữ Việt/CJK + mật khẩu PDF): NFC đúng, **NFD sai** → chuẩn hoá NFC; **không font nào đủ Việt+CJK** → fallback theo script; font tự subset; mật khẩu OK. Đã xem ảnh render xác nhận. Merge fast-forward vào `feat/pdf-office` (`a939da8`) | ✅ → `lmm-wiki/concepts/xuat-chu-ra-pdf.md` | chờ chạy lại test rồi commit + push |
| 26/10 11:0x | **H2 xong** (`pptx_reader` với PowerPoint thật): sửa 4 lỗi — `tint/shade` phải tính trên linear RGB; `bgRef/fillRef` đọc theme (nền texture); `custGeom` giữ đường vẽ (`customPaths`); bullet font Wingdings (`bulletFontFamily/Color/SizePct`). 59 test pass + 2 skip (file `deck_organic` 1MB cố ý không commit). Còn thiếu: hình preset (rightArrow…) chưa có đường vẽ, gradient chỉ lấy stop đầu, `fontScale` chưa thử thật, SmartArt/media/WordArt chưa thử. Merge vào `feat/pdf-office` | ✅ | `merge: thu pptx_reader…` |
| 26/10 11:1x | **H1 xong** (`office_reader` với Word/Excel thật): sửa 3 lỗi — công thức shared Excel bị rỗng, xuống dòng CRLF trong ô, `w:caps/smallCaps` bị bỏ. 80 test pass (45 cũ + 35 mới). Còn: định dạng ngày Mỹ bị đảo, rich text trong ô Excel, vAlign bảng Word. Merge vào `feat/pdf-office` | ✅ | `merge: thu office_reader…` |
| 26/10 11:3x | Người dùng đổi ý: **làm luôn T1…T10** → tung 10 agent (mỗi agent 1 worktree) | ⏳→❌ | 10 nhánh `worktree-agent-*` |
| 26/10 13:3x | **Cả 10 agent bị dừng do hết lượt dùng** (rate limit 429) khi mới có logic/engine + test, **chưa có UI** | ❌ | — |
| 26/10 13:55 | Người dùng quyết định **bàn giao phần còn lại cho người khác**: commit `WIP(Tn)` trong từng worktree (bỏ file probe/exp), **push 10 nhánh** `feat/t1-documents … feat/t10-settings` lên origin; ghi mục E vào `feature-tasks.md`, wiki `modules/tinh-nang-t1-t10.md` | ✅ | `origin/feat/t*` |
| 26/10 | **Đổi kế hoạch (người dùng):** 10 tính năng **không** tung agent nữa — viết thành bản giao việc để người khác làm | ✅ `docs/superpowers/plans/2026-10-26-feature-tasks.md` | chưa commit |

**Ghi chú:** 5 agent song song làm hết lượt dùng trong ~40 phút → agent nên **commit sau từng phần nhỏ** để bị ngắt
không mất việc. Lần đầu gọi Agent tạo worktree từng lỗi rỗng — gọi lại là được.

### Nếu phiên bị ngắt — làm tiếp thế nào
1. `git -C D:/Phuong/project/chuyenanh log --oneline -10` và `git status` để xem đã commit tới đâu.
2. Phần nền còn lại (Claude làm): build APK debug sạch → commit; làm lại H1/H2/S1 nếu người dùng muốn.
3. **Tính năng:** người khác nhận theo `docs/superpowers/plans/2026-10-26-feature-tasks.md` (T1…T10), mỗi người một
   nhánh `feat/<feature>` tách từ `feat/pdf-office`.

## Rủi ro / lưu ý
- Flutter giữ "startup lock" → nhiều agent chạy lệnh flutter cùng lúc phải chờ nhau.
- `.claude/worktrees/` đã thêm vào `.gitignore` để commit `git add -A` không kéo worktree vào.
- Thư viện mới chỉ test bằng fixture dựng bằng code — chưa thử file Office/PDF thật.
- Chưa build Android lần nào → lỗi Gradle giữa ~30 plugin có thể xuất hiện ở đợt 2.
