# Phiên 30/10/2026 — Giao diện mới Phiotron PDF

## Yêu cầu
1. Gom toàn bộ chức năng thành 1 file .md để đưa vào công cụ design → `docs/design-brief-pdf-office.md`.
2. Hướng dẫn dùng Claude Design (claude.ai/design), nhắc tính nguyên bản/bản quyền, đổi logo có ký hiệu cá nhân, đổi tên app không trùng công ty.
3. Xuất thiết kế (Bước 8) vào `design-mobile/` + README cho người code.
4. Chuyển app Flutter theo đúng thiết kế, làm hết các nhóm, chia nhiều agent song song; build lại APK, thay file ở link tải.

## Kết quả
- Tên **Phiotron PDF**, logo "Xấp định dạng", font Be Vietnam Pro, icon Material Symbols Rounded, token sáng/tối, thanh dưới mới + tablet.
- Đổi giao diện: Trang chủ, Tập tin, Công cụ, Cài đặt (bảng chọn), Ảnh sang PDF, Quét, Công cụ PDF (8 màn), Chuyển đổi, PDF sang ảnh,
  Trình đọc PDF, DOCX/XLSX/PPTX/TXT, Chú thích/Ký/Điền biểu mẫu.
- 791/791 test, analyze sạch (2 info cũ ở `ios_simulation_test.dart`), APK release 120.000.714 byte (sha256 3f719ff0…aa517) đã lên Release
  `android-latest`; bản trước lưu `dist/backup/PDFOffice-2026-10-30-nhom1.apk`, bản 29/10 lưu `dist/backup/PDFOffice-2026-10-29.apk`.

## File thay đổi chính
| Nhóm | File |
|---|---|
| Nền | `app/lib/core/theme/app_tokens.dart` (mới), `app_theme.dart`, `app_colors.dart`, `app/pubspec.yaml` (fonts, material_symbols_icons), `app/assets/ui_fonts/` (mới), `app/lib/main.dart` (giấy phép font) |
| Thành phần chung | `app/lib/core/widgets/app_sheet.dart` (mới), `app_dialog.dart`, `dialogs.dart`, `app_text_field.dart`, `empty_state.dart`, `file_type_icon.dart` |
| Khung + tab | `features/documents/main_shell.dart`, `home_tab.dart`, `home_screen.dart`, `list_screens.dart`, `widgets/*`, `document_actions.dart` |
| Công cụ + Cài đặt | `features/documents/widgets/tools_sheet.dart`, `core/tools/tool_registry.dart`, `features/settings/*` |
| Màn con | `features/image_to_pdf/**`, `scanner/**`, `pdf_tools/ui/*`, `convert/convert_screen.dart`, `reader/**`, `office_viewer/**`, `office_pptx/pptx_viewer_screen.dart`, `editor/*` |
| Tên + icon | ARB core/docs/img2pdf/settings (6 ngôn ngữ), `AndroidManifest.xml`, `Info.plist`, `res/drawable/ic_launcher_*.xml`, `values/ic_launcher_background.xml`, `mipmap-*/ic_launcher.png`, `AppIcon.appiconset/*.png`, `features/settings/app_logo.dart` |
| Thiết kế | `design-mobile/` (README + screens), `docs/design-brief-pdf-office.md` |
| Test | ~20 file test (chữ thường đầu câu, icon Symbols, key mới), `integration_test/app_test.dart`, `app_features_test.dart` |

## Rủi ro / lưu ý
- **Chưa thử trên máy thật** (Galaxy A13, iPhone). Cần đi qua mọi màn, sáng + tối, và tablet.
- Nền vùng trang PDF vẫn xám Syncfusion; màn cắt ảnh uCrop vẫn thanh đỏ; ngăn kéo Tập tin còn mục "Thư mục lưu" trên iOS.
- Thư mục lưu thật vẫn tên "PDF Office" (cố ý).
- Integration test iOS chỉ sửa theo suy luận, chưa chạy CI.
- Sau phiên: đã khảo sát 32 app Play (tính năng thiếu + bình luận 1–3★) — báo cáo chưa lưu file, đề xuất P1: mở file từ app khác, nén PDF,
  chèn chữ/vẽ/ảnh/ảnh chữ ký lên PDF, số trang, chèn trang, test thứ tự/hướng trang.
