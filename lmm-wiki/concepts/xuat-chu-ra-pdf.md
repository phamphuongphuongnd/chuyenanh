---
title: Xuất chữ Việt / Trung / Nhật / Hàn ra PDF bằng Syncfusion
type: concept
updated: 2026-10-26
sources:
  - app/test/spikes/pdf_text_spike_test.dart
  - app/test/spikes/pdf_text_fallback_test.dart
  - app/test/spikes/pdf_password_spike_test.dart
  - app/test/spikes/vi_nfc.dart
  - spikes/pdf_text/out/vi_cjk_page1.png
  - spikes/pdf_text/out/vi_arial_page1.png
---

# Xuất chữ Việt / Trung / Nhật / Hàn ra PDF bằng Syncfusion

Kết quả spike S1 (26/10/2026), đã **nhìn tận mắt** ảnh render (`spikes/pdf_text/out/*.png`). Người làm convert/văn bản→PDF
([[0002-syncfusion-community]]) bắt buộc đọc.

## Tiếng Việt
- Chữ **NFC** (dấu đã dựng sẵn thành 1 ký tự) vẽ **đúng hoàn toàn** với `PdfTrueTypeFont` + arial.ttf, kể cả dấu chồng
  `ặ ỗ ữ ẫ ậ ề ở`, cả `PdfTextElement` + `PdfLayoutType.paginate`.
- Chữ **NFD** (chữ + dấu rời) vẽ **SAI**: Syncfusion không áp dụng GPOS/mark positioning nên dấu rời và lệch chỗ.
- **Cách sửa:** chuẩn hoá về NFC **trước khi vẽ**. Dart không có `normalize`, spike đã viết `composeVietnamese()` bằng bảng
  tra (nhận dấu thanh/dấu mũ theo thứ tự bất kỳ, 11 trường hợp test) ở `app/test/spikes/vi_nfc.dart` → **chuyển vào
  `app/lib/core/utils/` khi làm convert**, kèm unit test. Áp cho mọi chuỗi đưa vào PDF (TXT/DOCX/XLSX/chữ gõ/OCR).

## Trung / Nhật / Hàn — không có font nào đủ cả Việt + CJK
| Font Windows | Kết quả |
|---|---|
| `msyh.ttc`, `simsun.ttc` | Trung + Nhật đúng; **không có Hangul**, **không có chữ Việt có dấu** (ra ô trống) |
| `malgun.ttf` | Hàn đúng, kana đúng; **thiếu chữ Hán giản thể** (汉 测 试 简 trống), không có dấu Việt |
| `YuGothR.ttc` | **Trang trắng hoàn toàn, lỗi im lặng** → không dùng |
| `arial.ttf` | Latin + Việt đúng, không có CJK |
- Syncfusion **nhận file `.ttc`** (đọc face đầu tiên).
- ⇒ Bắt buộc **fallback theo script**, tách chuỗi thành từng đoạn cùng hệ chữ rồi vẽ mỗi đoạn bằng font riêng:
  Latin/Việt → Noto Sans, Hán/kana → Noto Sans SC/JP, Hangul → Noto Sans KR. Đã kiểm dòng trộn
  `Hà Nội 河内 하노이 ハノイ` đúng (`pdf_text_fallback_test.dart`). Trong app dùng font Noto đóng gói trong `assets/fonts/`
  (chưa tải, cần người dùng đồng ý) chứ **không** dùng font Windows.
- Gotcha: `measureString` **cắt dấu cách cuối đoạn** → cộng thêm bề rộng dấu cách khi nối các đoạn.

## Kích thước
Font **được subset tự động**: `vi_arial.pdf` 33 KB (font gốc 1,0 MB); `vi_cjk.pdf` dùng 3 font chỉ 105 KB (font gốc 19,7 MB + 13,5 MB).

## Mật khẩu PDF
- Mở PDF mã hoá AES-256 **không mật khẩu** → `ArgumentError` (name=`password`, "Cannot open an encrypted document. The password is invalid.").
  **Sai mật khẩu và mật khẩu rỗng cho cùng một `ArgumentError`** → chỉ phân biệt được bằng việc app có truyền mật khẩu
  hay không (`SyncfusionPdfSecurity` đã xử lý: `PasswordRequired` / `WrongPassword`).
- Mở bằng mật khẩu đúng → đặt `userPassword = ''` và `ownerPassword = ''` → lưu → mở lại không cần mật khẩu: **OK**.
- PDF chỉ có owner-password (user rỗng) mở được bình thường, `isEncrypted` = false.

Liên quan: [[0002-syncfusion-community]], [[thu-vien-dart-thuan]].
