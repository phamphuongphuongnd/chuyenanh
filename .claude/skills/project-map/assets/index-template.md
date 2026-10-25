# <Tên dự án> — Bản đồ hệ thống

> **Chế độ:** tổng quan | chi tiết · **Commit:** `<short-sha>` · <YYYY-MM-DD>
> **Quyền được cấp:** <kết nối DB môi trường nào / file env nào được đọc / không có>

Code đã đổi kể từ commit trên thì tài liệu lệch tương ứng — đối chiếu lại trước
khi tin một chi tiết. Ghi cả chế độ vì tài liệu tổng quan dễ bị nhầm là đã đầy
đủ; nếu ở chế độ tổng quan thì phần validate, rẽ nhánh, ngưỡng **chưa** được
khảo sát.

<!-- Chế độ chi tiết thì thêm hai dòng này:
- [Tài liệu kỹ thuật](technical.md) — luồng code, cấu trúc DB, config
- [Tài liệu nghiệp vụ](business.md) — quy tắc và ví dụ, cho người không đọc code
-->

Bản tổng quan chỉ trả lời "hệ thống có gì, làm gì". Cần biết từng tính năng
validate ra sao, rẽ nhánh chỗ nào, ngưỡng nào ảnh hưởng hành vi thì chạy lại với
yêu cầu **chi tiết**.

Quy ước đánh dấu: không nhãn = đã xác nhận trong code, có trích dẫn `file:line`.
`[suy luận]` = suy ra chưa xác nhận. `[chưa rõ]` = chưa xác định, xem Câu hỏi mở.

## Hệ thống này làm gì

Một đoạn ngắn: mục đích, ai dùng, giá trị mang lại. Viết cho người hoàn toàn
chưa biết dự án.

## Công nghệ

| Hạng mục | Dùng gì |
|---|---|
| Ngôn ngữ / runtime | |
| Framework | |
| Database | |
| Hàng đợi / cache | |
| Dịch vụ ngoài | |

## Chạy thế nào

Cách khởi động, biến môi trường bắt buộc, cách chạy test. Ngắn gọn — chỉ đủ để
người mới chạy được máy của họ.

## Danh mục tính năng

Tính năng = năng lực mà **người dùng hoặc hệ thống gọi** sẽ gọi tên, không phải
module hay class.

| Tính năng | Làm gì | Điểm vào | Chi tiết |
|---|---|---|---|
| <Tên> | một dòng | `POST /api/...` | [chi tiết](features/<slug>.md) |

## Bản đồ thư mục

Thư mục nào chứa gì. Chỉ liệt kê chỗ đáng quan tâm, bỏ qua phần khung sườn.

| Đường dẫn | Vai trò |
|---|---|
| | |

## Config toàn cục

Những cấu hình ảnh hưởng nhiều tính năng. Config riêng của một tính năng thì để
ở trang tính năng đó.

| Tên | Giá trị mặc định | Khai báo ở | Tác dụng |
|---|---|---|---|
| | | | |

## Điểm cần chú ý

Chỗ dễ sập, nợ kỹ thuật, hành vi phản trực giác, phần có vẻ đã chết. Người nhận
bàn giao cần biết những cái này trước khi động vào code.

- ...

## Câu hỏi mở

Chỗ chưa xác định được, kèm lý do. Một khoảng trống thành thật có ích hơn một
câu khẳng định sai — người đọc không đủ hiểu hệ thống để phát hiện mình bị dẫn sai.

- [chưa rõ] ...

## Tài liệu liên quan

- [Data model](data-model.md)
