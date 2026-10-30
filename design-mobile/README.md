# Phiotron PDF — Bàn giao thiết kế giao diện

Nguồn yêu cầu: `design-brief-pdf-office.md` (tên cũ "PDF Office", nay là **Phiotron PDF**).
Chức năng giữ nguyên theo brief; thư mục này chỉ mô tả **giao diện**.

```
design-mobile/
├── README.md
└── screens/
    ├── Phiotron PDF Thiet bi.dc.html   ← trang tổng: 4 thiết bị × 4 màn (mở file này trước)
    ├── PDF Office Redesign.dc.html     ← bản đầu: iPhone 390×844, 4 màn sáng/tối
    ├── PDF Office Logo.dc.html         ← 4 phương án logo (đã chọn 1c)
    ├── PdfOfficeApp.dc.html            ← component điện thoại (iOS/Android, mọi kích thước)
    ├── PdfOfficeTablet.dc.html         ← component máy tính bảng (dọc/ngang)
    ├── support.js                      ← runtime để mở các file .dc.html
    └── assets/                         ← logo (SVG màu + 1 màu cho Android 13)
```

---

## 1. Design tokens

### 1.1 Màu giao diện

| Token | Sáng | Tối | Dùng cho |
|---|---|---|---|
| `bg` | `#F5F3F1` | `#121111` | Nền màn |
| `surface` | `#FFFFFF` | `#1E1C1B` | Thẻ, danh sách, thanh dưới, sidebar, sheet, hộp thoại |
| `surface-2` | `#EEEBE8` | `#2A2726` | Skeleton, nền minh hoạ trống |
| `text` | `#1C1918` | `#F4F0EE` | Chữ chính |
| `text-muted` | `#6B6461` | `#A8A09C` | Phụ đề, nhãn nhóm, icon phụ |
| `line` | `rgba(28,25,24,.08)` | `rgba(255,255,255,.08)` | Đường kẻ, viền thẻ |
| `line-strong` | `rgba(28,25,24,.18)` | `rgba(255,255,255,.20)` | Viền nút phụ, sao chưa chọn |
| `primary` | `#E5393B` | `#E5393B` | Nút chính, nút ⇄, dấu ✓, thanh tiến độ |
| `primary-text` | `#C62828` | `#FF7B76` | Chữ đỏ trên nền (“Xem tất cả ›”, tiêu đề nhóm công cụ, mục đang chọn) |
| `primary-soft` | `#FDECEC` | `#3A1E1E` | Nền icon Cài đặt, băng xin quyền, mục nav đang chọn |
| `input` | `#FFF8E1` | `#2C2A22` | Ô nhập (theo brief) |
| `scrim` | `rgba(20,16,15,.38)` | `rgba(0,0,0,.60)` | Lớp phủ sau sheet/hộp thoại |
| `snackbar` | nền `#2B2726` / chữ `#FFFFFF` | nền `#F4F0EE` / chữ `#1C1918` | Snackbar |
| `files-all-header` | `#25212B` | `#2C2833` | Thanh tiêu đề tab "Tất cả" (mực than tím, không trùng đỏ PDF) |
| `favorite` | `#F9A825` | `#F9A825` | Ngôi sao yêu thích |
| `tint-blue` / `tint-orange` | `#E3F0FD` / `#FEEDE4` | `#14283D` / `#3A2117` | Nền icon "Quét tài liệu" / "PDF sang ảnh" |

### 1.2 Màu theo loại file (giữ nguyên ở cả sáng/tối)

| Loại | Icon file | Thanh tiêu đề tab (đậm hơn để chữ trắng đủ tương phản) |
|---|---|---|
| PDF | `#E53935` | `#D32F2F` |
| DOC/DOCX | `#1E88E5` | `#1565C0` |
| XLS/XLSX | `#43A047` | `#2E7D32` |
| PPT/PPTX | `#F4511E` | `#D84315` |
| TXT | `#78909C` | `#546E7A` |
| Ảnh | `#8E24AA` | — |
| Khác (FILE) | `#9E9E9E` | — |

