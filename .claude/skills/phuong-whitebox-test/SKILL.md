---
name: phuong-whitebox-test
description: Use when the user asks for white-box testing of source code — "kiểm thử hộp trắng", "kiểm thử nhị phân", control flow graph / CFG, cyclomatic complexity / V(G) / McCabe, basis paths, branch or condition coverage, or test-case data derived from code — including a request for just one of those steps.
---

# Kiểm thử hộp trắng — nhị phân (5 bước thiết kế + Bước 6 thực thi)

## Tổng quan
**Nhị phân = mỗi điều kiện nguyên tử trong code phải được kiểm ở cả nhánh Đ và S.** Mọi con số (nút, V(G), đường, bộ dữ liệu)
tính ở **một mức duy nhất: mức điều kiện con**. Không đưa nhiều con số ("mức quyết định / mức điều kiện / theo ESLint")
cho người dùng tự chọn. Vì nút đã nguyên tử nên C1 (phủ nhánh) ≡ C2 (phủ điều kiện) — ghi rõ điều này, đừng tách 2 tiêu chí.

**Bước 1–5 là THIẾT KẾ:** không viết, sửa hay chạy file test mới; không sửa code. **Bước 6** (viết test, chạy, ghi
PASS/FAIL) chỉ làm khi người dùng gọi đích danh. Không bước nào được chạy lệnh DB, commit, hay sửa code ứng dụng.

**Thư mục kết quả — cố định theo từng project, mỗi file nguồn 1 thư mục riêng.** Trước Bước 1, đọc `CLAUDE.md` ở gốc
project tìm dòng `Thư mục kết quả whitebox: <đường dẫn>`. Chưa có ⇒ hỏi người dùng (gợi ý `<gốc project>/test-output/whitebox/`),
rồi **thêm đúng dòng đó vào `CLAUDE.md`** (tạo file nếu chưa có) để lần sau dùng luôn — đây là file duy nhất ngoài thư mục kết
quả được phép ghi ở Bước 1–5. Dưới đây `<KQ>` = đường dẫn đó.
```
<KQ>/
├── tong-hop.md                         sổ tổng: mỗi file nguồn, mỗi lần chạy Bước 6 = 1 dòng
└── <chủ-đề>/                           vd thanh-toan (viết thường, gạch nối)
    └── <tên-file-nguồn>/               bỏ đuôi file, vd payment.controller, OrderTable, order_service
        └── buoc-1-ma-nguon.md … buoc-6-ket-qua.md
```
Mỗi controller / service / guard / component được kiểm có thư mục riêng; **không gộp nhiều file nguồn vào chung một bộ
`buoc-*`**. Đơn vị nằm trong file nào thì đồ thị, đường, dữ liệu, kết quả của nó nằm trong thư mục file đó. File A gọi
hàm của file B ⇒ ở A coi đó là 1 nút (lời gọi có thể ném) và trỏ link sang thư mục của B, không vẽ lại. Không lưu kết quả
ở chỗ nào khác.

**Nhịp làm & ghi file:**
- Làm liền đúng các bước người dùng gọi (1 bước, vài bước hay cả 6), trình kết quả, rồi chờ — không tự làm bước kế tiếp.
- Bản nháp (và đầu vào cho script) để ở scratchpad. Bước 1–5: chỉ ghi vào thư mục kết quả khi người dùng duyệt (plan mode
  ⇒ ghi vào plan trước). Bước 6: ghi ngay sau khi chạy — PASS/FAIL là số đo, không cần duyệt.
