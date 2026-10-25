# <Tên tính năng>

> Nguồn: `<đường/dẫn/entry-point.py:42>` · Commit: `<short-sha>` · Cập nhật: <YYYY-MM-DD>

Quy ước đánh dấu: không có nhãn = đã đọc code và xác nhận, có trích dẫn
`file:line`. `[suy luận]` = suy ra chứ chưa xác nhận trực tiếp.
`[chưa rõ]` = chưa xác định được, xem mục Câu hỏi mở.

## Tóm tắt

Hai đến ba câu: tính năng này làm gì, ai/cái gì kích hoạt nó, kết quả là gì.
Viết cho người chưa biết hệ thống — tránh tên class, nói bằng ngôn ngữ nghiệp vụ.

## Điểm vào

| Loại | Định danh | Vị trí |
|---|---|---|
| HTTP / CLI / queue / cron | `POST /api/...` | `path/to/file.py:42` |

## Luồng chính

Đánh số từng bước, mỗi bước kèm vị trí code. Bước nào rẽ nhánh thì ghi rõ điều
kiện rồi trỏ xuống mục Rẽ nhánh.

1. Nhận request tại `handler.py:42` — parse payload thành `<DTO>`.
2. Validate (xem mục dưới) — `validators.py:18`.
3. ...
4. Ghi xuống `<bảng>` tại `repository.py:77`.
5. Trả về `<shape>` — `handler.py:96`.

## Validate và các trường hợp từ chối

Ghi theo **đúng thứ tự thực thi** — kiểm tra chạy trước sẽ che các kiểm tra sau,
đây là chỗ người sửa code hay hiểu nhầm.

| # | Kiểm tra gì | Điều kiện | Trả về khi hỏng | Vị trí |
|---|---|---|---|---|
| 1 | | | | |

## Rẽ nhánh

| Điều kiện | Nhánh đúng | Nhánh sai | Vị trí |
|---|---|---|---|
| | | | |

Nhánh có vẻ không bao giờ chạy tới thì ghi vào đây kèm lý do — hoặc là mình đọc
sai điều kiện, hoặc là dead code, cả hai đều đáng nói ra.

## Vòng lặp và retry

Với mỗi vòng lặp/retry: cái gì giới hạn nó, chạm giới hạn thì sao, có sleep hay
backoff không, chạy hai lần có an toàn không (idempotent).

## Ngưỡng và config

Cột "đổi thì sao" mới là cột đáng giá — nó cho người đọc biết có dám sửa không.

| Tên | Giá trị hiện tại | Khai báo ở | Đọc ở | Đổi thì sao |
|---|---|---|---|---|
| | | | | |

Kể cả magic number viết cứng trong code — loại này càng quan trọng vì không ai
biết nó tồn tại. Hằng số khai báo mà không nơi nào đọc cũng ghi vào đây, đánh
dấu rõ là dead config.

## Đường lỗi

| Lỗi gì | Bắt ở đâu | Xử lý thế nào | Người dùng thấy gì |
|---|---|---|---|
| | | | |

Chỗ nào nuốt exception (catch rồi bỏ qua, hoặc chỉ log) thì nêu riêng — đó là
cách hệ thống hỏng âm thầm.

## Quy tắc nghiệp vụ

Viết bằng ngôn ngữ nghiệp vụ, không phải ngôn ngữ code. Đây là phần chưa từng
được ghi ở đâu khác, và là lý do tài liệu này đáng đọc.

- Quy tắc — `file.py:120`
- ...

## Dữ liệu chạm tới

| Bảng / collection | Đọc | Ghi | Ghi chú |
|---|---|---|---|
| | | | |

## Phụ thuộc bên ngoài

API, hàng đợi, service khác, cronjob. Ghi cả chuyện gì xảy ra khi chúng chết.

## Liên quan

- [<tính-năng-khác>](<ten-file>.md)
- [Data model](../data-model.md)

## Câu hỏi mở

Những chỗ chưa xác định được. Đây là mục có giá trị thật — nó chỉ đúng vào phần
tri thức đã mất, thay vì giả vờ là đã hiểu hết.

- [chưa rõ] ...
