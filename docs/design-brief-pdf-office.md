# PDF Office — Tài liệu chức năng cho thiết kế giao diện

> Mục đích file này: đưa cho designer / công cụ design để **thiết kế lại toàn bộ giao diện**. Chức năng giữ nguyên;
> chỉ đổi hình thức. Mô tả theo hiện trạng app (Flutter, Android + iOS). Không có chi tiết kỹ thuật.
> Mục 0 cho biết cái gì **được phép đổi** và **bắt buộc giữ**.

---

## 0. Tóm tắt cho designer

| | |
|---|---|
| **Tên app** | PDF Office |
| **Là gì** | App dùng cá nhân để đọc / tạo / chuyển đổi / chỉnh sửa PDF, xem file Office, quét tài liệu + nhận dạng chữ (OCR) |
| **Nguyên tắc** | Hoạt động **hoàn toàn offline**, **không quảng cáo**, **không tài khoản / đăng nhập / premium / mua trong app**, không thu thập dữ liệu |
| **Nền tảng** | Điện thoại Android (chính) và iPhone. Màn dọc, rộng 360–412dp |
| **Ngôn ngữ giao diện** | 6: Tiếng Việt · English · 中文 · 日本語 · 한국어 · Bahasa Indonesia (chữ dài ngắn khác nhau → thiết kế phải chịu được chữ dài) |
| **Chế độ sáng / tối** | Có cả hai + "Theo máy" |
| **Ứng dụng tham chiếu** | Một app chuyển đổi PDF phổ biến trên Google Play — chỉ tham khảo các luồng chức năng phổ biến của nhóm app chuyển đổi PDF; giao diện, logo, icon và tài nguyên do dự án tự thiết kế |
| **Quy mô** | 5 mục điều hướng chính · 19 công cụ · 5 trình xem · 8 màn cài đặt |

### Cái designer được đổi
Màu, font, icon, bo góc, độ dày, bố cục từng màn, kiểu thanh tiêu đề, kiểu thẻ, animation, minh hoạ trống/lỗi, logo.

### Cái bắt buộc giữ (chức năng)
- Đủ 5 mục điều hướng chính và nút hành động ⇄ (Ảnh sang PDF) ở giữa.
- Đủ 19 công cụ, mỗi công cụ vẫn có các tuỳ chọn ghi ở mục 5–9.
- Mọi trạng thái ghi ở từng màn (trống, đang tải, lỗi, thiếu quyền, cần mật khẩu, thành công).
- Màu **theo loại file** (PDF/DOC/XLS/PPT/TXT) vẫn phải phân biệt được — người dùng muốn các loại file "hành xử giống nhau, cùng màu theo loại".
- Luồng "tạo ra file mới, **không ghi đè file gốc**" và màn kết quả có **Mở / Chia sẻ**.

### Những chỗ native, designer không chỉnh được (đừng vẽ)
- Camera + tự nhận viền + cắt của **Quét tài liệu** (do trình quét của hệ điều hành/Google cung cấp).
- Màn **Cắt ảnh** (uCrop) trong Ảnh sang PDF.
- Bộ chọn file / chọn thư mục / chia sẻ của hệ điều hành; hộp thoại xin quyền.
- Trang "Giấy phép mã nguồn mở".
- Phần vẽ nội dung PDF bên trong màn Chú thích / Điền biểu mẫu (do thư viện PDF vẽ; app chỉ bao quanh nó bằng thanh công cụ).

### Không làm — đừng thiết kế thừa
Premium / nâng cấp / biểu ngữ quảng cáo · đăng nhập · quản lý đăng ký · "ứng dụng khác" · onboarding · chọn màu chủ đề tuỳ ý ·
widget màn hình chính · chú thích vẽ tay / chèn chữ / chèn hình / con dấu · chế độ trình chiếu toàn màn hình PPT · ký bằng ảnh chữ ký.

### Hạn chế hiện tại (đừng thiết kế như thể đã chạy)
- **Mở file từ app khác** ("Mở bằng PDF Office", chia sẻ file/ảnh vào app) đã khai báo nhưng **chưa hoạt động**: chọn app này chỉ mở Trang chủ.
- Splash hiện chỉ là nền trống (không logo). Designer có thể đề xuất splash, nhưng không bắt buộc.

---

## 1. Điều hướng tổng thể

```
Thanh điều hướng dưới (5 mục)
├── Trang chủ    — ô tìm, 3 ô tính năng lớn, Yêu thích, Gần đây
├── Tập tin      — duyệt mọi tài liệu, 6 tab loại file, sắp xếp
├── ⇄ (nút tròn đỏ, giữa)  — KHÔNG phải trang: bấm = mở thẳng "Ảnh sang PDF"
├── Công cụ      — lưới 19 công cụ chia 4 nhóm
└── Cài đặt
```
- Các tab giữ nguyên trạng thái khi chuyển qua lại. Bấm Back ở tab khác Trang chủ → về Trang chủ (không thoát app).
- Hiện chưa có FAB ở bất kỳ màn nào.
- Màn **Tập tin** còn có **ngăn kéo trái** (hamburger): Gần đây · Yêu thích · Ngôn ngữ · Giao diện · Thư mục lưu · Giới thiệu.

### Bản đồ màn hình

| Khu vực | Màn |
|---|---|
| Khung chính | Trang chủ · Tập tin · Công cụ · Cài đặt |
| Danh sách phụ | Tìm kiếm · Gần đây · Yêu thích |
| Tạo PDF | Chọn ảnh → Chỉnh sửa ảnh → (Tuỳ chọn PDF) → Kết quả · Quét tài liệu (+ chỉnh 4 góc thủ công) · Văn bản sang PDF · Tạo PDF trắng |
| Chuyển đổi | Word sang PDF · Excel sang PDF · PDF sang ảnh · PDF sang văn bản · PDF sang Word · PDF sang Excel |
| Công cụ PDF | Gộp · Tách · Sắp xếp trang · Khoá · Mở khoá (+ màn chọn PDF) · Thêm hình mờ |
| Chỉnh sửa PDF | Chú thích · Ký PDF (+ bảng vẽ chữ ký) · Điền biểu mẫu |
| Trình xem | PDF · DOCX · XLSX · PPTX · TXT |
| Cài đặt con | Ngôn ngữ · Giao diện · Thư mục lưu · Khổ giấy mặc định · Giới thiệu · Chính sách bảo mật |

---

## 2. Hệ thống nhận diện hiện tại (tham khảo để thiết kế lại)

