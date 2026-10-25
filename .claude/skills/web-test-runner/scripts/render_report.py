#!/usr/bin/env python3
"""Doc results.json, validate theo contract (xem
references/testcase-schema.md), sinh report.html va tom tat tieng Viet."""

import argparse
import json
import os
import sys
from datetime import datetime

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

STATUS_ENUM = {"passed", "fixed", "flaky", "failed", "blocked", "skipped"}
ASSERTION_RESULT_ENUM = {"pass", "fail", "skip"}
ROOT_CAUSE_ENUM = {"tooling", "selector", "wait", "data", "env", "config",
                    "app-bug", "testcase"}
FIX_RISK_ENUM = {"low", "medium", "high"}

FIX_LEVEL_ORDER = {"L0": 0, "L1": 1, "L2": 2, "L3": 3}

SCHEMA_DOC = """
results.json contract
======================
Root object:
  cases: array (BAT BUOC)
  run:   {base_url, env, engine, fix_level, started_at, source}

Case (moi status can toi thieu): id, title, status, priority, tags
Case fail/blocked/flaky them: expected, actual, assertions[],
  root_cause{category, summary, evidence}, fix{applied, proposed, category,
  description, files, diff, risk, level}, verify{rerun, status, runs},
  artifacts{}, attempts, blocked_by

status enum:            passed | fixed | flaky | failed | blocked | skipped
assertions[].result:    pass | fail | skip
root_cause.category:    tooling | selector | wait | data | env | config |
                         app-bug | testcase
fix.risk:                low | medium | high
fix.applied / fix.proposed: loai tru nhau (khong cung true)
fix.level: cap fix that su duoc dung. proposed L3 trong run co fix_level=L2
  la HOP LE (chi la de xuat cho user duyet). applied L3 trong run co
  fix_level=L2 la FATAL (vuot quyen).
""".strip()


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict) or "cases" not in data or not data["cases"]:
        fatal(["Thieu key bat buoc \"cases\" (array), hoac cases rong."])
    cases = []
    for raw in data["cases"]:
        c = dict(raw)
        rc = c.get("root_cause")
        if isinstance(rc, str):
            c["root_cause"] = {"category": "", "summary": rc, "evidence": ""}
        fx = c.get("fix")
        if isinstance(fx, str):
            c["fix"] = {"applied": False, "proposed": False,
                        "description": fx}
        cases.append(c)
    data["cases"] = cases
    return data


def fatal(messages):
    print("FATAL — khong sinh report:", file=sys.stderr)
    for m in messages:
        print(f"  - {m}", file=sys.stderr)
    sys.exit(1)


def validate(data):
    fatals, warnings = [], []
    run = data.get("run", {}) or {}
    run_fix_level = FIX_LEVEL_ORDER.get(run.get("fix_level", "L2"), 2)
    seen_ids = set()

    for c in data["cases"]:
        cid = c.get("id", "<no id>")
        status = c.get("status")
        assertions = c.get("assertions") or []
        fix = c.get("fix") or {}
        root_cause = c.get("root_cause") or {}
        verify = c.get("verify") or {}
        attempts = c.get("attempts", 0) or 0

        if cid in seen_ids:
            fatals.append(f"{cid}: duplicate ID")
        seen_ids.add(cid)

        if status not in STATUS_ENUM:
            fatals.append(f'{cid}: status "{status}" khong hop le '
                          f"(phai la mot trong {sorted(STATUS_ENUM)})")

        for a in assertions:
            res = a.get("result")
            if res not in (None, *ASSERTION_RESULT_ENUM):
                fatals.append(f'{cid}: assertions[].result "{res}" sai enum')

        if status in ("passed", "fixed"):
            if any(a.get("result") == "fail" for a in assertions):
                fatals.append(f"{cid}: status={status} nhung co assertion "
                              "result=fail (partial pass bi giau)")
            if status == "passed" and root_cause.get("category") == "app-bug":
                fatals.append(f"{cid}: status=passed nhung root_cause la "
                              "app-bug (bug duoi case xanh)")

        if fix.get("applied") and verify.get("status") != "passed":
            fatals.append(f"{cid}: fix.applied=true nhung verify.status "
                          f'!= "passed" (fix chua duoc chung minh)')

        if status == "fixed" and not fix:
            fatals.append(f"{cid}: status=fixed nhung khong co fix record")

        if status == "failed" and not root_cause.get("category") \
                and not c.get("needs_human"):
            fatals.append(f"{cid}: status=failed nhung khong co root_cause "
                          "VA khong co needs_human")

        if fix.get("applied") and fix.get("proposed"):
            fatals.append(f"{cid}: fix.applied va fix.proposed cung true "
                          "(phai loai tru nhau)")

        fix_level = fix.get("level")
        if fix.get("applied") and fix_level in FIX_LEVEL_ORDER:
            if FIX_LEVEL_ORDER[fix_level] > run_fix_level:
                fatals.append(f"{cid}: fix APPLIED o level {fix_level} vuot "
                              f"run.fix_level={run.get('fix_level')}")

        rc_cat = root_cause.get("category")
        if rc_cat and rc_cat not in ROOT_CAUSE_ENUM:
            fatals.append(f'{cid}: root_cause.category "{rc_cat}" sai enum')
        risk = fix.get("risk")
        if risk and risk not in FIX_RISK_ENUM:
            fatals.append(f'{cid}: fix.risk "{risk}" sai enum')

        # warnings
        if status == "flaky" and not root_cause.get("summary"):
            warnings.append(f"{cid}: flaky nhung khong ghi suspected cause")
        if status not in ("passed",) and status != "skipped" and not assertions:
            warnings.append(f"{cid}: status={status} nhung khong co assertions")
        if status == "blocked" and not c.get("blocked_by"):
            warnings.append(f"{cid}: blocked nhung khong co blocked_by")
        if status == "failed" and not any(a.get("result") == "fail" for a in assertions):
            warnings.append(f"{cid}: failed nhung khong clause nao ghi fail")
        if status == "passed" and fix.get("proposed"):
            warnings.append(f"{cid}: passed nhung co fix.proposed (dang ngo)")
        if attempts and attempts > 3:
            warnings.append(f"{cid}: attempts={attempts} > 3 "
                            "(dang dem sai hoac vuot gioi han cho phep)")
        duration = c.get("duration_ms")
        if isinstance(duration, (int, float)) and 0 < duration < 20:
            warnings.append(f"{cid}: duration_ms={duration} qua nho "
                            "(co the dang ghi bang giay thay vi ms)")

    return fatals, warnings


