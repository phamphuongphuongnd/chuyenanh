#!/usr/bin/env python3
"""Survey a repository: languages, entry points, routes, config, migrations, tests.

Read-only and standard-library only. It opens no network connection, writes no
file, and never prints values from .env files — only which keys exist — so
secrets stay out of the transcript and out of any generated documentation.

The point is to skip the tedious first pass of an unfamiliar repo, not to
replace reading it. Treat the output as a map of where to look.

Usage:
    python3 survey.py --repo /path/to/repo
    python3 survey.py --repo . --max-files 20000
"""

from __future__ import annotations  # keeps `X | None` valid on Python 3.8/3.9

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

SKIP_DIRS = {
    ".git", "node_modules", "vendor", "dist", "build", "target", "out",
    "__pycache__", ".venv", "venv", "env", ".tox", ".mypy_cache", ".next",
    ".nuxt", ".pytest_cache", "coverage", ".idea", ".vscode", "bin", "obj",
    ".gradle", ".terraform", "Pods", ".cache", "site-packages", ".svelte-kit",
}

LANGS = {
    ".py": "Python", ".js": "JavaScript", ".jsx": "JavaScript",
    ".ts": "TypeScript", ".tsx": "TypeScript", ".rb": "Ruby", ".go": "Go",
    ".java": "Java", ".kt": "Kotlin", ".cs": "C#", ".php": "PHP",
    ".rs": "Rust", ".swift": "Swift", ".scala": "Scala", ".ex": "Elixir",
    ".exs": "Elixir", ".c": "C", ".cpp": "C++", ".h": "C/C++ header",
    ".sql": "SQL", ".vue": "Vue", ".svelte": "Svelte", ".dart": "Dart",
}

MANIFESTS = [
    "package.json", "requirements.txt", "pyproject.toml", "Pipfile", "setup.py",
    "Gemfile", "go.mod", "pom.xml", "build.gradle", "build.gradle.kts",
    "composer.json", "Cargo.toml", "mix.exs", "pubspec.yaml", "*.csproj",
]

CONFIG_FILES = [
    ".env.example", ".env.sample", ".env.template", "config.yml", "config.yaml",
    "config.json", "settings.py", "appsettings.json", "application.yml",
    "application.properties", "docker-compose.yml", "docker-compose.yaml",
    "Dockerfile", "serverless.yml", "wrangler.toml", "nginx.conf",
]

MIGRATION_HINTS = [
    "migrations", "migrate", "alembic", "schema.rb", "schema.prisma",
    "liquibase", "flyway", "db/migrate",
]

# (label, regex) — kept deliberately loose; false positives cost far less than
# a missed entry point, since the model verifies anything it acts on.
ROUTE_PATTERNS = [
    ("http-route", re.compile(
        r"""(?:app|router|r|srv|mux)\.(?:get|post|put|patch|delete|all|use)\s*\(\s*['"`]([^'"`]+)"""
        , re.I)),
    ("decorator-route", re.compile(
        r"""@(?:app|router|blueprint|bp)\.(?:route|get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)""")),
    ("spring-mapping", re.compile(
        r"""@(?:Request|Get|Post|Put|Patch|Delete)Mapping\s*\(\s*(?:value\s*=\s*)?['"]([^'"]+)""")),
    ("aspnet-route", re.compile(
        r"""\[Http(?:Get|Post|Put|Patch|Delete)\s*\(\s*['"]([^'"]*)""")),
    ("nest-route", re.compile(
        r"""@(?:Get|Post|Put|Patch|Delete)\s*\(\s*['"]([^'"]*)""")),
    ("django-url", re.compile(
        r"""(?:path|re_path|url)\s*\(\s*r?['"]([^'"]*)""")),
    ("go-handler", re.compile(
        r"""http\.HandleFunc\s*\(\s*['"]([^'"]+)""")),
]

ENTRY_PATTERNS = [
    ("cli", re.compile(r"""(?:argparse\.ArgumentParser|@click\.command|cobra\.Command|new Command\()""")),
    ("main", re.compile(r"""(?:if\s+__name__\s*==\s*['"]__main__['"]|func\s+main\s*\(|public\s+static\s+void\s+main)""")),
    ("scheduled-job", re.compile(r"""(?:@Scheduled|@periodic_task|celery\.schedules|cron\.schedule|@Cron\()""", re.I)),
    ("queue-consumer", re.compile(r"""(?:@(?:app\.)?task\b|Sidekiq::Worker|@Processor\(|@RabbitSubscribe|consumer\.subscribe)""")),
    ("event-handler", re.compile(r"""(?:@EventHandler|\.on\s*\(\s*['"]|addEventListener\s*\(\s*['"])""")),
    ("graphql", re.compile(r"""(?:type\s+Query\s*\{|Resolver\(\)|@Resolver)""")),
]

