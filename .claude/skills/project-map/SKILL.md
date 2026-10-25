---
name: project-map
description: Reverse-engineer an unfamiliar or undocumented codebase into documentation. Runs in two modes — an overview by default (what the system does, what features exist, tech stack, architecture components), or a full detailed analysis when asked, covering every feature's validation rules, branches, loops, config thresholds and the special values that flip behaviour, inspecting the database structure and data, and producing a technical document plus a business document complete enough to rebuild the software from. Use this skill whenever the user asks what a project does or what features it has, how a specific feature or flow works, where a business rule lives, why the system behaves a certain way, what a config value controls, or asks to document, map, explore, audit, hand over, or onboard someone onto a codebase — including when they say they inherited a project, are new to a repo, or need to understand code before changing it. Also use it when they ask what tables or columns exist and how they relate.
---

# Project Map

Turn a codebase you don't know into documentation you can navigate.

The reason this needs a method rather than just reading code: in an unfamiliar
project the hard part is not reading any single file, it's knowing which files
matter and how they connect. Reading top-to-bottom drowns you in plumbing while
the business rules stay hidden — buried in a validation helper, a config
default, a `WHERE` clause. So work outside-in: find the entry points, follow
what they call, and let the interesting parts announce themselves.

Written for projects nobody fully remembers anymore — legacy handovers, audits,
onboarding. That shapes what counts as valuable: the rules and thresholds
someone would otherwise have to rediscover by breaking production.

## Two modes

**Detail mode** when the request says **"chi tiết"** — or "detail", "đầy đủ",
"phân tích kỹ" — or when the request carries the name `project-map-detail` in any
form: as a slash command, as bare text, hyphenated or spaced, with or without a
leading slash. Treat that name as an unambiguous request for detail mode; it is
not a topic to ask about. **Overview mode** otherwise; that is the default.

Say which mode you're running in one sentence before starting. Detail mode costs
many times the effort, so a silent wrong guess means either the user waits a long
time for something they didn't want, or they get a thin document and only find
out when they need it. Announced, a wrong guess costs one sentence to correct.

A request that names one specific feature *and* asks for detail — "phân tích chi
tiết luồng đặt chỗ" — is detail mode scoped to that feature. Don't build the full
catalogue; do write enough of `index.md` that the page is reachable, since a page
nothing links to is invisible.

## Output

Everything lands in `docs/project-map/` (create it if missing).

**Overview mode** — one file:

```
docs/project-map/
└── index.md      what the system does, feature catalogue, tech stack, architecture
```

**Detail mode** — the overview plus two documents, split by who reads them:

```
docs/project-map/
├── index.md         as above
├── technical.md     flows with file:line, DB structure, config names, mechanics
└── business.md      rules, conditions and worked examples — almost no code
```

The split exists because these are two different readers with opposite needs.
Someone about to change the code needs the exact line; someone learning the
domain is slowed down by it. One merged file serves one of them badly.

Templates are in `assets/`. Copy their structure rather than inventing a new one
each time — consistent shape is what makes the set navigable.

Nesting under `docs/project-map/` rather than `docs/` directly is deliberate:
most projects already keep handwritten documentation in `docs/`, and generated
pages should sit beside it without competing for `docs/index.md`. If the
directory already exists from an earlier run, update it in place — but if any
file there looks hand-edited, show the user before overwriting. Losing someone's
edits to an automated run is not recoverable if they weren't committed.

Write the docs in **Vietnamese with English technical terms**: identifiers, file
paths, table and column names, and technical terms (`race condition`,
`idempotency`, `soft delete`) stay English; explanation and reasoning in
Vietnamese. File names are English kebab-case so links stay greppable.

## The rule that makes this trustworthy: cite or mark

Every claim about behavior carries either a citation or an uncertainty marker.

- **Verified** — cite `path/to/file.py:142`. You read that line and it says so.
- **Inferred** — prefix `[suy luận]` and say from what. Naming conventions,
  framework defaults, and "this is the only caller" arguments are inference,
  not fact.
- **Unknown** — prefix `[chưa rõ]` and put it in the Open questions section.

This matters more here than in ordinary documentation. The reader is someone who
does *not* know the system — they cannot spot a wrong claim, so they will act on
it. A page that quietly mixes what the code does with what it probably does is
worse than no page, because it converts your guesses into their certainties.
Being visibly unsure costs nothing; being confidently wrong costs a production
incident.

In `business.md` the citation is usually a burden on the reader, so keep the
markers but move the line references to `technical.md` — the uncertainty is what
they need, the file path is not.

