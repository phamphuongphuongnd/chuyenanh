---
name: phuong-perf-test-jmeter
description: Use when the user asks for performance or load testing of a web app/API, or to find why a system is slow under one or many users — "test hiệu năng", "kiểm thử tải", "load test", "JMeter", "hệ thống chạy chậm", "đo thời gian phản hồi", "nhiều người dùng cùng lúc", "tìm nguyên nhân chậm". Runs only against a local/Docker copy with user-chosen RAM/CPU limits and produces a report.
---

# Test hiệu năng bằng JMeter (local/Docker)

Trả lời tiếng Việt; tên file/field/code giữ tiếng Anh.

## 0. Quy tắc cứng (đọc trước)
1. **Chỉ chạy trên máy này** (localhost/Docker). Tuyệt đối không nhắm host production/staging thật. Mọi script chạy đều có chốt chặn từ chối host không phải localhost/127.0.0.1.
2. **Chỉ test, không sửa** code hay DB trừ khi người dùng cho phép rõ. Thao tác ghi dữ liệu (kể cả qua nút của ứng dụng) = hỏi trước; nếu hệ thống chặn thì DỪNG, không vòng qua, giao lại cho người dùng.
3. **Đổi dữ liệu = theo cách project quản lý schema** (migration/seed của project); dữ liệu thử thì đưa SQL cho người dùng tự chạy. `SELECT` / `EXPLAIN` chạy thẳng được.
4. **Không tự khởi động/dừng backend người dùng đang chạy.** Backend để test là bản Docker riêng, cổng khác.
5. **Không tự commit.** Không đưa tên đăng nhập/mật khẩu vào báo cáo hay chat.
6. **Không đoán cấu hình live (RAM/CPU).** Hỏi người dùng họ muốn test với bao nhiêu RAM, bao nhiêu CPU. Nếu họ không nhớ thì gợi ý cách tra (file triển khai của project: k8s/Helm values, docker-compose, Terraform; ảnh chụp dashboard nhà cung cấp) và ghi "giả định chưa kiểm chứng" trong báo cáo.
7. **Theo luật gốc 🔒 trong `CLAUDE.md`:** không tự đăng nhập hay gõ mật khẩu, không mở / sửa / xoá file bí mật (`.env*`, `*.secret.*`…), chỉ trỏ đường dẫn cho JMeter/Docker dùng.
8. **Luật riêng của project:** đọc `CLAUDE.md` và wiki/preferences của project (nếu có) trước khi bắt đầu — trang cấm mở, dữ liệu không được đụng, quy ước dữ liệu thử.

## 1. HỎI người dùng trước khi làm bất cứ việc gì (không tự đặt mặc định)
Hỏi gọn trong 1 lượt, rồi ghi lại câu trả lời:
1. **Số trường hợp cần test** và, với **từng trường hợp**: bao nhiêu người dùng theo từng vai trò (vd n USER thường, n ADMIN), bao nhiêu **RAM**, bao nhiêu **CPU** (cho DB, backend, web, giới hạn riêng từng thành phần hay chung một hệ thống).
2. **Môi trường** (Docker local) và **tài khoản** dùng để test: người dùng **tự điền** tài khoản vào `jmeter/users.secret.csv` (Claude chỉ đưa dòng tiêu đề mẫu `username,password,role`, không mở file). Hỏi tên các vai trò để biết cột `role`.
3. **Có test thao tác ghi không** (Lưu, tạo/sửa/xóa, đổi trạng thái...). Nếu có: cho phép đổi dữ liệu DB local, dùng bản ghi nào.
4. **Phạm vi loại trừ**: hỏi người dùng muốn loại trang nào, mục nào. Đưa danh sách gợi ý để họ chọn, **không tự loại và không tự chạy**: trang vận hành/quản trị hệ thống (chạy job, console SQL, đồng bộ thủ công), API gọi dịch vụ bên thứ ba, hàng đợi/message broker, lưu trữ/đồng bộ ngoài (cloud storage, spreadsheet, email), import/export, mọi nút ghi/xóa. Mục nào chưa được người dùng cho phép rõ thì coi là **không chạy**.
5. **Báo cáo**: lưu vào **file nào** (đường dẫn đầy đủ kèm tên file, ví dụ `D:\bao-cao\hieu-nang.docx`) và **định dạng nào** (Word `.docx`, `.odt`, `.pdf`, Excel `.xlsx`...), khổ **ngang hay dọc**, và **thang tô màu ô thời gian** (gợi ý: không tô < 1 s, 1–< 3 s xanh, 3–< 5 s vàng, ≥ 5 s đỏ). Không tự đặt mặc định. Nếu thư mục đã có file khác thì không đụng tới.

