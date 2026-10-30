---
title: Giao diện mới Phiotron PDF (thiết kế design-mobile → Flutter)
type: module
updated: 2026-10-30
sources:
  - design-mobile/README.md
  - design-mobile/screens/
  - docs/design-brief-pdf-office.md
  - app/lib/core/theme/app_tokens.dart
  - app/lib/core/theme/app_theme.dart
  - app/lib/core/widgets/app_sheet.dart
  - app/lib/features/documents/main_shell.dart
  - planhistory/2026-10-30-giao-dien-phiotron.md
---

# Giao diện mới "Phiotron PDF" (30/10/2026)

**Yêu cầu:** gom chức năng thành brief → vẽ lại giao diện trên Claude Design → chuyển app sang đúng thiết kế, iPhone + Android.
**Trạng thái:** đã làm toàn bộ (khung, 4 tab, mọi màn con, tên, logo, icon), 791/791 test, analyze sạch, APK release đã lên link
`android-latest`. **Chưa thử trên Galaxy A13.**

## Quy trình thiết kế (dùng lại được)
1. Viết brief chức năng không kỹ thuật: `docs/design-brief-pdf-office.md` (mỗi màn: bố cục, tuỳ chọn + mặc định, trạng thái, chữ thật).
2. claude.ai/design → mẫu *Mobile app design*, đính kèm brief + logo, nhắc "tính nguyên bản/bản quyền" (không chép app khác, icon/font giấy phép mở).
3. **Bước 8 – xuất:** Claude Design không ghi được ổ đĩa → tải `design-mobile.zip`, giải nén vào `design-mobile/` (README + `screens/*.dc.html`
   + `support.js` + `assets/`; không có `canvas.json`). README thêm mục 6 "màn → file Flutter".
4. File `.dc.html` chỉ để tra style; chuyển sang Flutter bằng token + thành phần dùng chung.

## Quyết định đã chốt
- **Giữ Flutter**, chỉ đổi giao diện (repo không có Frontend/Backend/API như một lời nhắn mẫu nói — app offline).
- **Tên Phiotron PDF**: Ph = Phương, φ tỉ lệ vàng, o = quỹ đạo/số 0 (0 quảng cáo), tron = máy khoa học. Lý do bỏ tên khác: "PDF Office"
  trùng app Readdle; Phi/Planck/Photon/Phoxel/Phitron đều trùng công ty (Planck insurtech, Poxel, Phytron GmbH có nhãn hiệu).
  Người dùng yêu cầu **tên không trùng công ty nào, có ký hiệu cá nhân**.
- Logo phương án "Xấp định dạng" (4 thẻ DOC/XLS/PPT/PDF xoay, chữ P) — vẽ bằng code `features/settings/app_logo.dart` (`AppLogoPainter`).
- **Giữ** thư mục lưu `Documents/PDF Office` (`core/utils/output_directory.dart` `appFolderName`), package id `com.phuong.pdfoffice`, tên file
  `PDFOffice.apk` — đổi sẽ lưu file chỗ khác / không cài đè được / gãy link.
- Font **Be Vietnam Pro** (OFL) đóng gói `app/assets/ui_fonts/` (commit vào git, ~0,7MB); icon **Material Symbols Rounded** gói
  `material_symbols_icons` (Apache 2.0). Nút chữ thường đầu câu.

## Kiến trúc giao diện
- Token sáng/tối: `core/theme/app_tokens.dart` (`AppTokens` ThemeExtension → `context.tokens`, `AppShadows`, `kUiFontFamily`); màu thanh
  tiêu đề theo loại: `AppColors.headerForCategory` (PDF #D32F2F, DOC #1565C0, XLS #2E7D32, PPT #D84315, TXT #546E7A; tab Tất cả #25212B).
- `app_theme.dart`: **AppBar mặc định nền sáng chữ đậm**; trình xem (PDF/DOCX/XLSX/PPTX/TXT) và màn có `AppSearchField` (Tìm kiếm, chọn PDF
  Khoá/Mở khoá) tự đặt nền màu + `titleTextStyle` trắng (theme `titleTextStyle` đè `foregroundColor`).
- Thành phần chung `core/widgets/app_sheet.dart`: `showAppSheet` (điện thoại = bottom sheet, tablet = hộp thoại 400), `SheetOption`,
  `SheetTitle`, `showChoiceSheet`, `CardSection`, `CardRow` (bo dòng đầu/cuối cho `ListView.builder`), `isTabletLayout` (cạnh ngắn ≥ 601).
- Khung `main_shell.dart`: thanh dưới tự vẽ (viên `primarySoft` + icon `fill: 1`, nút ⇄ đỏ 58 nhô lên); tablet = thanh bên + mục Lối tắt.
  Key giữ nguyên `nav-home/files/convert/tools/settings`.
- Văn phòng: `office_viewer/widgets/office_common.dart` `OfficeViewerAppBar`, `OfficeBottomBar`, `OfficeSearchBar(category:)` — 5 loại
  trình xem giống hệt nhau (yêu cầu người dùng). Công cụ PDF: `pdf_tools/ui/tool_widgets.dart` (`ToolCard`, `ToolChoiceChip`, `ToolColorDot`…).

## Gotcha
- `material_symbols_icons` mang 3 font ~34MB nhưng **bản release tree-shake còn ~24KB**; APK chỉ tăng ~0,4MB. Bản debug thì không cắt.
- Icon iOS **phải RGB không alpha** (`test/core/ios_simulation_test.dart` kiểm). Máy không có Pillow → vẽ PNG bằng test tạm dùng
  `AppLogoPainter` + `toImage`, rồi bỏ alpha bằng gói `image` (`convert(numChannels: 3)`), xoá test tạm. Contents.json liệt kê trùng tên (15 file thật).
- Bottom sheet nhiều nội dung phải `isScrollControlled: true` + cuộn, kẻo tràn ở màn thấp (bộ lọc Quét tràn 83px trong test).
- Test dò chữ IN HOA (`'CANCEL'`, `'MERGE'`…) và `Icons.*` phải đổi theo chữ thường + `Symbols.*_rounded`; test mặc định 800×600 → cạnh ngắn
  600 < 601 nên vẫn bố cục điện thoại.
- `integration_test/app_test.dart`: bảng chọn Cài đặt không có nút back → đóng bằng chạm vùng tối; `app_features_test.dart` dò key `conv_result`.
- Chưa đạt: nền xám quanh trang PDF là của Syncfusion (cần `syncfusion_flutter_core` để đổi), màn cắt uCrop vẫn đỏ, ngăn kéo còn "Thư mục lưu" trên iOS.

## Cách làm đã chạy: 12 agent song song
Tự làm phần chung trước (token, font, icon, app_sheet, khung, chuỗi l10n mới `docs_shortcuts`, `docs_countDocs` + gen-l10n), rồi giao mỗi agent
một nhóm file riêng, cấm chạy flutter (chỉ `dart analyze` file của mình), cấm sửa ARB; mình ghép + chạy test tuần tự. Một agent lỡ ghi rỗng 3 file
test (đường dẫn tương đối trong PowerShell) rồi tự `git restore` — **luôn xem `git diff` sau khi agent sửa test**. Xem [[build-song-song-agent]].

Liên quan: [[ui-app-goc]], [[documents]], [[phat-hanh-apk]], [[ios]], [[kiem-thu-flutter]], [[preferences]].
