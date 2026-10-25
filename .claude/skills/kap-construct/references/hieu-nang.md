# Chế độ hiệu-năng: nghi phạm và cách đo

Thứ tự trong file này là **thứ tự nên đào**, xếp theo (khả năng gặp × mức tác động). Đừng đảo thứ tự vì trực
giác — trực giác hay dẫn tới tối ưu nhầm chỗ.

---

## Nguyên tắc: đo trước, sửa sau

Nếu có kết nối DB, **chạy §Đo trước**, rồi mới đọc code theo hướng nó chỉ. `pg_stat_statements` trả lời câu
"chậm ở đâu" chính xác hơn mọi phán đoán từ đọc code.

Không có DB thì vẫn làm được — nhưng sản phẩm là **danh sách nghi phạm đã thu hẹp**, không phải chẩn đoán.
Phải nói rõ điều đó với người dùng và ghi ngay đầu tài liệu.

---

## A. Cơ sở dữ liệu

### A1. Việc nặng chạy đồng bộ trong request người dùng

```bash
grep -rn "REFRESH MATERIALIZED\|VACUUM\|ANALYZE \|CREATE INDEX\|ALTER TABLE" --include=*.ts */src
```

Với mỗi kết quả, hỏi **hai** câu — câu thứ hai quan trọng hơn và hay bị quên:

1. Nó nằm trong cron hay trong đường xử lý request?
2. Nó có nằm **trong transaction** không? (`em.transactional`, `BEGIN`) — nếu có, khoá giữ tới lúc commit,
   tệ hơn nhiều.

`REFRESH MATERIALIZED VIEW` **không kèm `CONCURRENTLY`** lấy khoá `ACCESS EXCLUSIVE`: chặn **mọi** người đọc
view đó trong suốt thời gian rebuild. Đây là nguyên nhân kinh điển của triệu chứng "cả hệ thống thỉnh thoảng
đứng vài chục giây rồi lại chạy". Ngược lại `CONCURRENTLY` không chặn đọc nhưng **tốn gấp 2–3 lần** và
**không chạy được trong transaction**.

### A2. Thiếu index — kiểm bằng cách so cột lọc với cột index

Đây là chỗ sai nhiều nhất, vì "có UNIQUE rồi" **không** có nghĩa là "lọc được".

**Luật index tiền tố:** index trên `(a, b, c)` chỉ dùng được khi truy vấn lọc `a`, hoặc `a+b`, hoặc `a+b+c`.
Lọc `a + c` thì **`c` không dùng được index**. Lọc `b` không thì vô dụng hoàn toàn.

**PostgreSQL KHÔNG tự tạo index cho khoá ngoại.** ORM cũng không. Nên bảng dựng bằng Knex/SQL tay thường
không có index nào ngoài PK — kể cả bảng hàng triệu dòng.

Cách kiểm không cần DB:

```bash
# 1. Liệt kê index đã khai trong migration
grep -rn "\.index(\|\.unique(\|CREATE INDEX" migrations/ db/migrations/ 2>/dev/null

# 2. Liệt kê cột đang bị lọc ở các truy vấn nóng
grep -rn "\.find(\|\.findOne(\|createQueryBuilder\|where(" -A 8 --include=*.service.ts */src | head -60
```

Rồi **so tay từng bảng**. Đừng viết script tự động kết luận — script rất dễ bỏ sót migration thêm index về
sau bằng raw SQL, và cho ra danh sách sai.

Có DB thì một câu là xong:

```sql
SELECT relname AS bang, seq_scan, seq_tup_read, idx_scan,
       pg_size_pretty(pg_total_relation_size(relid)) AS dung_luong
FROM pg_stat_user_tables
WHERE schemaname = '<schema>'
ORDER BY seq_tup_read DESC LIMIT 15;
```

`seq_scan` cao + `idx_scan` gần 0 + bảng lớn = đúng chỗ cần index.

### A3. Định nghĩa view có mẫu đắt

Đọc file SQL của view. Ba mẫu cần soi:

