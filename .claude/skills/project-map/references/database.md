# Database — inferring the data model, and querying safely

Read this when reconstructing the data model, and always before touching a live
database.

## Part 1 — From the repository (default)

This needs no credentials and carries no risk. Do it first, and often it's
enough.

### Migrations are a changelog of the business

Read them oldest to newest, not just the final schema. The final schema tells
you the shape today; the sequence tells you *why*. A column added in month
eight, backfilled with a default, then made `NOT NULL` in month nine is the
fossil record of a policy that changed — and that policy is usually undocumented
elsewhere.

Worth noticing as you read:

- Columns added later than their table — a capability bolted on.
- Columns dropped, or renamed — and whether code still references the old name.
- A `NOT NULL` added after the fact — implies a backfill, so old rows may hold
  a synthesized value rather than a real one.
- Constraints and unique indexes — each is a business rule the database enforces
  regardless of what the application code believes.
- Indexes — they tell you which queries the team cared about, which points at
  the hot paths.
- Tables with no foreign keys where you'd expect them — the relationship exists
  in the application's head only, so nothing stops orphans.

Common locations: `migrations/`, `db/migrate/`, `alembic/versions/`,
`prisma/schema.prisma`, `*.sql`, `supabase/migrations/`, Django app
`migrations/` directories.

### ORM models fill in what migrations omit

Models carry validation, defaults, lifecycle hooks, soft-delete flags,
serialization rules, and relationship cardinality that the schema alone doesn't
show. Where the model and the migration disagree, say so on the page — that gap
is a real bug waiting to happen, not a detail to smooth over.

### Seed and fixture data shows intent

Seeds encode the values the team expected: status enumerations, role names,
default configuration rows, reference tables. Test fixtures show what a
"normal" record looks like — useful when a column's purpose isn't obvious from
its name.

### Raw SQL in application code

Grep for `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`. Hand-written queries
often carry business logic that never made it into a model: a `WHERE` clause
that quietly excludes cancelled records, a `JOIN` revealing a relationship no
foreign key declares.

## Part 2 — Querying a live database

### Permission — asked once, up front

Permission is established in a single question at the end of the survey (Phase 1
of `SKILL.md`), not accumulated query by query. By then you know whether the repo
has migrations, a database dependency, and which env files exist, so you can ask
something concrete: may you connect, to which environment, and which env files
may you read values from.

Work to that answer for the rest of the session. Re-asking before each statement
fragments the work and teaches the user to approve without reading — which is how
a blanket yes ends up covering something they never considered.

A connection string sitting in `.env`, `docker-compose.yml`, or a config file is
**not** permission on its own. Credentials being reachable says nothing about
whether querying is wanted, and the host they point at may well be production.

What a standing yes does **not** cover, regardless of how it was phrased:

- **Writes.** Permission to connect is permission to read. Never anything else.
- **Production**, unless the user named it. If the connection you were handed
  turns out to point at production, stop and confirm before the first query.
- **Copying credentials or personal data into the docs.** That is governed by the
  rules below, not by the connection permission.

### Before the first query

