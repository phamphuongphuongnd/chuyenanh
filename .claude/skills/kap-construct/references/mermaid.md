# Quy ước biểu đồ mermaid

Đọc **trước khi vẽ**. Sửa thử-sai từng vòng rất tốn thời gian — bộ tài liệu đầu tiên mất 5 vòng sửa chỉ vì
không biết mấy luật dưới đây.

---

## Đã thử gì, kết quả ra sao

Bảng này **không phải suy đoán** — chạy thật qua `mermaid.parse()` (mermaid v10, phiên bản GitHub dùng).

| Viết thế này | Kết quả | Ghi chú |
|---|---|---|
| `Note over A: xong; tiếp` (sequenceDiagram) | ❌ **VỠ** | `;` là dấu kết thúc câu lệnh |
| `A->>B: xong; tiếp` (sequenceDiagram) | ❌ **VỠ** | như trên |
| Nhãn **mở đầu** bằng backtick — `A["` + backtick + `code…` | ❌ **VỠ** | bị hiểu là markdown-string |
| Backtick **ở giữa** nhãn — `A["x ` + backtick + `code` + backtick + ` y"]` | ✅ được | chỉ vị trí đầu mới vỡ |
| `A["a; b"]` (flowchart) | ✅ được | chỉ sequenceDiagram mới vỡ vì `;` |
| `Note over A: iat < changedAt` | ✅ được | `<` và `>` **không** phải vấn đề |
| `Note over A: dòng1<br/>dòng2` | ✅ được | `<br/>` là cách xuống dòng đúng |
| `A["**đậm**"]` | ⚠️ parse được, **hiện ra dấu sao** | markdown không render trong nhãn |
| `A["*(nghiêng)*"]` | ⚠️ parse được, **hiện ra dấu sao** | như trên |
| `class X { «view» }` | ✅ được | không cần tránh |
| `class X { +t : a \| b }` | ✅ được | không cần tránh |
| `class X { <<view>> }` | ✅ được | cách chuẩn để ghi stereotype |

**Rút gọn thành 3 luật:**

1. Trong `sequenceDiagram`: **không dùng `;`** ở bất kỳ đâu. Dùng `,`.
2. Nhãn **không được mở đầu** bằng backtick.
3. **Không dùng `**` hay `*...*`** trong nhãn — parse được nhưng hiện nguyên dấu sao. Muốn nhấn mạnh thì tách
   dòng bằng `<br/>` hoặc dùng emoji.

Xuống dòng luôn dùng `<br/>`.

---

## Kiểm tra

**Luôn chạy trước khi commit:**

```bash
node .claude/skills/kap-construct/scripts/check-docs.mjs docs/architecture
```

Nhanh, không cần cài gì, bắt 3 luật trên + liên kết hỏng + anchor hỏng.

**Muốn chắc chắn 100%** (parse thật bằng chính mermaid):

```bash
mkdir -p /tmp/mmd && cd /tmp/mmd && npm i mermaid@10 jsdom
node /đường/dẫn/.claude/skills/kap-construct/scripts/parse-mermaid.mjs /đường/dẫn/docs/architecture
```

Phải chạy **từ thư mục đã cài** (`/tmp/mmd`) — script tự phân giải module từ cwd.

> ⚠️ Nếu tự viết script sửa hàng loạt nhãn mermaid: **chỉ sửa bên trong khối ```mermaid**, và **grep lại sau
> khi sửa**. Một lệnh bỏ dấu `*` từng ăn nhầm vào nội dung thật, biến `user_*` thành `user_`.

---

## Anchor trong liên kết nội bộ

GitHub sinh anchor bằng: đổi chữ thường → bỏ dấu câu → **mỗi khoảng trắng thành một gạch nối**.

Không gộp khoảng trắng liên tiếp. Nên `## 3. \`crawler\` — service crawl` sinh ra
`#3-crawler--service-crawl` — **hai gạch nối**, vì em dash bị bỏ và hai khoảng trắng quanh nó thành hai gạch.

Dấu tiếng Việt được **giữ nguyên**: `## Bốn tầng phân quyền` → `#bốn-tầng-phân-quyền`.

`check-docs.mjs` đã cài đúng luật này. Đừng tự viết lại bằng `\s+` — sẽ báo lỗi giả.

---

## Chọn loại biểu đồ

| Muốn diễn đạt | Dùng |
|---|---|
| Ai gọi ai, hệ thống gồm gì | `flowchart TB` / `LR` |
| Trình tự theo thời gian, ai chờ ai | `sequenceDiagram` |
| Entity và quan hệ | `classDiagram` |
| Vòng đời trạng thái | `stateDiagram-v2` |

**Vài mẹo dùng được ngay:**

- `sequenceDiagram` — nhóm các chặng bằng `rect rgb(240,246,255)` kèm `Note over`. Luồng nhiều chặng nối bằng
  hàng đợi đọc dễ hơn hẳn.
- `autonumber` ở đầu sequence để đánh số bước, tiện khi viết văn bản tham chiếu "bước 4".
- `flowchart` — `A & B --> C` gộp nhiều nguồn, đỡ rối.
- Tô đỏ chỗ nguy hiểm: `style X fill:#c00,color:#fff` — mắt tìm ra ngay.
- Đừng nhét quá ~15 node vào một hình. Nhiều hơn thì tách thành 2 hình theo tầng.

## Đừng vẽ khi

- Nội dung là danh sách hoặc bảng tra cứu → dùng bảng markdown, đọc nhanh hơn nhiều.
- Chuỗi bước tuyến tính không rẽ nhánh → dùng danh sách đánh số.
- Hình chỉ vẽ lại y hệt đoạn văn ngay trên nó → bỏ hình.

Một hình chỉ xứng đáng khi nó cho thấy **thứ mà câu chữ khó diễn đạt**: cái gì song song, cái gì chờ cái gì,
vòng lặp ở đâu, khoá chặn ai.