| Mẫu | Vì sao đắt | Thay bằng |
|---|---|---|
| `JOIN LATERAL (... ORDER BY ... LIMIT 1)` | chạy một truy vấn con **cho từng dòng** | `DISTINCT ON` hoặc window function |
| `GROUP BY` thiếu cột phân vùng (vd thiếu `account_id`) | **số liệu sai** — nhân N lần, không chỉ chậm | thêm cột vào `GROUP BY` |
| Cửa sổ thời gian neo vào `MAX(date)` **của dữ liệu** | job sync chết thì view vẫn "sạch", số đứng yên mà UI không báo | neo vào `CURRENT_DATE`, hoặc hiện "cập nhật lúc" trên UI |

---

## B. Tiến trình backend

### B1. Một tiến trình gánh nhiều loại việc

Đây là nguyên nhân của triệu chứng khó chịu nhất: **chậm ở khắp nơi, không theo quy luật nào**.

```bash
grep -rn "@Cron(\|setInterval(" --include=*.ts */src           # có cron trong tiến trình API?
grep -rn "@SqsMessageHandler\|consumer\|subscribe(" --include=*.ts */src   # có consumer chung tiến trình?
grep -rn "cheerio\|jsdom\|sharp\|JSON.parse(.*readFile\|csv-parse" --include=*.ts */src  # việc CPU nặng?
```

Node.js chạy JavaScript trên **một luồng**. Bất kỳ việc CPU đồng bộ nào — parse HTML bằng cheerio, xử lý ảnh,
`JSON.parse` file lớn, `_.sumBy` trên mảng trăm nghìn phần tử — **khoá toàn bộ API** trong lúc chạy.

Kiểm luôn: cron có bị gate bằng env không, và **production có bật gate đó không**? Một `@Cron` gate bằng
`ENVIRONMENT === 'PROD'` là vô hại ở dev nhưng chạy thật ở production.

### B2. Gộp số liệu trong ứng dụng thay vì trong SQL

```bash
grep -rn "_.sumBy\|_.groupBy\|_.meanBy\|reduce((.*,.*) =>" --include=*.service.ts */src | head -20
```

Với mỗi chỗ: dữ liệu vào từ đâu? Nếu là `repo.find(...)` **không có `limit`** thì đây là mẫu "kéo hết về rồi
mới cộng". Ba chi phí chồng nhau:

1. truyền toàn bộ dòng qua mạng
2. **ORM hydrate từng dòng thành entity** (thường là phần đắt nhất, hay bị bỏ qua — dùng query builder trả
   plain object sẽ nhẹ hơn nhiều)
3. cộng trong Node = CPU đồng bộ = khoá event loop (xem B1)

### B3. Chi phí nền trên mọi request

| Kiểm | Lệnh | Vì sao |
|---|---|---|
| ORM log mọi câu SQL | `grep -rn "debug: true" */src` | tốn CPU serialize + I/O + ngập log. Phải gate theo env |
| Không nén response | `grep -rn "compression" */src */package.json` | JSON nén gzip còn ~10–15% |
| Xác thực tra DB mỗi request | đọc `jwt.strategy.ts` / middleware auth | thường là chủ ý (thu hồi quyền tức thì) nhưng cache 30–60s được |
| Poll hàng đợi kiểu short polling | `grep -rn "ReceiveMessageCommand" -A 4 */src` | thiếu `WaitTimeSeconds` ⇒ gọi API liên tục **và** hay trả rỗng dù có message |
| Vòng lặp `UPDATE` từng dòng | `grep -rn "for (.*of.*) {" -A 4 --include=*.service.ts */src \| grep -i "update\|execute"` | N round-trip nối tiếp thay vì 1 |

---

## C. Frontend

```bash
grep -rn "React.lazy\|Suspense\|loadable(" src/ | head        # rỗng = không chia nhỏ bundle
grep -c "from 'lodash'" -r src/ ; grep -c "from 'lodash/" -r src/   # barrel vs từng hàm
grep -rn "new QueryClient" -A 12 src/                          # thiếu staleTime ⇒ refetch mọi lần mount
grep -rn "usePagination\|useGlobalFilter\|useSortBy" src/       # lọc/sắp xếp ở client?
grep -rn "react-window\|react-virtual\|useVirtual" src/         # rỗng = không ảo hoá bảng
grep -E '"@mui|"@mantine|"antd|"bootstrap' package.json         # hơn 1 thư viện UI?
```

