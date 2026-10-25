# Token Budget

Read when: the 6 compact rules in SKILL.md §1 aren't enough on their own —
a large suite, context running low mid-run, or you need to decide when to
switch modes. This file goes deeper into *how* to apply each rule, not just
what the rule is.

## Why this matters here specifically

The single biggest token cost in a browser-driving run is not reasoning —
it's **accessibility-tree snapshots and raw DOM/network dumps**. A snapshot
of a busy page can run into the thousands of tokens; a suite that
re-snapshots on every single action instead of once per screen can burn
through a context window before it's a third of the way through the cases.
Everything below exists to keep that cost proportional to *screens visited*,
not *actions taken*.

## Rule 1 — snapshot caching, in practice

- Key the cache by **screen identity**, not by case: `(current URL path,
  a stable marker on the page — e.g. a heading text or a `data-testid` on
  the root container)`. Two different cases hitting the same screen should
  reuse the same cached selectors.
- Invalidate the cache when: you navigate to a new URL, a modal/dialog
  opens or closes, or an action you just performed is known to re-render
  the section you're about to interact with (e.g. a form validation error
  appearing). When in doubt after a state-changing action, a fresh
  **targeted** `evaluate` check on just the element you care about is
  usually cheaper than a full re-snapshot.
- Write `selectors.json` once per screen the first time you see it; every
  later case that touches that screen reads from it instead of asking the
  browser again.

## The `evaluate` technique

This is the single highest-leverage move beyond the 6 rules: prefer a
targeted `evaluate()` call over a full `snapshot()` whenever you're
checking something specific rather than exploring a new screen.

- A snapshot of a busy page can run 5000+ tokens. A single `evaluate()`
  call that just reads back a few values costs on the order of ~20 tokens.
  That's not a marginal difference — it's the difference between a suite
  that fits in context and one that doesn't.
- **Batch multiple clauses into one `evaluate()` call** instead of calling
  it once per clause. Return a small object with everything you need to
  check in one round trip:

  ```js
  () => ({
    path: location.pathname,
    toast: document.querySelector('[data-testid="toast"]')?.textContent ?? null,
    rows: document.querySelectorAll('table tbody tr').length,
    errors: [...document.querySelectorAll('.field-error')].map(e => e.textContent),
  })
  ```

  One call, one round trip, and every clause in a multi-clause `expected`
  (SKILL.md §3) gets checked against a single cheap result instead of N
  separate expensive ones.
- Reach for a full snapshot only when you genuinely don't know the DOM
  shape yet (a new screen) or need to find a selector you don't have
  cached. Once you have it, subsequent checks on that same screen should
  almost always be `evaluate()`, not another snapshot.

## Rule 2 — one line per pass, in practice

Use a fixed, short line shape when a case just passes cleanly, e.g.:

```
TC-014 passed (P2) — cart badge shows correct count
```

Don't restate the steps you took or the assertion logic that already lives
in `testcases.json` — that's redundant with what `results.json` will
contain. Save the narration budget for cases that actually failed or
needed a fix; those are what the user needs explained.

## Rule 3 — artifacts to files, in practice

- Screenshots: PNG to `<outputs>/artifacts/<case_id>.png`, referenced by
  path in `results.json.artifacts.screenshot`.
- Network evidence: save as `.har` or a trimmed JSON of just the
  request/response pair that matters, not a full traffic capture.
- Console output: save the relevant lines to a `.log` file rather than
  pasting a scrollback dump; quote at most 2-3 lines inline if a snippet
  is genuinely needed to explain a root cause.
- Never inline a base64 screenshot or a full HAR file into the
  conversation — that defeats the entire point of writing artifacts to
  disk.

## Rule 4 — append-only results, in practice

Treat `results.json` as the durable source of truth, not your own working
memory. Concretely:

- Open, append one case object, close/flush — don't accumulate an
  in-context list of "all results so far" that you re-emit at the end.
- This is also what makes **resume** (SKILL.md §0) cheap: a fresh session
  that starts and finds a partial `results.json` can skip every case
  that already has a terminal status without needing any of the prior
  session's reasoning trace.
- If you can tell context is getting low (long transcript, many large
  tool results accumulated), proactively flush current progress and
  consider ending the session cleanly rather than pushing until you're
  forced to truncate mid-case.
- **Concretely, once context is roughly >60% full**: write `results.json`
  (as always) plus a short `resume.md` in the output dir — a few lines
  noting which case you were on, anything in-flight that isn't captured by
  `results.json` alone (e.g. "was mid-diagnosis on TC-019, suspect group 2"),
  and any selector/auth state the next session should know about. Then tell
  the user to open a new session. The new session's first move is reading
  `results.json` + `selectors.json` (+ `resume.md` if present) and
  continuing from whichever cases don't have a terminal status yet — not
  re-deriving anything from this session's transcript.

## Rule 5 — Explore once, reuse in Batch mode

- Explore mode naturally maps out selectors and flow as a side effect of
  running cases step by step. When switching to Batch mode for the rest of
  a large suite, generate the `.spec.ts` files from what you already
  learned — selectors, navigation paths, timing quirks — rather than
  re-discovering the app from a blank slate.
- **When to switch to Batch mode**: the threshold is **>12 cases** (SKILL.md
  §5) — the fixed cost of writing the spec files pays for itself against
  the token cost of stepping through each case live past that point.
  For 12 cases or fewer, or genuinely exploratory testing, Explore mode
  alone is usually cheaper overall.
- A suite can be **mixed**: run the well-understood majority in Batch mode,
  keep the handful of unusual/ambiguous cases in Explore mode.

## Rule 6 — targeted reads, in practice

- Grep the source file for the case ID or title first; read only the
  matched region (~±30 lines) instead of the whole file.
- If a source file is small (well under the ±30-line window itself), just
  read the whole thing — the grep-then-slice dance isn't worth it below
  that size.
- The same principle applies to reading `results.json` back during a
  resume: don't load and re-print the entire file into context just to
  check which cases are done — read it, extract the set of already-done
  IDs programmatically (or scan quickly), and move on.

## Rough per-run budgeting

If you know roughly how much context you have to work with, divide it by
the case count to get a rough per-case ceiling before you start. This
isn't a hard cap — some cases (a tricky group-4 diagnosis) legitimately
cost more than others — but if you're consistently blowing past the
average early in the run, that's a signal to tighten up (switch remaining
cases to Batch mode, cut narration further) rather than discovering the
problem only once context is nearly gone.
