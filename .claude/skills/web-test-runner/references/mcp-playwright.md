# Engine: Playwright MCP

Read when: Engine Selection (SKILL.md) picked Playwright MCP.

## When this is picked

Default engine whenever the available MCP tool set includes something like
`browser_navigate` / `browser_snapshot` / `browser_click` under a
Playwright-flavored server. Exception: hand a case off to
`mcp-chrome-devtools.md` instead if it's specifically about performance,
network timing, or console behavior — Chrome DevTools MCP has better tools
for those.

## Standard pattern

```
navigate → wait for the page to settle → snapshot ONCE
  → fill / click using the snapshot's element refs
  → evaluate to assert the outcome
  → append the result to results.json
```

- Take the **accessibility-tree snapshot once per new screen**, not once
  per action (this is Token Discipline rule 1 in SKILL.md §1). Reuse the
  element refs from that snapshot for every subsequent interaction until
  the screen changes.
- Prefer role/label/text-based locators over brittle CSS selectors when the
  snapshot exposes them — they survive minor markup changes.
- Use `evaluate` for assertions that need to read computed state (text
  content, attribute values, element counts) rather than trying to infer
  pass/fail from whether an action "looked like" it worked.
- Waits: prefer an explicit wait-for-condition (element visible, network
  idle, a specific text present) over a fixed sleep. A fixed sleep is a
  common source of group-1 flakiness (see `triage-and-autofix.md`).
- For multi-tab / popup flows, track which page/tab is "current" explicitly
  — don't assume actions apply to the last-opened one without checking.

## Batch mode

When SKILL.md §5 calls for Batch mode, generate `tests/*.spec.ts` files
using the selectors and flow you already mapped during Explore mode (Token
Discipline rule 5) — don't re-discover the app from scratch just to write
the spec files. Run with:

```bash
npx playwright test --reporter=json
```

Then read only the failing entries from the JSON report; feed each one
through `triage-and-autofix.md` individually.

If Playwright isn't installed yet, don't install it wherever you happen to
be standing — see "Installing Playwright" in SKILL.md: ask the user for a
location first, defaulting to a fresh `playwright-tests/` subfolder.
