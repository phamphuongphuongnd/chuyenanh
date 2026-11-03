# Bản soạn Google Play Console — Phiotron PDF

- **Package:** `com.phiotron.phiotronpdf` (đổi 03/11/2026 — gõ đúng chữ thường vào ô "Tên gói" khi tạo app) · bản đầu `1.0.0 (1)` · minSdk 24 (Android 7) · targetSdk 36
- **Nhà phát triển:** Phạm Phương (Phiotron), tài khoản cá nhân
- **Mô hình:** miễn phí, không quảng cáo, không mua trong ứng dụng, không tài khoản
- **Ngôn ngữ listing:** mặc định **Tiếng Việt (vi-VN)**, thêm bản dịch **English (United States) (en-US)**.
  Giao diện app chỉ có tiếng Việt và tiếng Anh, nên không thêm listing ngôn ngữ khác.

Nguồn đã đối chiếu: `public-site/privacy.md` (chính sách đang công khai), `public-site/index.md` (trang hỗ trợ),
`docs/store/google-play-all-files-access.md`, `lmm-wiki/decisions/0005-len-store-mien-phi.md`,
`lmm-wiki/modules/tinh-nang-offline.md`, manifest release đã gộp (`app/build/app/intermediates/merged_manifests/release/…`,
bản build 03/11) và `app/lib/core/tools/tool_registry.dart`.

Ký hiệu: **(cần bạn xác nhận)** = câu trả lời chưa chắc, cần chủ dự án quyết hoặc xem lại trên Console.

---

## 1. Store listing (Main store listing / Bố cục trang thông tin)

### 1.1 Thông tin liên hệ & danh mục (Store settings)

| Mục trên Console | Điền |
|---|---|
| App category → **Category** | **Productivity** (Năng suất). Phương án khác: *Tools* (Công cụ). App là trình đọc/quản lý tài liệu nên Productivity hợp nhất. |
| **Tags** (tối đa 5, chọn từ danh sách Google đưa ra) | Gợi ý: *Document editor*, *PDF*, *Document scanner*, *Office*, *File manager* — tên tag đúng trên danh sách **(cần bạn xác nhận)**, chỉ chọn tag thật sự khớp. |
| Contact details → **Email** | `phamphuongphuongnd@gmail.com` |
| Contact details → **Website** | `https://phamphuongphuongnd.github.io/phiotron-pdf/` |
| Contact details → Phone | Để trống (không bắt buộc). |
| **Privacy policy** (ở App content) | `https://phamphuongphuongnd.github.io/phiotron-pdf/privacy` |

### 1.2 Tên ứng dụng (App name, ≤ 30 ký tự)

Dùng cùng tên ở cả hai ngôn ngữ, khớp tên hiện trong app (không thêm "free", "best", "no ads", "#1", không thêm
từ khoá):

```text
Phiotron PDF
```

→ **12 / 30 ký tự** (vi và en giống nhau).

### 1.3 Mô tả ngắn (Short description, ≤ 80 ký tự)

Luật Google cho mô tả ngắn: không emoji, không chữ in hoa để nhấn mạnh, không "Free/Best/#1/New", không kêu gọi
"tải ngay", chỉ dùng dấu chấm khi có nhiều câu.

**Tiếng Việt**

```text
Đọc, quét, chuyển đổi và chỉnh sửa PDF, Word, Excel ngay trên điện thoại
```

→ **72 / 80 ký tự** (dạng NFC — chép từ file này là NFC; nếu gõ lại bằng bộ gõ tách dấu thì có thể vượt 80)

**English**

```text
Read, scan, convert and edit PDF, Word and Excel files right on your phone
```

→ **74 / 80 ký tự**

### 1.4 Mô tả đầy đủ (Full description, ≤ 4000 ký tự)

Viết thật, không nhồi từ khoá, không emoji (chỉ dùng dấu "•" làm gạch đầu dòng). Nêu rõ app là **trình quản lý
tài liệu quét cả máy** — khớp với tờ khai All files access.

**Tiếng Việt**

