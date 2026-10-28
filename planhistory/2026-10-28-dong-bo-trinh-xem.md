# Phiên 28/10/2026 — đồng bộ trình xem 5 định dạng, Khoá/Mở khoá chọn PDF trong app, giảm dựng lại

Kiến thức chắt lọc ở `lmm-wiki/concepts/trinh-xem-dong-bo.md`; trang này chỉ là mốc phiên.

## Yêu cầu người dùng
1. App chạy chậm ở mọi trang → nhanh hơn.
2. Khoá PDF chỉ hiện PDF; Mở khoá PDF chỉ hiện PDF đã khoá.
3. Thanh tìm kiếm ở màn xem chi tiết: bỏ nền vàng nhạt + chữ trắng khó nhìn; mọi nơi cùng một kiểu, đặt trên cùng.
4. Cả 5 định dạng (PDF, Word, Excel, PPT, TXT) phải giống nhau: cùng có tìm kiếm + phóng to/thu nhỏ; PPT tô vàng chữ tìm; PDF không để thanh tìm che thanh tiêu đề.

## Kết quả
- Commit trên `feat/pdf-office` + `master`: `d1ff646` (tính năng chính), `3cdb98d` (PPT tô vàng, thanh tìm PDF), `293470b` (sắp xếp một lần), `b269d2b` + `e603547` (wiki).
- Đã thử bản release trên Galaxy A13: Khoá/Mở khoá, Word, Excel, PPT, PDF, TXT (xem log).
- Cách làm: Explore agent khảo sát; 3 agent sửa code song song theo file riêng (Gần đây/Yêu thích, MainShell + debounce, test mới), rồi thêm 3 agent (PDF zoom, Excel tìm, PPT tìm + zoom); tôi tự chạy `flutter analyze/test` tuần tự.
- Chưa làm (tuỳ chọn): đo tốc độ trước/sau, PPT tô riêng kết quả hiện tại, Excel loại hàng/cột ẩn khỏi kết quả.