ENV_KEY = re.compile(r"""^\s*(?:export\s+)?([A-Z][A-Z0-9_]{2,})\s*[=:]""", re.M)
ENV_KV = re.compile(r"""^\s*(?:export\s+)?([A-Z][A-Z0-9_]{2,})\s*[=:]\s*(.*)$""", re.M)
ENV_READ = re.compile(
    r"""(?:process\.env\.([A-Z0-9_]+)|os\.environ(?:\.get)?\[?\(?['"]([A-Z0-9_]+)|"""
    r"""getenv\(\s*['"]([A-Z0-9_]+)|ENV\[['"]([A-Z0-9_]+))""")

TEXT_EXT = set(LANGS) | {
    ".yml", ".yaml", ".json", ".toml", ".ini", ".cfg", ".properties",
    ".md", ".txt", ".env", ".xml", ".gradle", ".tf", ".sh",
}


def walk(root: Path, max_files: int) -> list[Path]:
    """Collect candidate files, skipping vendored and build directories."""
    found: list[Path] = []
    stack = [root]
    while stack and len(found) < max_files:
        d = stack.pop()
        try:
            entries = list(d.iterdir())
        except (PermissionError, OSError):
            continue
        for e in entries:
            if e.is_symlink():
                continue  # avoid cycles and escaping the repo
            if e.is_dir():
                if e.name not in SKIP_DIRS:
                    stack.append(e)
            elif e.is_file():
                found.append(e)
                if len(found) >= max_files:
                    break
    return found


def read_text(p: Path, limit: int = 400_000) -> str:
    try:
        if p.stat().st_size > limit:
            return ""
        return p.read_text(encoding="utf-8", errors="ignore")
    except (OSError, ValueError):
        return ""


TEMPLATE_SUFFIXES = (".example", ".sample", ".template", ".dist")
SAFE_HINTS = ("dev", "uat", "local", "test", "staging", "sample", "example",
              "template", "dist")
UNSAFE_HINTS = ("prod", "production", "live")


def is_env_file(p: Path) -> bool:
    return p.name == ".env" or p.name.startswith(".env.") or p.suffix == ".env"


def is_secret_file(p: Path) -> bool:
    """True for env files that hold real values rather than a documented template."""
    n = p.name
    return is_env_file(p) and not n.endswith(TEMPLATE_SUFFIXES)


def classify_env_file(p: Path) -> str:
    """Suggest whether this file is safe to propose reading values from.

    A suggestion only. The filename records what someone intended, not what the
    file contains — `.env.dev` can point at a real database — so the caller is
    expected to confirm with the user before anything is unmasked.
    """
    n = p.name.lower()
    if any(h in n for h in UNSAFE_HINTS):
        return "not_proposed"
    if n == ".env":
        return "not_proposed"  # bare .env is whatever the machine actually runs
    if any(h in n for h in SAFE_HINTS):
        return "proposed"
    return "not_proposed"