```text
Phiotron PDF giúp bạn đọc, tạo, chuyển đổi và chỉnh sửa tài liệu PDF và Office ngay trên điện thoại. Tệp được xử lý trên máy của bạn và không bị tải lên mạng.

QUẢN LÝ TÀI LIỆU
• Tìm và liệt kê các tệp PDF, Word (DOC, DOCX), Excel (XLS, XLSX), PowerPoint (PPT, PPTX) và TXT có trên máy, chia theo loại
• Tìm theo tên hoặc theo nội dung bên trong tệp, sắp xếp, đánh dấu yêu thích, xem tệp gần đây
• Đổi tên, xoá, chia sẻ tệp; mở tệp được gửi từ ứng dụng khác bằng "Mở bằng" hoặc "Chia sẻ"

ĐỌC TÀI LIỆU
• Đọc PDF, Word, Excel, PowerPoint và tệp văn bản
• Chế độ dàn chữ: hiển thị lại chữ trong PDF cho dễ đọc trên màn hình nhỏ
• Đọc to bằng giọng đọc có sẵn trên máy
• Dịch giữa tiếng Việt và tiếng Anh ngay trên máy, sau khi tải gói ngôn ngữ một lần. Đây là bản dịch máy, hãy kiểm tra lại nội dung quan trọng

TẠO PDF VÀ QUÉT
• Ảnh sang PDF, văn bản sang PDF, tạo PDF trắng
• Quét tài liệu bằng máy ảnh, nhận dạng chữ (OCR) cho chữ cái Latin
• Quét thẻ 2 mặt: ghép mặt trước và mặt sau của thẻ (ví dụ thẻ căn cước) lên một trang PDF hoặc JPG
• Quét mã QR và mã vạch từ ảnh chụp hoặc ảnh có sẵn

CÔNG CỤ PDF
• Gộp, tách, sắp xếp lại trang
• Chèn trang trắng, ảnh hoặc trang từ PDF khác
• Khoá PDF bằng mật khẩu, mở khoá PDF
• Thêm hình mờ, đánh số trang
• Nén PDF, có mức nén giữ lại chữ chọn được và liên kết

CHỈNH SỬA PDF
• Chú thích: tô sáng, gạch chân, gạch ngang, ghi chú
• Ký PDF bằng chữ ký vẽ tay hoặc lấy từ ảnh chụp chữ ký
• Điền biểu mẫu PDF

CHUYỂN ĐỔI
• Word, Excel, PowerPoint sang PDF
• PDF sang Word, Excel, PowerPoint, ảnh hoặc văn bản

RIÊNG TƯ
• Không cần tài khoản, không cần đăng nhập
• Tệp PDF, Office và ảnh của bạn được xử lý ngay trên máy, không tải lên máy chủ
• Chỉ cần Internet khi bạn chọn tải gói ngôn ngữ dịch. Thành phần Google ML Kit trong ứng dụng có thể gửi dữ liệu chẩn đoán cho Google, không kèm nội dung tệp hay chữ của bạn. Chi tiết trong chính sách bảo mật
• Khoá ứng dụng bằng vân tay, khuôn mặt hoặc mã PIN của máy (tuỳ chọn)
• Không quảng cáo, không mua trong ứng dụng

VỀ QUYỀN TRUY CẬP
Trên Android 11 trở lên, ứng dụng xin quyền "Truy cập tất cả file" để tìm và hiển thị tài liệu trên máy ở tab Tập tin. Nếu từ chối, bạn vẫn có thể chọn từng tệp để mở. Máy ảnh chỉ được dùng khi bạn quét hoặc chụp.

Ứng dụng có giao diện tiếng Việt và tiếng Anh. Góp ý và báo lỗi: phamphuongphuongnd@gmail.com

Microsoft Word, Excel và PowerPoint là nhãn hiệu của Microsoft Corporation. Phiotron PDF không liên kết với Microsoft.
```

→ **2460 / 4000 ký tự** (đếm theo ký tự Unicode dạng NFC, gồm cả xuống dòng)

**English**

```text
Phiotron PDF lets you read, create, convert and edit PDF and Office documents right on your phone. Your files are processed on your device and are never uploaded.

DOCUMENT MANAGER
• Finds and lists the PDF, Word (DOC, DOCX), Excel (XLS, XLSX), PowerPoint (PPT, PPTX) and TXT files on your device, grouped by type
• Search by file name or by the text inside your files, sort, mark favorites and see recent files
• Rename, delete and share files; open files sent from other apps with "Open with" or "Share"

READ
• Read PDF, Word, Excel, PowerPoint and text files
• Reflow mode: shows the text of a PDF in a layout that is easy to read on a small screen
• Read aloud with the voices installed on your device
• Translate between Vietnamese and English on the device, after a one-time language pack download. This is machine translation, so please double-check important content

CREATE PDF AND SCAN
• Image to PDF, text to PDF, blank PDF
• Scan documents with the camera and recognize text (OCR) in Latin script
• ID card, two sides: place the front and back of a card (for example a national ID card) on one PDF or JPG page
• Scan QR codes and barcodes from a photo you take or pick

PDF TOOLS
• Merge, split and reorder pages
• Insert blank pages, images or pages from another PDF
• Lock a PDF with a password, unlock a PDF
• Add a watermark, add page numbers
• Compress PDF, with levels that keep selectable text and links

EDIT PDF
• Annotate: highlight, underline, strikethrough, sticky notes
• Sign a PDF with a hand-drawn signature or one taken from a photo of your signature
• Fill in PDF forms

CONVERT
• Word, Excel, PowerPoint to PDF
• PDF to Word, Excel, PowerPoint, image or text

PRIVACY
• No account, no sign-in
• Your PDF, Office files and images are processed on your device and are not uploaded to any server
• Internet is needed only when you choose to download a translation language pack. The Google ML Kit component in the app may send diagnostic data to Google, without the content of your files or text. See the privacy policy for details
• Optional app lock with your device fingerprint, face or PIN
• No ads, no in-app purchases

ABOUT PERMISSIONS
On Android 11 and later, the app asks for "All files access" to find and show the documents on your device in the Files tab. If you decline, you can still pick files one by one. The camera is used only when you scan or take a photo.

The app is available in Vietnamese and English. Feedback and bug reports: phamphuongphuongnd@gmail.com

Microsoft Word, Excel and PowerPoint are trademarks of Microsoft Corporation. Phiotron PDF is not affiliated with Microsoft.
```

