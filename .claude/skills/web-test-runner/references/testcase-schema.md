# Test Case & Results Schema

Read when: normalizing input into `testcases.json`, or writing entries into
`results.json` and you need the exact field contract.

## `testcases.json` (output of `scripts/normalize_testcases.py`)

```json
{
  "meta": {"source": "file.xlsx", "generated_at": "ISO-8601", "count": 24},
  "testcases": [{
    "id": "TC-001",
    "title": "Đăng nhập hợp lệ",
    "priority": "P1",
    "tags": ["login"],
    "preconditions": ["Đã có tài khoản"],
    "steps": ["Mở /login", "Nhập email", "Nhập password", "Bấm đăng nhập"],
    "expected": "Chuyển tới /dashboard",
    "data": {"email": "user@test.com"},
    "depends_on": [],
    "needs_clarification": []
  }]
}
```

Field notes:

- `id` — always present, auto-generated as `TC-001`, `TC-002`, ... when the
  source didn't have one. Collisions get a `-b`, `-c`, ... suffix.
- `priority` — always normalized to `P1`/`P2`/`P3` (`P3` is the default when
  unknown/unspecified).
- `tags` — always an array, even if the source had one bare string.
- `data` — always an object. Free text that couldn't be parsed as
  `key=value` pairs is preserved as `{"raw": "..."}` rather than dropped.
- `needs_clarification` — array of short Vietnamese strings flagging
  ambiguity (see `testcase-generation.md` for the Oracle rule this
  supports). Empty array = nothing flagged, not "not checked."
- `extra` — present only when the source had columns that didn't map to any
  known field; nothing from the source is ever silently discarded.

## `results.json` (input to `scripts/render_report.py`)

```json
{
  "run": {
    "base_url": "https://staging.example.com",
    "env": "staging",
    "engine": "playwright-mcp",
    "fix_level": "L2",
    "started_at": "2026-08-08T10:00:00Z",
    "source": "testcases.json"
  },
  "cases": [ /* one entry per test case, appended as each finishes */ ]
}
```

Every case, minimum fields:

```json
{"id": "TC-001", "title": "...", "status": "passed", "priority": "P1", "tags": ["login"]}
```

Non-`passed` cases additionally carry:

```json
{
  "expected": "...", "actual": "...",
  "assertions": [{"description": "...", "result": "pass|fail|skip"}],
  "root_cause": {"category": "tooling|selector|wait|data|env|config|app-bug|testcase",
                 "summary": "...", "evidence": "artifacts/TC-001-net.har"},
  "fix": {"applied": false, "proposed": true, "level": "L3",
          "category": "...", "description": "...", "files": ["..."],
          "diff": "...", "risk": "low|medium|high"},
  "verify": {"rerun": true, "status": "passed", "runs": 1},
  "artifacts": {"screenshot": "artifacts/TC-001.png"},
  "attempts": 2,
  "blocked_by": "..."
}
```

## Enums (exact values, nothing else is valid)

| Field | Values |
|---|---|
| `status` | `passed`, `fixed`, `flaky`, `failed`, `blocked`, `skipped` |
| `assertions[].result` | `pass`, `fail`, `skip` |
| `root_cause.category` | `tooling`, `selector`, `wait`, `data`, `env`, `config`, `app-bug`, `testcase` |
| `fix.risk` | `low`, `medium`, `high` |

## Invariants `render_report.py` enforces

- `fix.applied` and `fix.proposed` are mutually exclusive — a fix is either
  actually applied, or it's a proposal waiting on the user, never both.
- `fix.applied=true` requires `verify.status == "passed"` — an applied fix
  that was never re-verified is a FATAL, not a warning.
- `status="passed"` with any `assertions[].result == "fail"` is FATAL —
  there is no such thing as a partial pass.
- A `fix.level` above the run's configured `fix_level` is fine when
  `fix.proposed` (it's just a suggestion for the user to consider), but
  FATAL when `fix.applied` (that means the run overstepped its allowed
  authority).

See `scripts/render_report.py --print-schema` for the machine-readable
version of this contract, and SKILL.md §4 for what each `status` value
means operationally.
