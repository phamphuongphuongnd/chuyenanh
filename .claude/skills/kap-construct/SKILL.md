---
name: kap-construct
description: Use when a system spans several repositories and the user asks for its overall architecture, a design or UML document set, why the system is slow, or a performance bottleneck root-cause analysis — including requests phrased as "kiến trúc tổng thể", "thiết kế hệ thống", "vẽ sơ đồ / UML / sequence diagram", "khảo sát các project", "hệ thống chạy chậm", "tối ưu hiệu năng", "tìm nút thắt". Also use when the question is how repos connect to each other (API, hàng đợi, cron, DB dùng chung) rather than what features one codebase has.
---

# kap-construct

Khảo sát **nhiều repo tạo thành một hệ thống**, rồi sinh ra bộ tài liệu kiến trúc và/hoặc phân tích hiệu năng
mà một kiến trúc sư sẽ giao.

**Khác `project-map` thế nào:** `project-map` mô tả **một** codebase theo từng tính năng. Skill này mô tả
**đường nối giữa các repo** — cái gì gọi cái gì, qua kênh nào, và ở đâu thì tắc. Hai skill bổ trợ nhau, không
thay thế nhau.

## Nguyên tắc cốt lõi

**Mọi câu khẳng định phải truy được về `file:line`, hoặc phải tự khai là suy luận.**

Bộ tài liệu này sẽ được dùng để ra quyết định kỹ thuật tốn tiền. Một câu đoán mò trộn lẫn giữa các câu đã xác
minh làm hỏng độ tin cậy của cả tài liệu. Nên mỗi kết luận mang đúng một trong hai nhãn:

- ✅ **Đã xác minh** — đã mở file đọc, có `file:line`. Đúng dù chưa chạy.
- 📐 **Suy ra** — cơ chế chắc đúng, nhưng mức độ phụ thuộc dữ liệu/tải thật. Phải kèm cách đo.

Không có nhãn thứ ba. "Chắc là", "có lẽ", "thường thì" mà không có nhãn 📐 là vi phạm.

## Chọn chế độ

Nói rõ đang chạy chế độ nào trong một câu trước khi bắt đầu.

| Người dùng hỏi | Chế độ | Sinh ra |
|---|---|---|
| kiến trúc, thiết kế, sơ đồ, UML, khảo sát các project | **kiến-trúc** | `README` + 5 file (xem `assets/outline.md`) |
| chạy chậm, hiệu năng, nút thắt, tối ưu | **hiệu-năng** | 1 file `06-hieu-nang.md` |
| cả hai, hoặc không rõ | hỏi một câu rồi làm | |

Chế độ hiệu-năng vẫn cần hiểu kiến trúc, nhưng **không** viết lại bộ tài liệu kiến trúc — đọc bộ có sẵn.

## Quy trình

### Bước 0 — Hỏi trước khi đào (bắt buộc, tốn 1 phút)

Hỏi **ngay từ đầu**, đừng phát hiện giữa chừng:

1. **Có kết nối DB đọc được không?** Không có DB thì mọi kết luận về khối lượng dữ liệu và độ chậm chỉ ở mức
   📐. Biết sớm để nói trước với người dùng, thay vì viết xong mới hạ cấp kết luận.
2. **Triệu chứng cụ thể là gì?** ("màn X chậm" vs "cả hệ thống thỉnh thoảng đứng" dẫn tới hai hướng đào hoàn
   toàn khác nhau).
3. **Ghi kết quả vào repo nào, nhánh nào?** Các repo còn lại mặc định **chỉ đọc**.

### Bước 1 — Đọc tài liệu có sẵn TRƯỚC khi đọc code

Đây là bước tiết kiệm thời gian nhiều nhất, và hay bị bỏ qua nhất.

```bash
ls docs/project-map/ lmm-wiki/ docs/architecture/ 2>/dev/null
cat docs/project-map/index.md lmm-wiki/index.md 2>/dev/null
```