→ **2641 / 4000 ký tự** (gồm cả xuống dòng)

> Ghi chú:
> - Câu "Không quảng cáo, không mua trong ứng dụng" chỉ để ở mô tả đầy đủ (mô tả sự thật), **không** đưa vào tên,
>   mô tả ngắn, icon hay ảnh bìa — Google cấm chữ kiểu giá/khuyến mãi ở các chỗ đó.
> - Dòng nhãn hiệu Microsoft là để tránh bị hiểu là app chính chủ (chính sách mạo danh / sở hữu trí tuệ).
> - Nếu sau này thêm tính năng cần mạng, phải sửa đoạn RIÊNG TƯ, chính sách bảo mật và Data safety cùng lúc.

### 1.5 Ghi chú phát hành (Release notes) bản 1.0.0 — tuỳ chọn

```text
<vi-VN>
Bản phát hành đầu tiên trên Google Play.
</vi-VN>
<en-US>
First release on Google Play.
</en-US>
```

---

## 2. App content (Nội dung ứng dụng)

Đường dẫn: **Play Console → chọn app → Policy and programs → App content**. Thứ tự dưới đây theo các thẻ trên trang.

### 2.1 Privacy policy

- **Privacy policy URL:** `https://phamphuongphuongnd.github.io/phiotron-pdf/privacy`
- Trang phải mở được công khai, không cần đăng nhập, không phải PDF tải về. Đã có cả tiếng Việt lẫn tiếng Anh.
- Trong app (Cài đặt) cũng có link tới trang này (`kPrivacyPolicyUrl`) — Google yêu cầu có cả trong app.

### 2.2 App access

- Chọn: **All functionality in my app is available without any access restrictions**.
- Lý do: không có tài khoản/đăng nhập/mã mời. Quyền "Truy cập tất cả file" và Khoá ứng dụng không phải giới hạn truy
  cập theo nghĩa của mục này (người duyệt tự cấp quyền được; Khoá ứng dụng mặc định tắt).

### 2.3 Ads

- **Does your app contain ads?** → **No, my app does not contain ads**.

### 2.4 Advertising ID (nếu Console hỏi trong App content)

- **Does your app use advertising ID?** → **No**.
- Đã kiểm manifest release gộp (build 03/11): **không có** quyền `com.google.android.gms.permission.AD_ID`. Trước mỗi
  lần nộp AAB mới nên kiểm lại manifest gộp, vì thư viện mới có thể tự thêm quyền này.

### 2.5 Content rating (Phân loại nội dung, bảng hỏi IARC)

- **Email liên hệ:** `phamphuongphuongnd@gmail.com`
- **Category:** **All Other App Types** (nhóm "Utility, Productivity, Communication, or Other" — app tiện ích/văn
  phòng). Không chọn Game, không chọn Social/Communication.
- Gợi ý trả lời (tên câu có thể khác chút trên Console):

| Câu hỏi | Trả lời | Ghi chú |
|---|---|---|
| Violence / bạo lực, máu | No | |
| Fear / nội dung gây sợ | No | |
| Sexuality / nudity | No | |
| Language / ngôn từ thô tục | No | |
| Controlled substances (ma tuý, rượu, thuốc lá) | No | |
| Crude humor | No | |
| Gambling / simulated gambling | No | |
| Does the app allow users to interact or exchange content with other users? | **No** | App không có chat, bình luận, đăng bài hay chia sẻ giữa người dùng. Nút "Chia sẻ" chỉ mở bảng chia sẻ của hệ thống để gửi tệp qua ứng dụng khác — người dùng tự gửi, không phải tính năng trao đổi trong app. Tệp người dùng mở là tài liệu của chính họ, không phải UGC công khai. |
| Does the app share the user's current physical location with other users? | No | Không dùng vị trí. |
| Does the app allow users to purchase digital goods? | No | Không mua trong app. |
| Is the app a web browser or search engine? / unrestricted internet access | No | Mã QR chứa link chỉ mở bằng trình duyệt ngoài sau khi người dùng bấm (qua `url_safety.dart`); app không có trình duyệt riêng. |
| Swastikas / Nazi symbols, other miscellaneous | No | |

