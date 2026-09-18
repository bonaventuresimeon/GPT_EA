#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

PASS = "✅ PASS"
HOLD = "⏸️ HOLD"
NOGO = "⛔ NO-GO"

TRUTH_SCHEMA = "gpt_ea_release_truth_v1"


def nonzero_hex(value: Any, length: int) -> bool:
    s = str(value or "")
    if len(s) != length:
        return False
    try:
        int(s, 16)
    except ValueError:
        return False
    return any(ch != "0" for ch in s.lower())


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def gate_status(data: dict[str, Any], key: str) -> str:
    return PASS if data.get("gates", {}).get(key) is True else HOLD


def assess(data: dict[str, Any]) -> tuple[list[dict[str, str]], str, list[str]]:
    rows: list[dict[str, str]] = []
    blockers: list[str] = []
    gates = data.get("gates", {})
    build = data.get("build", {})
    ci = data.get("ci_static", {})
    api = data.get("api_transport", {})
    soak = data.get("demo_soak", {})
    privacy = data.get("privacy_signoff", {})
    compile_ev = data.get("compile_evidence", {})
    final = data.get("final_review", {})

    def add(name: str, status: str, evidence: str, action: str = "") -> None:
        rows.append({"name": name, "status": status, "evidence": evidence, "action": action})
        if status == NOGO:
            blockers.append(name + ": " + evidence)

    head = git_head()
    git_sha = str(build.get("git_sha", ""))
    if nonzero_hex(git_sha, 40):
        if head and head.lower() != git_sha.lower():
            add("Source identity", NOGO, f"evidence Git SHA {git_sha} differs from repository HEAD {head}", "Rebuild evidence for the exact candidate.")
        else:
            add("Source identity", PASS if gates.get("artifact_identity") is True else HOLD, f"candidate Git SHA {git_sha}", "Archive exact artifact identity." if gates.get("artifact_identity") is not True else "")
    else:
        add("Source identity", HOLD, "candidate Git SHA is missing/placeholder", "Record the exact 40-character candidate SHA.")

    compile_errors = int(build.get("compile_errors", 0) or 0)
    compile_warnings = int(build.get("compile_warnings", 0) or 0)
    if compile_errors > 0 or compile_warnings > 0:
        add("MetaEditor compile", NOGO, f"errors={compile_errors}, warnings={compile_warnings}", "Fix compile errors/warnings and restart the evidence cycle.")
    elif gates.get("metaeditor_compile") is True and gates.get("compile_evidence") is True and compile_ev.get("validated") is True and nonzero_hex(compile_ev.get("evidence_digest"), 64):
        add("MetaEditor compile", PASS, "compile gate + machine-readable compile evidence are validated")
    else:
        add("MetaEditor compile", HOLD, "real compile evidence is not fully validated", "Compile exact candidate in MetaEditor and validate compile-evidence.json.")

    if int(ci.get("runner_id", 0) or 0) == 0:
        add("Executed CI / runner", HOLD, "no allocated runner evidence (runner_id=0 or absent)", "Obtain an actually executed runner/job bundle.")
    elif str(ci.get("conclusion", "")) not in {"", "success"}:
        add("Executed CI / runner", NOGO, f"CI conclusion={ci.get('conclusion')}", "Resolve the executed CI failure.")
    elif gates.get("ci_static") is True and ci.get("bundle_validated") is True and ci.get("attestation_verified") is True:
        add("Executed CI / runner", PASS, f"runner_id={ci.get('runner_id')} bundle validated and attested")
    else:
        add("Executed CI / runner", HOLD, "runner evidence is incomplete or unvalidated", "Complete CI bundle/attestation evidence.")

    for label, key in [
        ("MT5 validation", "mt5_validation"),
        ("Strategy Tester", "strategy_tester"),
        ("Intelligence matrix", "intelligence_matrix"),
        ("Broker/deployment", "broker_matrix"),
        ("Recovery", "recovery"),
        ("Stop management", "stop_matrix"),
        ("Stop observability", "stop_observability"),
    ]:
        add(label, gate_status(data, key), f"gates.{key}={str(gates.get(key, False)).lower()}",
            "Complete and validate required evidence." if gates.get(key) is not True else "")

    secret_leaks = int(api.get("secret_leak_count", 0) or 0)
    if secret_leaks > 0:
        add("API transport", NOGO, f"secret_leak_count={secret_leaks}", "Revoke exposed secrets, remediate, and repeat API evidence.")
    elif gates.get("api_transport") is True and api.get("high_priority_matrix_passed") is True and api.get("webrequest_allow_list_verified") is True:
        add("API transport", PASS, f"mode={api.get('mode','')} endpoint={api.get('endpoint_host','')}")
    else:
        add("API transport", HOLD, "API transport evidence is incomplete", "Complete WebRequest/matrix/failure-recovery evidence.")

    soak_zero = int(soak.get("zero_tolerance_failures", 0) or 0)
    soak_critical = int(soak.get("unresolved_critical_states", 0) or 0)
    soak_secrets = int(soak.get("secrets_exposed", 0) or 0)
    if soak_zero > 0 or soak_critical > 0 or soak_secrets > 0:
        add("Five-day demo soak", NOGO, f"zero_tolerance={soak_zero}, critical={soak_critical}, secrets={soak_secrets}", "Resolve failure and restart/repeat soak as required.")
    elif gates.get("demo_soak") is True and nonzero_hex(soak.get("evidence_digest"), 64):
        add("Five-day demo soak", PASS, f"days={soak.get('trading_days',0)} London={soak.get('london_sessions',0)} NY={soak.get('ny_sessions',0)}")
    else:
        add("Five-day demo soak", HOLD, "soak gate/evidence digest not validated", "Complete exact-candidate five-day soak and schema validation.")

    privacy_critical = int(privacy.get("unresolved_critical_findings", 0) or 0)
    if privacy_critical > 0:
        add("R10 privacy sign-off", NOGO, f"unresolved critical privacy findings={privacy_critical}", "Resolve critical privacy findings before live authorization.")
    elif gates.get("privacy_signoff") is True and privacy.get("validated") is True and nonzero_hex(privacy.get("evidence_digest"), 64) and privacy.get("telemetry_state") in {"DISABLED", "APPROVED"}:
        add("R10 privacy sign-off", PASS, f"jurisdiction={privacy.get('jurisdiction','')} telemetry={privacy.get('telemetry_state','')}")
    else:
        add("R10 privacy sign-off", HOLD, "privacy sign-off is missing/unvalidated", "Complete jurisdiction-matched privacy sign-off.")

    decision = str(final.get("decision", "HOLD")).upper()
    if decision == "NO-GO":
        add("Final GO/NO-GO", NOGO, "final review decision is NO-GO", "Resolve blocking findings and create a new review.")
    elif decision == "GO" and gates.get("operator_review") is True and nonzero_hex(final.get("review_digest"), 64):
        add("Final GO/NO-GO", PASS, f"reviewer={final.get('reviewer','')} decision=GO")
    else:
        add("Final GO/NO-GO", HOLD, f"decision={decision or 'HOLD'}", "Complete final review only after all prerequisite evidence passes.")

    if any(r["status"] == NOGO for r in rows):
        overall = NOGO
    else:
        mandatory_gate_values = [v for k, v in gates.items() if k != "operator_review"]
        if decision == "GO" and gates.get("operator_review") is True and mandatory_gate_values and all(v is True for v in mandatory_gate_values):
            overall = PASS
        else:
            overall = HOLD

    return rows, overall, blockers