- **Phong cách:** Material 3, màu chủ đạo **đỏ**. Thanh tiêu đề (AppBar) **đỏ ở cả sáng lẫn tối**, chữ trắng, tiêu đề căn trái, không đổ bóng.
- **Màu chính:** đỏ `#E5393B` (đậm hơn `#C62828`).
- **Nền:** sáng `#F5F5F5` (thẻ trắng) · tối `#121212` (thẻ `#1E1E1E`).
- **Ô nhập:** nền vàng nhạt `#FFF8E1` (tối `#2C2A22`), bo 8, không viền.
- **Màu theo loại file** (giữ nguyên ở chế độ tối):

| Loại | Màu | Dùng ở |
|---|---|---|
| PDF | `#E53935` | icon file, AppBar tab PDF/trình xem PDF |
| DOC/DOCX | `#1E88E5` | icon, AppBar tab DOC & trình xem DOCX |
| XLS/XLSX | `#43A047` | icon, AppBar tab XLS & trình xem XLSX |
| PPT/PPTX | `#F4511E` | icon, AppBar tab PPT & trình xem PPTX |
| TXT | `#78909C` | icon, AppBar tab TXT & trình xem TXT |
| Ảnh | `#8E24AA` | icon |
| Khác | `#9E9E9E` | icon |

- **Màu trạng thái:** thành công xanh `#43A047` · yêu thích vàng (ngôi sao) · lỗi theo mặc định Material 3.
- **3 ô lớn ở Trang chủ (gradient):** Ảnh sang PDF `#EF5350→#C62828` · Quét tài liệu `#42A5F5→#1565C0` · PDF sang ảnh `#FFA726→#E65100`.
- **Bo góc đang dùng:** 8 (ô nhập, banner) · 12 (nút, ô công cụ) · 16 (hộp thoại, 3 ô Trang chủ) · 28 (ô tìm kiếm Trang chủ).
- **Font:** mặc định hệ thống, chưa có font riêng.
- **Logo:** nền vuông bo đỏ `#E5393B`, trang giấy trắng gập góc phải trên, mũi tên xuống đỏ ở giữa. Có bản adaptive icon Android + monochrome.

### Thành phần dùng chung (nên thiết kế thành một bộ)
| Thành phần | Mô tả |
|---|---|
| **Dòng tài liệu** (`DocumentTile`) | Icon loại file (có ổ khoá nhỏ nếu PDF có mật khẩu) · tên (1 dòng) · phụ đề `dung lượng • giờ/ngày • thư mục` · ⭐ · ⋮ |
| **Icon loại file** | Trang giấy gập góc, nhãn PDF/DOC/XLS/PPT/TXT/IMG/FILE ở dưới, màu theo loại; rộng = 0.8 × cao |
| **Trạng thái trống** | Icon/minh hoạ lớn + tiêu đề + mô tả + (nút) |
| **Hộp thoại** | Tiêu đề đậm + nội dung + 2 nút bằng nhau cùng hàng: HUỶ (viền) / OK (đỏ đặc) |
| **Hộp thoại tiến độ** | Không đóng được bằng chạm ngoài; thanh tiến độ + phần trăm + nút HUỶ |
| **Hộp thoại mật khẩu** | Thông điệp + ô mật khẩu có nút mắt hiện/ẩn + lỗi "Mật khẩu không đúng." |
| **Nút chính** | Đỏ đặc, full width, cao 48, chữ IN HOA (màn công cụ); đôi khi kèm icon |
| **Thẻ chọn file đầu vào** | Icon loại file + tên + "n trang • dung lượng" + nút "Đổi tệp" |
| **Banner ghi chú** | Khung nền nhạt, icon ⓘ hoặc ⚠, chữ nhỏ (cảnh báo / gợi ý) |
| **Màn kết quả chung** | Dấu ✓ xanh lớn + tên + thông tin + nút Mở / Chia sẻ / Xong |
| **Ô tìm kiếm trên AppBar** | Trong suốt, chữ trắng, tự focus |
| **Thanh tìm trong trình xem** | Nền theo màu loại file; ô nhập + "n/m" hoặc "Không có kết quả" + ▲ ▼ ✕ |
| **Chip lựa chọn / SegmentedButton / Slider / chấm màu** | Dùng ở hầu hết màn tuỳ chọn |

---

## 3. Trang chủ & Tập tin

### 3.1 Tab Trang chủ
- **AppBar:** "PDF Office", không có nút.
- **Thân (cuộn dọc):**
  1. Ô tìm kiếm giả (pill): icon 🔍 + "Tìm tài liệu" — chạm mở màn Tìm kiếm.
  2. **3 ô tính năng** (cao ~176): ô lớn trái "**Ảnh sang PDF**" (đỏ); phải-trên "**Quét tài liệu**" (xanh dương); phải-dưới "**PDF sang ảnh**" (cam). Mỗi ô: icon trắng + nhãn trắng đậm (tối đa 2 dòng).
  3. Mục **Yêu thích** — tiêu đề + "Xem tất cả ›" → tối đa 5 dòng tài liệu. Trống: "Chưa có file yêu thích".
  4. Mục **Gần đây** — tiêu đề + "Xem tất cả ›" → tối đa 5 dòng. Trống: "Chưa mở file nào gần đây".
- Trạng thái: chỉ có "trống" hoặc "có dữ liệu".

### 3.2 Tab Tập tin
- **AppBar** đổi màu theo tab đang chọn: Tất cả = đỏ chủ đạo; PDF/DOC/XLS/PPT/TXT = màu loại file.
  - Trái: hamburger (mở ngăn kéo). Phải: ⭐ Yêu thích · 🕘 Gần đây · 🔍 Tìm · ⇅ Sắp xếp.
  - **TabBar** cuộn ngang, vuốt ngang để chuyển: Tất cả · PDF · DOC · XLS · PPT · TXT.
- **Thân mỗi tab:** danh sách dòng tài liệu; kéo xuống để quét lại.
  - **Riêng tab Tất cả**: ở đầu có **lưới loại file** PDF · DOC · XLS · PPT · TXT · "Khác" (icon 40px + nhãn; bấm ô = chuyển sang tab đó; "Khác" mở bộ chọn file hệ thống).
