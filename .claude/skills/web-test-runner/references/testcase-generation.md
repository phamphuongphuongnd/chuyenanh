# Test Case Generation

Read when: the user wants their app tested but doesn't have test cases
written down.

## The Oracle rule

Every `expected` you write must come from a legitimate source:

- **Spec** (a ticket, a requirements doc, a design doc) — the strongest
  source. Cite it if you can (e.g. in `data` or a note).
- **Convention** — a widely-shared expectation that doesn't need a specific
  doc to justify it (a failed login should show *some* error message; a
  required field left empty should block submission). Legitimate, but use
  judgment — "convention" is not a license to assert whatever seems
  reasonable.
- **Observed behavior** ("the app currently does X") — **forbidden** as a
  basis for `expected`. Writing down what the app happens to do right now
  turns a potential bug into a contract that then "passes" forever. If you
  don't know what's *supposed* to happen, ask the user, or write the case
  with `expected` left explicit about the gap and flag it via
  `needs_clarification` — don't infer it from the current UI.

## Counting — anchor to the app's actual surface, not a fixed quota

Generate coverage proportional to what's really there, using these rules
as a floor:

- **Every screen** → at least 1 case for "loads / initial state is
  correct."
- **Every form** → 1 case with valid input, plus 1 per class of invalid
  input the form should reject (empty required field, malformed value e.g.
  bad email format, a value the backend should reject e.g. duplicate
  username).
- **Every action that changes state** → 1 case asserting the effect
  happened, plus 1 covering the cumulative/reset behavior if relevant (e.g.
  "add to cart twice" as well as "add to cart once").
- **Every navigation edge** → 1 case, but only for edges that are actually
  reachable through the UI you're testing — don't invent routes.

## Priority as a budget signal

Assign `P1`/`P2`/`P3` so that if the suite gets cut short (context runs
out, time runs out), what already ran still covers what matters most.
`P1` first means: if only `P1` cases run, the most important behavior is
still verified.

Don't generate accessibility, i18n, responsive-layout, or performance cases
unless the user specifically asked for that kind of coverage — it inflates
the suite with cases nobody requested and burns budget that should go to
functional coverage.

## Always generate these, even when nobody asked

Some defects are invisible to feature-shaped cases but break real users.
Add one case per item below whenever the app has the surface for it:

- **Paginated list integrity** — one case per paginated list: scan all
  pages twice, assert no duplicate ids, `unique == total`, and that both
  scans return the same set. See SKILL.md §3.8 for why the second scan is
  the load-bearing part and for the `ORDER BY` tie-breaker root cause.
  Cheap to write, catches a class of bug that silently corrupts every
  export, report and reconciliation built on the list.

## Process

```
Write draft cases → run scripts/normalize_testcases.py --stats to get
                     final count + flagged ambiguities
                  → present the count and the list of flagged cases to the
                     user
                  → STOP and wait for their review/approval.
```

Never run a generated suite that the user hasn't reviewed. Generation
produces a draft; the user turning it into an approved test plan is a
separate, required step.
