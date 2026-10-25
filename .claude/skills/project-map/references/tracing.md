# Tracing techniques

Read this when a flow resists the obvious approach — the entry point isn't
where you expected, the logic is scattered, or the framework hides the wiring.

## Finding entry points by stack

Entry points are where external input arrives. Everything else is reachable
from them, so the map starts here.

| Stack | Look for |
|---|---|
| Express / Fastify / Koa | `app.get(`, `router.post(`, `app.use(` |
| NestJS | `@Controller`, `@Get`, `@Post` |
| Django | `urls.py` → `urlpatterns`, then the view |
| Flask / FastAPI | `@app.route`, `@router.get`, `APIRouter` |
| Rails | `config/routes.rb`, then `app/controllers/` |
| Spring | `@RestController`, `@RequestMapping`, `@GetMapping` |
| ASP.NET | `[ApiController]`, `[HttpGet]`, `MapGet(` |
| Laravel | `routes/web.php`, `routes/api.php` |
| Go | `http.HandleFunc`, `mux.HandleFunc`, `r.Get(` |
| gRPC | `.proto` service definitions, then the generated server impl |
| GraphQL | schema files, then resolvers |
| CLI | `argparse`, `click`, `cobra`, `commander`, `main()` |
| Queue workers | `@task`, `@Processor`, consumer registrations, `Sidekiq::Worker` |
| Cron / schedulers | crontab files, `@Scheduled`, `celery beat`, cloud scheduler configs |
| Webhooks | routes with `webhook`/`callback` in the path, signature verification |
| Event handlers | `on(`, `subscribe(`, `addEventListener`, message-bus registrations |

Don't stop at HTTP. Scheduled jobs and queue consumers are entry points too,
and they're where forgotten business logic tends to accumulate — nobody reads
the cron job until it breaks.

## Following a flow

Work forward from the entry point, one hop at a time. At each step ask what
this function calls, and grep for the callee's definition rather than guessing
from its name. Names lie — especially in old code where the function outgrew
what it was called.

When a call target is ambiguous (interface, dependency injection, dynamic
dispatch), find the concrete implementation by grepping for the class that
implements the interface, or the DI registration. If several implementations
exist, say which one is wired up in the configuration you're reading, and note
that others exist.

Stop descending when you hit a boundary: a library call, a database write, an
HTTP request to another service. Note what crosses the boundary and move back
up. Following a flow into a third-party library rarely earns its cost.

## Working backwards when you can't find the front

Sometimes you know the outcome, not the trigger — a row appears in a table, an
email goes out. Then work backwards:

- Grep for the table or model name to find every write site.
- Grep for the email template name, the log message, the error string.
- Grep for a magic constant you saw in the data.

String literals are the best handles in an unfamiliar codebase. An error
message a user reported is often the fastest route into the code that produced
it.

## Finding the parts that matter

**Thresholds and magic numbers.** Grep for bare numeric literals in comparisons
— `> 100`, `>= 0.8`, `== 3`. Each is a rule someone decided and nobody wrote
down. Also read the config schema, `.env.example`, and default values in
settings classes; then grep each key to find where it's actually read. A key
defined but never read is dead config, and worth flagging — someone will
otherwise try to tune it and wonder why nothing changes.

**Validation.** Look for schema validators (`zod`, `joi`, `pydantic`,
`class-validator`, form/serializer classes), guard clauses at function top,
database constraints, and manual `if not ... raise` blocks. Validation is
usually spread across all four layers, and they don't always agree — where they
disagree, that's a finding.

**Error handling.** Grep for `catch`, `except`, `rescue`, `recover`. Pay
attention to empty handlers and ones that only log: those turn failures into
silence, which is how a system can be broken for weeks without anyone knowing.

**Feature flags and toggles.** Grep for `flag`, `feature`, `enabled`, `toggle`,
`if config.`. Flags create hidden branches — code that looks live may be dark,
and vice versa. A flag defaulting one way in code and another in production
config is a trap.

**Business rules hidden in queries.** A `WHERE status != 'cancelled'` inside a
repository method is a business rule wearing a data-access costume. These are
easy to miss because they don't look like logic.

## Reading tests as documentation

Tests state intent more directly than implementation does — a test name is
often the only place a rule is written in plain language. Test fixtures show
what a valid record looks like; edge-case tests reveal the boundaries someone
already thought about.

But treat tests as evidence of intent, not proof of behavior: a test can be
skipped, outdated, or asserting the wrong thing. When a test and the code
disagree, read the code again — and if they really do disagree, that's a
finding worth putting on the page.

## Judging what's alive

Not everything in a repo runs. Before documenting something as a feature, check
whether anything reaches it:

- Grep for callers of the entry function. No callers and no route means dead.
- Check git recency (`git log -1 --format=%ci -- <path>`) — untouched for years
  alongside an actively-changing codebase is a signal, though not proof.
- Look for the feature flag that gates it, and its default.
- Commented-out route registrations are a strong tell.

Say what you found rather than deleting it from the map: "[suy luận] có vẻ
không còn dùng — không tìm thấy caller, route đã comment tại `routes.py:88`"
is more useful to the reader than silence, and it's exactly the sort of thing a
handover needs to surface.

## When the codebase is too big to hold

Trace one feature at a time and write its page before starting the next. Trying
to keep five flows in your head at once produces vaguer pages than doing them
sequentially.

For genuinely large systems, dispatch a subagent per feature with a precise
brief — the entry point, the files you already know are involved, and the
template to fill — and have each return a finished page. That keeps each
context small enough to stay accurate, which matters more here than speed.