- **Sắp xếp** (menu có dấu ✓, nhớ lựa chọn): Tên A–Z · Tên Z–A · **Mới nhất trước (mặc định)** · Cũ nhất trước · Lớn nhất trước · Nhỏ nhất trước.
- **Trạng thái:**
  - *Đang quét, chưa có file:* thanh tiến độ + "Đang quét… đã tìm thấy {n} file" + ~8 dòng skeleton xám.
  - *Đang quét, đã có file:* thanh tiến độ mỏng phía trên danh sách.
  - *Thiếu quyền, chưa có file:* icon thư mục gạch chéo lớn · "Cho phép truy cập file" · "PDF Office cần quyền truy cập tất cả file để tìm tài liệu trên thiết bị." · nút "Cấp quyền" · nút viền "Chọn file thủ công".
  - *Thiếu quyền, đã có file cũ:* băng đỏ nhạt phía trên (icon khoá + "Cấp quyền truy cập file để tìm tất cả tài liệu" + nút "Cấp quyền").
  - *Trống:* minh hoạ theo loại + "Không tìm thấy tài liệu".
  - *Lỗi:* icon lỗi + nút "Thử lại".

### 3.3 Dòng tài liệu — menu ⋮ và hộp thoại
- Menu ⋮: Mở · Đổi tên · Chia sẻ · Thêm vào yêu thích / Bỏ yêu thích · Thông tin · Xoá.
- **Đổi tên:** ô nhập có sẵn tên không đuôi; lỗi "Tên không được để trống" / "Đã có file trùng tên"; HUỶ / OK.
- **Thông tin** (chỉ nút OK): Tên · Đường dẫn · Dung lượng · Ngày sửa.
- **Xoá:** "Xoá file?" + "\"{tên}\" sẽ bị xoá vĩnh viễn."; HUỶ / XOÁ; sau đó snackbar "Đã xoá \"{tên}\"".
- **Lỗi mở file:** snackbar (vd "File không còn tồn tại").
- **Mở file theo loại:** PDF → trình đọc PDF; DOCX/XLSX/PPTX/TXT → trình xem riêng; DOC/XLS/PPT cũ → mở bằng app ngoài.

### 3.4 Màn Tìm kiếm / Gần đây / Yêu thích
- **Tìm kiếm:** ô nhập trong AppBar (chữ trắng, tự focus, lọc theo tên với độ trễ ~0.2s) + ✕ (khi có chữ) + ⇅ Sắp xếp. Trống: icon + "Không có file phù hợp".
- **Gần đây:** AppBar "Gần đây" + danh sách. Trống: icon đồng hồ + "Chưa mở file nào gần đây".
- **Yêu thích:** AppBar "Yêu thích" + danh sách. Trống: sao rỗng + "Chưa có file yêu thích" + "Nhấn ngôi sao ở một file để thêm vào đây".
- Cả ba có skeleton khi tải và trạng thái lỗi.

### 3.5 Tab Công cụ
- **AppBar** "Công cụ". Thân: 4 nhóm theo thứ tự, mỗi nhóm có tiêu đề (đỏ đậm) + lưới ô (rộng ~82: vòng tròn icon + nhãn tối đa 2 dòng):

| Nhóm | Công cụ |
|---|---|
| **Tạo PDF** | Ảnh sang PDF · Quét tài liệu · Văn bản sang PDF · Tạo PDF trắng |
| **Chuyển đổi** | Word sang PDF · Excel sang PDF · PDF sang ảnh · PDF sang văn bản · PDF sang Word · PDF sang Excel |
| **Công cụ PDF** | Gộp PDF · Tách PDF · Sắp xếp trang · Khoá PDF · Mở khoá PDF · Thêm hình mờ |
| **Chỉnh sửa PDF** | Chú thích · Ký PDF · Điền biểu mẫu |

- Chú thích / Ký PDF / Điền biểu mẫu **bắt buộc có PDF**: bấm là mở bộ chọn PDF của hệ thống trước, rồi mới vào màn.
- Các công cụ PDF khác khi mở không kèm file sẽ tự mời chọn file ở đầu màn.

---

## 4. Quyền truy cập (xuất hiện ở nhiều nơi)
- **Bộ nhớ / tất cả file** (Android): để quét mọi tài liệu → thấy ở tab Tập tin (mục 3.2).
- **Ảnh** (khi chọn ảnh): từ chối → màn giải thích (4.1 mục Chọn ảnh); cấp một phần → banner "Chỉ một phần ảnh trong máy được cấp quyền." + "Mở cài đặt".
- **Camera**: cho Quét tài liệu và chụp ảnh.
- Luôn có đường lui: nút "Chọn file thủ công" / "Mở cài đặt".

---

## 5. Nhóm TẠO PDF

### 5.1 Ảnh sang PDF (3 bước)
**Vào từ:** ô lớn Trang chủ · nút ⇄ giữa thanh dưới · tab Công cụ.

**Bước 1 — Chọn ảnh**
- AppBar "Chọn ảnh" (nếu có ≥2 album: tiêu đề thành tên album ▾ mở menu "Tên album (số ảnh)").
- Lưới 3 cột (khoảng cách 2px), tải thêm khi cuộn. **Ô đầu tiên luôn là "Máy ảnh"** (chụp trực tiếp).
- Mỗi ảnh có vòng tròn góc trên phải: trống = chưa chọn; **số thứ tự trong nền đỏ** = đã chọn (ảnh có viền đỏ 3px + phủ tối nhẹ). **Tối đa 100 ảnh** ("Chỉ thêm được tối đa {n} ảnh.").
- **Thanh dưới (chỉ hiện khi đã chọn):** dải thumbnail 56×56 cuộn ngang (mỗi ảnh có ✕ + số thứ tự) + "Đã chọn {n}" + nút **TIẾP**.
- Trạng thái: chờ quyền (spinner) · bị từ chối (icon + "Cần quyền truy cập ảnh" + "Hãy cho phép PDF Office đọc ảnh trong máy để bạn chọn ảnh cần chuyển." + "Cho phép truy cập" + "Mở cài đặt") · quyền giới hạn (banner) · album trống "Album này chưa có ảnh" · lỗi "Thử lại".
- Bấm TIẾP: hộp thoại tiến độ "Đang chuẩn bị ảnh…"; nếu ảnh hỏng: "Có {n} ảnh không đọc được nên đã bị bỏ qua."
- Cũng được dùng ở chế độ "thêm ảnh" từ màn sửa (khi đó xong thì quay lại màn sửa).

**Bước 2 — Chỉnh sửa ảnh**
- AppBar "Chỉnh sửa ảnh" + nút "Thêm" (thêm ảnh).
- Từ trên xuống:
  1. Vùng xem trước lớn (nền xám nhạt / đen), nhãn "x / y" góc trên trái.
  2. **Thanh công cụ 5 nút:** Xoay · Cắt · Bộ lọc · Đặt lại (chỉ bật khi ảnh đã sửa) · Xoá.
  3. **Dải thumbnail** (cao 88, **kéo thả đổi thứ tự**): ảnh đang chọn viền đỏ, số ở góc dưới trái, ô "＋ Thêm" ở cuối.
  4. Nút lớn **"TẠO PDF (n)"**.
