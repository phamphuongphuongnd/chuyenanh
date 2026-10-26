---
title: Trạng thái 10 tính năng T1…T10 (bàn giao)
type: module
updated: 2026-10-26
sources:
  - docs/superpowers/plans/2026-10-26-feature-tasks.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
  - app/lib/features/
---

# Trạng thái 10 tính năng T1…T10 (bàn giao 26/10/2026)

Chi tiết từng việc (sở hữu file, thư viện dùng, việc cần làm, test, ước lượng) ở
`docs/superpowers/plans/2026-10-26-feature-tasks.md` — **mục E là bảng trạng thái bàn giao**. Trang này tóm tắt.

## Tóm tắt (cập nhật 26/10 ~15:10)
- **Nền đã xong và đã kiểm:** [[0003-kien-truc-riverpod]] + [[thu-vien-dart-thuan]] (4 thư viện, đã thử file thật 2/4) + build Android
  ([[build-android]]) + spike chữ ([[xuat-chu-ra-pdf]]).
- Người dùng chốt: **Claude làm tiếp T1…T10** (không còn "giao người khác"). Chia **đợt 5 agent**, mỗi agent 1 worktree, commit từng bước,
  không push/merge. Đợt 1 = T2, T3, T4, T5, T10; đợt 2 = T6, T7, T8, T9. T1 do chính Claude làm.
- **Đã push 26/10 ~15:20** (fast-forward, không force) 7 nhánh: `feat/pdf-office`, `feat/t1-documents`, `feat/t2-image-to-pdf`, `feat/t3-reader`,
  `feat/t4-pdf-tools`, `feat/t5-editor`, `feat/t10-settings`. T6–T9 chưa có gì mới.
- "Tự kiểm" = Claude tự chạy lại `flutter analyze` + `flutter test`; "agent báo" = mới đọc báo cáo của agent. **Chưa việc nào
  chạy trên điện thoại thật.**

| Việc | Nhánh | Mức |
|---|---|---|
| T1 Trang chủ Tài liệu | `feat/t1-documents` @ `1159b7b` (local) | **Xong UI, tự kiểm** (analyze sạch, 102 test pass) → [[documents]] |
| T2 Ảnh → PDF | `feat/t2-image-to-pdf` @ `abc7253` | **Tự kiểm 26/10: analyze sạch, 172 test pass**; chưa thử plugin thật (camera, photo_manager, cropper) |
| T3 Trình đọc PDF | `feat/t3-reader` @ `2184e98` | **Tự kiểm 26/10: analyze sạch, 144 test pass.** Viewer (tìm, mục lục, tối, in, mật khẩu, bookmark), PDF→ảnh, lối tắt. **Kotlin (`MainActivity`/`ShortcutChannel`) chưa biên dịch**; viewer thật chỉ test bằng viewer giả |
| T4 Công cụ PDF | `feat/t4-pdf-tools` @ `4bc8261` | **Tự kiểm 26/10: analyze sạch, 148 pass / 1 fail** (`app_smoke_test` — bước `push(Routes.merge)` đòi `PlaceholderScreen`); 7 màn + engine; watermark/tiêu đề cần font Noto (chưa tải, rơi về Helvetica) |
| T5 Chỉnh sửa PDF | `feat/t5-editor` @ `10d0489` | **Tự kiểm 26/10: analyze sạch, 145 test pass**; `SfPdfViewer` chỉ test bằng viewer giả; màn Ký cần `pdfRenderEngineProvider` của T3 |
| T6 Chuyển đổi | `feat/t6-convert` | Chưa giao (đợt 2) |
| T7 Xem DOCX/XLSX/TXT | `feat/t7-office-viewer` | Chưa giao (đợt 2) |
| T8 Xem PPTX | `feat/t8-pptx` | Chưa giao (đợt 2) |
| T9 Máy quét + OCR | `feat/t9-scanner` | Chưa giao (đợt 2) |
| T10 Cài đặt + thương hiệu | `feat/t10-settings` @ `66fead3` | **Tự kiểm 26/10: analyze sạch, 100 test pass**; Giao diện/Thư mục lưu/Khổ giấy là màn con `Navigator.push` (không có route riêng); icon launcher vector chưa thử build APK |