Icon loại file là **hình tự dựng**: trang giấy gập góc phải trên, nhãn chữ PDF/DOC/XLS/PPT/TXT/FILE trắng ở dưới, tỉ lệ rộng = 0.8 × cao (32×40 trong danh sách, 48×60 trên thẻ tablet). PDF có mật khẩu: huy hiệu ổ khoá tròn ở góc dưới phải. Không dùng logo của hãng nào.

### 1.3 Font & thang cỡ chữ

Font: **Be Vietnam Pro** (400 / 500 / 600 / 700 / 800). Không dùng font khác.

| Vai trò | Cỡ / độ đậm |
|---|---|
| Tiêu đề màn (Công cụ, Cài đặt, tablet) | 30 / 800, letter-spacing −0.02em |
| Tên app ở Trang chủ điện thoại | 24 / 800 |
| Tiêu đề thanh Tập tin | 21 (điện thoại) · 24 (tablet) / 700–800 |
| Tiêu đề hộp thoại, trạng thái trống lớn | 19 / 700 |
| Ô tính năng chính | 18–19 / 700 |
| Tiêu đề mục (Yêu thích, Gần đây) | 17–18 / 700 |
| Chữ thân, dòng menu, nút | 15–15.5 / 500–600 |
| Tên file trong dòng | 14.5 / 600 (1 dòng, “…”) · thẻ tablet 14 / 600 (tối đa 2 dòng) |
| Tiêu đề nhóm công cụ | 14–15 / 700, màu `primary-text` |
| Phụ đề, số lượng, sắp xếp | 13–13.5 / 500–600 |
| Phụ đề dòng file, nhãn công cụ | 12–12.5 / 500 |
| Nhãn thanh điều hướng dưới | 11 / 600 |
| Nhãn trên icon file | 8.5 / 800 (thẻ lớn 11) |

### 1.4 Khoảng cách

Bước 2px, dùng chủ yếu: **4 · 6 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 22 · 24 · 28 · 32**.
- Lề ngang màn: 16 (điện thoại) · 24–32 (tablet).
- Khoảng giữa các khối: 18–24 · trong thẻ: 12–16.
- Vùng chạm tối thiểu: **44×44** (nút icon), nút chính cao 46–54.

### 1.5 Bo góc

| Thành phần | Bo |
|---|---|
| Icon file | 5 (nhỏ) · 7 (lớn) |
| Ô icon (công cụ, cài đặt, ô tính năng) | 10–16 |
| Ô nhập | 14 |
| Mục menu / lựa chọn | 12–16 |
| Thẻ, danh sách, nhóm | 18–22 |
| Ô tính năng Trang chủ | 20–24 |
| Thanh tiêu đề Tập tin | 0 0 26 26 (điện thoại) · 26 (tablet) |
| Hộp thoại | 26–28 · Bottom sheet 28 28 0 0 |
| Nút, tab, ô tìm kiếm | pill (= nửa chiều cao) |

### 1.6 Đổ bóng

| Dùng cho | Giá trị |
|---|---|
| Nút/ô đỏ chính | `0 10px 24px rgba(229,57,59,.28)` |
| Nút ⇄ giữa | `0 8px 18px rgba(229,57,59,.35)` + viền 4px màu `bg` |
| Menu sắp xếp | `0 16px 40px rgba(0,0,0,.22)` |
| Hộp thoại | `0 20px 50px rgba(0,0,0,.25)` |
| Snackbar | `0 10px 30px rgba(0,0,0,.25)` |
Danh sách và thẻ file **không** đổ bóng (nhẹ cho máy yếu, theo brief mục 12.6).

### 1.7 Icon & giấy phép

- Icon: **Material Symbols Rounded** (Google) — **Apache License 2.0**, cho phép dùng thương mại. Trạng thái chọn dùng `FILL 1`.
- Font: **Be Vietnam Pro** — **SIL Open Font License 1.1**.
- Logo: phương án **1c "Xấp định dạng"**, vector tự vẽ (`screens/assets/logo-3-color.svg`, bản 1 màu `logo-3-mono.svg`).
- Minh hoạ trống/lỗi: hình khối tự dựng bằng CSS, không dùng ảnh ngoài.

---

## 2. Khác biệt theo nền tảng