When you genuinely cannot resolve something within reasonable effort, say so and
move on. An honest gap is a finding — often the most valuable one, because it
points at exactly the knowledge that was lost.

## Phase 1 — Survey, then ask once

Get oriented before reading anything in depth:

```bash
python3 {skill_dir}/scripts/survey.py --repo <repo-root>
```

It reports languages, likely entry points, route/handler declarations, config
files and environment variables, migration directories, and where the tests
live. Read-only, standard library only, no network. By default it prints only
which keys a `.env` declares, never their values.

Use it to decide where to look, not as a substitute for looking. If it misses
something for this stack, fall back to `Glob`/`Grep`; the point is just to skip
the tedious first twenty minutes.

**Then ask for permissions once, in a single question.** The survey has just
told you whether this repo has migrations, database dependencies, or env files —
so this is the moment when you can ask something specific instead of vague, and
the moment after which everything else can run uninterrupted:

- May you connect to a live database, and if so which environment?
- Which of the env files found may you read values from? (see Database below)

Then work to that answer for the rest of the session. Asking again before each
query is the behaviour to avoid — it fragments the work and trains the user to
approve without reading.

**Record what was asked and what was granted** in the header of every document
you write — which environment you were allowed to query, which env files you were
allowed to unmask, and what you did not touch. A reader months later needs to
know whether a claim rests on real data or only on the repository, and a
permission that lives solely in a chat log cannot be audited by anyone,
including you on the next run.

**Skip the question entirely** when the survey found no migrations, no database
dependency, and no env files. Asking then is noise.

Overview mode rarely needs either permission; detail mode usually needs both,
since it documents real data. Ask anyway in overview mode if the repo has a
database — a schema question often surfaces mid-way.

Then read, in this order: the README, the dependency manifest (what the project
pulls in tells you what it does), the routes or CLI commands, and the migration
directory. Those four give you most of the shape.

## Overview mode

Write `docs/project-map/index.md` from `assets/index-template.md`:

- What the system does and who it serves.
- The feature catalogue: each feature with a short line on what it means and
  roughly how it works.
- The technology stack.
- The architecture components and how they fit together.

