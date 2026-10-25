# Web Test Runner

Turn an AI agent into an autonomous QA tester: take test cases in any format,
drive a real browser via MCP, diagnose and fix failures, verify fixes, and
produce a Vietnamese HTML report.

This skill is agent-agnostic — it was written for use from Kiro, Claude
Code, or any other LLM agent that can call an MCP browser tool and run
Python scripts. Nothing below assumes a specific host; "the agent" means
whichever AI is executing this skill.

To use it with a tool that expects skills at a specific path (e.g. Kiro at
`.kiro/skills/<name>/`, Claude Code at `.claude/skills/<name>/` with a
`name`/`description` YAML frontmatter block for auto-discovery), copy this
whole `web-test-runner/` folder to that location. Nothing inside it assumes
where it's copied to.

## §0 Setup

- Resolve `$SKILL_DIR` = the directory containing this file.
- Resolve `$PY` = whichever of `python3` / `py -3` / `python` resolves to
  Python 3.x on this machine. Use it for every script invocation below.
- Resume check: if an old `results.json` exists in the run's output dir, load
  it (plus `selectors.json` and `resume.md` if present) and skip cases whose
  `id` already has a terminal status
  (`passed|fixed|flaky|failed|blocked|skipped`). See
  `references/token-budget.md` for when a prior session would have written
  `resume.md`.
- Read `testrun.config.yaml` if present **at the project root** (not inside
  this skill dir) — see `assets/testrun.config.example.yaml` for the shape.
- Preflight, in order, before touching any test case:
  1. **Is the URL alive?** (HTTP fetch/curl status). Fail → STOP, tell the
     user the URL is unreachable.
  2. **Is the landing page the app?** An error page / parking page / wrong
     app → STOP, confirm the URL with the user.
  3. **Does it need login?** (redirect to a login route, 401/403, or a
     password form on the landing page) → yes → go through
     `references/auth-gate.md` before running anything.
  4. **Is the output dir writable?** Fail → pick another dir, tell the user
     which one.
  5. **Headed or headless?** ASK the user before running anything — don't
     pick for them. See "Headed vs Headless" below.
  6. **Does Playwright need installing?** (CLI fallback only — not needed
     when an MCP browser is available.) If so, ASK where to install it —
     never auto-pick a folder that happens to have `node_modules`. See
     "Installing Playwright" below.

## §1 Token Discipline

These 6 rules apply for the entire run, not just one case:

1. **One snapshot per new screen.** After a snapshot, extract and cache the
   selectors you'll need into `selectors.json` (in the output artifacts dir)
   and reuse them. Don't re-snapshot a screen that hasn't changed.
2. **One passing case = one line.** Don't re-explain or re-narrate a case
   that passed; append its result and move on.
3. **Artifacts go to files, not the transcript.** Screenshots, traces,
   network logs → write to `<outputs>/artifacts/<case_id>.<ext>` and
   reference the path in `results.json`. Never paste raw dumps inline.
4. **Append to `results.json` right after each case finishes** — don't hold
   results in memory until the end. This is what makes resume possible if
   context runs out mid-run.
5. **Batch mode explores through MCP context, not fresh snapshots.** When
   generating `.spec.ts` files for batch mode, use what you already learned
   from Explore mode; don't re-snapshot pages you've already mapped.
6. **Read test-case sources with a target, not cover-to-cover.** Grep for the
   case ID / heading first, then read roughly ±30 lines around the match.
   Don't load an entire multi-hundred-line spec file to find one case.

For deeper tactics behind each rule (cache-key strategy, when to switch to
Batch mode, how to budget per case, what to do when context is running
low mid-run) see `references/token-budget.md`.

## §2 Workflow

`0. Setup → 1. Intake → 1b. Generate → 2. Normalize → 3. Pick engine → 4. Explore → 5. Execute → 6. Triage & Fix → 7. Report`

1. **Intake** — user gives test cases (any format) or a target to test.
2. **Generate** (only if the user has no test cases) — see
   `references/testcase-generation.md`. Produces a draft, then STOPS for
   user review before anything runs.
3. **Normalize** — run `scripts/normalize_testcases.py` on whatever the user
   gave you (or the generated draft) to get a canonical `testcases.json`.
   See `references/testcase-schema.md` for the schema and
   `references/testcase-generation.md` for how ambiguous cases get flagged.
4. **Pick engine** — see "Engine Selection" below.
5. **Explore** — for each screen the suite touches, take one snapshot, note
   the selectors, and sanity-check the flow before asserting against it.
6. **Execute** — run the cases (Explore mode step-by-step, or Batch mode via
   generated specs — see §5).
7. **Triage & Fix** — for every failure, follow
   `references/triage-and-autofix.md`.