- Trạng thái: đang chuẩn bị (spinner + "Đang chuẩn bị ảnh…") · đang xử lý (phủ tối + spinner) · xoá ảnh → snackbar "Đã xoá ảnh" + "Hoàn tác" · xoá hết → thoát màn.
- Back khi đã có ảnh: "Bỏ các thay đổi?" / "Các chỉnh sửa và thứ tự ảnh sẽ bị mất." (Không/Có).
- **Cắt:** màn native (uCrop), tiêu đề "Cắt ảnh" — không tuỳ biến.
- **Bộ lọc (bottom sheet, chọn chip là đóng ngay):** **Gốc (mặc định)** · Xám · Đen trắng · Tăng tương phản · Sáng hơn · Màu tài liệu.

**Bảng "Tuỳ chọn PDF" (bottom sheet cuộn)** — hiện khi bấm TẠO PDF:
| Mục | Lựa chọn | Mặc định |
|---|---|---|
| Tên file | Ô nhập (nền vàng nhạt) | app tự sinh tên |
| Khổ giấy | A4 · Letter · Vừa ảnh | A4 (hoặc theo Cài đặt) |
| Hướng giấy | Tự động · Dọc · Ngang (vô hiệu khi "Vừa ảnh") | Tự động |
| Lề | Không (0) · Nhỏ (18pt) · Lớn (36pt) | Không |
| Chất lượng | Slider 30–100% | 85% |
| Ước tính | "Dung lượng ước tính: {size} · {n} trang" | — |
Nút: HUỶ / TẠO PDF. (Không có mật khẩu.) Tiến độ: "Đang tạo PDF…" có HUỶ; lỗi: "Không tạo được PDF".

**Bước 3 — Kết quả** (AppBar "Đã tạo PDF", nút ✕ về Trang chủ)
- Dấu ✓ xanh lớn (88) · icon PDF · tên file · "{n} trang • {size}" · "Đã lưu trong \"{thư mục}\"" · (nếu có ảnh bị bỏ: dòng đỏ báo).
- Nút: **MỞ** (đặc, full width) · CHIA SẺ + ĐỔI TÊN (2 nút viền) · XONG (chữ).

### 5.2 Quét tài liệu (+ OCR)
**Vào từ:** ô Trang chủ · tab Công cụ. **Tự mở camera quét ngay khi vào nếu chưa có trang.**
- Camera, tự nhận viền, cắt: **native — không thiết kế được**. App thiết kế phần danh sách trang + sheet xuất.
- **AppBar** "Quét tài liệu" (không nút).
- **Trống:** icon máy quét + "Chưa có trang nào" + "Quét tài liệu bằng camera. Viền giấy được nhận tự động." + nút "Quét trang".
- **Có trang:** danh sách **kéo thả đổi thứ tự**; mỗi thẻ: thumbnail 72×96 (đã áp xoay + lọc) · "Trang {n}" (+ tên bộ lọc nếu khác Gốc) · hàng icon **Xoay · Bộ lọc · Chụp lại · Xoá** · tay kéo ≡.
- **Thanh dưới:** nút viền "Thêm trang" + nút đặc "Xuất".
- Back khi đã có trang: "Bỏ bản quét?" / "Các trang đã quét sẽ bị mất."
- **Sheet bộ lọc trang:** chip Gốc · Xám · Đen trắng · Làm nét · Làm sáng · Màu tự động + ô "Áp dụng cho mọi trang".
- **Sheet Xuất:**
  - Công tắc **"Làm cho PDF tìm kiếm được (OCR)"** — **bật mặc định**; phụ đề "Thêm lớp chữ vô hình để tìm và sao chép chữ. Xuất sẽ lâu hơn."
  - 3 dòng định dạng (bấm là chạy luôn): **PDF** · **Word (DOCX, nhận dạng chữ)** · **Văn bản (TXT, nhận dạng chữ)**.
  - Dropdown **"Ngôn ngữ chữ cần nhận dạng":** Latin (Anh, Việt, Indonesia) · Tiếng Trung · Tiếng Nhật · Tiếng Hàn (mặc định theo ngôn ngữ app).
- **Tiến độ:** "Đang xuất…" hoặc "Đang nhận dạng chữ…".
- **Kết quả:** **snackbar** "Đã lưu: {tên}" + nút "Mở" (không có màn kết quả riêng — khác Ảnh sang PDF; designer có thể đề xuất thống nhất). Nếu OCR không ra chữ: "Không nhận ra chữ nào. Hãy kiểm tra ngôn ngữ chữ và chất lượng ảnh."; có thể kèm dòng báo trang bị bỏ qua.
- **Chỉnh 4 góc thủ công** (dự phòng khi máy không dùng được trình quét tự động): thông báo "Máy này không dùng được trình quét tự động. Hãy chụp ảnh rồi tự kéo bốn góc." → AppBar "Chỉnh bốn góc" · gợi ý "Kéo bốn góc về mép tài liệu." · ảnh có đa giác viền đỏ, tô đỏ nhạt, 4 chấm tròn trắng viền đỏ kéo được · nút "Cắt" (vô hiệu nếu tứ giác không hợp lệ).

### 5.3 Văn bản sang PDF và 5.4 Tạo PDF trắng
- **Văn bản sang PDF:** dùng **màn Chuyển đổi chung** (mục 6.1) — ô gõ chữ nhiều dòng (hint "Gõ hoặc dán văn bản vào đây") + nút viền "Mở file TXT" + tuỳ chọn khổ giấy/hướng/**cỡ chữ 8–24 (mặc định 12)**/lề. Từ trình xem TXT bấm "Chuyển sang PDF" thì nội dung được nạp sẵn. Để trống → snackbar "Hãy nhập văn bản trước."
- **Tạo PDF trắng** (AppBar "Tạo PDF trắng"):
  1. Xem trước trang (có mẫu dòng/ô).
  2. **Mẫu:** Trắng (mặc định) · Kẻ dòng · Kẻ ô.
  3. "Tiêu đề" (không bắt buộc, in ở đầu trang 1) · "Tên file" (hint "Tài liệu trắng").
  4. **Khổ giấy:** A4 · Letter (theo Cài đặt). **Hướng:** Dọc (mặc định) · Ngang.
  5. **Màu nền** (6 chấm): Trắng (mặc định) · Vàng nhạt `#FFF59D` · Xanh dương nhạt `#BBDEFB` · Xanh lá nhạt `#C8E6C9` · Hồng nhạt `#F8BBD0` · Xám nhạt `#E0E0E0`.
  6. **Danh mục** (ghi vào thuộc tính file): Không · Công việc · Học tập · Cá nhân · Ghi chú.
  7. **Số trang:** nút − / + và ô số, mặc định 1, hợp lệ 1–1000 ("Nhập số từ 1 đến 1000.").
  - Nút **TẠO** → màn kết quả chung (mục 7.1).

