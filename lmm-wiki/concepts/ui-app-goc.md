---
title: UI App gốc — cấu trúc giao diện app mẫu (com.readpdf.pdfreader.pdfviewer)
type: concept
updated: 2026-10-27
sources:
  - lmm-wiki/decisions/0004-pham-vi-bam-app-goc.md
---

# UI App gốc — Giao diện app mẫu

App mẫu: **"Image to PDF Converter"** (TrustedOffice, `com.readpdf.pdfreader.pdfviewer`, v4.0.3, Android 7.0+).
Khảo sát trực tiếp qua ADB screencap trên Samsung Galaxy A13, 27/10/2026.

## Cấu trúc điều hướng tổng thể

```
BottomNavigationBar (5 item)
├── [0] Trang chủ   — icon nhà, search bar + 3 tile + recent files
├── [1] Tập tin     — duyệt file, tab All/PDF/DOC/XLS/PPT/TXT
├── [FAB]           — nút đỏ giữa, icon ⇄ (chuyển đổi / hành động chính)
├── [2] Công cụ     — lưới công cụ PDF theo nhóm
└── [3] Cài đặt     — trang cài đặt
```

> App của mình hiện dùng **Hamburger drawer + AppBar màu + tab** thay cho bottom nav.
> Kế hoạch redesign: thay bằng `NavigationBar` Material 3 (xem [[0004-pham-vi-bam-app-goc]]).

---

## Tab Trang chủ

```
┌─────────────────────────────────┐
│  🔍  Tìm kiếm tập tin      💎  │  ← search bar + premium icon (bỏ qua, ta không có premium)
├─────────────────────────────────┤
│ ┌───────────┐ ┌───────────────┐ │
│ │ Hình ảnh  │ │  Quét PDF    │ │  ← tile lớn đỏ/hồng (trái) + tile xanh (phải trên)
│ │ sang PDF  │ ├───────────────┤ │
│ │ (đỏ, to)  │ │ PDF thành hình│ │  ← tile cam (phải dưới)
│ └───────────┘ └───────────────┘ │
├─────────────────────────────────┤
│ Các tập tin gần đây  Xem tất cả>│
│ [thumb] TenFile.pdf  PDF · ngày · kích thước  ⋮ │
│ [thumb] TenFile.docx DOC · ...                ⋮ │
│ ...                             │
└─────────────────────────────────┘
```

### 3 tile tính năng chính
| Tile | Màu | Tính năng | Route app mình |
|---|---|---|---|
| Hình ảnh sang PDF | Đỏ/hồng gradient, lớn (chiếm ~50% width, ~2 hàng cao) | `image_to_pdf` | `Routes.imageToPdf` |
| Quét PDF | Xanh dương gradient | `scanner` | `Routes.scanner` |
| PDF thành hình… | Cam/vàng gradient | `pdf_to_image` | `Routes.pdfToImage` |

### Phần "Gần đây"
- Tiêu đề "Các tập tin gần đây" + link "Xem tất cả >"
- Mỗi dòng: thumbnail | tên file | badge loại (màu) | ngày | kích thước | ⋮

---

## Tab Tập tin

Giống màn hiện tại của app mình (tab All/PDF/DOC/XLS/PPT/TXT + danh sách file).
Cấu trúc dòng file:
```
[thumbnail] TenFile.ext
            [BADGE]  · ngày  · kích thước          ⋮
```

### Badge màu loại file
| Loại | Màu badge |
|---|---|
| PDF | Đỏ `#E53935` |
| DOC / DOCX | Xanh dương `#1E88E5` |
| XLS / XLSX | Xanh lá `#43A047` |
| PPT / PPTX | Cam `#F4511E` |
| TXT | Xám `#78909C` |

---

## Tab Công cụ

Lưới icon công cụ cuộn được, nhóm theo danh mục. Tương đương `ToolsSheet` hiện tại của app mình
(sẽ chuyển thành tab cố định khi redesign).

---

## Trình đọc PDF

AppBar:
```
← TenFile.pdf    🔖  🌙  ⚙️(view)  🔍  ⋮
```

Nút View Settings (⚙️) mở bottom sheet:
- **Vertical / Horizontal** (icon minh hoạ)
- **Continuous** (toggle)
- **Color inversion** (toggle — chế độ tối)

Menu ⋮: các chức năng bổ sung (in, chia sẻ, thông tin, ...).

---

## So sánh nhanh với app mình

| Điểm | App mẫu | App mình (hiện tại) |
|---|---|---|
| Điều hướng | Bottom nav 5 item | Hamburger drawer + tab |
| Trang chủ | Tile tính năng + gần đây | Danh sách file có tab |
| Header | Search bar thuần | AppBar có title |
| Công cụ | Tab riêng | Bottom sheet (FAB +) |
| Cài đặt | Tab riêng | Route `/settings` từ drawer |
| Badge loại file | Màu theo loại | Cùng màu (chưa có badge màu khác nhau) |

**Tính năng**: đã đủ, chỉ khác giao diện.

Liên quan: [[0004-pham-vi-bam-app-goc]], [[tinh-nang-t1-t10]], [[documents]].

## Cập nhật 27/10: đã làm giao diện giống app mẫu
Bottom nav 5 mục + 3 ô tính năng + Yêu thích/Gần đây đã làm xong (xem [[documents]]). **Cài đặt app mẫu** (chụp qua ADB): nhóm
*Chung* (Ngôn ngữ, Màu chủ đề) và *Về ứng dụng* (Thêm tiện ích, Chia sẻ ứng dụng, Phản hồi, Chính sách bảo mật, Ứng dụng khác,
Quản lý Đăng ký) + biểu ngữ nâng cấp. App mình làm: Chia sẻ (gửi link Release), Phản hồi (mailto), Chính sách bảo mật (màn tĩnh),
chia 2 nhóm. **Bỏ** biểu ngữ/Ứng dụng khác/Quản lý Đăng ký (không quảng cáo, không đăng ký, không store); **chưa làm** "Thêm tiện ích".