A "feature" here is a capability a *user or calling system* would name — "đặt
chỗ", "tính giá", "gửi email xác nhận" — not a module or a class. Modules are
how the code is filed; features are what the system does. When they don't line
up (they often don't), follow the capability across whatever files it touches.

Stop there. No validation tables, no branch analysis, no database queries — that
is what detail mode is for. Finish by telling the user detail mode exists and
what it would add, so they can ask for it if the overview isn't enough.

## Detail mode

Everything in overview mode, plus, **for every feature**, the analysis below —
written into `technical.md`, with the domain-level consequences written into
`business.md`.

**The main flow** — entry point → validation → business logic → persistence →
response, with `file:line` at each step. A numbered list beats prose here.

**Validation and its rejections** — what's checked, in what order, what the
caller gets back on each failure. Order matters: a check that runs first hides
the ones after it, which is exactly the sort of thing that confuses whoever
edits it next.

**Branches** — every meaningful `if`/`switch`/guard clause, and what makes each
side happen. Note branches that look unreachable; either you misread the
conditions, or it's dead code, and both are worth saying out loud.

**Loops and retries** — what bounds them, what happens when the bound is hit,
whether anything sleeps or backs off, whether the whole thing is safe to run
twice.

When you write out a derived sequence or total rather than the expression that
produces it, evaluate it rather than eyeballing it — `2 ** attempt` over
`range(3)` is 1, 2, 4, and writing 0, 2, 4 because the loop starts at zero is the
kind of slip that survives review precisely because the citation next to it is
correct. Check the first and last elements specifically; boundaries are where
these go wrong. Better still, give both: the expression *and* its values, so a
reader can catch you.

**Thresholds, config, and the special values that flip behaviour** — the
constants and settings that change what the system does: name, current value,
where it's defined, where it's read, and what visibly changes if you move it.
Pay particular attention to the ones that feed a branch condition, because those
are where behaviour actually turns over; a threshold nothing branches on is
merely a number. Hardcoded magic numbers count and matter more, since nobody
knows they exist. Follow each value from definition to use — a constant defined
and never read is a trap for the next person, and worth flagging.

**Failure paths** — what's caught, what's swallowed, what propagates, what the
user sees. Swallowed exceptions are worth calling out specifically; they are how
systems fail silently.

**Business rules** — the domain rules the code enforces, stated in domain terms
rather than code terms. This is the part that was never written down anywhere
else, and the reason a handover document is worth reading at all.

**Database structure and data** — go and look, within whatever permission you
were given in Phase 1. Structure tells you what is allowed; data tells you what
actually happens. See the Database section.

**Worked examples** — for each rule with a threshold or a branch, give a concrete
case on each side of the line:

> Đơn 600.000đ → miễn phí ship. Đơn 499.000đ → cộng 30.000đ phí ship.

Examples are what turn a rule someone can recite into a rule they can apply, and
they expose your own misreadings: if you cannot produce a concrete case, you have
not understood the condition. Draw them from real data when you have access, and
mask anything personal.

If a flow spans several services or files, a small diagram helps. Mermaid
`flowchart` or `sequenceDiagram` in a fenced block renders on GitHub and stays
diffable. Use one when the branching genuinely resists prose — not by default.

### The bar for the pair

Before you call detail mode finished, apply this test:

> Could another AI, reading **both documents** and never seeing the code, build
> software that behaves the same way — and that the existing callers and the
> existing database could be pointed at unchanged?

Where the answer is no, something is missing — a rule, a threshold, a branch, an
error case, a default. Go find it.

The test spans the pair deliberately. `business.md` alone cannot pass it and
should not try: route paths, request field names, response shapes and exception
types are not domain knowledge, and stuffing them in would wreck the document
for the reader it exists for. The rules live in one file, the contract surface in
the other, and the rebuild needs both.

That split is also what makes the test bite, because each document has a
characteristic way of failing:

- `business.md` drops a condition — an ordering, a boundary direction, a case the
  code handles silently. Ask of every rule: which comparison, which side of the
  line, what happens at exactly the threshold.
- `technical.md` describes the machinery but never states the **contract**: the
  route and method, the exact request and response shapes, the status code for
  each outcome, which exception class is retried versus which propagates, how the
  environment is selected, the table and column names with their types. These
  feel too obvious to write down while you are reading the code — and they are
  exactly what someone without the code cannot recover.

Read both back with the question in mind and note every place you would have to
guess. Each of those is a hole in the document, not a detail.

This test is more useful than any checklist because it is adversarial about
omissions rather than about form. It is easy to write documents that look
complete and silently drop the condition nobody thought to ask about; it is hard
to rebuild a system from documents with a hole in them.

**Stating what the system does *not* do counts.** No authentication, no negative
value check, no deduplication, a scorer that is a stub returning a constant — a
rebuilder who isn't told will invent the missing guard and produce something that
behaves differently from the original in exactly the places that matter.

## Database

Reconstruct the data model from the repo first: migrations (in order — they are
a changelog of the schema and often of the business), ORM models, seed and
fixture data, and raw SQL in the code. This works without credentials, without
risk, and on any checkout. Read migrations oldest to newest: a column added
later, or backfilled, usually marks a moment the business changed.

Record it in `technical.md` (detail mode) — tables, columns and types,
relationships, indexes and what they suggest about query patterns, and
constraints, since a `UNIQUE` or `CHECK` constraint is a business rule the
database enforces whether or not the application does. Constraints that encode
domain rules also belong in `business.md`, stated in domain terms.

Live database access and env-file reading both run on the permission you asked
for in Phase 1. `references/database.md` has the full protocol — read it before
the first query, and before reading values out of any env file. In short:
confirm which host and database you're pointed at before querying, keep every
statement read-only and bounded, prefer aggregates over rows, and never copy
credentials or personal data into the docs regardless of which environment they
came from.

## Working on large projects

Context is the binding constraint, so spend it where it pays. Survey broadly but
read deeply only along the path you're tracing. When a repo is too big to hold at
once, dispatch subagents per feature — each returns a finished section — rather
than trying to keep the whole system in your head.

When two flat files would be unreadable — a few dozen features — keep the
two-track split but let each become a directory, `technical/` and `business/`,
one file per feature, with `index.md` linking both tracks. The split by reader is
the part that matters; the file count is not.

Prefer `Grep` for a symbol over reading whole files. Read a file fully when you
are about to make claims about its control flow; skim it when you only need to
know what it exports.

## Keeping the map alive

At the end of a run, note in `index.md` which mode you ran, what permissions you
were granted, and which commit the map was built from
(`git rev-parse --short HEAD`). Documentation that doesn't say how old it is gets
trusted long past its expiry, and documentation that doesn't say how deep it went
gets mistaken for exhaustive.

When you later find the code has moved on, update the affected pages and say what
changed rather than silently rewriting — the delta is often the most interesting
thing on the page.

See `references/tracing.md` when a flow resists the obvious approach: finding
entry points per stack, working backwards from an outcome, and judging whether
code is still alive.