---

## 6. Nhóm CHUYỂN ĐỔI

### 6.1 Màn Chuyển đổi chung (một màn cho 6 chế độ)
| Chế độ | Đầu vào | Đầu ra | Tuỳ chọn khổ giấy | Cảnh báo bố cục | OCR |
|---|---|---|---|---|---|
| Văn bản sang PDF | gõ chữ / TXT | PDF | Có (+ cỡ chữ) | — | — |
| Word sang PDF | DOCX | PDF | Có | — | — |
| Excel sang PDF | XLSX | PDF | Có | — | — |
| PDF sang văn bản | PDF | TXT | — | — | Có |
| PDF sang Word | PDF | DOCX | — | Có | Có |
| PDF sang Excel | PDF | XLSX | — | Có | Có |

- **AppBar:** tên chế độ. **Thân** (cuộn, từ trên xuống):
  1. Chọn đầu vào: thẻ "Chọn file" (→ "Đã chọn: {tên}") có icon thư mục; riêng Văn bản sang PDF là ô gõ chữ.
  2. *(PDF sang Word/Excel)* khung thông báo: "Không giữ nguyên bố cục gốc. Tiêu đề, đoạn văn và bảng được dựng lại gần đúng từ chữ trong PDF."
  3. *(Mọi chế độ từ PDF)* thông báo "Trang không có chữ (ảnh quét) sẽ được nhận dạng chữ (OCR), có thể mất thời gian." + dropdown "Ngôn ngữ chữ trên trang quét" (Latin / Trung / Nhật / Hàn).
  4. *(Mọi chế độ sang PDF)* mục **"Tuỳ chọn":** Khổ giấy (A4 mặc định · Letter) · Hướng (Dọc mặc định · Ngang) · Cỡ chữ (chỉ Văn bản) · Lề (slider 0–72, mặc định 40).
  5. Nút đặc **"Chuyển đổi"** (vô hiệu khi đang chạy; nếu chưa chọn file thì tự mở bộ chọn).
  6. **Thẻ kết quả ngay trong màn:** ✓ "Đã chuyển đổi xong" · "Đã lưu tại: {đường dẫn}" · nút "Mở" (chỉ khi app mở được định dạng) + "Chia sẻ".
- Tiến độ "Đang xử lý…" (phần trăm + HUỶ). PDF có mật khẩu → hộp thoại mật khẩu. Lỗi riêng: "Không tìm thấy chữ. PDF dạng ảnh quét cần nhận dạng chữ (OCR) trước."
- Từ trình xem DOCX/XLSX/TXT có nút "Chuyển sang PDF" mở thẳng màn này.

### 6.2 PDF sang ảnh (màn riêng)
- **Vào từ:** ô Trang chủ · tab Công cụ · menu ⋮ của trình đọc PDF.
- Chưa có file: icon ảnh + "Chọn file PDF để chuyển thành ảnh" + nút "Chọn file".
- Có file: thumbnail trang 1 + tên · "{n} trang" + nút đổi file; rồi:
  - **Trang cần chuyển:** "Tất cả các trang" (mặc định) · "Khoảng trang" (ô nhập hint "ví dụ 1-3, 5" + "Đã chọn {n} trang").
  - **Định dạng ảnh:** JPG (mặc định) · PNG.
  - **Độ phân giải (chip):** 72 · 100 · **150 (mặc định)** · 200 · 300 DPI + "Khoảng {w} × {h} px mỗi trang".
  - Nút **CHUYỂN ĐỔI**.
- Lỗi khoảng trang: "Hãy nhập các trang cần chuyển." / "Định dạng không đúng. Ví dụ: 1-3, 5" / "Trang phải nằm trong khoảng từ 1 đến {n}." / "Trong một khoảng, trang đầu không được sau trang cuối."
- Tiến độ "Đang chuyển thành ảnh…" (có HUỶ). PDF có mật khẩu → hộp thoại mật khẩu.
- **Kết quả (thay thân màn):** ✓ lớn · "Chuyển đổi xong" · "Đã lưu {n} ảnh vào:" + đường dẫn thư mục (chọn được chữ) · nút "CHIA SẺ" + "CHUYỂN FILE KHÁC".

---

## 7. Nhóm CÔNG CỤ PDF

### 7.1 Khung chung của các công cụ
- AppBar = tên công cụ; nút chính IN HOA ở đáy; thẻ chọn file đầu vào (mục 2); nếu mở không kèm file thì tự mời chọn.
- **Màn kết quả chung:** ✓ xanh (72) · "Hoàn tất!" · "Đã lưu vào {thư mục}" (1 file) hoặc "Đã tạo {n} tệp" (nhiều) · danh sách thẻ file (bấm = mở; nhiều file thì mỗi dòng có nút chia sẻ) · nút: 1 file → CHIA SẺ + MỞ; nhiều file → XONG.
- Cảnh báo dùng chung: "Chú thích, biểu mẫu và liên kết sẽ không được giữ lại trong tệp mới." (Gộp, Tách, Sắp xếp, Hình mờ.)
- PDF có mật khẩu → hộp thoại nhập mật khẩu. Tất cả đều ra **file mới**, không ghi đè gốc.

### 7.2 Gộp PDF
- Hướng dẫn "Kéo để đổi thứ tự. Các tệp được gộp từ trên xuống dưới." + cảnh báo mất chú thích. Chưa đủ 2 tệp: dòng đỏ "Hãy chọn ít nhất 2 tệp PDF."
- Danh sách **kéo thả**: mỗi thẻ = icon + tên + "{n} trang • {size}" + ✕ "Bỏ" + tay kéo.
- Đáy: **THÊM TỆP** (viền) + **GỘP** (đặc; vô hiệu khi <2 tệp). Tự mở bộ chọn nhiều file khi vào nếu chưa có.
- Bấm GỘP: hộp thoại "Tên tệp sau khi gộp" (gợi ý `A & B` hoặc `A & B (+N)`).

