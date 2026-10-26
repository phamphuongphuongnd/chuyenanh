---
title: Preferences — Cách làm việc người dùng muốn
type: preferences
updated: 2026-10-22
sources: []
---

# Preferences — Cách người dùng muốn tôi làm việc

> Rút ra từ các phiên đã xác nhận (kể cả từ dự án trước). Cập nhật khi lộ ra preference mới
> (xem [[SCHEMA]] → Ingest, nhóm 6).

## Giao tiếp
- **Trả lời bằng tiếng Việt.** Tên file/field/thuật ngữ kỹ thuật giữ tiếng Anh.
- Tài liệu phiên (`planhistory/`) viết tiếng Việt, chi tiết, có bảng tóm tắt file thay đổi + phần "Rủi ro / lưu ý".

## Cách code
- **Đi đúng pattern sẵn có** thay vì tự nghĩ cách mới.
- **Tách logic thành hàm thuần (pure function) để unit test** thay vì test xuyên qua service có phụ thuộc.
- **Refactor chỉ di chuyển logic, không đổi hành vi** → phải có unit test regression bao phủ.
- **Nhãn hiển thị khớp đúng chữ người dùng đang thấy** (tiêu đề cột, tên nút, tên lệnh…).

## Chia subagent khi có nhiều việc độc lập
- Người dùng muốn: *"nhiều task bạn tạo các sub agent chạy cho nhanh"* — lượt nào có **nhiều việc không phụ thuộc
  nhau** thì chia subagent chạy song song, đừng làm tuần tự.
- Vẫn làm thẳng khi các việc **nối tiếp nhau** hoặc tranh chấp tài nguyên dùng chung (cùng một tab trình duyệt,
  cùng một file, cùng một DB dev) — chia ra lúc đó chỉ chậm thêm và dễ dẫm chân nhau.
- Subagent **có thể trả kết quả sai hoặc gây hại** → kiểm tra lại kết quả; khi giao việc đụng dữ liệu thật, viết
  luật an toàn vào ngay prompt (kiểm tra danh tính, cấm ghi lên bản ghi thật, cấm tự sửa mã nguồn). Subagent bị
  chặn một lệnh thì dừng lại, không chạy hộ lệnh đó qua đường khác.

- Khi **cần gấp**, người dùng muốn *"tách ra nhiều agent nhất có thể"* — tìm cả việc làm được trước khi có móng
  (thư viện thuần, nghiên cứu) để không agent nào ngồi chờ. Cách làm: [[build-song-song-agent]].
- Người dùng nhắc lại (26/10): *"làm đến đâu lưu wiki đến đó"* — xác nhận để Ingest dần theo từng mốc, không chờ cuối phiên;
  chỉ ghi "đã kiểm" cho thứ Claude tự chạy lại, còn lại ghi "agent báo".
- Người dùng muốn **lưu wiki liên tục** trong phiên dài để mở chat mới/hết token không phải làm lại: ghi checkpoint
  tiến độ vào `planhistory/` sau mỗi mốc; kiến thức đã qua test thì lưu vào wiki, ghi rõ phần chưa kiểm trên máy thật.
- Khi gặp giới hạn lượt dùng/thiếu thời gian, người dùng **bàn giao phần còn lại cho người khác qua git** (không muốn mình tiếp tục
  tung agent): lưu wiki + checkpoint, đẩy nhánh lên git, viết bản giao việc tự đủ — xem [[tinh-nang-t1-t10]].
- Người dùng **đặt ngân sách lượt dùng** (vd "dùng đến 75% thì dừng"). Mình **không thấy %** lượt dùng của tài khoản (chỉ thấy bộ đếm token phiên) →
  nói thẳng điều đó, bảo họ xem `/usage`, và dừng bằng cách: không tung thêm agent mới, ghép + kiểm + lưu wiki rồi dừng; "dừng" từ họ → dừng agent, commit WIP.
- Hay hỏi "xong chưa / còn bao lâu / đúng không": trả lời **ngắn, thẳng**, tách rõ *đã kiểm bằng máy* và *chưa chạy máy thật*; không nói "xong" khi
  chưa test trên điện thoại. Hỏi nhiều câu "có cần X không" (master, cáp, CSDL) → giải thích đơn giản kèm cách làm cụ thể.