- Kết quả dự kiến: **Everyone / PEGI 3 / IARC 3+** (hoặc tương đương mỗi vùng).

### 2.6 Target audience and content (Đối tượng mục tiêu)

- **Target age groups:** khuyên chọn **chỉ "18 and over"**.
  - Lý do: app là công cụ văn phòng; có tính năng **quét thẻ căn cước 2 mặt** (giấy tờ tuỳ thân) và khoá PDF —
    đối tượng thực tế là người lớn. Chỉ chọn 18+ thì không phải đáp ứng thêm yêu cầu cho nhóm thiếu niên và không
    dính chính sách Gia đình (Families).
  - Phương án khác (hợp lệ): chọn **13–15, 16–17, 18+** nếu muốn học sinh dùng. Vẫn hợp với chính sách bảo mật
    ("không hướng tới trẻ em dưới 13 tuổi"). **Tuyệt đối không chọn nhóm dưới 13** — sẽ bị áp chính sách Families
    (ML Kit gửi mã định danh theo lượt cài đặt, phải dùng SDK được chứng nhận cho trẻ em…). **(cần bạn xác nhận
    chọn 18+ hay 13+)**
- **Could your store listing unintentionally appeal to children?** → **No** (không có nhân vật hoạt hình, màu sắc
  hay ngôn từ hướng tới trẻ em). Ảnh store cũng không nên có hình hoạt hình.

### 2.7 News apps

- **Is your app a news app?** → **No**.

### 2.8 Health apps / Health features

- Chọn **My app does not have any health features** (không có tính năng sức khoẻ).

### 2.9 Financial features

- Chọn **My app doesn't provide any financial features** (không ngân hàng, cho vay, ví, tiền ảo…).

### 2.10 Government apps

- **Is your app developed by or on behalf of a government?** → **No**.

### 2.11 Foreground service permissions

- **Không áp dụng:** manifest release gộp không có `FOREGROUND_SERVICE` và không có `<service>` nào khai
  `foregroundServiceType`. Các service có trong manifest đều của thư viện Google (ML Kit component discovery,
  datatransport `JobInfoSchedulerService`, `ModuleDependencies` đang tắt) — không phải dịch vụ chạy nền hiển thị.
  Nếu Console không hiện thẻ này thì bỏ qua.

### 2.12 Photo and video permissions

- **Không áp dụng:** app không xin `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`; ảnh chọn qua Photo Picker của hệ thống.

### 2.13 All files access (`MANAGE_EXTERNAL_STORAGE`)

- Câu trả lời soạn sẵn, video minh hoạ và điều kiện kiểm trước khi nộp: xem
  **[google-play-all-files-access.md](google-play-all-files-access.md)** (không chép lại ở đây).

### 2.14 Data safety (An toàn dữ liệu) — đi từng bước

#### Cách Google định nghĩa (đã đọc trang chính thức)

- **"Collect"** = dữ liệu **được truyền ra khỏi thiết bị** của người dùng, kể cả do **thư viện/SDK** trong app gửi
  (gửi cho bạn hay cho bên thứ ba đều tính).
- **"Share"** = chuyển dữ liệu đã thu cho **bên thứ ba**. Không tính là "share": nhà cung cấp dịch vụ xử lý thay bạn,
  hành động do người dùng tự khởi xướng mà họ hiểu rõ (ví dụ tự bấm Chia sẻ tệp), mục đích pháp lý, dữ liệu ẩn danh hoàn toàn.
- **Xử lý chỉ trên máy** (không bao giờ rời thiết bị) → **không phải khai** là collected.
- **Ephemeral** = chỉ giữ trong bộ nhớ, không lâu hơn mức cần để phục vụ một yêu cầu tức thời.
- **Optional** chỉ khi **mọi người dùng** đều có thể chọn không cung cấp / tắt việc thu; dữ liệu SDK tự thu khi dùng
  tính năng thì thường là **required**.
- Bạn chịu trách nhiệm khai cả dữ liệu do SDK thu.

Nguồn:
- Google Play Help — Data safety: <https://support.google.com/googleplay/android-developer/answer/10787469>
- ML Kit Android data disclosure: <https://developers.google.com/ml-kit/android-data-disclosure>
- Firebase (Installations, Remote Config) data disclosure: <https://firebase.google.com/docs/android/play-data-disclosure>