Tài liệu cũ cho biết **chỗ nào đã từng đau** — nhanh hơn nhiều so với tự dò. Nhưng nó có thể lỗi thời: **mọi
con số lấy từ tài liệu cũ phải ghi rõ nguồn và ngày đo**, không được trình bày như vừa tự xác minh.

### Bước 2 — Khảo sát theo checklist, không đọc lan man

**Đọc `references/khao-sat.md`** — checklist theo tầng, kèm lệnh chạy sẵn.

Đọc theo checklist chứ không đọc theo cảm hứng. Trong lần dựng bộ tài liệu đầu tiên, phát hiện nghiêm trọng
nhất (`REFRESH MATERIALIZED VIEW` chạy trong request người dùng) chỉ tìm ra **do tình cờ** đọc hết một file.
Checklist tồn tại để chuyện đó không còn là may rủi.

Ở chế độ hiệu-năng, thêm **`references/hieu-nang.md`** — danh mục nghi phạm + câu lệnh đo.

### Bước 3 — Viết

Theo bộ khung ở `assets/outline.md`. Quy ước hình vẽ ở `references/mermaid.md` — **đọc trước khi vẽ**, đừng
vẽ xong mới sửa.

### Bước 4 — Kiểm tra trước khi commit (bắt buộc)

```bash
node .claude/skills/kap-construct/scripts/check-docs.mjs docs/architecture
```

Exit code khác 0 ⇒ **chưa được commit**. Muốn chắc chắn 100% thì parse thật (xem `references/mermaid.md`).

Ngoài ra tự kiểm ba việc:

- [ ] Mọi `file:line` đã **mở file xác minh**, không viết từ trí nhớ.
- [ ] Các repo khác vẫn sạch: `git status --porcelain` rỗng ở từng repo chỉ-đọc.
- [ ] Không sao chép giá trị secret vào tài liệu (kể cả DATABASE_URL, kể cả một phần).

## Bốn cái bẫy đã sập thật

Bốn cái này lấy từ lần chạy thật, không phải giả định.

| Bẫy | Chuyện đã xảy ra | Luật rút ra |
|---|---|---|
| **Tin script tự viết** | Script đếm index trả 6 bảng, sửa lại thì trả 33 bảng có dương tính giả (bỏ sót một migration dùng raw `CREATE INDEX`) | Script chỉ dùng để **khoanh vùng**. Con số đưa vào tài liệu phải **xác minh tay từng dòng**. |
| **Sửa hàng loạt bằng regex** | Lệnh bỏ dấu `*` trong nhãn mermaid ăn luôn vào nội dung: `user_*` thành `user_` | Sửa hàng loạt xong phải **grep lại** các mẫu dễ bị ăn nhầm (`*`, `_`, backtick). |
| **Trích dẫn từ trí nhớ** | Gán file SQL 319 dòng của `report_monthly` cho `report_daily` — hai view khác nhau, phải sửa sau khi đã viết | Trước khi viết một `file:line`, **mở lại file đó**. |
| **Tin công cụ kiểm tra của chính mình** | Checker anchor báo lỗi giả vì gộp khoảng trắng, trong khi GitHub không gộp (em dash sinh `--`) | Công cụ mới phải **thử trên ca hỏng cố ý** trước khi tin kết quả "sạch". |

## Cờ đỏ — dừng lại và làm lại

- Viết "khoảng X triệu dòng" mà chưa mở DB và cũng chưa dẫn nguồn tài liệu cũ.
- Kết luận một đoạn code là nút thắt mà chưa đọc nơi gọi nó.
- Sửa mermaid bằng cách thử-sai nhiều vòng → dừng, đọc `references/mermaid.md`.
- Sắp commit mà chưa chạy `check-docs.mjs`.
- Sắp nói "đã tối ưu xong" mà chưa đo lại.

## Điều phải nói với người dùng ở cuối

Nếu không đo được (không có DB, không có APM), **nói thẳng ngay trong câu trả lời và ngay đầu tài liệu**.
Một bộ phân tích hiệu năng không kèm số đo là một **danh sách nghi phạm đã thu hẹp**, không phải chẩn đoán —
trình bày nó đúng như vậy, và luôn kèm phần "chạy gì để xác nhận".
