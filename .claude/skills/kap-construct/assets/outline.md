# Bộ khung tài liệu

Ghi vào `docs/architecture/`. Sáu file, mỗi file trả lời **một** câu hỏi — đừng trộn.

| File | Trả lời câu hỏi | Hình chính |
|---|---|---|
| `README.md` | Hệ thống là gì, gồm những gì, ai nói chuyện với ai | context (C4-L1) + khối (C4-L2) |
| `01-thanh-phan.md` | Bên trong mỗi service có gì | component theo tầng |
| `02-luong-xu-ly.md` | Chuyện gì xảy ra khi X | sequence, mỗi luồng một hình |
| `03-mo-hinh-du-lieu.md` | Dữ liệu trông thế nào | class theo cụm + state machine |
| `04-trien-khai.md` | Nó chạy ở đâu, deploy ra sao | deployment + CI/CD |
| `05-danh-gia.md` | Chỗ nào đáng lo | bảng rủi ro theo P0/P1/P2 |
| `06-hieu-nang.md` | Vì sao chậm *(chỉ ở chế độ hiệu-năng)* | xem `references/hieu-nang.md` |

Ít repo hoặc hệ thống nhỏ thì gộp bớt — nhưng **giữ nguyên thứ tự câu hỏi**: là gì → gồm gì → chạy ra sao →
dữ liệu → deploy → lo gì.

---

## Đầu mỗi file

Ở `README.md`, ngay dưới tiêu đề — ghi rõ phạm vi và giới hạn, đừng để người đọc tự đoán:

```markdown
> Nguồn: đọc trực tiếp code của N repo (<ngày>). Commit: <sha>.
> Quyền có được: <có/không kết nối DB, có/không đọc .env, có/không xem được production>.
> Nhãn: ✅ đã xác minh (có file:line) · 📐 suy ra (cần đo mới biết mức độ).
```

Cuối mỗi file cùng bộ: một dòng `[← về mục lục](README.md)` ở đầu file, để đọc từ giữa vẫn quay lại được.

---

## Viết cho ai

Người đọc là **kỹ sư mới vào dự án** và **người sắp ra quyết định kỹ thuật**. Nghĩa là:

- Nói cơ chế, đừng liệt kê file. "Lịch cron nằm ở Terraform, không nằm trong code" đáng giá hơn một bảng 30
  tên file.
- Mỗi bảng/hình phải trả lời một câu hỏi có thật. Bảng liệt kê cho đủ thì bỏ.
- **Luôn kèm hệ quả.** Không phải "chỉ có 1 replica" mà "chỉ có 1 replica, và đó là bắt buộc chứ không phải
  tiết kiệm — vì tiến trình này vừa chạy API vừa chạy cron; nhân đôi là chạy trùng".
- Chỗ nguy hiểm dùng 🔴 và nói thẳng. Tài liệu lịch sự quá thì người đọc lướt qua đúng chỗ cần dừng.
- Tiếng Việt cho câu chữ, **giữ nguyên tiếng Anh** cho tên file/bảng/cột/hàm.

---

## Ba mục hay bị quên mà giá trị nhất

**1. "Điểm dễ nhầm"** — chỗ hai thứ trông giống nhau nhưng khác hẳn. Ví dụ hai hệ phân quyền song song; hai
bảng `ac_*` và `rp_*`; module tên `migration` không liên quan gì tới schema migration. Đây là thứ làm mất
nhiều giờ debug nhất của người mới, và không đọc code nào ra được.

**2. "Câu hỏi mở"** — cái chưa xác định được, và **vì sao**. Phân biệt rõ "không đọc kỹ" với "không thể biết
từ repo" (cấu hình thật trên AWS, hạn mức nhà cung cấp cấp cho, giá trị secret). Nói rõ giới hạn làm tài liệu
đáng tin hơn, không phải kém đi.

**3. "Không phải nguyên nhân"** — ở tài liệu hiệu năng. Chặn trước những hướng đi sai phổ biến.

---

## Trước khi commit

```bash
node .claude/skills/kap-construct/scripts/check-docs.mjs docs/architecture
for d in <các-repo-chỉ-đọc>; do
  n=$(cd "$d" && git status --porcelain | wc -l)
  [ "$n" != "0" ] && echo "⚠️  $d bị sửa $n file"
done
```

Commit message nói **kết luận**, không nói đã làm những bước gì. Người đọc `git log` sau này cần biết tài liệu
này *phát hiện ra cái gì*.
