#!/usr/bin/env node
// Kiểm tra bộ tài liệu markdown trước khi commit: cú pháp nhãn mermaid, liên kết
// tương đối, và anchor. Không cần cài gì (chỉ dùng Node core).
//
// Dùng:  node check-docs.mjs <thư-mục-hoặc-file.md> [...]
//
// Bảy luật lint dưới đây KHÔNG phải lý thuyết — mỗi luật tương ứng một lần biểu đồ
// thật sự vỡ khi dựng bộ tài liệu docs/architecture/ (phiên 2026-08-26).
import fs from 'fs'
import path from 'path'

const targets = process.argv.slice(2)
if (!targets.length) {
  console.error('Dùng: node check-docs.mjs <thư-mục-hoặc-file.md> [...]')
  process.exit(2)
}

/** Thu thập file .md từ danh sách đường dẫn (thư mục thì quét 1 cấp). */
function collect(paths) {
  const out = []
  for (const p of paths) {
    if (!fs.existsSync(p)) { console.error(`Không tìm thấy: ${p}`); process.exit(2) }
    const st = fs.statSync(p)
    if (st.isDirectory()) {
      for (const f of fs.readdirSync(p)) if (f.endsWith('.md')) out.push(path.join(p, f))
    } else if (p.endsWith('.md')) out.push(p)
  }
  return out.sort()
}

/** Tách các khối ```mermaid ... ``` kèm số dòng bắt đầu và loại biểu đồ. */
function mermaidBlocks(text) {
  const lines = text.split('\n')
  const blocks = []
  let buf = null, start = 0
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim()
    if (!buf && t.startsWith('```mermaid')) { buf = []; start = i + 2; continue }
    if (buf && t === '```') {
      const kind = (buf.find((l) => l.trim())?.trim().split(/\s+/)[0]) ?? ''
      blocks.push({ start, kind, lines: buf })
      buf = null; continue
    }
    if (buf) buf.push(lines[i])
  }
  if (buf) blocks.push({ start, kind: '', lines: buf, unterminated: true })
  return blocks
}

// Bốn luật. Mỗi luật đã được KIỂM CHỨNG bằng chính parser mermaid v10
// (xem references/mermaid.md — bảng "đã thử gì, kết quả ra sao").
// ERROR = biểu đồ không dựng được. WARN = dựng được nhưng hiển thị sai.
const RULES = [
  { id: 'MD-SEMICOLON', sev: 'ERROR',
    test: (l, k) => k === 'sequenceDiagram' && l.includes(';'),
    msg: '`;` trong sequenceDiagram là dấu kết thúc câu lệnh → VỠ biểu đồ. Dùng `,`.' },
  { id: 'MD-BACKTICK', sev: 'ERROR',
    test: (l) => /(\[|\(\[|\{\{)"\s*`/.test(l),
    msg: 'Nhãn MỞ ĐẦU bằng backtick bị hiểu là markdown-string → VỠ biểu đồ. Bỏ backtick đó (backtick ở giữa nhãn thì không sao).' },
  { id: 'MD-BOLD', sev: 'WARN',
    test: (l) => l.includes('**'),
    msg: '`**đậm**` parse được nhưng hiện nguyên dấu sao trên nhãn. Bỏ đi.' },
  { id: 'MD-ITALIC', sev: 'WARN',
    test: (l) => /\*\(|\)\*/.test(l),
    msg: '`*(nghiêng)*` parse được nhưng hiện nguyên dấu sao trên nhãn. Bỏ đi.' },
]

/** Thay nội dung code (fenced + inline) bằng khoảng trắng, GIỮ NGUYÊN số dòng và cột.
 *  Cần thiết vì tài liệu hay trích ví dụ liên kết trong code span — đó không phải liên kết thật. */
function maskCode(text) {
  const blank = (m) => m.replace(/[^\n]/g, ' ')
  return text
    .replace(/^```[\s\S]*?^```/gm, blank)   // khối ```...```
    .replace(/``[^`\n]*``/g, blank)          // code span 2 backtick
    .replace(/`[^`\n]*`/g, blank)            // code span 1 backtick
}

/** Slug theo đúng cách github-slugger sinh anchor: bỏ dấu câu, KHÔNG gộp khoảng trắng. */
function ghSlug(heading) {
  return heading.trim().toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')   // bỏ dấu câu, GIỮ khoảng trắng và gạch nối
    .replace(/ /g, '-')                   // mỗi khoảng trắng = 1 gạch nối (em dash ⇒ '--')
}

const files = collect(targets)
const headings = new Map()
for (const f of files) {
  const set = new Set()
  const seen = new Map()
  for (const l of fs.readFileSync(f, 'utf8').split('\n')) {
    if (!/^#{1,6}\s/.test(l)) continue
    let s = ghSlug(l.replace(/^#{1,6}\s+/, ''))
    const n = seen.get(s) ?? 0            // heading trùng tên ⇒ -1, -2 như GitHub
    seen.set(s, n + 1)
    set.add(n === 0 ? s : `${s}-${n}`)
  }
  headings.set(path.resolve(f), set)
}

let errors = 0, warns = 0
const report = (file, line, id, msg, snippet, sev = 'ERROR') => {
  sev === 'ERROR' ? errors++ : warns++
  console.log(`${sev === 'ERROR' ? '❌' : '⚠️ '} ${file}:${line}  [${id}] ${msg}`)
  if (snippet) console.log(`     ${snippet.trim().slice(0, 110)}`)
}

for (const f of files) {
  const text = fs.readFileSync(f, 'utf8')

  for (const b of mermaidBlocks(text)) {
    if (b.unterminated) { report(f, b.start, 'MD-UNTERMINATED', 'Khối ```mermaid không có ``` đóng.'); continue }
    if (!b.kind) { report(f, b.start, 'MD-EMPTY', 'Khối mermaid rỗng.'); continue }
    b.lines.forEach((l, i) => {
      for (const r of RULES) {
        try { if (r.test(l, b.kind)) report(f, b.start + i, r.id, r.msg, l, r.sev) } catch { /* bỏ qua */ }
      }
    })
  }

  // Liên kết tương đối + anchor — dò trên bản đã che code
  const scanned = maskCode(text)
  for (const m of scanned.matchAll(/\[[^\]]*\]\(([^)\s]+)\)/g)) {
    const href = m[1]
    if (/^(https?:|mailto:|#)/.test(href)) continue
    const [rel, anchor] = href.split('#')
    const line = scanned.slice(0, m.index).split('\n').length
    const abs = path.resolve(path.dirname(f), rel)
    if (!fs.existsSync(abs)) { report(f, line, 'LINK-404', `Liên kết trỏ tới file không tồn tại: ${rel}`); continue }
    if (anchor && abs.endsWith('.md')) {
      const set = headings.get(abs)
      if (!set) continue   // file ngoài phạm vi quét — không kết luận
      if (!set.has(decodeURIComponent(anchor))) {
        report(f, line, 'ANCHOR-404', `Không có heading nào sinh ra anchor "#${anchor}" trong ${rel}`)
      }
    }
  }
}

console.log(errors + warns === 0
  ? `✅ ${files.length} file — không có vấn đề.`
  : `\n${errors} lỗi (làm vỡ biểu đồ) · ${warns} cảnh báo (hiển thị sai) · ${files.length} file.`)
console.log('Lint này chỉ bắt 4 lỗi hay gặp. Muốn chắc chắn 100%, parse thật:')
console.log('  npm i mermaid@10 jsdom && node parse-mermaid.mjs <thư-mục>   (xem references/mermaid.md)')
process.exit(errors > 0 ? 1 : 0)
