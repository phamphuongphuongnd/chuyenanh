# Engine: Chrome DevTools MCP

Read when: Engine Selection (SKILL.md) picked Chrome DevTools MCP — either
because no Playwright MCP tool was available, or because the current case
is specifically about performance, network, or console behavior.

## When this is picked

- No `playwright` + `browser_navigate`-style tool is available, but a
  `chrome-devtools` / `navigate_page`-style tool is.
- Or: Playwright MCP is available generally, but *this specific case* needs
  DevTools-level access — network waterfall, console messages, performance
  timing — that Playwright's snapshot/evaluate model doesn't expose as
  directly.

## Standard pattern

Same shape as Playwright MCP: `navigate → wait → snapshot once → fill/click
→ evaluate assert → append result`. The difference is what you reach for
when the assertion itself needs DevTools-specific signal:

- **Network** — assert against actual request/response data (status code,
  payload shape, timing) rather than inferring success from the UI alone.
  Useful for cases like "submitting the form sends exactly one POST to
  `/api/orders`."
- **Console** — assert absence of errors/warnings as part of a case, or
  assert a specific expected console message appears (e.g. a debug log a
  feature is supposed to emit).
- **Performance** — for cases that check load time / responsiveness
  budgets, use the DevTools performance trace rather than a manual
  stopwatch approach.

## Notes

- Still follow Token Discipline (SKILL.md §1): one snapshot per new screen,
  artifacts (HAR files, traces) written to `<outputs>/artifacts/`, not
  pasted inline.
- If a suite is mostly functional (not perf/network-focused) but one case
  needs DevTools, it's fine to switch engines just for that case and switch
  back — the engine choice is per-case guidance, not a whole-run lock-in,
  as long as the primary engine stays consistent for everything else.