8. **Report** — run `scripts/render_report.py` to validate `results.json`
   and produce `report.html` + a Vietnamese summary.

## §3 Assertion Logic

Turning prose `expected` into something checkable:

1. **Split expected into atomic clauses.** "Vào dashboard VÀ hiện tên user"
   = 2 clauses, checked independently.
2. **Map each clause to the cheapest observable that proves it**: URL,
   visible text of a specific element, element presence, element count, or
   an attribute value — prefer whichever one is checkable with a small
   `evaluate()` call over one that forces a full snapshot.
3. **Every clause must pass. Partial satisfaction = failed.** Never report a
   case passed because "most of it" worked.
4. **Relative values need a BEFORE + AFTER measurement in the same run.**
   "Cart count increases by 1" = read the count → perform the action → read
   the count again → assert the delta. Never assume a starting value.
5. **No concrete value given → assert weaker, but record why.** "Shows the
   user's name" with no name specified → assert the name element is
   non-empty, and write an `assertion_notes` entry explaining the weaker
   check.
6. **A clause that truly can't be observed** (no selector, no signal
   exists) → ask the user, or mark the case `blocked`. Never silently drop
   the clause and report a pass.
7. **Assert absence explicitly too.** "Shows an error message" means: the
   error element MUST exist AND be non-empty. A calm-looking page with no
   error banner and no exception is not evidence of "no message shown" —
   that clause is only satisfied if you can prove the message container is
   genuinely empty/absent.

8. **A paginated list is one object, not N independent pages.** Checking
   page 1 looks right proves nothing about the list. Scan **every** page,
   collect the ids, and assert three things:
   - no id appears twice (duplicates),
   - `unique ids == total` reported by the server (nothing skipped),
   - a **second full scan returns the same set** (stable ordering).

   The third check is the one that matters and the one everyone omits: a
   single clean scan can pass by luck. Two scans that disagree prove the
   order is non-deterministic even when neither scan shows duplicates.

   **Root cause to look for when it fails: `ORDER BY` on a non-unique
   column with no tie-breaker.** Rows sharing a value (bulk imports land
   thousands of rows with an identical `created_at`, to the millisecond)
   have *undefined* relative order — the database may return them
   differently on each query, so `LIMIT/OFFSET` paging repeats some rows on
   one page and drops others. The fix is always the same shape: append a
   unique column, normally the primary key —
   `ORDER BY created_at DESC, id DESC`. Report it as a real bug, not
   flakiness, and check **every** paginated query in the codebase once you
   find one; this bug never appears alone.

   Watch for it hiding behind other symptoms: a data-scope or filter case
   that is off by one or two rows out of thousands is far more likely to be
   this than the filter logic being wrong. Re-measure with a server-side
   `COUNT` before blaming the feature under test.

## §4 Case Status

Exactly six values. Do not invent others.

| Status | Meaning |
|---|---|
| `passed` | Passed on the first attempt. |
| `fixed` | Failed, a fix was applied, re-run PASSED. |
| `flaky` | Failed once, passed on a clean re-run with nothing changed. |
| `failed` | Still failing after every fix attempt allowed by the fix level. |
| `blocked` | Couldn't run (a dependency failed, auth is missing, a clause is unobservable). |
| `skipped` | Deliberately not run. |

## §5 Two Run Modes

- **Explore mode (default).** Step through each case via MCP tool calls one
  action at a time. Use this when the app hasn't been mapped yet, or the
  suite is **≤12 cases**.
- **Batch mode.** Generate `tests/*.spec.ts` from the normalized cases, run
  `npx playwright test --reporter=json`, then read **only the failures**
  from the JSON report and diagnose each one individually via
  `references/triage-and-autofix.md`. Switch to this once a suite is
  **>12 cases** — re-running everything step-by-step past that size burns
  too many tokens.

## §6 Fix Levels

| Level | Allowed to touch |
|---|---|
| L0 | Nothing — report only, no changes. |
| L1 | Env/config, test data, restarting the server. |
| L2 (default) | Everything in L1, **plus** selectors, waits, `data-testid` additions, fixing wrong test steps. |
| L3 | Everything in L2 **plus application source code**. Requires all three: a dedicated git branch, a non-production target, and explicit user approval **after** they've seen the diagnosis and diff. |

**L3 is never opened by "just fix it" said before the run starts.** The user
must see, for the specific case: what happened vs. what should happen, the
evidence, the exact location in source, and the proposed diff — then
explicitly approve — before you touch source code. Track this as
`fix.proposed` until approved, `fix.applied` only after.

At L1/L2, when you hit what looks like an application bug, don't silently
downgrade it to "test issue" — present, for the user: (1) what happened,
(2) what should have happened, (3) evidence (screenshot/log path), (4) the
likely location in source if you can tell, (5) that it's blocked pending L3
approval.

