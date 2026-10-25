# Triage & Autofix

Read when: a case fails and you need to diagnose it, decide whether/how to
fix it, and re-verify.

## The loop

```
FAIL
 → re-run once, from a clean state (this attempt does NOT count toward the
   3-attempt cap below)
    ├── PASS → status = "flaky". Record a suspected cause even though you
    │           didn't fix anything — a guess based on what you saw is
    │           still useful signal for whoever reads the report.
    └── still FAIL → collect evidence: screenshot, the relevant DOM region,
        console output, network activity → classify into one of the 6
        groups below → apply a fix within your current fix level (see
        SKILL.md §6) → re-run
            ├── PASS → status = "fixed"
            │           (if the fix touched application source, re-run
            │           every other case sharing the same tag — a source
            │           change can affect more than just the case that
            │           originally failed)
            └── FAIL → try a different angle within the same group, or
                        reclassify if the evidence pointed the wrong way
                        (max 3 real attempts total) → status = "failed",
                        set needs_human with what you tried and why it
                        didn't work.
```

## The 6 cause groups

| Group | Signal | Fix level |
|---|---|---|
| 0. Tooling | The element is genuinely fine, but the MCP tool itself refused the action, or you're looking at stale state — cold start, a stale `304`, leftover SPA state from a previous case. | Retry / re-probe / cache-bust, not a "fix" in the code sense. |
| 1. Selector/Wait | "Element not found" but a snapshot shows the element **is** on the page. | L2 — better selector, add a wait, add `data-testid`. |
| 2. Data/Env | `401`/`403`, "record not found", empty DB/seed data. | L1 — seed data, refresh token, (re)start the server. |
| 3. Config | Wrong URL, viewport mismatch, timezone, a feature flag gating the thing under test. | L1 — fix the test config, not the app. |
| 4. App bug | The thing the suite exists to catch: `500`, wrong data, an expected message that never renders, a button that doesn't respond. | Diagnose fully at L2, then **ask the user** — only patch at L3 if they approve (SKILL.md §6). |
| 5. Test case itself is wrong | `expected` clearly contradicts the real spec/reality, or doesn't match how the feature is actually supposed to work per a source you trust (not just "what the app currently does" — see the Red Line in SKILL.md §7 against deriving expected from observed behavior). | Never silently rewrite `expected`. State the contradiction and get the user's call; if it's not clear-cut, `blocked` instead. |

## Quick decision table

- Element not found, and the page **does** have it (confirmed via
  `evaluate`) → **group 1**.
- Element not found, and the page genuinely doesn't have it → **group 4**.
- Tool refuses the action, and `evaluate` confirms the page state is fine →
  **group 0**.
- Several cases fail in a row and they all redirect to `/login` → the
  session died → **group 2 or 0** (re-probe via the auth gate; the user
  re-creates the session file — you never log in yourself),
  not a real bug in each individual case — see auth-gate.md.
- Passes when you step through it manually, fails when automated → **group
  1** (almost always a missing wait).
- A case passes on its own but fails inside the full suite → **group 2**,
  the previous case likely left behind state (uncommitted form, open modal,
  leftover cart item) that this case didn't account for.

## Forbidden behaviors during triage

None of these are "fixes" — they make a failure disappear without making
the underlying thing true. Doing any of these invalidates the fix the same
way a Red Line violation does:

- Changing `expected` to match whatever reality currently is.
- Loosening or deleting an assertion so it stops catching the failure.
- Wrapping the check in a try/catch that swallows the error.
- Bumping a timeout just to paper over a race condition instead of fixing
  the actual wait condition.
- Adding `?.` / `||` fallback defaults that mask a real crash.
- Marking a case you don't want to deal with as `skipped`.
- Retrying until it happens to go green and reporting that as `passed` —
  that's `flaky`, not `passed`, and needs the suspected cause recorded.
- Treating "didn't crash" as a pass when a clause requires a specific
  message/state that never actually appeared — absence of a crash is not
  presence of the required evidence (see SKILL.md §3 rule 7).

## Notes

- "Collect evidence" before classifying, not after — deciding the group
  first and then looking for evidence to match it produces wrong
  diagnoses.
- A `needs_human` case is not a failure of the process — it's the correct
  outcome when 3 real attempts haven't nailed the cause. Write down exactly
  what you tried so the human doesn't repeat it.