#### Dữ liệu thật sự rời khỏi máy (căn cứ cho câu trả lời)

| Nguồn | Gửi gì | Có phải khai? |
|---|---|---|
| Tệp PDF/Office/ảnh, ảnh chụp/quét, ảnh thẻ ID, chỉ mục tìm kiếm, gần đây/yêu thích, cài đặt, ảnh chữ ký | **Không gửi đi** — xử lý và lưu trên máy | Không (on-device). |
| OCR, mã QR/mã vạch, Dịch (ML Kit **bản đóng gói sẵn**: `text-recognition`, `barcode-scanning`, `translate`) | Thông tin thiết bị (hãng, model, phiên bản OS, bộ tăng tốc ML), tên gói + phiên bản app, **mã định danh theo lượt cài đặt**, số đo hiệu năng (độ trễ), cấu hình API, kích thước đầu vào/ra, phiên bản tính năng, loại sự kiện (khởi tạo, tải model, nhận dạng, giải phóng), mã lỗi; riêng Dịch: cặp ngôn ngữ đã cấu hình. Mục đích theo Google: **diagnostics and usage analytics**. Mã hoá HTTPS, Google **không chuyển cho bên thứ ba**. | **Có** (SDK gửi ra khỏi máy). |
| Dịch → **Firebase Installations** + **Firebase Remote Config** (ML Kit dùng để "remote configuration diagnostics") | Firebase installation ID (FID), user agent Firebase; Remote Config: mã quốc gia, mã ngôn ngữ, múi giờ, phiên bản nền tảng/OS, Firebase App ID, tên gói, phiên bản SDK | **Có** — FID thuộc nhóm *Device or other IDs* (Google lấy chính FID làm ví dụ). |
| Quét tài liệu: **ML Kit Document Scanner** qua Google Play services (`play-services-mlkit-document-scanner`, loại "thin") | Như hàng ML Kit trên, cộng **mã định danh thiết bị** (Google ghi: tính năng thin thu device identifier + per-installation identifiers). Ảnh quét không rời máy. | **Có** (gộp chung vào các nhóm dưới). |
| Tải gói ngôn ngữ dịch từ máy chủ Google | Địa chỉ IP và thông tin kỹ thuật của yêu cầu tải | Không khai riêng một loại dữ liệu (không dùng IP để định vị). Đã nêu trong chính sách bảo mật. |
| Đọc to | Do **bộ đọc của hệ thống** (ứng dụng riêng, ví dụ Google TTS) xử lý; app chỉ dùng giọng đã cài, bỏ giọng cần mạng | Không (không phải SDK trong app). |
| Khoá ứng dụng (vân tay/khuôn mặt/PIN) | App chỉ nhận "thành công/thất bại" từ hệ điều hành | Không. |
| Nút Phản hồi | Mở **ứng dụng email của người dùng**; email do người dùng tự gửi, app không truyền gì | Không khai là dữ liệu app thu **(cần bạn xác nhận)** — người dùng tự gửi ngoài app, giống liên hệ qua email trên trang hỗ trợ. |
| Chia sẻ tệp ra app khác | Do người dùng tự bấm, qua bảng chia sẻ của hệ thống | Không (user-initiated). |

#### Bước "Data collection and security"

| Câu hỏi trên Console | Trả lời | Ghi chú tiếng Việt |
|---|---|---|
| **Does your app collect or share any of the required user data types?** | **Yes** | Vì SDK Google ML Kit (và Firebase Installations/Remote Config đi kèm Dịch) gửi dữ liệu chẩn đoán ra khỏi máy. Trả lời "No" là **sai** và mâu thuẫn với mục 4 của chính sách bảo mật. |
| **Is all of the user data collected by your app encrypted in transit?** | **Yes** | ML Kit và Firebase ghi rõ mã hoá HTTPS; gói ngôn ngữ tải qua kết nối mã hoá. App không có kết nối mạng nào khác. |
| **Which of the following methods of account creation does your app support?** | **My app does not allow users to create an account** | Không tài khoản, không đăng nhập ⇒ không cần "Delete account URL". (Tên lựa chọn chính xác **(cần bạn xác nhận)** trên Console.) |
| **Do you provide a way for users to request that their data is deleted?** (bản mới: "…some or all of their data is deleted, without requiring them to delete their account") | Khuyên **No** **(cần bạn xác nhận)** | Dữ liệu đã khai là do Google ML Kit/Firebase giữ, nhà phát triển **không có công cụ để xoá** cho từng người. Trả lời "Yes" mà không xoá được là khai sai. Dữ liệu trong app thì người dùng tự xoá bằng cách gỡ app (chính sách mục 6), nhưng dữ liệu đó không rời máy nên không thuộc phạm vi câu này. |

