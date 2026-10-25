# <Tên dự án> — Tài liệu nghiệp vụ

> Chế độ: chi tiết · Commit `<short-sha>` · <YYYY-MM-DD>

File này viết cho người **không đọc code**: người mới vào dự án, người làm
nghiệp vụ, người nhận bàn giao. Phần kỹ thuật (đường dẫn file, số dòng, cấu trúc
bảng) nằm ở [technical.md](technical.md).

Đánh dấu: không nhãn = đã xác nhận trong code. `[suy luận]` = suy ra chưa xác
nhận. `[chưa rõ]` = chưa xác định được, xem mục cuối.

## Hệ thống này giải quyết việc gì

Vài câu: bài toán nghiệp vụ, ai dùng, đầu vào đầu ra là gì. Không nhắc công nghệ.

## Thuật ngữ

Từ vựng nghiệp vụ của dự án. Người mới vấp thuật ngữ trước khi vấp logic, nên
mục này đặt sớm.

| Thuật ngữ | Nghĩa trong dự án này |
|---|---|
| | |

## Các tính năng

Với **mỗi** tính năng, lặp lại khối dưới đây.

---

### <Tên tính năng>

**Mục đích.** Tính năng này phục vụ việc gì, ai kích hoạt, khi nào.

**Điều kiện đầu vào.** Cần có gì thì mới chạy được. Nói bằng lời, không phải tên
biến.

**Quy tắc nghiệp vụ.** Đánh số từng quy tắc, phát biểu bằng ngôn ngữ nghiệp vụ:

1. ...
2. ...

**Ngưỡng và mốc đặc biệt.** Con số nào làm hệ thống đổi hành vi, và đổi thế nào.
Ghi cả tên config nếu người trong team gọi nó bằng tên đó.

| Mốc | Giá trị | Dưới mốc thì sao | Từ mốc trở lên thì sao |
|---|---|---|---|
| | | | |

**Ví dụ cụ thể.** Mỗi ngưỡng cho **hai** ví dụ, một ở mỗi phía. Đây là phần biến
quy tắc đọc-thuộc-được thành quy tắc dùng-được, và cũng là chỗ lộ ra chỗ mình
hiểu sai điều kiện — không nghĩ ra được ví dụ nghĩa là chưa hiểu.

> Đơn 600.000đ → miễn phí ship, khách trả 600.000đ.
> Đơn 499.000đ → cộng 30.000đ phí ship, khách trả 529.000đ.

**Trường hợp bị từ chối.** Khi nào hệ thống không cho làm, và người dùng nhận
được thông báo gì. Ghi theo **đúng thứ tự kiểm tra** — kiểm tra chạy trước sẽ che
kiểm tra sau, nên người dùng gặp lỗi đầu tiên chứ không phải lỗi nghiêm trọng
nhất.

| Thứ tự | Bị từ chối khi | Người dùng thấy |
|---|---|---|
| 1 | | |

**Khi có sự cố.** Hệ thống thử lại không, bao nhiêu lần, chờ bao lâu, và nếu vẫn
hỏng thì dữ liệu ra sao. Người nghiệp vụ cần biết đơn có bị trùng không, tiền có
bị trừ hai lần không.

**Trạng thái và vòng đời.** Bản ghi đi qua những trạng thái nào, cái gì đẩy nó
sang trạng thái kế tiếp.

---

## Dữ liệu hệ thống lưu

Mô tả bằng lời: lưu những loại thông tin gì, cái nào bắt buộc, cái nào liên quan
tới cái nào. Không cần tên bảng/cột trừ khi team quen gọi thế.

Ràng buộc do dữ liệu áp đặt cũng là quy tắc nghiệp vụ — ví dụ "mỗi mã tham chiếu
chỉ tồn tại một đơn" — nên ghi ở đây chứ không chỉ ở tài liệu kỹ thuật.

## Quy tắc chưa được thực thi

Chỗ nào tài liệu/thiết kế nói một đằng mà hệ thống làm một nẻo, hoặc quy tắc đã
khai báo nhưng không có tác dụng thật. Người nhận bàn giao cần biết trước khi
tin vào chúng.

## Câu hỏi mở

Chỗ chưa xác định được và tại sao. Khoảng trống thành thật có ích hơn câu khẳng
định sai — người đọc không đủ hiểu hệ thống để phát hiện mình bị dẫn sai.

- [chưa rõ] ...

---

## Hệ thống KHÔNG làm gì

Mục này nghe lạ nhưng rất quan trọng. Người đọc — và AI đọc để dựng lại — sẽ mặc
định hệ thống có những thứ "đương nhiên phải có". Không nói ra thì họ tự thêm
vào, và bản dựng lại khác bản gốc đúng ở chỗ nguy hiểm nhất.

Ghi rõ những thứ **cố tình hoặc vô tình không có**: không xác thực người gọi,
không kiểm giá trị âm, không chống trùng đơn, không kiểm tồn kho, một hàm chấm
điểm chỉ trả hằng số, một quy tắc khai báo nhưng chưa chạy.

- ...

## Tự kiểm trước khi bàn giao

Đọc lại **cả file này lẫn [technical.md](technical.md)** rồi tự hỏi: *một AI chỉ
đọc hai file này, không nhìn code, có dựng lại được phần mềm hoạt động tương tự —
và hệ thống gọi vào lẫn database hiện có vẫn dùng được không?*

Phép thử áp lên **cặp hai file**, không lên riêng file này. Tên route, tên field,
dạng response, tên exception không phải tri thức nghiệp vụ — nhét vào đây là hỏng
file cho đúng người nó phục vụ. Chúng thuộc `technical.md`.

Phần thuộc trách nhiệm của file này: mỗi quy tắc phải rõ **so sánh nào, phía nào
của lằn ranh, và đúng tại ngưỡng thì sao**. Chỗ nào đọc lại mà phải đoán là chỗ
thủng, không phải chi tiết vụn.

Phép thử này tốt hơn checklist vì nó soi vào chỗ **bỏ sót**, không phải chỗ sai
hình thức: viết một tài liệu trông đầy đủ mà thiếu đúng cái điều kiện không ai
nghĩ tới thì dễ, còn dựng lại một hệ thống từ tài liệu thủng lỗ thì không.
