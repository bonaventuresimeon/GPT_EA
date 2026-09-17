#!/usr/bin/env python3
"""Run all repository-level GPT_EA release checks without GitHub Actions.

This does not replace MetaEditor compilation, Strategy Tester, broker matrices,
recovery tests, adaptive terminal tests, or demo soak. It provides an offline/CI-
independent equivalent of the repository static gate and writes static-check.txt.
"""
from __future__ import annotations

import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "static-check.txt"
CHECKS = [
    ROOT / "tools" / "check_mql_static.py",
    ROOT / "tools" / "check_release_certification.py",
    ROOT / "tools" / "check_r5_adaptive.py",
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
    lines.append("GPT_EA OFFLINE STATIC RELEASE CHECK")
    lines.append(f"UTC: {datetime.now(timezone.utc).isoformat()}")
    lines.append(f"Python: {sys.version.split()[0]}")
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
