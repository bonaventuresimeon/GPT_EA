#!/usr/bin/env python3
"""Run all repository-level GPT_EA release checks without GitHub Actions.

This does not replace MetaEditor compilation, Strategy Tester, broker matrices,
recovery tests, adaptive terminal tests, WebRequest/API transport failure
injection or demo soak. It provides an offline/CI-independent repository static
gate and writes static-check.txt at repository root.
"""
from __future__ import annotations

import hashlib
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "static-check.txt"
CHECKS = [
    ROOT / "tools" / "check_mql_static.py",
    ROOT / "tools" / "check_mql_compile_hygiene.py",
    ROOT / "tools" / "check_release_certification.py",
    ROOT / "tools" / "check_r5_adaptive.py",
    ROOT / "tools" / "check_r6_resilience.py",
    ROOT / "tools" / "check_r6_soak_lifecycle.py",
    ROOT / "tools" / "check_runner_recovery_contract.py",
    ROOT / "tools" / "check_mt5_validation_contract.py",
    ROOT / "tools" / "check_release_readiness_contract.py",
    ROOT / "tools" / "check_release_contract_linkage.py",
    ROOT / "tools" / "check_api_transport_static.py",
    ROOT / "tools" / "check_legal_rollout_static.py",
    ROOT / "tools" / "check_documentation_branding.py",
    ROOT / "tools" / "check_r10_privacy_compile.py",
    ROOT / "tools" / "check_architecture_release_truth.py",
    ROOT / "tools" / "check_release_truth_drift.py",
    ROOT / "tools" / "check_release_hardening.py",
    ROOT / "tools" / "scan_release_secrets.py",
]


def run_check(path: Path) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, str(path)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return proc.returncode, proc.stdout


def main() -> int:
    lines: list[str] = []
    try:
        source_git_sha = subprocess.check_output(
            ["git","rev-parse","HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        source_git_sha = "UNKNOWN"
    main_source = ROOT / "GPT_EA.mq5"
    source_file_sha256 = hashlib.sha256(main_source.read_bytes()).hexdigest() if main_source.exists() else "MISSING"

    lines.append("GPT_EA OFFLINE STATIC RELEASE CHECK")
    lines.append(f"UTC: {datetime.now(timezone.utc).isoformat()}")
    lines.append(f"Python: {sys.version.split()[0]}")
    lines.append(f"SOURCE_GIT_SHA={source_git_sha}")
    lines.append("SOURCE_LAYOUT=MONOLITHIC")
    lines.append(f"SOURCE_FILE=GPT_EA.mq5")
    lines.append(f"SOURCE_FILE_SHA256={source_file_sha256}")
    lines.append("")

    failed = False
    for check in CHECKS:
        lines.append(f"=== {check.name} ===")
        if not check.exists():
            lines.append(f"ERROR: missing checker: {check}")
            lines.append("")
            failed = True
            continue
        code, output = run_check(check)
        lines.append(output.rstrip())
        lines.append(f"EXIT_CODE={code}")
        lines.append("")
        if code != 0:
            failed = True

    lines.append("RESULT=" + ("FAILED" if failed else "PASS"))
    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text, end="")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