## 2. Kiểm kê theo TRANG WEB (không chỉ theo controller)
- Đọc file khai báo route của FE + nơi gọi API (hook/service/store — vd React: `routes.tsx`, `use*.ts`; Vue/Angular: router + service tương đương): mỗi trang gọi API nào khi mở, tham số thật (page size, limit, khoảng ngày, populate, sort), có tự làm mới không (`refetchInterval`, `setInterval`, polling, websocket), nút ghi nào.
- Mỗi trang là 1 Transaction Controller tên là đường dẫn trang (vd `/orders`), thêm nhóm web tĩnh.

## 3. Dựng kịch bản JMeter (sinh bằng script, không viết XML tay)
- Tự viết script sinh `.jmx` (Node/Python) ở scratchpad hoặc thư mục người dùng chỉ định — không đặt vào repo của họ.
- Login 1 lần/thread bằng CSV Data Set Config trỏ tới `jmeter/users.secret.csv` (Claude chỉ ghi đường dẫn vào kịch bản, không đọc giá trị), bootstrap = các API trang chủ gọi ngay sau đăng nhập (thông tin user, menu, quyền, thông báo...).
- Body đúng DTO (validation chặt kiểu Joi `allowUnknown:false`, class-validator `forbidNonWhitelisted`, zod `strict`, Pydantic `extra=forbid` → thừa field là 400). Trích ID bằng JSON extractor; **đặt biến mặc định** cho mọi ID (thứ tự ngẫu nhiên có thể vào trang trước khi biến được trích).
- Các vai trò khi so sánh dùng **chung một phạm vi dữ liệu** (cùng tenant/account/tổ chức, truyền qua `-J<biến>`), nếu không kết quả bị nhiễu do dữ liệu khác nhau.
- Smoke test 1 vòng cho mọi tài khoản (lỗi đăng nhập ⇒ nhờ người dùng tự kiểm file tài khoản), sửa mọi lỗi 4xx/5xx trước khi đo (lỗi 0 ms = lỗi kịch bản, không phải lỗi hệ thống).

## 4. Dựng môi trường giới hạn (Docker)
- Build backend + web (bản production) thành image riêng, chạy cổng khác (ví dụ 18080/13000), nối DB local qua mạng Docker riêng.
- Đặt giới hạn RAM/CPU **đúng theo giá trị người dùng đã trả lời ở mục 1**, cho từng thành phần họ nêu.
- **Sau MỖI lần khởi động lại DB phải đặt lại và kiểm tra `cpu.max`/`memory.max` trong cgroup** (`docker update --cpus 2` rồi `--cpus <n>`; không bao giờ dùng `--cpu-quota -1`, không gỡ được và làm mất giới hạn sau mỗi restart).
- Tự viết 2 script dựng/dọn môi trường (vd `env-up` / `env-down`, `.ps1` trên Windows hoặc `.sh`) để chạy lại được.

## 5. Đo 1 người dùng = "lần đầu mở trang" (nguội)
- Người dùng thật lần nào cũng như lần đầu → **mỗi lượt** khởi động lại DB + xóa cache máy ảo (`docker run --rm --privileged <image> sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"`).
- 5 cặp lượt đo giữa các vai trò (vd ADMIN/USER), **đảo thứ tự** giữa các cặp để loại yếu tố chạy trước/sau. Không dùng "vòng nóng" làm số liệu chính.