#### Bước "Data types" — chọn những loại sau

| Nhóm → Loại dữ liệu | Chọn? | Vì sao |
|---|---|---|
| **App info and performance → Diagnostics** | **Có** (chắc chắn) | Độ trễ, số đo hiệu năng, mã lỗi, phiên bản tính năng, thông tin thiết bị dùng để chẩn đoán — đúng định nghĩa "Diagnostics" của Google. |
| **App info and performance → Other app performance data** | **Có** (khuyên chọn) | Cấu hình API (định dạng/độ phân giải ảnh), kích thước đầu vào/ra, cặp ngôn ngữ dịch, dữ liệu Remote Config — không nằm gọn trong "Diagnostics". Khai dư an toàn hơn khai thiếu. |
| **Device or other IDs** | **Có** (chắc chắn) | Mã định danh theo lượt cài đặt của ML Kit, Firebase installation ID, mã định danh thiết bị của Document Scanner qua Play services. |
| **App activity → App interactions** | **Có** (khuyên chọn, thận trọng) **(cần bạn xác nhận)** | ML Kit gửi "loại sự kiện" (khởi tạo, tải model, nhận dạng…) cho "usage analytics" — tức là thống kê việc người dùng dùng tính năng. Chính sách bảo mật đã nêu "thống kê sử dụng" + "loại sự kiện" nên khai mục này vẫn khớp. Nếu bỏ, Data safety chỉ còn 2 nhóm, nhưng có rủi ro bị cho là khai thiếu. |
| App info and performance → Crash logs | Không | ML Kit chỉ gửi mã lỗi, không gửi stack trace/crash; app không có SDK báo lỗi. |
| Location (Approximate / Precise) | Không | App không xin quyền vị trí. Mã quốc gia/múi giờ của Remote Config lấy từ cài đặt máy, không phải vị trí; IP khi tải gói không dùng để định vị **(cần bạn xác nhận)**. |
| Personal info (Name, Email, User IDs, Address, Phone, …) | Không | Không tài khoản; email phản hồi do người dùng tự gửi qua app email (xem bảng trên). |
| Financial info, Health and fitness, Messages, Calendar, Contacts, Web browsing | Không | Không dùng. |
| **Photos and videos** | **Không** | Ảnh chụp/quét/ảnh thẻ ID chỉ xử lý trên máy, ảnh tạm bị xoá; Document Scanner trả ảnh thẳng cho app, không gửi đi. |
| **Files and docs** | **Không** | Tệp chỉ đọc/ghi trên máy, không tải lên. (Quyền All files access ≠ thu thập.) |
| Audio files | Không | Đọc to phát âm thanh, không ghi âm, không gửi đi. |
| App activity → In-app search history, Installed apps, Other user-generated content, Other actions | Không | Lịch sử/chỉ mục tìm kiếm chỉ lưu cục bộ. |

#### Bước "Data usage and handling" — trả lời giống nhau cho cả 4 loại đã chọn

| Câu hỏi | Trả lời | Ghi chú |
|---|---|---|
| **Is this data collected, shared, or both?** | **Collected** (bỏ tick **Shared**) | Google ML Kit/Firebase là SDK gửi dữ liệu về Google và Google tuyên bố **không chuyển cho bên thứ ba** ⇒ "collected", không "shared". |
| **Is this data processed ephemerally?** | **No** | Google lưu để chẩn đoán/thống kê, không chỉ giữ trong bộ nhớ cho một yêu cầu tức thời. |
| **Is this data required for your app, or can users choose whether it's collected?** | **Data collection is required (users can't turn off this data collection)** | App không có công tắc tắt việc ML Kit gửi dữ liệu. Người dùng chỉ "tránh" được bằng cách không dùng OCR/QR/Dịch/Quét, nhưng Google chỉ cho chọn "optional" khi mọi người dùng đều tắt/bỏ qua được. |
| **Why is this user data collected?** | **Analytics** | Định nghĩa của Google: "hiểu cách dùng/hiệu năng, theo dõi tình trạng, chẩn đoán lỗi" — đúng mục đích "diagnostics and usage analytics" của ML Kit. |
|  | Riêng **Device or other IDs**: có thể tick thêm **App functionality** **(cần bạn xác nhận)** | Firebase Installations/Remote Config phục vụ cấu hình từ xa cho tính năng Dịch. Khai thêm mục đích không làm sai; không tick cũng chấp nhận được vì ML Kit ghi mục đích là chẩn đoán. |
|  | **Không** tick: Advertising or marketing, Personalization, Account management, Developer communications, Fraud prevention… | Không có quảng cáo, cá nhân hoá, tài khoản. |