## §7 Red Lines

Violating **any** of these invalidates the entire run — treat them as hard
stops, not judgment calls:

- Never loosen a test to make it pass (widening an assertion, deleting a
  check, silently rewriting `expected`).
- Never change `expected` without asking the user — it's a business
  contract, not a suggestion.
- Never log in yourself, type or guess a password, or register a new
  account to get in — even if the user pastes a password. The user logs in
  and saves a session file; you only pass its path (`references/auth-gate.md`,
  root rule `CLAUDE.md` → 🔒).
- Never write a password, cookie, or session token into output, report, or
  a reply to the user. (An account identifier like an email is fine.)
- Never run against production unless it's strictly L0 read-only — no
  submitting real forms, no creating data.
- Never open, edit, copy or delete secret files (`.env*`, `.auth/`,
  `auth*.json`, `*.secret.*`, keys). Never touch migrations, CI/CD, payment
  flows, or auth code unless the user explicitly named exactly that.
- Never read the user's own terminal / PowerShell; ask them to paste output.
- Never commit, push, or open a PR without asking first.
- Never derive `expected` from currently-observed behavior — that turns a
  bug into a contract.
- Never fabricate a case in `results.json` for something found during
  exploration that wasn't an actual test case.
- Never report `passed` for a case that didn't actually run, or that still
  has an unverified clause.

When unsure whether something crosses a red line — ask the user before
acting.

## §8 References — read on demand

Don't load every reference file up front. Each file below states when to
read it; only pull it in when you're at that step.

- `references/auth-gate.md` — Read when: preflight check 3 says the app
  needs login.
- `references/token-budget.md` — Read when: the §1 rules aren't enough on
  their own — a large suite, context running low mid-run, or deciding
  when to switch to Batch mode.
- `references/triage-and-autofix.md` — Read when: a case fails and you need
  to diagnose/fix it.
- `references/testcase-schema.md` — Read when: normalizing input or writing
  to `results.json` and you need the exact field contract.
- `references/testcase-generation.md` — Read when: the user has no test
  cases and you need to write some from scratch.
- `references/mcp-playwright.md` — Read when: the Playwright MCP engine was
  selected.
- `references/mcp-chrome-devtools.md` — Read when: the Chrome DevTools MCP
  engine was selected.
- `references/exploratory-pass.md` — Read when: the scripted suite is done
  and there's budget left for an exploratory pass.
- `references/worked-example.md` — Read when: you want a concrete
  end-to-end example of one suite run start to finish.

## Engine Selection

```
Does the available MCP tool set contain "playwright" + "browser_navigate"?
├── YES → use Playwright MCP (default)
│         Exception: cases specifically about performance/network/console
│         → use Chrome DevTools MCP instead, even if Playwright is available.
└── NO  → Does it contain "chrome-devtools" / "navigate_page"?
          ├── YES → use Chrome DevTools MCP
          └── NO  → Fallback: write tests/*.spec.ts and run them with
                     `npx playwright test` (Batch mode only, no live MCP
                     browser).
```

Standard interaction pattern for both engines: `navigate → wait → snapshot
once → fill/click → evaluate assert → append result to results.json`.

## Installing Playwright (CLI fallback only)

Only the CLI fallback needs an install — if a Playwright or Chrome DevTools
MCP server is available, there is nothing to install, so don't offer to.

**Never pick the install location by scanning the disk for a folder that
already has `node_modules`.** That heuristic finds some unrelated
sub-project and installs into it, which adds a `@playwright/test`
dependency, rewrites that project's `package.json` / lockfile, and drops
`playwright.config.ts` + `tests/` into a codebase the user never agreed to
touch. It looks convenient and is a mess to undo. The presence of
`node_modules` says a project lives there — that's a reason to leave it
alone, not a reason to install into it.

Order of precedence:

1. `playwright_dir` in `testrun.config.yaml` → use it, no question.
2. Otherwise → **ask the user where to install**, defaulting to a fresh
   subfolder `playwright-tests/` in the current working directory. Say
   the default out loud so accepting it is one word.
3. Never install without asking, and never into an existing project folder
   unless the user explicitly named that folder.

Why a dedicated subfolder is the default: the generated specs, config, and
`node_modules` are throwaway test scaffolding, not part of the app under
test. Keeping them in their own directory means the whole thing can be
deleted in one step, and nothing about the user's project changes.

```bash
mkdir playwright-tests && cd playwright-tests
npm init -y
npm install --save-dev @playwright/test
npx playwright install chromium     # skip if using channel: 'chrome'/'msedge'
```