**Câu hỏi quyết định:** màn nặng nhất lọc/sắp xếp/phân trang ở **client hay server**? Nếu ở client thì API có
trả toàn bộ dữ liệu không? Đó là mẫu chậm tuyến tính theo dữ liệu — hôm nay chịu được, sang năm thì không.

---

## D. Hạ tầng

```bash
grep -rn "replicas:\|resources:\|requests:\|limits:\|Probe:" */**/templates/*.yaml
cat */Dockerfile
```

| Thiếu gì | Hậu quả |
|---|---|
| `resources.requests/limits` | pod là **BestEffort** — bị giết trước tiên khi node thiếu RAM ⇒ chậm/restart **thất thường** |
| `readinessProbe` | traffic vào pod khi app **chưa khởi động xong** ⇒ lỗi mỗi lần deploy |
| `livenessProbe` | pod treo thì không ai restart hộ |
| Dockerfile một tầng, không prune | image lớn ⇒ pull lâu ⇒ rollout lâu |
| Tag image "trôi" (`:master`) | GitOps không nhận ra thay đổi, và **không có đường rollback** |

---

## Đo — 6 lệnh, 30 phút

### 1. Thời gian rebuild view (làm trước nếu có matview)

```sql
\timing on
REFRESH MATERIALIZED VIEW CONCURRENTLY <schema>.<view>;
```

> `> 5 giây` ⇒ A1 là nguyên nhân chính. `>` chu kỳ cron ⇒ các lượt refresh đang chồng lên nhau.

### 2. Truy vấn tốn tổng thời gian nhiều nhất — câu quan trọng nhất

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT calls,
       round(total_exec_time::numeric)   AS tong_ms,
       round(mean_exec_time::numeric, 1) AS tb_ms,
       round(100 * total_exec_time / sum(total_exec_time) OVER (), 1) AS phan_tram,
       left(query, 120) AS cau_lenh
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
```

> Chú ý cột `tong_ms`, **không phải** `tb_ms`. Một câu 5ms chạy 2 triệu lần tệ hơn một câu 2s chạy 10 lần.

### 3. Bảng nào đang bị quét tuần tự — xem §A2.

### 4. Kế hoạch thực thi của truy vấn nghi ngờ nhất

```sql
EXPLAIN (ANALYZE, BUFFERS) <câu truy vấn thật>;
```

> Thấy `Seq Scan` trên bảng lớn ⇒ xác nhận thiếu index.

### 5. Ai đang chặn ai — **chạy đúng lúc hệ thống đang đứng**

```sql
SELECT pid, wait_event_type, wait_event, state,
       now() - query_start AS chay_duoc, left(query, 100) AS cau_lenh
FROM pg_stat_activity
WHERE state <> 'idle' AND datname = current_database()
ORDER BY query_start;
```

> Nhiều dòng `wait_event_type = 'Lock'` cùng lúc với một `REFRESH`/`ALTER` = bằng chứng trực tiếp cho A1.

### 6. Phía HTTP và bundle

```bash
npm run build && du -sh build/static/js/*.js dist/assets/*.js 2>/dev/null | sort -h
curl -sI <url-asset-có-hash> | grep -i 'cache-control\|content-encoding'
curl -s -o /dev/null -w 'bytes=%{size_download} time=%{time_total}s\n' \
  -H 'Accept-Encoding: gzip' -H 'Authorization: Bearer <token>' '<api-nặng-nhất>'
```

---

## Viết kết quả ra sao

Xếp nguyên nhân theo **mức tác động**, không theo thứ tự tìm ra. Mỗi mục cần đủ bốn phần:

1. Nhãn ✅ hay 📐
2. Bằng chứng `file:line`, hoặc số đo
3. **Người dùng thấy triệu chứng gì** — đây là phần nối kỹ thuật với trải nghiệm thật, đừng bỏ
4. Sửa thế nào, tốn bao nhiêu công

Luôn có mục **"những thứ KHÔNG phải nguyên nhân"**. Nó chặn cả một hướng đi sai (thường là "thêm cache đi",
"tăng replica đi", "đổi ngôn ngữ đi") và thường là phần được cảm ơn nhất.

Và luôn xếp riêng nhóm **"sửa được ngay, rủi ro gần bằng 0"** (thường là vài dòng: tắt debug log, bật nén,
đặt `staleTime`). Nhóm đó tạo đà và mua thời gian cho các việc lớn hơn.