- **Push luôn hỏi lại** mỗi lần (không tự push); `master` chỉ gộp khi họ nói.
- Muốn **xem lý do + ưu/nhược điểm** trước khi chọn (nền tảng, thư viện, cách build) — trình bày bảng so sánh rồi mới hỏi.

## Người dùng sở hữu server, tôi không tự chạy
- Người dùng tự chạy ứng dụng / dev server ở terminal của họ. **Không tự chạy lệnh build, lệnh chạy app hay preview
  server** khi họ đang chạy — build ghi đè thư mục output (`dist/`, `bin/`, `target/`…) làm chết tiến trình đang chạy;
  tự chạy server thì giành cổng.
- Cần kiểm tra biên dịch thì dùng lệnh **chỉ kiểm, không ghi output** ghi ở mục Tổng quan dự án trong `index.md` (vd TypeScript
  `npx tsc --noEmit`, Python `python -m py_compile` / `mypy`, Go `go vet`, Rust `cargo check`); cần verify thì gọi vào
  app người dùng đang chạy hoặc nhờ họ mở màn hình. Cần restart thì **nhờ họ**.

## Test kỹ trước khi báo xong — nhưng phải test AN TOÀN
- Người dùng từng nhắc: *"nhớ là k ảnh hưởng các chức năng cũ nhé, và phải test trước khi giao cho tôi"*,
  *"bạn nên test các thứ cho tôi trước"* — luôn verify (kiểm tra biên dịch, chạy test, chạy thử migration, gọi thử chức năng thật) trước khi báo
  hoàn thành, không báo "chắc ổn".
- Sau **mọi** lần sửa hàng loạt bằng script: khẳng định kết quả (`assert old in s` trước khi thay, grep lại xem
  định danh cũ đã biến mất chưa) — lệnh replace có thể thất bại im lặng.
- Trên môi trường dùng chung dữ liệu thật: không tự ý gọi API ghi/đổi trạng thái lên bản ghi không chắc là dữ liệu
  test của mình — dừng lại hỏi. Trên Windows, `curl` gọi từ Git Bash từng làm hỏng UTF-8 tiếng Việt khi ghi DB.

## Bảo mật — lý do & bài học (luật gốc ở `CLAUDE.md` → 🔒)
- **Đăng nhập:** cách kiểm chứng mà vẫn giữ luật là dùng phiên người dùng **tự** đăng nhập rồi lưu lại (file
  `.auth/…`, JWT họ dán), hoặc bám Chrome thật của họ qua `mcp__claude-in-chrome__*`. Người dùng từng nhắc: *"bạn k
  đăng nhập được thì phải bảo tôi chứ"* — nên báo rõ đã kiểm được gì bằng cách khác và **những gì chưa kiểm được**.
- **Vá lỗ hổng:** ưu tiên người dùng đã nói rõ là **không làm gãy việc đang chạy > bịt hết mọi đường leo thang**.
  Buộc phải siết một route đang có người dùng thật ⇒ **backfill quyền trước**, đừng để hiệu lực ngay. Rủi ro còn lại
  sau khi người dùng đã chốt là đánh đổi có ý thức — đừng "sửa lại cho chặt" ở phiên sau nếu chưa hỏi.

## Khi nào lưu wiki
- Chỉ Ingest **sau khi người dùng xác nhận code chạy tốt** (test pass / đã kiểm thử). Xem [[SCHEMA]].

## Plan mode — khi nào dùng, khi nào không
- **Dùng plan mode** cho việc thêm capability mới (bảng mới, màn hình mới, thay đổi schema, feature mới).
- **Không cần** plan mode cho việc sửa bug tiếp nối trực tiếp từ tính năng vừa code trong cùng phiên — sửa thẳng,
  báo cáo ngắn gọn.
- Quyết định đã chốt qua `AskUserQuestion` mà người dùng **đổi ý ngay sau đó** → cập nhật lại plan ngay.

## Xác minh nguồn thật thay vì suy đoán từ context cũ
- Nghi ngờ về cấu trúc dữ liệu nguồn (vd mapping cột sheet) → **mở trực tiếp nguồn thật để xem** thay vì tin
  mapping đã nhớ từ phiên trước.

## Tôn trọng chỉnh sửa song song của người dùng
- Người dùng có thể tự sửa file **trong lúc** tôi đang làm việc trên cùng file. Thấy note "modified by the user or a
  linter" → **không revert**, điều chỉnh code của mình cho tương thích, không hỏi lại.