### iOS (khung mẫu 430×932, iPhone Pro Max; bản đầu 390×844)
- Safe area: trên **50px** (Dynamic Island), dưới **34px** (home indicator) → thanh dưới cao 88 (54 nội dung + 34 an toàn).
- Back: vuốt từ cạnh trái + nút ‹ ở thanh tiêu đề màn con.
- Menu ⋮, chọn ngôn ngữ/giao diện/khổ giấy: **bottom sheet** có tay kéo.
- **"Thư mục lưu" ẩn** trong Cài đặt và ngăn kéo (theo brief).

### Android (khung mẫu 360×800)
- Safe area: thanh trạng thái **32px**, thanh cử chỉ ~**8px** → thanh dưới cao 68.
- Back: nút/cử chỉ hệ thống. Ở tab khác Trang chủ → về Trang chủ, không thoát app.
- Sheet và hộp thoại giống iOS; "Thư mục lưu" **hiện**.
- Icon 1 màu Android 13: dùng `logo-3-mono.svg`.

### Máy tính bảng (từ 600dp; mẫu 820×1180 dọc, 1180×820 ngang)
- **Thanh bên trái cố định** (236px dọc · 264px ngang) thay thanh dưới.
- Nút ⇄ thành nút đỏ nổi bật **"Ảnh sang PDF"** ở đầu thanh bên.
- Ngăn kéo của Tập tin bỏ: "Gần đây", "Yêu thích" ở mục **Lối tắt** của thanh bên; Ngôn ngữ / Giao diện / Thư mục lưu / Giới thiệu ở Cài đặt.
- Tập tin hiển thị **lưới thẻ lớn** (tự xếp cột, tối thiểu 168px dọc / 180px ngang).
- Trang chủ: 3 ô tính năng một hàng; Yêu thích + Gần đây xếp cạnh nhau khi đủ rộng (≥ 2×340px).
- Menu ⋮ và các bảng chọn thành **hộp thoại giữa màn** (rộng 400).

---

## 3. Danh sách màn (theo brief mục 1)

✅ đã vẽ · ⬜ chưa vẽ

**Khung chính**
- ✅ Trang chủ (có / trống)
- ✅ Tập tin — 6 tab, lưới loại file, sắp xếp, ngăn kéo; trạng thái: danh sách · đang quét · đang quét có file · thiếu quyền · băng xin quyền · trống · lỗi
- ✅ Công cụ (19 công cụ, 4 nhóm)
- ✅ Cài đặt (màn gốc)
- ✅ Menu ⋮ · Đổi tên (2 lỗi) · Thông tin · Xoá + snackbar · Menu sắp xếp

**Danh sách phụ**
- ⬜ Tìm kiếm · ⬜ Gần đây · ⬜ Yêu thích (mới có lối vào)

**Tạo PDF**
- ⬜ Ảnh sang PDF: Chọn ảnh → Chỉnh sửa ảnh → Tuỳ chọn PDF → Kết quả
- ⬜ Quét tài liệu (+ sheet Xuất, chỉnh 4 góc) · ⬜ Văn bản sang PDF · ⬜ Tạo PDF trắng

**Chuyển đổi**
- ⬜ Màn chuyển đổi chung (Word/Excel sang PDF, PDF sang văn bản/Word/Excel) · ⬜ PDF sang ảnh

**Công cụ PDF**
- ⬜ Gộp · ⬜ Tách · ⬜ Sắp xếp trang · ⬜ Khoá · ⬜ Mở khoá · ⬜ Màn chọn PDF · ⬜ Thêm hình mờ · ⬜ Màn kết quả chung

**Chỉnh sửa PDF**
- ⬜ Chú thích · ⬜ Ký PDF (+ bảng vẽ chữ ký) · ⬜ Điền biểu mẫu

**Trình xem**
- ⬜ PDF · ⬜ DOCX · ⬜ XLSX · ⬜ PPTX · ⬜ TXT

**Cài đặt**
- ✅ Ngôn ngữ · ✅ Giao diện · ✅ Khổ giấy mặc định (dạng bảng chọn)
- ⬜ Thư mục lưu · ⬜ Giới thiệu · ⬜ Chính sách bảo mật

**Khác:** ✅ Logo (4 phương án, chọn 1c) · ⬜ Splash (không bắt buộc)

---