### 7.3 Tách PDF
- Thẻ file + 3 chip chế độ: **Theo khoảng (mặc định)** · Mỗi trang một tệp · Mỗi N trang.
  - *Theo khoảng:* ô "Khoảng trang" hint "VD: 1-3, 5, 7-9"; lỗi "Khoảng trang không hợp lệ. Dùng trang từ 1 đến {max}, vd. 1-3, 5."
  - *Mỗi N trang:* ô "Số trang mỗi tệp" mặc định **2**; lỗi "Nhập một số nguyên từ 1 trở lên."
- Dòng xem trước "Sẽ tạo {n} tệp" + cảnh báo mất chú thích. Nút **TÁCH**. Kết quả nhiều file.

### 7.4 Sắp xếp trang
- Thẻ file + gợi ý "Chạm để chọn trang. Nhấn giữ rồi kéo để đổi thứ tự."
- **Thanh công cụ** (cuộn ngang): Chọn tất cả / Bỏ chọn · "Đã chọn {n}" · Xoay trái · Xoay phải · Dời lên trước · Dời ra sau · Xoá · **Trích** (chỉ các trang đã chọn → file riêng) · Hoàn lại. (Các nút bật khi có chọn trang.)
- **Lưới thumbnail trang** (ô ≤140 rộng, tỉ lệ 0.68): nền trắng, viền xám nhạt; **đã chọn = viền đỏ 3px + ✓ góc trên phải**; số thứ tự hiện tại ở dưới; nhấn giữ + kéo để đổi chỗ (ô đích có viền nhấn); trang xoay thì thumbnail xoay; không render được thì hiện số trang.
- Đáy: **LƯU**. Thông báo: "Phải giữ lại ít nhất một trang." · "Hãy chọn các trang cần trích." · "Chưa có thay đổi nào để lưu."

### 7.5 Khoá PDF
- Thẻ file · "Đặt mật khẩu. Cần nhập mật khẩu này để mở tệp." · ô "Mật khẩu" (có mắt) · ô "Nhập lại mật khẩu" · lỗi "Hãy nhập mật khẩu." / "Mật khẩu nhập lại không khớp." · cảnh báo ⚠ "Hãy ghi nhớ mật khẩu: mất mật khẩu sẽ không thể khôi phục." · nút **KHOÁ**.
- Mã hoá AES-256. Chọn file bằng **màn chọn PDF trong app** (7.7), chỉ hiện PDF chưa khoá.

### 7.6 Mở khoá PDF
- Thẻ file (có ổ khoá). File không có mật khẩu: banner "Tệp này không có mật khẩu." và không có nút đáy. Có mật khẩu: "Nhập mật khẩu hiện tại để gỡ bỏ." + ô "Mật khẩu" (lỗi hiện dưới ô: "Mật khẩu không đúng.") + nút **MỞ KHOÁ**.
- Chọn file bằng màn chọn PDF trong app, chỉ hiện PDF đã khoá.

### 7.7 Màn chọn PDF trong app (dùng cho Khoá / Mở khoá)
- AppBar đỏ: ô tìm kiếm trắng (hint "Tìm tài liệu") + nút "Mở" (chọn từ bộ nhớ hệ thống). Thân: danh sách PDF đã quét, mới nhất trước (dòng như dòng tài liệu nhưng **không có ⭐ ⋮**). Trống: icon PDF + "Không có file phù hợp".

### 7.8 Thêm hình mờ (watermark)
- Thẻ file, rồi:
  1. **Ô xem trước** trang A4 (180 rộng): nền trắng, vài dòng xám giả nội dung, hình mờ hiển thị theo thông số đang chỉnh.
  2. Chip chế độ: **Chữ (mặc định)** · **Ảnh**.
  3. *Chữ:* ô "Nội dung watermark" (mặc định "CONFIDENTIAL") · cảnh báo nếu có ký tự ngoài Latin cơ bản · **Màu** 6 chấm: đỏ `#E5393B` (mặc định) · đen · xanh dương · xanh lá · cam · xám · slider **Cỡ chữ** 12–120 (mặc định 48).
  4. *Ảnh:* nút "Chọn ảnh" (chỉ PNG/JPG; lỗi "Hãy chọn ảnh PNG hoặc JPG.") · slider **Cỡ ảnh** 10–100% (mặc định 50%).
  5. Slider **Độ mờ** 5–100% (mặc định **30%**).
  6. Slider **Góc xoay** −90°…90° bước 5° (mặc định **−45°** cho chữ, **0°** cho ảnh).
  7. **Vị trí:** lưới 3×3 chấm tròn (mặc định giữa trang).
  8. Cảnh báo mất chú thích. Nút **ÁP DỤNG** (áp dụng mọi trang). Lỗi: "Hãy nhập nội dung watermark."
  - Lưu ý chữ: nhãn trong màn này còn dùng từ "watermark" (chưa Việt hoá); tên công cụ là "Thêm hình mờ".

---

## 8. Nhóm CHỈNH SỬA PDF
**Chung:** luôn lưu ra file mới (`_annotated`, `_signed`, `_filled`), gốc không đổi. Thoát khi còn thay đổi: "Bỏ thay đổi?" / "Bạn có thay đổi chưa lưu. Thoát mà không lưu?". Sau khi lưu: hộp thoại "Đã lưu" / "Đã lưu file mới: {tên}\nFile gốc không bị thay đổi." (MỞ / ĐÓNG). Có dải gợi ý mỏng (ⓘ) dưới AppBar. Lỗi mở: "Không mở được PDF này."

### 8.1 Chú thích
- AppBar: tên file · Hoàn tác · Làm lại · Xoá chú thích đang chọn (chỉ khi đang chọn) · Lưu.
- Gợi ý: "Chọn công cụ rồi bôi chọn chữ trên trang." (với Ghi chú: "Chạm vào trang để thêm ghi chú.")
- Vùng PDF chiếm phần còn lại. **Thanh công cụ đáy 2 hàng:**
  - Hàng màu (7 chấm): vàng `#FFEB3B` · xanh lá `#66BB6A` · xanh dương nhạt `#29B6F6` · hồng `#F48FB1` · đỏ `#EF5350` · cam `#FFA726` · tím `#7E57C2`.
  - Hàng **5 công cụ** (icon + nhãn; chạm lần nữa để tắt): **Tô sáng · Gạch chân · Gạch ngang · Gạch sóng · Ghi chú dán**.
- **Không có** vẽ tay / chữ / hình / độ dày nét.
- Lưu khi chưa đổi gì: snackbar "Chưa có thay đổi nào để lưu."