#### Data safety sẽ hiện trên trang store (dự kiến)

- **No data shared with third parties**
- **This app may collect these data types:** App activity, App info and performance, Device or other IDs
  (nếu bỏ App interactions thì chỉ còn App info and performance, Device or other IDs)
- **Data is encrypted in transit**
- Dòng về xoá dữ liệu: theo câu trả lời "No" ở trên, trang store sẽ không có dòng "You can request that data be
  deleted" (cách hiển thị chính xác **(cần bạn xác nhận)** ở bản xem trước của Console).

#### Kiểm tra chéo với chính sách bảo mật

| Câu Data safety | Chỗ tương ứng trong `privacy.md` | Khớp? |
|---|---|---|
| Collected: thiết bị, app, ID theo lượt cài đặt / thiết bị, hiệu năng, sự kiện, lỗi, cặp ngôn ngữ | Mục 4 "Google ML Kit (chạy trên thiết bị)" liệt kê đủ | Khớp |
| Not shared | Mục 4: "không được chuyển cho bên thứ ba" | Khớp |
| Encrypted in transit | Mục 4 (HTTPS) + mục 7 | Khớp |
| Photos, Files and docs không collected | Mục 1, 2, 3: xử lý trên máy, không tải lên | Khớp |
| Purpose: Analytics | Mục 4: "chẩn đoán và thống kê sử dụng" | Khớp |
| Không có tài khoản | Mục 1 | Khớp |
| Mã quốc gia/ngôn ngữ/múi giờ (Remote Config) | Mục 4 chỉ nói "Dịch cũng dùng Firebase Remote Config và Firebase Installations", không liệt kê từng trường | Chấp nhận được (có nêu SDK), nhưng xem đề xuất ở cuối tài liệu |
| "Collected = Yes" | Mục 1: "chúng tôi **không thu thập**… dữ liệu của bạn" và "chỉ dùng Internet để tải gói ngôn ngữ" | **Lệch câu chữ** — xem mục "Điểm lệch cần sửa" ở cuối |

---

## 3. Xin quyền phát hành chính thức (Production access) — tài khoản cá nhân

Điều kiện (tài khoản cá nhân tạo sau 13/11/2023): **closed test có ≥ 12 người thử opt-in liên tục ≥ 14 ngày**, sau
đó vào **Dashboard → Apply for production**. Người rời test rồi vào lại phải tính lại 14 ngày từ đầu.
Nguồn: <https://support.google.com/googleplay/android-developer/answer/14151465>

Mẹo:
- Mời **15–20 người** (dư phòng người rời), dùng danh sách email (Google Groups hoặc danh sách email trong Console).
  Gửi họ link opt-in, nhắc **không gỡ app và không rời chương trình** trong 14 ngày.
- Nhờ họ **dùng thật**: mở PDF/Word/Excel thật của họ, quét giấy tờ, OCR, gộp/nén/ký, chuyển PDF↔Word, quét QR, thử
  tải gói Dịch, bật Khoá ứng dụng, cấp/từ chối quyền "Truy cập tất cả file". Google hỏi testers có dùng hết tính năng không.
- Thu phản hồi có dấu vết: một Google Form ngắn hoặc email về `phamphuongphuongnd@gmail.com`; ghi lại lỗi đã sửa.
- **Ra ít nhất 1–2 bản cập nhật** trong 14 ngày (sửa lỗi testers báo) — câu hỏi "thay đổi gì sau closed test" cần
  có câu trả lời cụ thể.
- Trả lời bảng hỏi ngắn gọn, cụ thể, đúng sự thật:
  - *Đối tượng:* người đi làm/sinh viên cần đọc và xử lý tài liệu trên điện thoại, ưu tiên làm việc offline.
  - *Giá trị:* xử lý tệp ngay trên máy, không tài khoản, không quảng cáo, đủ bộ công cụ PDF + Office + quét/OCR trong một app.
  - *Ước lượng lượt cài năm đầu:* chọn mức thấp, thực tế (ví dụ 0–10K) **(cần bạn xác nhận)**.
  - *Sẵn sàng phát hành:* dựa trên số lỗi crash/ANR trong Android vitals của bản test, phản hồi testers, thử trên máy thật (Galaxy A13…).
- Tờ khai All files access và Data safety nên nộp **ngay từ bản closed test**, để nếu bị từ chối thì còn thời gian sửa.

---

## 4. Checklist hình ảnh (Graphics)

File sẽ đặt ở **`docs/store/graphics/`** (phiên chính làm). Thông số theo
<https://support.google.com/googleplay/android-developer/answer/9866151>.