def render_html(data, template_path):
    if template_path and os.path.exists(template_path):
        with open(template_path, "r", encoding="utf-8") as f:
            template = f.read()
    else:
        skill_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        default_path = os.path.join(skill_dir, "assets", "report-template.html")
        with open(default_path, "r", encoding="utf-8") as f:
            template = f.read()
    payload = json.dumps(data, ensure_ascii=False)
    payload = payload.replace("</script", "<\\/script")  # tranh gay the <script>
    return template.replace("__RESULTS_JSON__", payload)


def summarize(data, warnings):
    cases = data["cases"]
    total = len(cases)
    counts = {}
    for c in cases:
        counts[c.get("status")] = counts.get(c.get("status"), 0) + 1
    passed = counts.get("passed", 0) + counts.get("fixed", 0) + counts.get("flaky", 0)
    pass_rate = (passed / total * 100) if total else 0.0

    app_bugs = [c for c in cases
                if (c.get("root_cause") or {}).get("category") == "app-bug"]
    pending_l3 = [c for c in cases if (c.get("fix") or {}).get("proposed")]
    flaky = [c for c in cases if c.get("status") == "flaky"]

    lines = []
    lines.append(f"Ket qua chay: {total} case — {pass_rate:.0f}% pass "
                 f"({passed}/{total})")
    for status in ("passed", "fixed", "flaky", "failed", "blocked", "skipped"):
        if counts.get(status):
            lines.append(f"  {status}: {counts[status]}")
    if app_bugs:
        lines.append(f"\nBug that su (can nguoi xem): {len(app_bugs)}")
        for c in app_bugs:
            lines.append(f"  - {c.get('id')}: {c.get('title', '')}")
    if pending_l3:
        lines.append(f"\nCho duyet fix (L3 / source code): {len(pending_l3)}")
        for c in pending_l3:
            lines.append(f"  - {c.get('id')}: {c.get('title', '')}")
    if flaky:
        lines.append(f"\nFlaky (can theo doi): {len(flaky)}")
        for c in flaky:
            lines.append(f"  - {c.get('id')}: {c.get('title', '')}")
    if warnings:
        lines.append(f"\nCanh bao ({len(warnings)}):")
        for w in warnings:
            lines.append(f"  - {w}")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(
        description="Validate results.json va sinh report.html + tom tat.")
    ap.add_argument("input", nargs="?", help="File results.json")
    ap.add_argument("-o", "--output", help="File report.html output")
    ap.add_argument("--template", help="Duong dan report-template.html "
                     "tuy chinh (mac dinh: assets/report-template.html)")
    ap.add_argument("--validate", action="store_true",
                     help="Chi validate, khong sinh report.")
    ap.add_argument("--summary", action="store_true",
                     help="In tom tat tieng Viet sau khi sinh report.")
    ap.add_argument("--summary-only", action="store_true",
                     help="Validate + in tom tat, khong ghi file HTML.")
    ap.add_argument("--print-schema", action="store_true",
                     help="In contract cua results.json roi thoat.")
    args = ap.parse_args()

    if args.print_schema:
        print(SCHEMA_DOC)
        return

    if not args.input:
        ap.error("thieu input results.json (hoac dung --print-schema)")

    data = load(args.input)
    fatals, warnings = validate(data)
    if fatals:
        fatal(fatals)

    if args.validate:
        print("OK — results.json hop le.")
        if warnings:
            print(f"({len(warnings)} canh bao, xem --summary de biet chi tiet)")
        return

    if not args.summary_only:
        html = render_html(data, args.template)
        out_path = args.output or "report.html"
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(html)
        print(f"Da sinh report: {out_path}")

    if args.summary or args.summary_only:
        print()
        print(summarize(data, warnings))


if __name__ == "__main__":
    main()