### 8.2 Ký PDF
- AppBar: tên file + nút ✓ "Ký và lưu" (vô hiệu đến khi tài liệu mở xong).
- Gợi ý: "Chọn chữ ký, kéo tới đúng chỗ và kéo góc để đổi cỡ."
- **Trang PDF** (hiển thị dạng ảnh, có bóng) + chữ ký đặt lên là lớp phủ: kéo để di chuyển · kéo góc để đổi cỡ (giữ tỉ lệ) · nút "Gỡ khỏi trang" khi chọn · bấm nền để bỏ chọn. **Một chữ ký đặt được nhiều lần, nhiều trang.**
- **Điều hướng trang:** ‹ "Trang {n} / {tổng}" ›.
- **Thanh chữ ký** (cao 96, cuộn ngang): ô "Chữ ký mới" + các chữ ký đã lưu (thumbnail nền trắng, ✕ góc, bấm = đặt lên trang, giữ = xoá → "Xoá chữ ký này?" / "Chữ ký đã lưu sẽ bị xoá khỏi thiết bị."). Chưa có: "Chưa có chữ ký đã lưu. Hãy vẽ một chữ ký để bắt đầu."
- Lỗi: chưa đặt chữ ký mà bấm ✓ → "Hãy đặt ít nhất một chữ ký lên trang trước." Lưu: tiến độ (không có HUỶ) rồi "Đã lưu".
- **Bảng vẽ chữ ký** (bottom sheet): "Vẽ chữ ký của bạn" · ô vẽ trắng cao 220 (đường kẻ mờ + chữ mờ "Ký tại đây"; viền đỏ khi lỗi "Hãy vẽ chữ ký trước.") · **Màu bút** 4 chấm: đen `#111111` (mặc định) · xanh `#1A3FA8` · đỏ `#C62828` · xanh lá `#2E7D32` · slider **Độ dày nét** 1.5–8 (mặc định 3) · nút "XOÁ NÉT" + "DÙNG CHỮ KÝ". Kết quả: PNG nền trong suốt cắt sát nét, tự lưu vào danh sách chữ ký đã lưu. **Chỉ có vẽ tay.**

### 8.3 Điền biểu mẫu
- AppBar: tên file · Lưu · menu ⋮ có 1 mục "**Lưu bản phẳng (không sửa lại được các ô)**".
- Gợi ý: "Chạm vào ô trên trang để điền." Nếu PDF không có ô: banner ⚠ "PDF này không có ô biểu mẫu để điền."
- Hỗ trợ ô: chữ · checkbox · radio · combo · list. Lưu khi chưa đổi: "Chưa có thay đổi nào để lưu."

---

## 9. TRÌNH XEM (5 định dạng)

**Chung cho 4 trình xem Office/TXT:** AppBar **màu theo loại file**, chữ trắng, tiêu đề = tên file. Đang tải: spinner. Lỗi: trạng thái trống + "Thử lại". Hỗ trợ **chụm 2 ngón để zoom**. **Thanh tìm kiếm** (nền cùng màu AppBar, "n/m", ▲ ▼ ✕). Mọi loại **cùng nút Tìm · Thu nhỏ · Phóng to** (đồng nhất theo yêu cầu người dùng).

### 9.1 Trình đọc PDF
- **AppBar** (tên file 1 dòng): 🔍 Tìm · Thu nhỏ · Phóng to · Đánh dấu trang (outline ↔ đặc) · ⋮. (Zoom 1.0–3.0, bước 0.25.)
- **Menu ⋮:** Đánh dấu · Mục lục · Đến trang │ **Chế độ tối** (tắt) · **Cuộn ngang** (tắt = cuộn dọc) · **Từng trang một** (tắt = cuộn liên tục) │ Đánh dấu cả tài liệu / Bỏ đánh dấu tài liệu · In · Thêm vào màn hình chính (chỉ khi hệ thống hỗ trợ) · PDF sang ảnh. Ba công tắc xem được nhớ giữa các lần mở. "Chế độ tối" = đảo màu vùng trang (không phải theme tối của app).
- **Thanh tìm** (dưới AppBar, nền đỏ): hint "Tìm trong tài liệu" · "{hiện tại} / {tổng}" hoặc spinner hoặc "Không có kết quả" · ▲ ▼ ✕.
- **Thanh trang dưới** (cao 48): ‹ `3 / 25` › — chạm số để nhập số trang cần nhảy; ‹ › vô hiệu ở đầu/cuối.
- **Hộp thoại "Đến trang":** ô số hint "Số trang (1–{n})", lỗi "Nhập số từ 1 đến {n}."
- **Sheet "Đánh dấu"** (cao ~55%): dòng "Cả tài liệu" (nếu có) + các dòng "Trang {n}" có nút xoá; trống: "Chưa có đánh dấu nào" / "Chạm biểu tượng đánh dấu để ghi nhớ một trang."; bấm một dòng = nhảy tới.
- **Sheet "Mục lục"** (cao ~60%): cây thụt lề tối đa 6 cấp, số trang bên phải; trống: "Tài liệu này không có mục lục."
- Trạng thái: giải mã (spinner) · cần mật khẩu (hộp thoại; sai → "Mật khẩu không đúng."; Huỷ → thoát màn) · lỗi (icon + thông báo + tên file + "Đóng").
- Snackbar: "Đã đánh dấu" / "Đã bỏ đánh dấu" · "Hãy xác nhận thêm lối tắt trên màn hình chính." · "Không tạo được lối tắt."
- Không có: thanh cuộn/thumbnail trang riêng, chia sẻ/thông tin trong màn đọc.

### 9.2 DOCX
- AppBar xanh dương: Tìm · Thu nhỏ · Phóng to (0.6–3.0) · **Chuyển sang PDF**.
- Thân: nền trắng, đoạn/bảng/ngắt trang, chọn được chữ, kết quả tìm tô sáng, bấm liên kết (http/https/mailto/tel) → snackbar URL đích. Trống: "Tài liệu trống". Ảnh không vẽ được: "Không hiển thị được ảnh". Chuỗi liên kết: "Đang mở: {url}" · "Không mở được liên kết" · "Đã chép liên kết".

### 9.3 XLSX
- AppBar xanh lá: Tìm · Thu nhỏ · Phóng to (0.5–3) · **Chuyển sang PDF**.
- Thân: **lưới cuộn 2 chiều**, hàng/cột nhãn (A, B, C / 1, 2, 3), màu nền/chữ/viền ô, ô khớp tìm tô sáng; sheet rỗng "Trang tính này trống".
- **Thanh tab sheet ở đáy** (cao 44): tên sheet cuộn ngang; tab chọn = chữ đậm + gạch chân xanh lá dày 3px.

