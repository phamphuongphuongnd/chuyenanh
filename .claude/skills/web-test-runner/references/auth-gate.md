# Auth Gate

Read when: preflight check 3 (in SKILL.md §0) determined the target needs a
login.

## Rule

Never run test cases against an app that's currently locked behind a login
you haven't gotten past. A run that starts hitting protected routes while
still logged out just produces garbage failures.

**You never log in yourself and never type a password** — not into a form,
not into an auth API call, not into a script — even if the user pastes a
password in chat or suggests a workaround. This is the project's root rule
(`CLAUDE.md` → 🔒), not a judgment call: say it's a fixed limit and move on.
The user logs in themselves; you reuse the session they saved.

## Where the session comes from

Sessions are Playwright storage-state files the **user** creates:

- `auth_states.primary` in `testrun.config.yaml` (default `.auth/user.json`)
- `auth_states.secondary` (default `.auth/user2.json`) — second account for
  permission cases (admin vs non-admin…).

You may only **check that the file exists** and **pass its path** to
Playwright (`storageState` in config / `browser.newContext({ storageState })`).
Never open, print, copy, edit or delete it — it holds cookies/tokens.
`.auth/` must be in `.gitignore`; if it isn't, tell the user, don't edit the
file's neighbours to "fix" it silently.

## Flow

```
Does the app need login?
├── NO  → run the suite normally.
└── YES → does the session file exist?
          ├── YES → start the browser context with storageState = that path
          │         → verify logged-in (see "Verifying") → run the suite.
          └── NO  → STOP. Give the user the command to create it (below).
```

Login-form test cases inside the suite:
- **Negative cases** with obviously fake values (e.g. `sai-mat-khau-123`,
  `khong-ton-tai@example.invalid`) are fine — they are not credentials.
- **Successful-login cases** need a real password → mark
  `blocked` with reason "cần người dùng tự đăng nhập", never type it.

OTP / MFA / SSO / CAPTCHA: the same command works — the user completes those
steps themselves in the window.

## Asking the user to create a session

Send all of this in **one** message:

1. **What hasn't run yet** — which cases/suite are blocked.
2. **The command to run themselves** (in its own `bash` block):
   ```bash
   npx playwright codegen <base_url> --save-storage=.auth/user.json
   ```
   Log in in the window that opens, then close it. Second account →
   `.auth/user2.json`.
3. **Why** — the root rule forbids you from logging in; the file lets every
   later run reuse their session without asking again (until it expires).
4. **The blast radius if they don't** — roughly how many cases will end up
   `blocked` (e.g. "all 14 cases that touch `/dashboard` or later").

## Verifying "done"

When the user says they've created the session, that is a **claim**, not a
fact. Verify before resuming:

- Check the file exists (existence only).
- Start a context with it and use `evaluate` / navigation to check something
  that only exists post-login — a known DOM marker, the current path, or
  navigating to a protected route and confirming it doesn't bounce to
  `/login`.
- Do not resume the suite on "xong rồi" / "done" alone.

If the session dies mid-run (expired cookie, server restart, wiped SPA
state) — **treat it as one environment error, not N separate application
bugs.** Re-probe with the same check; if it fails, stop and ask the user to
re-run the command above. Every case that failed purely because the session
was dead is re-run after recovery, not reported as N `app-bug` findings.

## Secrets

Never write a password, cookie value, or session/auth token into
`results.json`, the HTML report, or a chat reply — not even truncated, not
even in a "for debugging" aside. An account **identifier** (an email
address, a username) is fine to log; the credential that unlocks it is not.
