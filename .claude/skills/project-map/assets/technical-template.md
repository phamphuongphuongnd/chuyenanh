# <Tên dự án> — Tài liệu kỹ thuật

> Chế độ: chi tiết · Commit `<short-sha>` · <YYYY-MM-DD>
> Quyền được cấp: <kết nối DB môi trường nào / file env nào được đọc / không có>

File này viết cho người **sẽ sửa code**. Phần nghiệp vụ thuần nằm ở
[business.md](business.md).

Đánh dấu: không nhãn = đã đọc code và xác nhận, có `file:line`. `[suy luận]` =
suy ra chưa xác nhận trực tiếp. `[chưa rõ]` = chưa xác định, xem mục cuối.

## Kiến trúc

Thành phần nào, chạy ở đâu, gọi nhau thế nào. Điểm vào của hệ thống.

| Thành phần | Vai trò | Vị trí |
|---|---|---|
| | | |

## Cách chạy

Khởi động, biến môi trường bắt buộc, chạy test. Đủ để người mới dựng được máy họ.

---

## Tính năng: <Tên>

Lặp khối này cho mỗi tính năng.

### Hợp đồng giao tiếp

Mục này quyết định người khác có gọi được hệ thống không. Lúc đang đọc code nó
có vẻ hiển nhiên tới mức không đáng ghi — nhưng đó chính xác là thứ người không
có code **không thể tự suy ra**. Ghi đủ, kể cả khi thấy thừa.

| Hạng mục | Giá trị |
|---|---|
| Ngôn ngữ / framework | |
| Đường dẫn + method | `POST /api/...` |
| Dạng request | tên đúng từng field, kiểu, bắt buộc hay không |
| Dạng response thành công | shape + mã HTTP |
| Dạng response lỗi | shape + mã HTTP cho từng loại lỗi |
| Cách chọn môi trường | tên biến env, giá trị mặc định khi thiếu |
| Exception nào được retry | tên class cụ thể, không mô tả chung chung |

### Điểm vào

| Loại | Định danh | Vị trí |
|---|---|---|
| HTTP / CLI / queue / cron | `POST /api/...` | `path/to/file.py:42` |

### Luồng chính

Đánh số từng bước kèm vị trí. Bước rẽ nhánh thì ghi điều kiện rồi trỏ xuống mục
Rẽ nhánh.

1. Nhận request tại `handler.py:42` — parse payload thành `<DTO>`.
2. Validate — `validators.py:18`.
3. ...

### Validate — theo đúng thứ tự thực thi

Thứ tự quan trọng: kiểm tra chạy trước che các kiểm tra sau, nên đảo thứ tự là
đổi luôn thông báo lỗi mà client nhận được.

| # | Kiểm tra | Điều kiện | Trả về khi hỏng | Vị trí |
|---|---|---|---|---|
| 1 | | | | |

### Rẽ nhánh

| Điều kiện | Nhánh đúng | Nhánh sai | Vị trí |
|---|---|---|---|
| | | | |

Nhánh có vẻ không bao giờ tới được thì ghi kèm lý do — hoặc mình đọc sai điều
kiện, hoặc là dead code, cả hai đều đáng nói ra.

### Vòng lặp và retry

Cái gì giới hạn, chạm giới hạn thì sao, có sleep/backoff không, chạy hai lần có
an toàn không.

Khi ghi ra một dãy giá trị thay vì biểu thức sinh ra nó, **tính thật rồi mới
ghi**: `2 ** attempt` với `range(3)` là 1, 2, 4 — viết thành 0, 2, 4 vì vòng lặp
bắt đầu từ 0 là lỗi sống sót qua review, đúng vì trích dẫn bên cạnh nó chuẩn.
Ghi cả biểu thức lẫn giá trị để người đọc bắt lỗi được.

### Ngưỡng và config

Cột "đổi thì sao" là cột đáng giá nhất — nó cho người đọc biết có dám sửa không.
Ưu tiên nêu rõ ngưỡng nào **đi vào điều kiện rẽ nhánh**, vì đó là chỗ hành vi
thật sự lật.

| Tên | Giá trị | Khai báo ở | Đọc ở | Vào nhánh nào | Đổi thì sao |
|---|---|---|---|---|---|
| | | | | | |

Kể cả magic number viết cứng — loại này quan trọng hơn vì không ai biết nó tồn
tại. Hằng số khai báo mà không nơi nào đọc cũng ghi vào, đánh dấu là dead config.

### Đường lỗi

| Lỗi | Bắt ở đâu | Xử lý | Người dùng thấy |
|---|---|---|---|
| | | | |

Chỗ nuốt exception (bắt rồi bỏ qua, hoặc chỉ log) nêu riêng — đó là cách hệ thống
hỏng âm thầm.

---

## Data model

### Lược sử migration

Đọc từ cũ tới mới. Cột thêm sau, cột backfill, ràng buộc siết sau — mỗi cái
thường đánh dấu một thời điểm nghiệp vụ thay đổi.

| Migration | Thay đổi | Suy ra điều gì |
|---|---|---|
| | | |

### Bảng

| Bảng | Cột | Kiểu | Ràng buộc | Ghi chú |
|---|---|---|---|---|
| | | | | |

Quan hệ, index và chúng gợi ý gì về truy vấn nóng. Ràng buộc `UNIQUE`/`CHECK` là
quy tắc nghiệp vụ do database áp — ghi cả sang [business.md](business.md).

### Quan sát từ dữ liệu thật

Chỉ điền khi được cấp quyền kết nối. Tách riêng khỏi phần trên vì đây là tính
chất của **một lát cắt dữ liệu**, không phải của hệ thống — reset database là
mất.

| Quan sát | Truy vấn dùng | Suy ra |
|---|---|---|
| `[quan sát từ dữ liệu]` ... | | |

Dữ liệu là lịch sử, không phải luật: "chưa có bản ghi nào vượt 100" khác với
"không thể vượt 100". Không bao giờ chép credential hay dữ liệu cá nhân vào đây.

## Nợ kỹ thuật và chỗ dễ vỡ

Chỗ dễ sập khi sửa, hành vi phản trực giác, phần có vẻ đã chết.

## Câu hỏi mở

- [chưa rõ] ...
