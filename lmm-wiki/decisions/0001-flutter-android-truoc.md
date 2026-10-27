---
title: ADR 0001 — Flutter, Android trước, dùng cá nhân
type: decision
updated: 2026-10-25
sources:
  - docs/superpowers/specs/2026-10-25-pdf-office-design.md
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# ADR 0001 — Flutter, Android trước, dùng cá nhân

**Bối cảnh:** clone app "Image to PDF: PDF Converter" (TrustedOffice) — xem [[0004-pham-vi-bam-app-goc]].

**Quyết định:**
- **Flutter** (Dart). Người dùng chọn sau khi so sánh Kotlin native / Flutter / React Native / PWA.
- **Android trước** (minSdk 24 = Android 7.0, compileSdk 36). Code iOS để sẵn nhưng **không build** (máy phát triển là Windows).
- **Dùng cá nhân, cài sideload, không lên store**, miễn phí hoàn toàn: không quảng cáo, không mua trong app, không mạng.
  → được dùng `MANAGE_EXTERNAL_STORAGE` (quét toàn máy) mà không lo Google Play duyệt.
- Tên **PDF Office**, gói `com.phuong.pdfoffice`, code ở `app/`.
- 6 ngôn ngữ UI: vi, en, zh, ja, ko, id.
- Thiết bị test thật: **Samsung Galaxy A13** qua cáp USB (Android SDK dạng dòng lệnh ở `C:\Android\sdk`, không cần emulator).

**Hệ quả:** iOS cần Mac/CI khi muốn làm. Thương hiệu (logo, icon) tự vẽ, không chép app mẫu.

Liên quan: [[0002-syncfusion-community]], [[0003-kien-truc-riverpod]], [[build-song-song-agent]].
