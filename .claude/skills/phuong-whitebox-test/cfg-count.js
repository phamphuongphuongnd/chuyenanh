#!/usr/bin/env node
// Đếm N, E, P và V(G) cho mọi khối ```mermaid flowchart trong 1 file markdown — để Bước 3 không đếm tay.
// Quy ước: nút quyết định = nút hình thoi {…}; mỗi nút không có cạnh ra (nút ra) trừ 1 được nối về "Kết thúc"
// bằng 1 cạnh ảo. Thoát 1 nếu: không thấy đồ thị nào, P + 1 ≠ E − N + 2, hoặc nút quyết định không đúng 2 cạnh ra.
// Dùng: node cfg-count.js buoc-2-cfg.md
const fs = require('fs')
const file = process.argv[2]
if (!file) {
  console.error('Dùng: node cfg-count.js <file.md>')
  process.exit(2)
}
const md = fs.readFileSync(file, 'utf8').split('\r\n').join('\n')
const blocks = [...md.matchAll(/```mermaid\n([\s\S]*?)```/g)].map((m) => ({ code: m[1], at: m.index }))
const headings = [...md.matchAll(/^#{2,4} (.+)$/gm)].map((m) => ({ at: m.index, text: m[1] }))
if (!blocks.length) {
  console.error('Không thấy khối ```mermaid nào — kiểm lại file.')
  process.exit(1)
}
let bad = 0
const rows = []
for (const { code, at } of blocks) {
  const title = (headings.filter((h) => h.at < at).pop() || { text: '?' }).text.slice(0, 50)
  const nodes = new Set()
  const decisions = new Set()
  const out = {}
  let edges = 0
  for (const raw of code.split('\n')) {
    // bỏ nội dung nhãn trong ngoặc kép để ký tự { } | -- trong nhãn không làm hỏng việc tách cạnh
    const line = raw.trim().replace(/"[^"]*"/g, '""')
    if (!line || /^(flowchart|graph|classDef|class |%%|style |subgraph|end$)/.test(line)) continue
    // tách theo mũi tên: "A -- Đ --> B", "A -->|Đ| B", "A --> B"
    const parts = line.split(/\s*(?:--\s*[^->]+?\s*-->|-->)\s*(?:\|[^|]*\|\s*)?/)
    // Mỗi đoạn có thể là nhóm "A & B" (mermaid: mọi nút trong nhóm nối tới mọi nút nhóm sau)
    const groups = []
    for (const p of parts) {
      const ids = []
      for (const one of p.split(/\s*&\s*/)) {
        const m = one.match(/^([A-Za-z0-9_]+)(\s*\{)?/)
        if (!m) continue
        ids.push(m[1])
        nodes.add(m[1])
        if (m[2]) decisions.add(m[1])
      }
      if (ids.length) groups.push(ids)
    }
    for (let i = 0; i + 1 < groups.length; i++) {
      for (const from of groups[i]) {
        edges += groups[i + 1].length
        out[from] = (out[from] || 0) + groups[i + 1].length
      }
    }
  }
  const exits = [...nodes].filter((n) => !out[n])
  const E = edges + Math.max(exits.length - 1, 0)
  const N = nodes.size
  const P = decisions.size
  const v1 = P + 1
  const v2 = E - N + 2
  const wrongDec = [...decisions].filter((d) => out[d] !== 2)
  if (v1 !== v2 || wrongDec.length) bad++
  rows.push({ đồ_thị: title, N, E, P, 'P+1': v1, 'E-N+2': v2, nút_ra: exits.join(','), lỗi: wrongDec.length ? `nút ≠2 cạnh ra: ${wrongDec}` : '' })
}
console.table(rows)
const sum = rows.reduce((a, r) => a + r['P+1'], 0)
console.log(`Tổng: ${rows.length} đồ thị, P = ${rows.reduce((a, r) => a + r.P, 0)}, ΣV(G) = ${sum}`)
if (bad) {
  console.error(`${bad} đồ thị lỗi — sửa đồ thị (không sửa số) trước khi sang Bước 3.`)
  process.exit(1)
}