## 6. Đo nhiều người dùng "dùng thật, lộn xộn"
- Số thread = **số người dùng từng vai trò theo câu trả lời ở mục 1**, mỗi trường hợp một đợt. Đăng nhập đồng loạt (Synchronizing Timer), sau đó thứ tự trang xáo ngẫu nhiên (Random Order), mỗi trang vào với xác suất ~65% (If Controller), nghỉ ngẫu nhiên 0,3–1,5 s, 2 vòng. Kiểm tra mỗi API có đủ số người gọi theo yêu cầu (ví dụ ≥ 30).
- Bắt đầu từ DB nguội. Thêm bản có **web tự làm mới** (đúng chu kỳ polling đọc được ở mục 2, vd thông báo 30 s) bằng thread group nền.
- **Chạy lặp ít nhất 2 lần** mỗi trường hợp để đo dao động; chỉ kết luận khi chênh lệch lớn hơn dao động.
- Trong lúc chạy lấy mẫu mỗi 2 s: `docker stats` (CPU/RAM từng container), phiên DB đang chạy (câu SQL, loại chờ, số truy vấn đồng thời tối đa), CPU tổng máy.
  - PostgreSQL: `pg_stat_activity`. MySQL: `SHOW PROCESSLIST` / `performance_schema`. SQL Server: `sys.dm_exec_requests` + `sys.dm_os_waiting_tasks`.