def canonical_evidence_sha256(data: dict[str, Any]) -> str:
    raw = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def semantic_truth_state(data: dict[str, Any]) -> dict[str, Any]:
    rows, overall, blockers = assess(data)
    return {
        "schema": TRUTH_SCHEMA,
        "release_validation_id": str(data.get("release_validation_id", "")),
        "candidate_git_sha": str(data.get("build", {}).get("git_sha", "")),
        "overall": overall,
        "rows": rows,
        "blockers": blockers,
    }


def semantic_truth_fingerprint(data: dict[str, Any]) -> str:
    state = semantic_truth_state(data)
    raw = json.dumps(state, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def render(data: dict[str, Any], source: Path) -> str:
    rows, overall, blockers = assess(data)
    generated = datetime.now(timezone.utc).isoformat()
    release_id = str(data.get("release_validation_id", ""))
    git_sha = str(data.get("build", {}).get("git_sha", ""))
    head = git_head()
    evidence_sha = canonical_evidence_sha256(data)
    truth_fingerprint = semantic_truth_fingerprint(data)

    table = ["| Release truth | Status | Evidence | Next action |", "|---|---|---|---|"]
    for r in rows:
        def esc(s: str) -> str:
            return str(s).replace("|", "\\|").replace("\n", " ")
        table.append(f"| **{esc(r['name'])}** | {esc(r['status'])} | {esc(r['evidence'])} | {esc(r['action'])} |")

    blocker_text = "\n".join(f"- {b}" for b in blockers) if blockers else "- No explicit NO-GO blocker is recorded; HOLD items may still prevent release."

    return f"""<!-- RELEASE_TRUTH_SCHEMA: {TRUTH_SCHEMA} -->\n<!-- RELEASE_TRUTH_EVIDENCE_SHA256: {evidence_sha} -->\n<!-- RELEASE_TRUTH_FINGERPRINT: {truth_fingerprint} -->\n<!-- RELEASE_TRUTH_OVERALL: {overall} -->\n<!-- GPT_EA_DOC_HEADER -->\n<div align="center">

# 🧠⚡ GPT_EA
### 🚦 Release-Truth Dashboard

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚦 **Document:** `RELEASE_TRUTH_DASHBOARD.md`

---

# 🚦 Release-Truth Dashboard

> **Overall candidate state: {overall}**

This dashboard reports evidence state; it does **not** estimate profitability or infer release readiness from source-code presence.

## 🧬 Candidate

- **Release validation ID:** `{release_id or 'UNSET'}`
- **Evidence Git SHA:** `{git_sha or 'UNSET'}`
- **Repository HEAD at generation:** `{head or 'UNAVAILABLE'}`
- **Evidence source:** `{source.as_posix()}`
- **Generated UTC:** `{generated}`

## 📊 Truth table

{chr(10).join(table)}

## ⛔ Explicit blockers

{blocker_text}

## 🎛️ Status semantics

- **✅ PASS** — explicit required evidence says PASS and the relevant validation/identity fields are present.
- **⏸️ HOLD** — evidence is missing, placeholder, incomplete, unvalidated or not yet authorized. HOLD never arms live trading.
- **⛔ NO-GO** — explicit failure, critical finding, identity mismatch, secret exposure or failed final decision.
- Source/docs/code presence alone never produces PASS.

## 🔄 Refresh

Generate from the exact candidate evidence file:

```text
python tools/generate_release_truth_dashboard.py release_evidence.json --output RELEASE_TRUTH_DASHBOARD.md
```

For a repository baseline using the intentionally unapproved template:

```text
python tools/generate_release_truth_dashboard.py RELEASE_EVIDENCE_TEMPLATE.json --output RELEASE_TRUTH_DASHBOARD.md
```

## 🔐 Release rule

A green dashboard is not sufficient by itself. The canonical release validators, final review, exact artifact hashes and archived release-evidence pack remain authoritative.

---

> 🚦 **Truth principle:** missing evidence is HOLD, explicit critical failure is NO-GO, and only validated evidence can become PASS.
"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate the GPT_EA release-truth dashboard from machine-readable release evidence.")
    ap.add_argument("evidence", nargs="?", default="release_evidence.json")
    ap.add_argument("--output", default="RELEASE_TRUTH_DASHBOARD.md")
    ap.add_argument("--require-pass", action="store_true", help="return nonzero unless the evaluated dashboard state is PASS")
    args = ap.parse_args()

    source = Path(args.evidence)
    if not source.is_absolute():
        source = ROOT / source
    if not source.exists():
        print(f"ERROR: evidence file not found: {source}")
        return 2

    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ERROR: invalid evidence JSON: {exc}")
        return 2

    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    output.write_text(render(data, source.relative_to(ROOT) if source.is_relative_to(ROOT) else source), encoding="utf-8")

    _, overall, _ = assess(data)
    print("RELEASE TRUTH DASHBOARD: " + overall.replace("✅ ", "").replace("⏸️ ", "").replace("⛔ ", ""))
    print("OUTPUT=" + str(output))
    if args.require_pass and overall != PASS:
        print("ERROR: --require-pass requested but dashboard state is not PASS")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
