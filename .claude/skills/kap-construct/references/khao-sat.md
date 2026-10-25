# Checklist khảo sát

Đọc theo thứ tự này. Mục tiêu không phải đọc hết code, mà là **trả lời đủ 7 câu hỏi** dưới đây bằng bằng chứng.

Lệnh viết cho thư mục cha chứa các repo. Đổi `*/` cho khớp bố cục thật.

---

## 1. Hệ thống gồm những gì, ai nói chuyện với ai

```bash
# Bản đồ repo + nhánh
for d in */; do echo "=== $d"; (cd "$d" && git remote -v | head -1 && git branch --show-current); done

# Mỗi repo là loại gì
for d in */; do echo "=== $d"; ls "$d" | grep -iE '^(package.json|go.mod|pom.xml|requirements.txt|Dockerfile|main.tf|Chart.yaml|appsscript.json)$'; done
```

**Câu hỏi phải trả lời:** repo nào **chạy** lúc runtime, repo nào chỉ **định nghĩa** hệ thống (IaC, k8s,
migration, tài liệu)? Nhầm hai loại này là hiểu sai kiến trúc ngay từ đầu.

Rồi tìm các kênh nối giữa chúng — đây mới là phần khó, và là phần `project-map` không làm:

```bash
# Gọi HTTP giữa các service nội bộ
grep -rn "BASE_URL\|_API_URL\|baseURL\|axios.create" --include=*.ts --include=*.js */src 2>/dev/null | head -20

# Hàng đợi / message: tên queue, topic
grep -rn "QUEUES\s*=\|QueueUrl\|@SqsMessageHandler\|new SQSClient\|Topic\|Kafka" --include=*.ts */src 2>/dev/null | head -20

# Lịch chạy: TRONG code hay NGOÀI code?
grep -rn "@Cron(\|cron(\|schedule_expression\|CronJob\|newTrigger" */ --include=*.ts --include=*.tf --include=*.js --include=*.yaml 2>/dev/null | head -20
```

> ⚠️ Nếu `schedule_expression` nằm ở Terraform mà không có `@Cron` nào trong code — **bộ lập lịch nằm ngoài
> repo ứng dụng**. Đây là kiểu kiến trúc rất hay gặp và cực dễ hiểu sai: đọc code sẽ không thấy job nào chạy.

## 2. Cửa vào và ranh giới bảo mật

```bash
grep -rn "@Controller\|@Get(\|@Post(\|app.get(\|router\." --include=*.ts */src 2>/dev/null | wc -l
ls */src/**/*.guard.ts */src/guards/* 2>/dev/null
grep -rn "@UseGuards\|canActivate" --include=*.ts */src 2>/dev/null | head -20
```

**Câu hỏi:** có mấy đường vào, mỗi đường xác thực bằng gì? Chú ý kiểu **cùng một service nhưng hai cửa** (một
cho người dùng dùng JWT, một cho máy gọi máy dùng API key) — rất hay gặp và hay bị bỏ sót.

## 3. Mô hình dữ liệu

```bash
ls */src/entities/ */models/ 2>/dev/null | head -40

# Quan hệ giữa entity
grep -rn "@ManyToOne\|@OneToMany\|@OneToOne" -A 1 --include=*.ts */src/entities/ 2>/dev/null | grep "=> " | head -30

# View / materialized view — tầng đọc, rất hay là nguồn của cả tính năng lẫn vấn đề
grep -rln "MATERIALIZED VIEW\|CREATE VIEW" */ 2>/dev/null | head
```

**Bẫy:** entity trong code ≠ bảng thật trong DB. Nếu migration nằm ở repo riêng, **so hai bên**: bảng nào có
entity mà không có migration là bảng **tạo tay ngoài luồng** — dựng lại DB sẽ thiếu.

## 4. Tích hợp bên ngoài

```bash
grep -rn "https://[a-z0-9.-]*\.\(com\|net\|org\|io\)" --include=*.ts */src 2>/dev/null \
  | grep -oE "https://[a-z0-9.-]+" | sort | uniq -c | sort -rn | head -20
```

Với mỗi đối tác: đọc/ghi hay cả hai? Có retry không? Có xử lý 429/timeout không? **Hai client cùng repo mà một
cái có retry, một cái không** là dấu hiệu nợ kỹ thuật đáng ghi lại.

## 5. Cấu hình quyết định hành vi

```bash
grep -rn "configService.get\|process.env\." --include=*.ts */src 2>/dev/null \
  | grep -oE "(get<[^>]*>\(|get\(|env\.)['\"]?[A-Z_]{3,}" | grep -oE "[A-Z_]{3,}" | sort | uniq -c | sort -rn | head -25
```

Tìm các **công tắc đổi hành vi**: `ENVIRONMENT`, `DISABLE_*`, `*_ENABLE`, `REMOTE_SECRETS`. Rồi **đối chiếu
với values production thật** — một cron gate bằng `ENVIRONMENT === 'PROD'` chỉ quan trọng khi production thật
sự đặt `PROD`.

## 6. Triển khai

```bash
cat */Dockerfile 2>/dev/null
grep -rn "replicas:\|resources:\|imagePullPolicy\|readinessProbe\|livenessProbe" */**/templates/*.yaml 2>/dev/null
grep -rn "branches:\|docker tag\|docker push" */.github/workflows/* 2>/dev/null | head
```

**Ba thứ luôn phải kiểm:** số replica, có `resources` không, có probe không. Thiếu cả ba là mẫu rất phổ biến
và ảnh hưởng trực tiếp tới độ ổn định.

## 7. Cái gì đang hỏng mà không ai biết

Đây là phần làm tài liệu có giá trị thật, không chỉ mô tả lại code.

```bash
# Bắt lỗi rồi nuốt luôn
grep -rn "catch" -A 2 --include=*.ts */src 2>/dev/null | grep -B 1 -E "^\S+-\s*\}" | head -20

# Việc nặng chạy đồng bộ trong request
grep -rn "REFRESH MATERIALIZED\|VACUUM\|readFileSync\|execSync" --include=*.ts */src 2>/dev/null | head

# Cờ debug bật cứng
grep -rn "debug: true\|DEBUG = true\|verbose: true" --include=*.ts */src 2>/dev/null
```

---

## Bảy câu hỏi phải trả lời được trước khi viết

Chưa trả lời được câu nào thì quay lại đào tiếp, đừng viết bừa cho đủ mục.

1. Repo nào chạy thật, repo nào chỉ định nghĩa hệ thống?
2. Các repo nối với nhau qua **kênh nào** (HTTP / hàng đợi / DB chung / file)?
3. Lịch chạy định kỳ nằm **trong code hay ngoài code**?
4. Có mấy đường vào, mỗi đường xác thực bằng gì?
5. Bảng nào là trục xương sống, bảng nào chỉ là phái sinh (view/matview)?
6. Cấu hình nào đổi được hành vi **mà không cần deploy**?
7. Chỗ nào hỏng **âm thầm** — lỗi xảy ra nhưng không ai được báo?
