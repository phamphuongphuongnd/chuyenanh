---
title: Kiểm thử Flutter — môi trường máy và cạm bẫy test widget
type: concept
updated: 2026-10-26
sources:
  - app/test/features/documents/
  - app/test/app_smoke_test.dart
  - planhistory/2026-10-25-pdf-office-khoi-tao.md
---

# Kiểm thử Flutter — môi trường máy và cạm bẫy test widget

## Dựng Flutter trên một máy mới (không Android SDK)
Chỉ cần để chạy `flutter analyze` / `flutter test`. Máy dev ngày 26/10 chiều **chưa có Flutter**; đã cài bằng
`git clone --depth 1 -b 3.47.8 https://github.com/flutter/flutter.git C:/src/flutter` (đúng chỗ các tài liệu khác ghi).
Không sửa PATH: trong Git Bash `export PATH="/c/src/flutter/bin:$PATH"`. Lần chạy đầu tự tải Dart SDK (vài phút).
Android SDK (build APK) cần người dùng tự chấp nhận license → xem [[build-android]].
Lệnh chuẩn trong `app/`: `dart run tool/merge_arb.dart && flutter gen-l10n` → `flutter analyze` → `flutter test`.
`lib/l10n/` bị gitignore nên **worktree mới phải sinh lại**.
Nhiều lệnh flutter chạy cùng lúc phải chờ nhau (startup lock) — khi 5 agent chạy song song, `flutter test` của mình có thể
chậm hàng chục phút; đặt `--timeout` để test treo không giữ cả phiên.

## Cạm bẫy test widget (đã dẫm)
- **`pumpAndSettle` không bao giờ dừng** khi có animation vô hạn (vd `LinearProgressIndicator` lúc đang quét) →
  dùng `pump()` + `pump(Duration(...))` cho trạng thái đó.
- **Stream của drift để lại timer 0 s** sau khi cây widget bị huỷ → `A Timer is still pending…` và test có thể treo tới
  hết timeout. Với test widget, override provider nguồn bằng stream cố định:
  `documentsProvider.overrideWith((ref) => Stream.value(items))`; test DAO/provider thì dùng
  `AppDatabase(NativeDatabase.memory())` ở test thường (không phải `testWidgets`).
- `appDatabaseProvider` mặc định mở DB thật (`driftDatabase`) → test nào dựng cả app phải override bằng DB bộ nhớ,
  nếu không drift cảnh báo "tạo AppDatabase nhiều lần".
- Menu `PopupMenuButton`: bấm `find.widgetWithText(CheckedPopupMenuItem<T>, 'nhãn')` thay vì `find.text` (tránh cảnh báo hit-test).
- State của notifier có `ref.mounted` — gán `state` sau `await` khi provider đã dispose sẽ ném lỗi; luôn kiểm `ref.mounted`.

## Cách test notifier có phụ thuộc hệ thống
Tách phụ thuộc thành interface rồi override bằng bản giả: `FileScanner` (`fileScannerProvider`),
`StoragePermissionService` (`storagePermissionProvider`), `scanRootsProvider`. Ví dụ đầy đủ:
`app/test/features/documents/documents_providers_test.dart`. Widget test thay luôn notifier:
`scanControllerProvider.overrideWith(() => _FixedScan(state))`.

Liên quan: [[documents]], [[build-android]], [[build-song-song-agent]].