Before installing the bundled browser, check whether Chrome or Edge is
already on the machine — `channel: 'chrome'` avoids a ~150MB download and
sidesteps the headed-mode dependency problem described below. Ask before
downloading anything large.

Tell the user afterwards: which directory it went into, and that deleting
that one folder removes everything the install added.

### "Executable doesn't exist" right after a successful install

A fresh `npm install @playwright/test` pins an exact browser build number,
so a machine that already has Chromium can still fail at launch with
`Executable doesn't exist at .../chromium_headless_shell-XXXX/...` plus
Playwright's "please run npx playwright install" banner. The install
succeeded; the version just doesn't match what's on disk.

Don't reflexively run `npx playwright install` — that re-downloads a whole
browser, and in sandboxes/CI it's often blocked or forbidden outright.
Check what's already there first (`ls` the browsers dir the error names,
`which google-chrome`, `which msedge`), then point at it:

- `channel: 'chrome'` / `'msedge'` — preferred when a system browser
  exists.
- `launchOptions.executablePath` — when the browser is present at a known
  path but under a different build number than the one Playwright wants.
  Worth wiring as an env knob next to the others so it doesn't need a
  config edit per machine:
  ```ts
  launchOptions: { executablePath: process.env.TESTRUN_BROWSER_PATH || undefined },
  ```
- Downloading via `npx playwright install` is the last resort, and it's a
  large download — ask first.

## Headed vs Headless

**Ask the user which one they want before the first case runs.** Never decide
silently. Watching the browser drive itself is often the whole point for a
non-engineer stakeholder — a run that quietly went headless reads to them as
"it didn't actually run."

Order of precedence:

1. `headed: true|false` in `testrun.config.yaml` → use it, no question.
2. Otherwise → ask, offering both, and state the tradeoff in one line:
   headed = you can watch it, slower; headless = faster, nothing to see.
3. Never infer it from "just run the tests."

Applying it:

| Engine | Headed | Headless |
|---|---|---|
| Playwright MCP / Chrome DevTools MCP | already a visible browser — nothing to do | n/a |
| Playwright CLI fallback | `npx playwright test --headed` | default |

For the CLI fallback, wire these optional env knobs into
`playwright.config.ts` so the choice doesn't require editing the config
each run:

```ts
launchOptions: {
  slowMo: Number(process.env.TESTRUN_SLOWMO || 0),
  executablePath: process.env.TESTRUN_BROWSER_PATH || undefined,
},
channel: process.env.TESTRUN_CHANNEL || undefined,
```

`TESTRUN_SLOWMO=500` makes a headed run followable by a human. Without it the
browser flickers through the suite too fast to see, which defeats the purpose
of asking.

### Headed can fail where headless succeeds — verify, never assume

The bundled Chromium ships two binaries: `chromium_headless_shell` and the
full `chrome.exe`. The full one has more OS dependencies, so a machine can
run the whole suite green headless and still fail to launch headed.

Real failure seen on Windows: every case failed instantly with
`browserType.launch: spawn UNKNOWN`. Running the binary directly gave the
actual cause — `The application has failed to start because its side-by-side
configuration is incorrect`, i.e. a missing Visual C++ Redistributable.
Playwright's own error never mentions it.

So:

- **Never report a headed run as done without seeing the pass/fail lines.**
  Actually run it. A green headless run is not evidence the headed run works.
- When a headed launch fails, run the browser binary directly
  (`& $binary --version`) to get the real OS-level error before diagnosing.
- Preferred fix: drive a browser already installed on the machine —
  `channel: 'chrome'` (or `'msedge'`). It sidesteps the missing dependency
  entirely and needs no system install. Check what's present before
  suggesting the user install a runtime.
- Record the actual engine in `results.json` `run.engine`, including headed
  vs headless and which browser really drove it (e.g.
  `"playwright-cli (Chrome 151, headed)"`). Don't record what you intended.

## Language

- This file and everything in `references/` are English — it costs roughly
  35% fewer tokens than the Vietnamese equivalent for the same content.
- Everything shown to the user — the HTML report, the stdout summary,
  chat replies, `assertion_notes` — is **Vietnamese**.
- Comments inside `scripts/*.py` are Vietnamese (the target audience for
  maintaining these scripts is Vietnamese-speaking devs).

## Scripts

- `scripts/normalize_testcases.py` — turns test cases in any input format
  into canonical `testcases.json`. See `references/testcase-schema.md`.
- `scripts/render_report.py` — validates `results.json` and renders
  `report.html` + a Vietnamese stdout summary.

Both scripts run standalone with `$PY script.py --help`; see each script's
own `--help` for the full CLI, or the "SCRIPTS" section of
`references/testcase-schema.md` for the JSON contracts they read/write.