## 4. Thanh điều hướng — vai trò từng mục

| Mục | Vai trò | Điện thoại | Tablet |
|---|---|---|---|
| **Trang chủ** | Trang | Thanh dưới, icon `home` | Thanh bên |
| **Tập tin** | Trang | Thanh dưới, icon `folder` | Thanh bên |
| **⇄** | **Hành động**, không phải trang: bấm = mở thẳng **Ảnh sang PDF**; không có trạng thái "đang chọn" | Nút tròn đỏ 58px ở giữa, nhô lên 20px | Nút đỏ "Ảnh sang PDF" ở đầu thanh bên |
| **Công cụ** | Trang | Thanh dưới, icon `widgets` | Thanh bên |
| **Cài đặt** | Trang | Thanh dưới, icon `settings` | Thanh bên |

- Mục đang chọn: icon đặc (`FILL 1`) trong viên nền `primary-soft`, chữ `primary`/`primary-text`.
- Các tab **giữ trạng thái** khi chuyển qua lại.

---

## 5. Hướng dẫn cho người code

**Thứ tự đề xuất**
1. Tokens (màu sáng/tối, màu loại file, chữ, bo góc) → theme sáng / tối / theo máy.
2. Thành phần dùng chung: icon loại file, dòng tài liệu, trạng thái trống, hộp thoại, sheet, snackbar, nút chính/phụ, thanh tiến độ.
3. Khung điều hướng: thanh dưới + ⇄ (điện thoại) và thanh bên (tablet ≥ 600dp).
4. 4 màn chính + mọi trạng thái của Tập tin.
5. Các màn còn lại theo thứ tự ưu tiên của brief: Ảnh sang PDF (3 bước) → Trình đọc PDF → Cài đặt con → công cụ.

**Quy tắc bắt buộc**
- Giữ **đủ chức năng, chữ và trạng thái** trong `design-brief-pdf-office.md`; thiết kế chỉ thay hình thức. Màn chưa vẽ thì theo brief và tái dùng thành phần ở trên.
- Luôn tạo **file mới**, không ghi đè file gốc.
- **Không hard-code chữ**: mọi chuỗi qua file đa ngôn ngữ (6 ngôn ngữ: Tiếng Việt · English · 中文 · 日本語 · 한국어 · Bahasa Indonesia). Nhãn phải chịu được chữ dài (xuống dòng tối đa 2 dòng hoặc “…”).
- Chuỗi tiếng Việt lưu dạng **Unicode NFC** (dấu dựng sẵn, vd “ệ” = U+1EC7, không tách thành e + dấu). Chuẩn hoá NFC cả khi so sánh/tìm tên file.
- Nút viết **chữ thường đầu câu** (Huỷ / OK / Xoá / Cấp quyền) và dùng thống nhất từ **"file"**.
- Vùng chạm ≥ 48dp; tránh blur/animation liên tục ở danh sách và trình xem.

**Cách mở file `.dc.html` để xem**
- Giữ nguyên cấu trúc `screens/` (các file `.dc.html` cần `support.js` và `assets/` cùng thư mục).
- Chạy server tĩnh trong `screens/`, ví dụ: `npx serve .` hoặc `python -m http.server 8000`, rồi mở `http://localhost:8000/Phiotron%20PDF%20Thiet%20bi.dc.html` bằng Chrome/Edge (cần mạng để tải font và icon từ Google Fonts).
- Mở thẳng bằng double-click (`file://`) có thể không tải được các component con → nên dùng server.
- Mỗi khung bấm được: điều hướng, sắp xếp, ⋮ → đổi tên/xoá/thông tin, yêu thích, Cài đặt → Giao diện để đổi sáng/tối.

---

## 6. Màn thiết kế → file Flutter cần sửa

> Mục này viết thêm từ mã nguồn thật trong `app/lib/` (Claude Design không thấy code). Đường dẫn tính từ `app/lib/`.
> File `.dc.html` chỉ để tra style; không chép HTML/CSS sang Flutter.

