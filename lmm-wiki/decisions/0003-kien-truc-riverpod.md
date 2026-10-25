---
title: ADR 0003 — Kiến trúc chia theo tính năng + Riverpod
type: decision
updated: 2026-10-25
sources:
  - docs/superpowers/plans/2026-10-25-parallel-build-contract.md
---

# ADR 0003 — Kiến trúc chia theo tính năng + Riverpod

**Quyết định:** feature-first + `flutter_riverpod` 3 (provider viết tay, không codegen), `go_router`, `drift`
(SQLite), `shared_preferences`.

```
app/lib/core/      theme, router (routes.dart + gộp <f>Routes), l10n core, errors (AppError), utils thuần, widgets
app/lib/data/      drift DB (documents, favorites, recents, bookmarks) · settings
app/lib/engines/   interface engine (MÓNG) — impl do agent tính năng viết
app/lib/features/  documents, image_to_pdf, reader, pdf_tools, editor, convert, office_viewer, office_pptx, scanner, settings
packages/          thư viện Dart thuần: pptx_reader, office_reader, pdf_layout, image_ops
```

- UI **không gọi thẳng** Syncfusion/pdfx/ML Kit — luôn qua `engines/`.
- Logic tách **hàm thuần** để unit test (theo [[preferences]]).
- Lỗi thống nhất `AppError` (WrongPassword, PasswordRequired, CorruptFile, UnsupportedFormat, NoSpace, PermissionDenied, Cancelled).
- Không ghi đè file gốc: ghi `.tmp` rồi rename, tên trùng thêm ` (1)`.
- Chuỗi đa ngôn ngữ: mỗi feature có `l10n/<prefix>_<locale>.arb`, gộp bằng `tool/merge_arb.dart` rồi
  `flutter gen-l10n`; `app/lib/l10n/` là file sinh, gitignore.

Liên quan: [[build-song-song-agent]], [[0002-syncfusion-community]].
