#!/usr/bin/env node
// Parse THẬT mọi biểu đồ mermaid bằng chính thư viện mermaid — chắc chắn 100%,
// khác với lint nhanh của check-docs.mjs (chỉ bắt 4 lỗi hay gặp).
//
// Cần cài trước (đặt ở thư mục tạm, đừng thêm vào repo):
//   mkdir -p /tmp/mmd && cd /tmp/mmd && npm i mermaid@10 jsdom
//   node <đường-dẫn>/parse-mermaid.mjs <thư-mục-tài-liệu>
//
// Chạy từ thư mục đã cài để Node tìm thấy node_modules.
import fs from 'fs'
import path from 'path'
import { createRequire } from 'module'
import { pathToFileURL } from 'url'

// Node ESM phân giải `import 'mermaid'` theo vị trí FILE SCRIPT, không theo cwd.
// Script này nằm trong .claude/skills/ còn node_modules nằm ở thư mục tạm nơi
// người dùng cài — nên phải phân giải tường minh từ cwd.
const requireFromCwd = createRequire(path.join(process.cwd(), 'noop.js'))
const loadFromCwd = async (name) => {
  try { return await import(pathToFileURL(requireFromCwd.resolve(name)).href) }
  catch {
    console.error(`Không tìm thấy "${name}" từ ${process.cwd()}.`)
    console.error('Cài trước rồi chạy lại TỪ ĐÚNG thư mục đó:')
    console.error('  mkdir -p /tmp/mmd && cd /tmp/mmd && npm i mermaid@10 jsdom')
    process.exit(2)
  }
}

const target = process.argv[2]
if (!target) { console.error('Dùng: node parse-mermaid.mjs <thư-mục-hoặc-file.md>'); process.exit(2) }

const { JSDOM } = await loadFromCwd('jsdom')
const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true })
global.window = dom.window
global.document = dom.window.document
Object.defineProperty(global, 'navigator', { value: dom.window.navigator, configurable: true })
global.HTMLElement = dom.window.HTMLElement
global.SVGElement = dom.window.SVGElement

const mermaid = (await loadFromCwd('mermaid')).default
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' })

const files = fs.statSync(target).isDirectory()
  ? fs.readdirSync(target).filter((f) => f.endsWith('.md')).map((f) => path.join(target, f)).sort()
  : [target]

let total = 0, bad = 0
for (const f of files) {
  const lines = fs.readFileSync(f, 'utf8').split('\n')
  let buf = null, start = 0
  for (let i = 0; i < lines.length; i++) {
    if (!buf && lines[i].trim().startsWith('```mermaid')) { buf = []; start = i + 2; continue }
    if (buf && lines[i].trim() === '```') {
      total++
      try { await mermaid.parse(buf.join('\n')) }
      catch (e) {
        bad++
        console.log(`\n❌ ${f}:${start}`)
        console.log('   ' + String(e.message).split('\n').slice(0, 4).join('\n   '))
      }
      buf = null; continue
    }
    if (buf) buf.push(lines[i])
  }
}
console.log(`\n${total - bad}/${total} biểu đồ parse OK`)
process.exit(bad > 0 ? 1 : 0)