## 7. Phân tích nguyên nhân (chỉ đọc)
- Phân biệt: API **tự nặng** (chậm cả khi 1 người) và API **chậm dây chuyền** (nhẹ khi 1 người, hàng giây khi nhiều người vì DB kín CPU / hết kết nối).
- **Đối chiếu từng giả thuyết, mỗi giả thuyết kết luận Đúng / Góp phần / Sai / Chưa đo kèm bằng chứng:**
  - **RAM:** DB dùng sát trần, tỉ lệ chờ đọc đĩa (IO) trong bảng phiên DB.
  - **CPU:** CPU DB/BE/máy chạy test theo thời gian; số truy vấn đồng thời.
  - **SQL kém:** kế hoạch thực thi thật (PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`, MySQL `EXPLAIN ANALYZE`, SQL Server actual execution plan), kích thước bảng, danh sách chỉ mục, câu SQL chiếm nhiều mẫu nhất.
  - **Backend chậm:** truy vấn thừa mỗi request (xác thực/quyền không cache), xử lý nặng trong code, refresh view/cache khóa người đọc khi lưu, và **giới hạn kết nối DB của chính hệ thống này**: đọc cấu hình pool trong code/ORM/driver (mỗi hệ thống một giá trị, có thể còn giới hạn ở phía DB hoặc bộ gom kết nối như PgBouncer/ProxySQL), rồi kiểm chứng bằng số đo: số truy vấn đồng thời tối đa khi chạy nhiều người. Nếu số đo chạm đúng một mức trần cố định và không bao giờ vượt, đó là dấu hiệu nghẽn kết nối; ghi rõ giá trị tìm được và nguồn (dòng cấu hình hoặc số đo), không mặc định con số nào.
  - **FE chậm:** số API mỗi trang, tự làm mới/polling, kích thước bundle, tải web tĩnh. JMeter **không đo** thời gian dựng giao diện trong trình duyệt → ghi "chưa đo" phần đó (cần Lighthouse/Playwright nếu người dùng muốn).
- Đọc chú thích trong code (thường có số đo cũ).

## 8. Báo cáo (file và định dạng theo câu trả lời ở mục 1, câu 5; script sinh từ dữ liệu, không gõ số tay)
- Cấu trúc: 1 Mục tiêu/phạm vi/môi trường → 2 Một người dùng (bảng theo trang, chi tiết từng API) → 3 Nhiều người dùng (theo trang, theo API, số người gọi mỗi API, web tự làm mới) → 4 Vì sao chậm (bảng đối chiếu giả thuyết RAM/CPU/SQL/BE/FE) → 5 Giải pháp **theo từng trang** (số liệu, nguyên nhân, giải pháp 1 người, kết quả sau sửa, giải pháp nhiều người) → 6 Giải pháp chung xếp theo chi phí thấp→cao → 7 Hạn chế và cách chạy lại.
- Định dạng: tô màu ô thời gian **theo thang người dùng trả lời ở mục 1, câu 5** (có chú thích màu ở đầu báo cáo); khổ theo câu trả lời (thường A4 ngang); cột chia theo nội dung; tắt kiểm tra chính tả trong bảng (`.odt`: ngôn ngữ `zxx`; `.docx`: `noProof`); không ghi tên đăng nhập (chỉ tên vai trò, vd "ADMIN"/"USER thường"); giải thích p90/p95, "nguội", "TB"/"Max" bằng ví dụ số thật.
- "Kết quả sau giải quyết" khi chưa sửa gì = **dự đoán, ghi rõ chưa đo**. Ghi rõ mọi phần chưa đo.
- `.docx` sinh theo skill `docx` (nếu có); mở thử bằng Word trước khi giao.
- Lưu **đúng đường dẫn và tên file** người dùng trả lời ở mục 1. File đang mở/khóa → ghi bản `<tên>-moi.<đuôi>`, nhắc người dùng đóng rồi xóa bản cũ; đưa 1 bản cuối.
- Làm phần 1 người trước cho người dùng đọc rồi mới chạy nhiều người, nếu họ yêu cầu.

## 9. Bẫy đã gặp (đừng lặp lại)
- PowerShell (Windows): `-Jusers=$csv` **không** thay biến → viết `"-Jusers=$csv"`.
- JMeter GUI tính lại số vòng lặp từ `${__P(...)}` → bản GUI dùng số cứng. `SyncTimer.groupSize` phải là `stringProp`.
- Transaction Controller (parent) ẩn request con → bật `subresults=true` trong bộ ghi kết quả.
- Body có biến mảng: đặt biến mảng trong `[]` sẽ thành mảng lồng `[[...]]` → 400.
- Response cực lớn làm tràn heap JMeter → chỉ lưu MD5 (`HTTPSampler.md5`); kiểm tra trang gửi đúng tham số như web thật trước khi kết luận là "chậm".
- Gửi phím/click để bấm Start GUI có thể rơi vào cửa sổ khác (trình duyệt). Để người dùng tự bấm Start, hoặc chạy dòng lệnh (`-n`) nếu họ đồng ý; kết quả giống nhau.
- `.env` có thể chứa ký tự NUL làm `--env-file` lỗi → báo người dùng tự lọc file (Claude không mở `.env`).
- Luôn ghi mốc thời gian và chỉ lấy mẫu trong cửa sổ chạy.

## 10. Dọn dẹp khi xong (bắt buộc, làm cuối cùng)
- Tắt Java **và cả cửa sổ `jmeter.bat`/`jmeter.sh`** đi kèm, các tiến trình lấy mẫu chạy ngầm.
- Xóa container/mạng/image test do mình tạo; **không đụng** container/image/volume của người dùng.
- **Nhắc người dùng tự xoá** file chứa mật khẩu/khóa (vd `jmeter/users.secret.csv` nếu không dùng nữa) — Claude không xoá. Xóa `jmeter.log`; trả giới hạn DB về không hạn chế; xác nhận DB đang chạy và dữ liệu không đổi (so md5 checksum).
- Liệt kê rõ những việc người dùng phải tự làm (file bị chặn xóa, thư mục được bảo vệ, cấu hình không gỡ được).
- Báo trung thực: cái gì đã đo, chưa đo, lỗi của mình đã sửa.