- [ ] **App icon:** 512 × 512 px, **PNG 32-bit (có alpha)**, ≤ 1024 KB. Không badge/chữ kiểu "Free", "#1", không
      gợi ý xếp hạng/giá. Khớp icon trong app.
- [ ] **Feature graphic (ảnh bìa):** 1024 × 500 px, **JPEG hoặc PNG 24-bit, KHÔNG alpha**. Nội dung chính tránh
      mép (có thể bị cắt); không hình điện thoại, không huy hiệu Google Play, không chữ "Free/Best/No ads".
- [ ] **Ảnh màn hình điện thoại:** **2–8 ảnh** (khuyên ≥ 4), **JPEG hoặc PNG 24-bit, không alpha**, mỗi cạnh
      **320–3840 px**, cạnh dài **≤ 2 lần** cạnh ngắn (khuyên 1080 × 1920 dọc, 9:16). Ảnh chụp nội dung thật của app,
      thanh thông báo sạch, chữ chú thích chiếm ≤ 20% ảnh, không ảnh tay cầm máy.
      Gợi ý thứ tự: Tài liệu (danh sách tệp) · Đọc PDF · Công cụ · Quét + OCR · Chuyển đổi · Ký/chú thích · Dịch/Đọc to · Khoá ứng dụng.
- [ ] **Alt text** cho ảnh bìa và từng ảnh màn hình: ≤ 140 ký tự, không mở đầu bằng "Ảnh của…" / "Image of…".
- [ ] Bộ ảnh cho **cả vi và en** (chụp app ở từng ngôn ngữ) hoặc dùng chung một bộ nếu chữ trên ảnh trung tính.
- [ ] Ảnh không dùng logo Microsoft Word/Excel/PowerPoint (nhãn hiệu của người khác); dùng icon riêng của app.
- [ ] Không bắt buộc: ảnh máy tính bảng (app chưa tối ưu tablet thì không đăng), video YouTube.

---

## Điểm lệch trong chính sách bảo mật — ĐÃ SỬA 03/11 (web + trong app, đã đẩy lên Pages)

Cả 4 điểm dưới đây đã sửa trong `public-site/privacy.md`, `public-site/index.md` và `settings_privacyBody` (vi + en).

1. **Mục 1 (vi + en) "không thu thập, không bán, không chia sẻ dữ liệu của bạn"** trong khi Data safety phải khai
   **Collected = Yes** (do SDK ML Kit). Mục 4 đã giải thích đúng, nhưng người duyệt đọc lướt mục 1 có thể thấy mâu
   thuẫn. Đề xuất đổi thành kiểu: "Chúng tôi không nhận, không bán, không chia sẻ dữ liệu của bạn; thành phần Google
   ML Kit trong app thu một số dữ liệu chẩn đoán (mục 4)".
2. **Mục 1 và mục 3 "Ứng dụng chỉ dùng Internet để tải gói ngôn ngữ dịch"** — thực tế ML Kit (và Firebase
   Installations/Remote Config, `datatransport`) cũng dùng Internet để gửi dữ liệu chẩn đoán, kể cả khi người dùng
   chỉ dùng OCR/QR/Quét (không tải gói dịch). Mục 1 có gạch đầu dòng ML Kit ngay sau, nhưng chữ "chỉ" là không đúng
   hẳn. Đề xuất: "Ứng dụng dùng Internet để tải gói ngôn ngữ dịch khi bạn chọn tải, và để các thành phần Google ML
   Kit gửi dữ liệu chẩn đoán (mục 4)". Trang hỗ trợ `index.md` (câu "Ứng dụng có tải tệp của tôi lên mạng không?")
   cũng có câu "chỉ dùng Internet…" tương tự.
3. **Firebase Remote Config** thu thêm **mã quốc gia, mã ngôn ngữ, múi giờ, phiên bản OS** — mục 4 chỉ nêu tên SDK,
   chưa liệt kê các trường này. Không bắt buộc nhưng nên thêm một dòng cho đầy đủ.
4. Ghi chú nhỏ (không phải lỗi): mục 3 "không đọc cả thư viện ảnh" vẫn đúng với cách chọn ảnh, nhưng quyền "Truy cập
   tất cả file" về kỹ thuật đọc được mọi tệp; bộ quét chỉ lấy đuôi tài liệu. Có thể thêm "bộ quét chỉ tìm tệp tài
   liệu (PDF, Word, Excel, PowerPoint, TXT)" cho rõ.

Sửa `public-site/privacy.md` thì phải chép lại sang repo `phamphuongphuongnd/phiotron-pdf` và đổi ngày hiệu lực
(xem `lmm-wiki/decisions/0005-len-store-mien-phi.md`, cập nhật 03/11).