### 6.1 Token → theme
| Thiết kế | File | Việc |
|---|---|---|
| Màu §1.1, §1.2 | `core/theme/app_colors.dart` | Thêm token sáng/tối (`ThemeExtension`); giữ hằng màu loại file cũ; thêm màu thanh tiêu đề tab đậm hơn; tab "Tất cả" đổi từ đỏ sang `#25212B` |
| Chữ, bo góc, bóng §1.3–1.6 | `core/theme/app_theme.dart` | `textTheme` Be Vietnam Pro; bo góc thẻ/hộp thoại/sheet; AppBar không còn đỏ toàn màn |
| Font | `pubspec.yaml` (`flutter: fonts:`) + `assets/fonts/` | **Đóng gói** Be Vietnam Pro trong app (app chạy offline, không tải Google Fonts lúc chạy) |
| Icon | `pubspec.yaml` | Material Symbols Rounded cần gói riêng có sẵn font (Flutter `Icons` là Material Icons cũ) |

### 6.2 Thành phần dùng chung
| Thiết kế | File |
|---|---|
| Icon loại file + huy hiệu khoá | `core/widgets/file_type_icon.dart` |
| Trạng thái trống / lỗi | `core/widgets/empty_state.dart` |
| Hộp thoại, mật khẩu, tiến độ | `core/widgets/app_dialog.dart`, `core/widgets/dialogs.dart` |
| Ô tìm kiếm, ô nhập | `core/widgets/app_search_field.dart`, `core/widgets/app_text_field.dart` |
| Dòng tài liệu (⭐, ⋮) | `features/documents/widgets/document_tile.dart` |

### 6.3 Màn đã vẽ → file
| Màn thiết kế | File |
|---|---|
| Khung + thanh dưới + nút ⇄ | `features/documents/main_shell.dart` |
| Thanh bên tablet ≥600dp | **Chưa có** — thêm layout tablet trong `main_shell.dart` |
| Trang chủ | `features/documents/home_tab.dart` |
| Tập tin (6 tab, lưới loại file, trạng thái) | `features/documents/home_screen.dart`, `widgets/document_list.dart`, `widgets/permission_views.dart` |
| Menu sắp xếp | `features/documents/widgets/sort_menu.dart` |
| Menu ⋮, Đổi tên, Thông tin, Xoá + snackbar | `features/documents/widgets/document_tile.dart`, `features/documents/document_actions.dart` |
| Ngăn kéo (bỏ trên tablet) | `features/documents/widgets/home_drawer.dart` |
| Công cụ | `features/documents/widgets/tools_sheet.dart` (`ToolsPage`), icon ở `core/tools/tool_registry.dart` |
| Cài đặt + bảng chọn Ngôn ngữ / Giao diện / Khổ giấy | `features/settings/settings_screen.dart`, `settings_widgets.dart`, `language_screen.dart`, `theme_screen.dart`, `page_size_screen.dart` |
| Màn chưa vẽ (§3 ⬜) | Theo `docs/design-brief-pdf-office.md` + tái dùng §6.2 |

### 6.4 Logo & tên "Phiotron PDF" (đổi khi chủ dự án chốt tên)
| Việc | File |
|---|---|
| Icon Android (màu + 1 màu) | `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`, `mipmap-anydpi-v26/ic_launcher.xml` ← từ `screens/assets/logo-3-color.svg`, `logo-3-mono.svg` |
| Icon iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Logo trong app | `lib/features/settings/app_logo.dart` |
| Tên app | `android/app/src/main/AndroidManifest.xml` (`android:label`), `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`), chuỗi tên app trong l10n 6 ngôn ngữ, lời nhắn Chia sẻ |

`screens/assets/logo.png` là **logo cũ** (tờ giấy + mũi tên), không dùng nữa. Không đổi package id `com.phuong.pdfoffice`.

### 6.5 Lưu ý khi code
- Giữ nguyên route `core/router/routes.dart`, CSDL, engine — chỉ đổi giao diện.
- Đổi chuỗi → chạy trong `app/`: `dart run tool/merge_arb.dart && flutter gen-l10n`.
- Một số quyết định của thiết kế khác app hiện tại (nút chữ thường, dùng từ "file", AppBar không đỏ, tab Tất cả màu than) — đã được chủ dự án duyệt cùng thiết kế.
- Kiểm `flutter analyze` + `flutter test`; thử bản release trên máy thật (Galaxy A13, 32-bit).