### 9.4 TXT
- AppBar xám xanh: Tìm · Thu nhỏ · Phóng to · **Chuyển sang PDF** (nạp nội dung sang Văn bản sang PDF).
- Cỡ chữ 16 (10–40, bước 2; chụm 2 ngón cũng đổi). Chọn được chữ; tìm tô vàng, kết quả hiện tại tô cam. File lớn: banner "File lớn, chỉ hiển thị phần đầu." **Thanh dưới:** "Bảng mã: {tên}" (tự nhận).

### 9.5 PPTX
- AppBar cam: Tìm · Thu nhỏ · Phóng to · **Ghi chú** (bật/tắt) · mắt "Hiện slide ẩn" (chỉ khi deck có slide ẩn).
- Từ trên xuống: (thanh tìm) → **vuốt ngang đổi slide** (bóng nhẹ; chạm đúp = reset zoom; chụm zoom 1–4, khi zoom thì khoá vuốt) → **khung Ghi chú** (khi bật; cao ≤140; trống "Slide này không có ghi chú") → "{n} / {tổng}" → **dải thumbnail** (cao 64; slide hiện tại viền cam 2.5px; slide ẩn có icon mắt gạch chéo).
- Trạng thái: deck rỗng "Bản trình chiếu không có slide nào" · đối tượng không vẽ được "Không hỗ trợ" · lỗi + "Thử lại".
- Không có chế độ trình chiếu toàn màn hình.

---

## 10. CÀI ĐẶT
**Màn gốc** (tab Cài đặt, AppBar "Cài đặt") — dòng có icon + tiêu đề + phụ đề giá trị hiện tại:

| Nhóm | Dòng | Phụ đề |
|---|---|---|
| **Chung** | Ngôn ngữ | tên ngôn ngữ hoặc "Theo máy" |
| | Giao diện | Theo máy / Sáng / Tối |
| | Thư mục lưu *(ẩn trên iPhone)* | đường dẫn hiện tại |
| | Khổ giấy mặc định | A4 / Letter / Vừa khít ảnh |
| **Về ứng dụng** | Chia sẻ ứng dụng | — (mở sheet chia sẻ hệ thống với lời nhắn giới thiệu + link tải Android và iPhone) |
| | Phản hồi | — (mở app email, tiêu đề "Phản hồi về PDF Office"; lỗi "Không mở được ứng dụng email") |
| | Chính sách bảo mật | — |
| | Giới thiệu | "Phiên bản 1.0.0" |

**Màn con:**
- **Ngôn ngữ:** danh sách chọn 1 (✓ đỏ): Theo máy · Tiếng Việt · English · 中文 · 日本語 · 한국어 · Bahasa Indonesia (tên bản địa). Đổi có hiệu lực ngay.
- **Giao diện:** chọn 1: Theo máy · Sáng · Tối. (Không có chọn màu chủ đề.)
- **Thư mục lưu:** thẻ hiện đường dẫn (mặc định "Documents/PDF Office") · nút đặc "Chọn thư mục" · nút viền "Dùng thư mục mặc định" (vô hiệu khi đang dùng mặc định) · lỗi "Không ghi được vào thư mục này. Hãy chọn thư mục khác."
- **Khổ giấy mặc định:** chọn 1: A4 · Letter · Vừa khít ảnh (mặc định A4) — áp cho Ảnh sang PDF, Tạo PDF trắng, các chuyển đổi sang PDF.
- **Giới thiệu:** logo 96 · "PDF Office" · "Phiên bản 1.0.0" · slogan "Đọc, tạo và chuyển đổi PDF, Office và ảnh." · 2 đoạn (hoạt động offline, không thu thập dữ liệu; dùng Syncfusion Community) · nút viền "Giấy phép mã nguồn mở".
- **Chính sách bảo mật:** một trang chữ tĩnh (offline, không thu thập/gửi/chia sẻ dữ liệu; tệp mới lưu vào thư mục người dùng chọn, tệp gốc không bị ghi đè; không quảng cáo, không mua trong app).

---

## 11. Tích hợp hệ thống
- **Lối tắt PDF trên màn hình chính** (Android 8+): từ ⋮ trong trình đọc → "Thêm vào màn hình chính"; nhãn ≤24 ký tự, icon = icon app; bấm = mở thẳng trình đọc. Ẩn nếu launcher không hỗ trợ.
- **Chia sẻ file** từ app ra ngoài: mọi nơi có nút "Chia sẻ" dùng sheet chia sẻ hệ thống.
- **Mở file / nhận file từ app khác:** đã khai báo (PDF, Office, TXT, ảnh) nhưng **chưa hoạt động** (xem mục 0).
- **Splash:** nền trống. **Onboarding:** không có.

---

## 12. Gợi ý yêu cầu thiết kế
1. **Phủ đủ** mọi màn ở mục 1 (bản đồ) cho cả **sáng và tối**; ưu tiên làm trước: Trang chủ, Tập tin, Công cụ, Ảnh sang PDF (3 bước), Trình đọc PDF, Cài đặt, rồi các công cụ.
2. **Bộ thành phần dùng chung** (mục 2) làm thành thư viện — nhiều màn công cụ cùng khuôn: *chọn file → tuỳ chọn → nút chính → kết quả*.
3. Nhất quán: **nút chính** (hiện lẫn IN HOA và chữ thường), **từ "tệp" / "file"** (đang lẫn), **cách báo kết quả** (Quét dùng snackbar, Chuyển đổi dùng thẻ trong màn, Công cụ PDF/Ảnh sang PDF dùng màn kết quả) — nên chọn một kiểu.
4. Chữ dài: tên file tiếng Việt dài, nhãn tiếng Đức/Indonesia dài — mọi nhãn cần quy tắc cắt/xuống dòng.
5. Vùng chạm tối thiểu 48dp; tương phản đủ trên cả 2 theme; tab/AppBar theo màu loại file phải đọc được.
6. Màn hình nhỏ (360dp) và máy 32-bit yếu: tránh hiệu ứng nặng (blur lớn, animation liên tục) ở danh sách file và trình xem.
7. Nên giao: bảng màu + chữ + icon + bo góc; bộ thành phần; mockup các màn chính (sáng/tối); luồng Ảnh sang PDF end-to-end; các trạng thái trống/lỗi/thiếu quyền.

---

*Nguồn: wiki dự án (`lmm-wiki/`) và đọc code các màn (`app/lib/features/**`, `app/lib/core/**`), bản dịch tiếng Việt `*_vi.arb`. Cập nhật 30/10/2026.*
