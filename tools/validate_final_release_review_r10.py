#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "final-release-review-validation-r10.txt"


def main() -> int:
    evidence = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "release_evidence.json"
    review = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "final_release_review.json"
    if not evidence.is_absolute():
        evidence = ROOT / evidence
    if not review.is_absolute():
        review = ROOT / review

    errors: list[str] = []
    for p in (evidence, review):
        if not p.exists():
            errors.append(f"file not found: {p}")
    if errors:
        text = "R10 FINAL RELEASE REVIEW: FAILED\n" + "\n".join("ERROR: " + e for e in errors) + "\n"
        OUT.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    try:
        ev = json.loads(evidence.read_text(encoding="utf-8"))
        rv = json.loads(review.read_text(encoding="utf-8"))
    except Exception as exc:
        text = f"R10 FINAL RELEASE REVIEW: FAILED\nERROR: invalid JSON: {exc}\n"
        OUT.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    checks = rv.get("review", {})
    if checks.get("compile_evidence_pass") is not True:
        errors.append("review.compile_evidence_pass must be true")
    if checks.get("privacy_signoff_pass") is not True:
        errors.append("review.privacy_signoff_pass must be true")

    candidate = rv.get("candidate", {})
    compile_digest = str(ev.get("compile_evidence", {}).get("evidence_digest", ""))
    privacy_digest = str(ev.get("privacy_signoff", {}).get("evidence_digest", ""))
    if str(candidate.get("compile_evidence_digest", "")) != compile_digest:
        errors.append("candidate.compile_evidence_digest must match release evidence")
    if str(candidate.get("privacy_signoff_digest", "")) != privacy_digest:
        errors.append("candidate.privacy_signoff_digest must match release evidence")

    if ev.get("compile_evidence", {}).get("validated") is not True:
        errors.append("compile evidence must be validated before final review")
    if ev.get("privacy_signoff", {}).get("validated") is not True:
        errors.append("privacy sign-off must be validated before final review")
    if int(ev.get("privacy_signoff", {}).get("unresolved_critical_findings", -1)) != 0:
        errors.append("privacy sign-off must have zero unresolved critical findings")

    if errors:
        text = "R10 FINAL RELEASE REVIEW: FAILED\n" + "\n".join("ERROR: " + e for e in errors) + "\n"
        OUT.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    base = ROOT / "tools" / "validate_final_release_review.py"
    proc = subprocess.run(
        [sys.executable, str(base), str(evidence), str(review)],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )
    if proc.returncode != 0:
        text = "R10 FINAL RELEASE REVIEW: FAILED\nBASE_REVIEW_VALIDATOR_FAILED\n" + proc.stdout
        OUT.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = "R10 FINAL RELEASE REVIEW: PASS\n" + proc.stdout
    text += "COMPILE_EVIDENCE_SHA256: " + compile_digest + "\n"
    text += "PRIVACY_SIGNOFF_SHA256: " + privacy_digest + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