def gitignore_covers_env(root: Path) -> bool:
    """Whether some .gitignore in the tree mentions .env at all."""
    for gi in list(root.glob(".gitignore")) + list(root.glob("*/.gitignore")):
        try:
            if ".env" in gi.read_text(encoding="utf-8", errors="ignore"):
                return True
        except OSError:
            continue
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=".", help="repository root (default: cwd)")
    ap.add_argument("--max-files", type=int, default=20000,
                    help="stop after this many files (default: 20000)")
    ap.add_argument("--max-routes", type=int, default=200,
                    help="cap route lines reported per pattern (default: 200)")
    ap.add_argument("--read-values", action="append", default=[], metavar="PATH",
                    help=(
                        "repo-relative path of an env file whose VALUES may be "
                        "printed. Repeatable. Default: none, so only key names "
                        "are shown. Anything not listed stays masked even if its "
                        "name looks harmless, so a mistake fails closed. This "
                        "controls what gets printed — it never permits copying "
                        "credentials into generated documentation."))
    args = ap.parse_args()

    root = Path(args.repo).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 1

    files = walk(root, args.max_files)
    rel = lambda p: str(p.relative_to(root))  # noqa: E731

    langs: Counter[str] = Counter()
    for p in files:
        lang = LANGS.get(p.suffix)
        if lang:
            langs[lang] += 1

    manifests, configs, migrations, tests, docs = [], [], [], [], []
    for p in files:
        r = rel(p)
        low = r.lower()
        if p.name in MANIFESTS or p.suffix == ".csproj":
            manifests.append(r)
        if p.name in CONFIG_FILES:
            configs.append(r)
        if any(h in low for h in MIGRATION_HINTS):
            migrations.append(r)
        if re.search(r"(^|/)(tests?|spec|__tests__)(/|$)|_test\.|\.test\.|\.spec\.|test_", low):
            tests.append(r)
        if low.endswith(".md"):
            docs.append(r)

    routes: dict[str, list[str]] = defaultdict(list)
    entries: dict[str, list[str]] = defaultdict(list)
    env_declared: set[str] = set()
    env_read: set[str] = set()
    secret_files: list[str] = []
    env_inventory: list[dict] = []
    env_values: dict[str, dict[str, str]] = {}

    # Normalise the allowlist so `--read-values .env.dev`, `./.env.dev` and an
    # absolute path all match the same file.
    allowed_values = set()
    for raw in args.read_values:
        cand = Path(raw)
        cand = cand if cand.is_absolute() else (root / raw)
        try:
            allowed_values.add(str(cand.resolve()))
        except OSError:
            allowed_values.add(str(cand))

    for p in files:
        # Dotfiles like `.env` have an empty suffix, so they must be matched by
        # name — otherwise the secret-file branch below never runs, which is
        # precisely the check that must not be skipped.
        if (p.suffix not in TEXT_EXT
                and p.name not in CONFIG_FILES
                and not p.name.startswith(".env")):
            continue

        if is_env_file(p):
            unmasked = str(p.resolve()) in allowed_values
            keys = [m.group(1) for m in ENV_KEY.finditer(read_text(p))]
            env_declared.update(keys)
            env_inventory.append({
                "path": rel(p),
                "holds_real_values": is_secret_file(p),
                "suggestion": classify_env_file(p),
                "keys": sorted(set(keys))[:80],
                "values_shown": unmasked,
            })
            if is_secret_file(p):
                secret_files.append(rel(p))
            if unmasked:
                # Values printed only for paths the caller explicitly allowed,
                # after confirming with the user which files are safe.
                text = read_text(p)
                env_values[rel(p)] = {
                    m.group(1): m.group(2).strip().strip("'\"")
                    for m in ENV_KV.finditer(text)
                }
            if is_secret_file(p):
                continue  # masked files contribute key names only

        text = read_text(p)
        if not text:
            continue

        if p.name in CONFIG_FILES or p.suffix in {".env", ".yml", ".yaml", ".properties"}:
            env_declared.update(m.group(1) for m in ENV_KEY.finditer(text))
        for m in ENV_READ.finditer(text):
            env_read.add(next(g for g in m.groups() if g))

        if p.suffix in LANGS:
            for label, pat in ROUTE_PATTERNS:
                for i, line in enumerate(text.splitlines(), 1):
                    if len(routes[label]) >= args.max_routes:
                        break
                    if pat.search(line):
                        routes[label].append(f"{rel(p)}:{i}: {line.strip()[:160]}")
            for label, pat in ENTRY_PATTERNS:
                if pat.search(text):
                    entries[label].append(rel(p))

    biggest = sorted(
        ((p.stat().st_size, rel(p)) for p in files if p.suffix in LANGS),
        reverse=True)[:15]

    warnings: list[str] = []
    if secret_files and not gitignore_covers_env(root):
        # One careless `git add -A` publishes these permanently. Report it;
        # fixing it means touching .gitignore or repo history, which is the
        # user's call, not this script's.
        warnings.append(
            f"{', '.join(secret_files)} hold real values and no .gitignore "
            "mentions .env — they are one `git add -A` away from being "
            "committed. Recommend gitignoring them and rotating anything "
            "already pushed.")

    report = {
        "repo": str(root),
        "counts": {
            "files_scanned": len(files),
            "truncated": len(files) >= args.max_files,
        },
        "languages": dict(langs.most_common()),
        "manifests": sorted(manifests)[:40],
        "config_files": sorted(configs)[:40],
        "migrations": sorted(migrations)[:80],
        "docs": sorted(docs)[:40],
        "tests_sample": sorted(tests)[:30],
        "test_count": len(tests),
        "routes": {k: v for k, v in routes.items() if v},
        "entry_points": {k: sorted(set(v))[:30] for k, v in entries.items() if v},
        "env_keys_declared": sorted(env_declared)[:120],
        "env_keys_read_in_code": sorted(env_read)[:120],
        "env_declared_but_never_read": sorted(env_declared - env_read)[:60],
        "env_read_but_not_declared": sorted(env_read - env_declared)[:60],
        "secret_files_present": secret_files,
        "env_files_found": sorted(env_inventory, key=lambda e: e["path"]),
        "env_values_unmasked": env_values,
        "gitignore_covers_env": gitignore_covers_env(root),
        "warnings": warnings,
        "largest_source_files": [{"bytes": b, "path": p} for b, p in biggest],
        "note": (
            "env values are masked unless the path was passed to --read-values. "
            "`suggestion` is a filename-based hint only — confirm with the user "
            "before unmasking, since a name records intent, not content. "
            "Unmasking affects what is printed here; credentials must never be "
            "copied into generated documentation regardless."
        ),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