## Việc phải làm khi ghép (đã biết)
- `test/app_smoke_test.dart` (MÓNG): test thứ 3 `push(Routes.merge, extra: '/x/a.pdf')` rồi đòi `find.text('/x/a.pdf')` (màn giữ chỗ) → vỡ khi T4
  thay màn thật; cách sửa: chỉ kiểm route đã đăng ký, bỏ bước push (hoặc đổi sang route còn giữ chỗ). Cùng file, test 1–2 từng khẳng định trang chủ là `PlaceholderScreen` → đã sửa ở nhánh T1 (override DB + `documentsProvider`
  cố định). Mọi nhánh feature thay route trang chủ/placeholder đều có thể vỡ test này khi ghép.
- Màn Ký (T5) cần `pdfRenderEngineProvider` thật từ T3 (T3 đã nối `pdfxRenderEngine`); nhánh T5 riêng chưa có nên màn hiện lỗi "Thử lại" cho tới khi ghép T3.
- **MÓNG phải làm cho T3:** thêm `ref.watch(shortcutLaunchProvider);` vào `PdfOfficeApp.build` (`lib/app.dart`, import `features/reader/shortcut/shortcut_launcher.dart`) thì lối tắt mới chạy; tuỳ chọn thêm `SfGlobalLocalizations.delegate`.
- Font Noto (`NotoSans-Regular`, `NotoSansSC/JP/KR-Regular`) vào `app/assets/fonts/` — chưa tải; T4 và T6 cần. `composeVietnamese` đang bị nhân đôi (T4 `pdf_tools/logic/vi_nfc.dart`, T6 sẽ có bản riêng) → gom vào `core/utils`.
- Gợi ý cho MÓNG (chưa làm): `device_info_plus` (biết SDK để xin quyền đúng, xem [[documents]]), `package_info_plus` (T10 đang hằng `kAppVersion`),
  thêm `Routes.theme/outputDir/pageSize` nếu muốn drawer mở thẳng.
- Nhánh T1 xuất phát từ `4a33139` nên **không có** wiki/doc bàn giao mới (commit `2f5a762`); wiki và README luôn ghi trên `feat/pdf-office`.

## Làm tiếp khi mở phiên mới
Xem mục "Dừng phiên 26/10" trong `planhistory/2026-10-25-pdf-office-khoi-tao.md`: tự kiểm T2–T5/T10 trong từng worktree
(`.claude/worktrees/agent-*`, đã gitignore) → đợt 2 (T6–T9) → ghép nhánh → build APK → hỏi người dùng rồi mới push.

## Gotcha khi nhận việc
- **Chưa chạy lại `flutter analyze`/`test` sau khi agent bị ngắt** — chạy trước khi làm tiếp. Mỗi nhánh có commit `WIP(Tn)`
  chứa file làm dở; file thử nghiệm tạm (`probe`, `exp_test`) cố ý **không** đưa lên git.
- Đổi gói (`pubspec.yaml`), Manifest, `core/**`, `data/db/**`, interface `*_engine.dart` là việc của người giữ nhánh
  `feat/pdf-office`; người nhận việc ghi vào "Cần MÓNG bổ sung" thay vì tự sửa (tránh xung đột khi ghép).
- Mọi việc cần chạy `dart run tool/merge_arb.dart && flutter gen-l10n` trong `app/` trước khi test (`lib/l10n/` bị gitignore).
- Thêm plugin mới → **build thử APK debug ngay** (lỗi Gradle chỉ lộ khi build Android) — xem [[build-android]].

Liên quan: [[build-song-song-agent]], [[0004-pham-vi-bam-app-goc]], [[documents]], [[kiem-thu-flutter]].