- Người dùng nói rõ bỏ một việc (vd "khỏi đo coverage") ⇒ bỏ, và ghi hệ quả ("chưa có mốc độ phủ — bảng đối chiếu Bước 4
  để trống"). Áp lực thời gian không phải lý do tự bỏ.

## Luật dựng đồ thị (Bước 2)
Nguyên tắc chung cho mọi ngôn ngữ: **mỗi điều kiện nguyên tử = 1 nút quyết định** (vế của toán tử ngắn mạch, toán tử
null-safe, nhánh `switch`/`match`, lời gọi ném lỗi nghiệp vụ). Biểu thức không rẽ nhánh, callback duyệt tập hợp và lỗi hạ
tầng ngẫu nhiên **không** thành nút. Ngôn ngữ chưa có bảng ⇒ áp đúng nguyên tắc này và ghi rõ cách quy đổi vào Bước 2.

### TS/JS (Node, React)
| Cấu trúc trong code | Thành nút quyết định |
|---|---|
| `if` / `?:` / `while` / `return` sớm có điều kiện / JSX `{c && <X/>}` / `disabled={!c}` | 1 nút |
| `a && b`, `a \|\| b` | 1 nút **mỗi vế** (kể cả vế là lời gọi như `!set.has(x)` hay `!!x`), nối theo thứ tự ngắn mạch |
| `x ?? y`, `x?.y` | 1 nút mỗi toán tử, **kể cả trong chuỗi thông báo**; Đ = vế trái null/undefined (với `?.`: Đ ⇒ giá trị `undefined`, rồi đi tiếp vào điều kiện bao ngoài) |
| `switch` k nhánh | k − 1 nút so sánh nối chuỗi |
| Lời gọi **thật sự có thể ném** (đọc cài đặt, vd `prefetchQuery` nuốt lỗi ⇒ không) mà ném là hành vi nghiệp vụ (guard, `assert…`, `canAccess…`, JWT) | 1 nút: Đ = ném ⇒ nút ra lỗi (403 / 401…) |
| `Promise.all([gọiNém1, gọiNém2])` | 1 nút mỗi lời gọi ném được, theo thứ tự viết |
| Hàm private cùng file được gọi | 1 nút ở chỗ gọi; nếu hàm đó cũng trong phạm vi ⇒ vẽ đồ thị riêng |
| Thân `useEffect` / `useCallback` / handler | đồ thị riêng (chạy ở thời điểm khác lúc render) |
| Biểu thức đứng riêng không rẽ nhánh: `return a.includes(b)`, callback `find` / `map` / `forEach` | **không** thành nút — dữ liệu Bước 5 phủ 0 / 1 / nhiều phần tử |
| Lỗi hạ tầng ngẫu nhiên (DB sập, mạng) | không vẽ |

### Python
| Cấu trúc | Thành nút |
|---|---|
| `if` / `elif` (mỗi nhánh) / `x if c else y` / `while` / `assert` nghiệp vụ | 1 nút |
| `a and b`, `a or b` | 1 nút mỗi vế, theo thứ tự ngắn mạch |
| `for … else` | 1 nút (vòng có chạy hết không `break`) |
| Comprehension có `if` | không thành nút (như callback) — dữ liệu Bước 5 phủ 0 / 1 / nhiều phần tử |
| `match` k `case` | k − 1 nút nối chuỗi (`case _` là nhánh còn lại) |
| `raise` nghiệp vụ / lời gọi có thể ném (`get_object_or_404`, `Depends` kiểm quyền…) | 1 nút: Đ = ném |
| `try/except` | 1 nút mỗi `except` bắt lỗi nghiệp vụ; `finally` không thành nút |

### Java / C#
| Cấu trúc | Thành nút |
|---|---|
| `if` / `?:` / `while` / `do…while` / `for` có điều kiện | 1 nút |
| `&&`, `\|\|` | 1 nút mỗi vế |
| C#: `?.`, `??`, `??=` | 1 nút mỗi toán tử |
| `switch` / switch expression / pattern `is` có điều kiện | k − 1 nút; `when` guard = thêm 1 nút |
| `throw` nghiệp vụ / lời gọi ném (`orElseThrow`, `[Authorize]`/`@PreAuthorize`, validator) | 1 nút: Đ = ném |
| `catch` bắt lỗi nghiệp vụ | 1 nút mỗi `catch` |
| Stream/LINQ (`filter`, `Where`, `map`), `Optional.map` | không thành nút; `Optional.orElse…` có giá trị mặc định = 1 nút |

### Go
| Cấu trúc | Thành nút |
|---|---|
| `if` (kể cả `if err != nil`) / `for` có điều kiện | 1 nút |
| `&&`, `\|\|` | 1 nút mỗi vế |
| `switch` / type switch / `select` k nhánh | k − 1 nút |
| Lời gọi trả `error` được kiểm ngay | nút nằm ở `if err != nil`, không đếm thêm ở lời gọi |
| `panic` nghiệp vụ | 1 nút; `recover` trong `defer` = 1 nút |

### PHP
| Cấu trúc | Thành nút |
|---|---|
| `if` / `elseif` / `?:` / `while` | 1 nút |
| `&&`, `\|\|`, `and`, `or` | 1 nút mỗi vế |
| `??`, `??=`, `?->`, `?:` rút gọn | 1 nút mỗi toán tử |
| `switch` / `match` k nhánh | k − 1 nút |
| `throw` nghiệp vụ / lời gọi ném (`abort(403)`, `authorize()`, `findOrFail`) | 1 nút: Đ = ném |
| `catch` bắt lỗi nghiệp vụ | 1 nút mỗi `catch` |

Mỗi nút đánh số; bảng kèm theo: số nút · điều kiện nguyên văn · **file:dòng đọc lại từ code hiện tại** (không lấy từ trí nhớ
hay chat cũ). Mermaid: nút quyết định dạng `{"…"}`, nhãn cạnh `Đ` / `S`, nhãn đặt trong ngoặc kép.

## Sản phẩm từng bước
| Bước | File | Phải có |
|---|---|---|
| 1 Mã nguồn | `buoc-1-ma-nguon.md` | phạm vi; bảng đơn vị: file:dòng, điều kiện nguyên văn, phụ thuộc cần mock; lớp chặn phía trước (BE: DTO / Joi / guard; FE: route, menu, nút cha ẩn); test hiện có; độ phủ đo thật làm mốc |
| 2 CFG | `buoc-2-cfg.md` | mermaid từng đơn vị + bảng nút quyết định (ghi MỚI/CŨ từng nút); tổng **nút quyết định** P, số nhánh = 2 × P |
| 3 V(G) | `buoc-3-do-phuc-tap.md` | bảng N, E, P, **P+1 và E−N+2** từ script; ngưỡng McCabe: 1–10 đơn giản · 11–20 vừa · 21–50 phức tạp · >50 khó kiểm |
| 4 Đường | `buoc-4-duong-di.md` | tiêu chí; ΣV(G) đường cơ sở có nhãn; C1 tối đa; bảng nhánh ↔ đường ↔ test hiện có |
| 5 Dữ liệu | `buoc-5-du-lieu-thu.md` | quy ước mock; mỗi đường khả thi 1 bộ: đầu vào + mock + kết quả mong đợi + **nguồn yêu cầu**; đối chiếu test hiện có; mục "Phát hiện hộp trắng" |
| 6 Thực thi | `buoc-6-ket-qua.md` + 1 dòng `tong-hop.md` | xem mục "Bước 6" |

**Phạm vi (Bước 1):** chỉ code mới/sửa so với `git -C <repo> diff HEAD` của **từng repo** trong workspace — kể cả repo lồng (dò
bằng `find . -maxdepth 3 -name .git -not -path '*/node_modules/*'`; `git diff` ở repo gốc không thấy repo lồng). Không có git ⇒
hỏi người dùng đơn vị cần kiểm, mọi nút ghi MỚI. Code dùng chung = phụ thuộc cần mock. Người dùng chỉ định đơn vị không có diff ⇒ vẫn kiểm, mọi phát hiện ghi CŨ. File lẫn MỚI và CŨ ⇒
ghi MỚI/CŨ theo từng nút; thay đổi chỉ ở dữ liệu (map cấu hình…) mà làm đổi nhánh của nút CŨ ⇒ ghi rõ ở nút đó.

**Đếm bằng máy:** `node <thư-mục-skill>/cfg-count.js <bản-nháp>/buoc-2-cfg.md` — in N, E, P, V(G); thoát 1 nếu 2 công thức
lệch, nút quyết định không đủ 2 cạnh ra, hoặc không thấy đồ thị. Lỗi ⇒ sửa đồ thị, không sửa số.

**Đo độ phủ (chỉ đọc, ~30 giây):** đọc cấu hình test của project trước (`package.json`, `jest.config.*`, `vitest.config.*`,
`pytest.ini`/`pyproject.toml`, `pom.xml`/`build.gradle`, `*.csproj`, `phpunit.xml`…) để biết công cụ, `rootDir`, tên file test.
Chỉ chạy **1 file test**, kết quả phủ ghi ra **ngoài repo** (scratchpad). Ví dụ:
```
# jest (rootDir = src)
npx jest --runInBand --testPathPattern "<tên-spec>" --coverage --collectCoverageFrom=<modules/…/file.ts> --coverageDirectory=<scratchpad>/cov
# react-scripts (rootDir = gốc app)
npx react-scripts test --watchAll=false --testPathPattern "<tên-test>" --coverage --collectCoverageFrom=<src/…/file.tsx> --coverageDirectory=<scratchpad>/cov
# vitest
npx vitest run <file-test> --coverage --coverage.include=<src/…/file.ts> --coverage.reportsDirectory=<scratchpad>/cov
# pytest
pytest <tests/test_x.py> --cov=<package.module> --cov-branch --cov-report=term-missing
# Java (Maven + JaCoCo đã cấu hình trong pom)
mvn -q test -Dtest=<TênTest> jacoco:report
# .NET
dotnet test --filter "FullyQualifiedName~<TênTest>" --collect:"XPlat Code Coverage" --results-directory <scratchpad>/cov
# Go
go test ./<gói>/ -run <TênTest> -covermode=count -coverprofile=<scratchpad>/cov.out
# PHPUnit
vendor/bin/phpunit --filter <TênTest> --coverage-text
```
jest: `collectCoverageFrom` tương đối với `rootDir`; không để đường dẫn spec đứng sau cờ dạng mảng (sẽ chạy cả bộ test). Công cụ
cần cài thêm (`pytest-cov`, `@vitest/coverage-v8`, JaCoCo…) mà project chưa có ⇒ hỏi người dùng, không tự cài.

**Công cụ đo phủ (Istanbul, coverage.py, JaCoCo…) chỉ là cận dưới, đối chiếu một chiều.** Nhánh công cụ báo chưa chạy ⇒ phải
trỏ được tới 1 đường (thiếu ⇒ bổ sung đồ thị). Công cụ báo 100% **không** có nghĩa nhị phân đủ: nó không thấy lời gọi ném,
`&&`/`and`/`??` thường chỉ đếm số lần mỗi vế được tính (Go `-covermode` chỉ đo câu lệnh, không đo nhánh).
Bảng phủ nhị phân lập theo nút đồ thị, đọc từng test xem đi nhánh nào.

## Đường cơ sở (Bước 4)
Chọn 1 đường gốc khả thi, mỗi đường sau **lật đúng 1 nút** so với một đường đã có ⇒ đủ ΣV(G) đường độc lập. Không làm phủ mọi
đường. Mỗi đường 1 nhãn:
- **khả thi** — đạt được qua API/UI thật.
- **chỉ khả thi mức unit** — không đạt qua API/UI vì lớp chặn trước (DTO `min(1)`, Joi, guard) hoặc vì cách nối dây (guard
  chạy 1 lần/request…); ghi rõ lý do.
- **không khả thi** — không đầu vào nào đạt được; chứng minh bằng code. Nhánh chỉ có ở đường loại này bị trừ khỏi trần
  ⇒ ghi "C1 tối đa = x/y".

## Kết quả mong đợi (Bước 5)
Nguồn theo thứ tự: quyết định người dùng (chat), plan, ADR, wiki của project (nếu có, vd `lmm-wiki/`), tài liệu yêu cầu. Doc-comment **ghi lại quyết định của người
dùng** dùng được nhưng đánh dấu `(nguồn: comment)`. Hành vi code hiện tại và spec cũ **không** phải nguồn.
Yêu cầu không nói (vd câu chữ thông báo 403) ⇒ chỉ khẳng định điều yêu cầu có (mã 403), đánh dấu `(*) cần xác nhận`.
Hành vi vô lý hoặc lệch yêu cầu ⇒ ghi vào "Phát hiện hộp trắng" (CŨ/MỚI, mức API hay chỉ unit), hỏi người dùng — không
biến thành expected.

## Bước 6 — Thực thi và ghi PASS/FAIL
1. **Viết test** cho các bộ Bước 5 mà người dùng chọn (mặc định: bộ "chưa có test"), vào spec/test **sẵn có** cạnh code. Tên
   test bắt đầu bằng mã bộ: `it('6-1 phạm vi all ⇒ cho qua', …)`. Expected **chép đúng từ Bước 5** — không chỉnh cho khớp code.
   Mỗi test khẳng định cả **nhánh đã đi** (hàm được gọi / không được gọi), không chỉ kết quả cuối — bắt kết quả trước
   (`const r = await fn().then(() => 'ok', (e) => e)`), khẳng định nhánh, rồi mới khẳng định `r`, để ca FAIL vẫn cho biết
   code đã đi đường nào. Bộ người dùng thêm mới ở bước này ⇒ gắn nhãn khả thi như Bước 4 (kiểm lớp chặn phía trước).
2. **Chạy** spec đó (cả test cũ lẫn mới) kèm độ phủ bằng lệnh ở trên; mốc "trước" và "sau" phải cùng config và cùng tập
   spec, so theo **dải dòng của đơn vị** (đổi config là tổng nhánh công cụ đo phủ đổi theo).
3. **Ca FAIL:** đọc lý do.
   - Test viết sai (mock thiếu, import sai) ⇒ sửa test, chạy lại, ghi "đã sửa test: …".
   - Code lệch expected ⇒ **FAIL thật**: giữ nguyên test, **không** sửa code, **không** `.skip` / `it.failing`, **không** đổi
     expected. Ghi vào "Phát hiện" (CŨ/MỚI) và hỏi người dùng: sửa code hay chốt lại yêu cầu.
4. **Ghi `buoc-6-ket-qua.md`:**
   - ngày giờ, nhánh git + repo, lệnh chạy lại nguyên văn;
   - bảng: mã bộ · đường mong đợi · đường thực đi (nếu khác) · nhánh phủ · **PASS / FAIL** · ghi chú (lý do fail, đã sửa
     test gì);
   - tổng: x PASS / y FAIL / z chưa viết;
   - độ phủ trước → sau: nhị phân (theo nút đồ thị, so với C1 tối đa) và công cụ đo phủ (riêng);
   - file test đã thêm/sửa (file:dòng);
   - "Phát hiện": lỗi code (CŨ/MỚI, mức API hay chỉ unit) **và** chỗ tài liệu Bước 1–5 sai (vd đồ thị thiếu nút) — chỉ ghi
     và đề xuất đính chính, không tự sửa file bước trước khi người dùng chưa đồng ý.
5. **Thêm vào `<KQ>/tong-hop.md` mỗi file nguồn 1 dòng** (tạo file kèm dòng tiêu đề nếu chưa có):
   `| ngày | chủ đề | file nguồn | PASS | FAIL | nhị phân x/y | [buoc-6](<chủ-đề>/<tên-file-nguồn>/buoc-6-ket-qua.md) |`
6. Không commit. Báo người dùng: số PASS/FAIL, ca FAIL thật, đường dẫn file kết quả.

## Lý do hay gặp và sự thật
| Lý do | Sự thật |
|---|---|
| "Ngoại lệ không tính vào McCabe, thêm test ngoại lệ sau" | Ném 403 là nhánh nghiệp vụ ⇒ nút quyết định, tính vào V(G). |
| "Đưa cả mức quyết định lẫn mức điều kiện cho đủ" | Nhị phân = mức điều kiện. Một con số. |
| "`??` chỉ ở chuỗi thông báo, không đổi luồng" | Vẫn là điều kiện có Đ/S. Vẽ vào. |
| "Công cụ đo phủ báo 100% rồi" | Cận dưới thôi. Đối chiếu theo nút đồ thị. |
| "Gấp, bỏ đo coverage" | 1 lệnh ~30 giây. Chỉ bỏ khi người dùng nói rõ. |
| "Viết luôn spec chạy thử cho chắc" | 5 bước là thiết kế. Viết test khi được bảo. |
| "Thêm ca kiểm thư viện (`includes` phân biệt hoa thường…)" | Ngoài phạm vi: chỉ kiểm điều kiện của code đang xét. |
| "Expected = message trong code" | Expected từ yêu cầu; code là đối tượng bị kiểm. |
| "Test fail, chỉnh expected / `.skip` cho xanh" | FAIL thật là kết quả cần báo. Giữ test, ghi FAIL, hỏi người dùng. |
| "Tiện sửa luôn code cho test pass" | Bước 6 chỉ đo. Sửa code là việc riêng khi người dùng bảo. |

## Dấu hiệu dừng lại
- Có 2 con số V(G) cho cùng một đơn vị.
- Số dòng chưa mở file kiểm lại.
- Tổng ở file sau khác file trước ⇒ đếm lại bằng script, sửa file trước, ghi chú chỗ đính chính.
- Đang tạo file `.spec` / `.test` khi người dùng chưa gọi Bước 6, hoặc lệnh test chạy hơn 1 phút (đang chạy cả bộ).
- Đang sửa file code ứng dụng (không phải test) ở bất kỳ bước nào.
- Kết quả sắp ghi ra ngoài `<KQ>/<chủ-đề>/<tên-file-nguồn>/`, `<KQ>` chưa chốt trong `CLAUDE.md`, hoặc một file `buoc-*` đang chứa đơn vị
  của 2 file nguồn trở lên.