Confirm out loud which environment you're pointed at, and get the user to
confirm it. Say the host and database name back to them. If the target looks
like production (host contains `prod`, or the user hasn't said otherwise), ask
explicitly whether that's intended and whether a staging copy would do instead.

Prefer, in order: a local copy → a staging or development database →
a read-replica → production. Every step down that list raises the cost of a
mistake.

Use read-only credentials when available. If the only credentials at hand are
read-write, say so — the user may want to create a restricted user first, and
that is a reasonable thing to spend five minutes on before letting an automated
process loose on their data.

### Query discipline

- **Read-only statements only.** `SELECT`, `SHOW`, `EXPLAIN`, `DESCRIBE`, and
  catalog reads. Never `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`,
  `TRUNCATE`, or `GRANT` — not even on a table you believe is scratch.
- **Bound every result set.** Put a `LIMIT` on anything that could return rows.
- **Prefer aggregates to rows.** `COUNT`, `MIN`/`MAX`, `COUNT(DISTINCT …)`,
  `GROUP BY` answer nearly every structural question and pull back no personal
  data. Reach for actual rows only when you need to see a shape, and take a
  handful.
- **Watch the cost.** A full scan on a large table on a production host is a
  performance incident even though it's read-only. Check row counts first;
  sample rather than scan.
- **One statement at a time.** Batching makes it easy to slip a write past your
  own review.

### What live data is actually good for

Schema tells you what is *allowed*. Data tells you what *happens*. The gap
between them is where undocumented rules live:

| Question | Query shape | What it reveals |
|---|---|---|
| Which enum values occur? | `SELECT status, COUNT(*) … GROUP BY status` | Values never used — dead states, or a rule enforced elsewhere |
| Is a nullable column ever null? | `COUNT(*) WHERE col IS NULL` | Effectively-required fields the schema doesn't enforce |
| What range does a numeric column span? | `MIN`, `MAX`, percentiles | Real thresholds vs configured ones |
| Is this relationship really 1-to-many? | `COUNT(*) / COUNT(DISTINCT fk)` | Cardinality the schema permits but reality doesn't use |
| Are there orphans? | `LEFT JOIN … WHERE parent.id IS NULL` | Missing foreign keys, and data integrity debt |
| Is the table live? | `MAX(created_at)`, `COUNT(*)` | Abandoned tables still carried by migrations |

### Two limits, and one confirmation to get

**Data is history, not law.** "No row exceeds 100" means the ceiling was never
hit — not that it can't be. Write those as observations (`[quan sát từ dữ
liệu]`), never as constraints. A future row may break whatever you inferred.

**The database may not be representative.** Development databases are seeded,
partially wiped, or years stale. So before drawing conclusions, **ask the user
to confirm the data is real and representative.** If they can't confirm it,
still record the findings — they may be the only signal available — but label
them `[suy luận từ dữ liệu chưa xác nhận]` so a later reader knows the footing
is soft.

## Part 3 — Reading env files

Two different things get confused here, and they have opposite answers.

**Reading values into your context** — allowed, for files the user confirmed.
You often need this: the connection details live there, and so do the thresholds
an application actually runs with, which may differ from the committed defaults.

**Writing values into the documentation** — never, for any environment. A dev
password is still a password, `docs/` gets committed, and git remembers it after
you delete it. This rule does not bend because the environment sounds harmless.

### Proposing which files to read

The survey lists every env file it found and classifies each by name:

- **Likely safe to propose** — names containing `dev`, `uat`, `local`, `test`,
  `staging`, `sample`, `example`, `template`.
- **Not proposed** — a bare `.env`, or names containing `prod`/`production`.

Present that list with the classification and let the user confirm or trim it
before you read anything. The classification is a starting suggestion, not a
verdict: `.env.dev` can perfectly well point at a real database, because the
filename records what someone intended, not what the file contains. The user
knows which is which; you are guessing from a string.

Read values only from confirmed files:

```bash
python3 {skill_dir}/scripts/survey.py --repo <root> --read-values .env.dev
```

Files outside that list stay masked even when they look innocuous, so a mistake
in the confirmation step fails closed.

### Regardless of permission

Flag it when a real `.env` sits in the working tree with nothing in `.gitignore`
covering it — that is one careless `git add -A` away from publishing credentials
permanently. Report it; don't fix it yourself, since `git rm --cached` and
`.gitignore` edits touch repository history and belong to the user.

Say which keys exist and what they configure. Never quote what they're set to.

### What never goes in the docs

Credentials, connection strings, tokens, API keys, and personal data. The docs
get committed and shared; anything pasted in is published, and git remembers it
even after you delete it.

When an example row makes a point, mask it:

```
email: a***@example.com
phone: 09*****89
name:  [đã ẩn]
```

Prefer describing the shape over quoting a row at all — "`status` chỉ nhận 3
trong 5 giá trị enum: `pending`, `paid`, `cancelled`" carries the finding
without carrying anyone's data.

## Recording what you found

In `docs/project-map/data-model.md`, keep repo-derived facts and live-data
observations visibly separate. A reader needs to know which claims survive a database reset
and which don't — the first are properties of the system, the second are
properties of one snapshot of it.
