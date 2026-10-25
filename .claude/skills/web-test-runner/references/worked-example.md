# Worked Example — one suite, end to end

Read when: you want to see the whole workflow (SKILL.md §2) applied to a
concrete, small suite, rather than reading the rules in the abstract.

## Scenario

User gives a markdown table with 3 cases for a demo shop at
`https://shop.example.com`, no credentials needed, no config file.

## 0 — Setup & preflight

- `$PY` resolves to `python3`.
- No `results.json` in the output dir yet → fresh run, not a resume.
- No `testrun.config.yaml` at the project root → defaults apply.
- Preflight: URL responds 200, landing page is clearly the shop (not an
  error page), no login redirect, output dir is writable. All 4 checks
  pass → proceed straight to normalization, skip `auth-gate.md`.

## 2 — Normalize

```bash
python3 scripts/normalize_testcases.py cases.md -o testcases.json --stats
```

Output: 3 cases, all `P1`/`P2`, zero flagged for `needs_clarification`.
Good to proceed without going back to the user.

## 3 — Pick engine

Available tools include `browser_navigate` from a Playwright-flavored MCP
server → Playwright MCP, per `mcp-playwright.md`.

## 4-5 — Explore & Execute (Explore mode, since it's only 3 cases)

**TC-001 — View product list (P1)**
`navigate("/")` → `wait` for the product grid → `snapshot` once → `evaluate`
to count `.product-card` elements (> 0) → assertion passes → append
`{"id": "TC-001", "status": "passed", ...}` to `results.json` immediately.

**TC-002 — Add to cart, badge shows 1 (P1)**
Already have a snapshot of `/` from TC-001 — no new snapshot needed (Token
Discipline rule 1). `evaluate` to read the cart badge **before** (`0` or
empty) → `click` "Add to cart" on the first product → `evaluate` to read
the badge **after** → assert delta is exactly `+1` (this is the
BEFORE+AFTER pattern from SKILL.md §3 rule 4, since "increases by 1" is a
relative claim).

First attempt: badge still reads `0` right after the click. Don't
immediately mark it failed — re-run once from a clean state per
`triage-and-autofix.md`. Second attempt: same result. Collect evidence
(screenshot + a fresh snapshot of the badge region) → classify: element
exists, value just hasn't updated yet → **group 1 (selector/wait)**, likely
a client-side render delay. Fix at L1: add a short wait-for-text-change on
the badge before reading it. Re-run → badge now reads `1` → assertion
passes → `status = "fixed"`, with `root_cause.category = "wait"` and
`fix.applied = true`, `verify.status = "passed"`.

**TC-003 — Checkout with empty cart shows an error (P2)**
`expected` says "hiển thị thông báo lỗi" (shows an error message). Per §3
rule 7, this asserts **presence**, not just "nothing crashed": `evaluate`
must find a non-empty error element, not merely confirm the page didn't
navigate. Empty cart → click "Checkout" → `evaluate` for the error banner
→ found, non-empty, text reads "Giỏ hàng trống" → assertion passes →
`status = "passed"`.

## 7 — Report

```bash
python3 scripts/render_report.py results.json -o report.html --summary
```

Validates cleanly (no FATALs), one case is `fixed` so the stdout summary
calls it out, and `report.html` shows all 3 cases with TC-002's fix detail
(root cause + diff-free description, since this was an L1 config/wait fix,
not a source change) expandable inline.

## What this example illustrates

- Preflight can genuinely pass all 4 checks and skip straight past
  `auth-gate.md` — that reference isn't always needed.
- A relative assertion ("+1") always needs a before/after read, even in a
  trivial 3-case suite.
- A single retry-then-fix cycle is the common case for group-1 issues —
  most fixes are this small, not a deep investigation.
- `results.json` is appended to after each case, not written once at the
  end — by the time TC-003 runs, TC-001 and TC-002 are already durably on
  disk.
