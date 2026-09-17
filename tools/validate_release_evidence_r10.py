#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "release-evidence-validation-r10.txt"
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def resolve(path_text: str) -> Path:
    p = Path(path_text)
    return p if p.is_absolute() else ROOT / p


def fail(errors: list[str], base_output: str = "") -> int:
    text = "R10 RELEASE EVIDENCE: FAILED\n"
    if errors:
        text += "\n".join("ERROR: " + e for e in errors) + "\n"
    if base_output:
        text += "\nBASE_VALIDATOR_OUTPUT\n" + base_output
    OUT.write_text(text, encoding="utf-8")
    print(text, end="")
    return 1


def main() -> int:
    evidence = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "release_evidence.json"
    if not evidence.is_absolute():
        evidence = ROOT / evidence
    if not evidence.exists():
        return fail([f"evidence file not found: {evidence}"])

    try:
        data = json.loads(evidence.read_text(encoding="utf-8"))
    except Exception as exc:
        return fail([f"invalid JSON: {exc}"])

    errors: list[str] = []
    build_sha = str(data.get("build", {}).get("git_sha", ""))

    compile_section = data.get("compile_evidence", {})
    if compile_section.get("schema_version") != "gpt_ea_compile_evidence_v1":
        errors.append("compile_evidence.schema_version must be gpt_ea_compile_evidence_v1")
    if compile_section.get("validated") is not True:
        errors.append("compile_evidence.validated must be true")
    compile_digest = str(compile_section.get("evidence_digest", ""))
    if not HEX64.fullmatch(compile_digest) or set(compile_digest) == {"0"}:
        errors.append("compile_evidence.evidence_digest must be a non-zero SHA-256")
    compile_path_text = str(compile_section.get("evidence_path", "")).strip()
    if not compile_path_text:
        errors.append("compile_evidence.evidence_path is required")
    else:
        compile_path = resolve(compile_path_text)
        if not compile_path.exists():
            errors.append(f"compile evidence file not found: {compile_path}")
        else:
            try:
                compile_record = json.loads(compile_path.read_text(encoding="utf-8"))
                if str(compile_record.get("git_sha", "")).lower() != build_sha.lower():
                    errors.append("compile evidence git_sha must match build.git_sha")
                if str(compile_record.get("evidence_id", "")) != str(compile_section.get("evidence_id", "")):
                    errors.append("compile evidence_id mismatch")
                if str(compile_record.get("evidence_digest", "")).lower() != compile_digest.lower():
                    errors.append("compile evidence digest mismatch")
                proc = subprocess.run(
                    [sys.executable, str(ROOT / "tools" / "validate_compile_evidence.py"), str(compile_path)],
                    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
                )
                if proc.returncode != 0:
                    errors.append("compile evidence validator failed: " + proc.stdout.replace("\n", " | ").strip())
            except Exception as exc:
                errors.append(f"could not validate compile evidence: {exc}")

    privacy = data.get("privacy_signoff", {})
    if privacy.get("schema_version") != "gpt_ea_privacy_signoff_v1":
        errors.append("privacy_signoff.schema_version must be gpt_ea_privacy_signoff_v1")
    if privacy.get("validated") is not True:
        errors.append("privacy_signoff.validated must be true")
    privacy_digest = str(privacy.get("evidence_digest", ""))
    if not HEX64.fullmatch(privacy_digest) or set(privacy_digest) == {"0"}:
        errors.append("privacy_signoff.evidence_digest must be a non-zero SHA-256")
    if int(privacy.get("unresolved_critical_findings", -1)) != 0:
        errors.append("privacy_signoff.unresolved_critical_findings must be 0")
    if privacy.get("telemetry_state") not in {"DISABLED", "APPROVED"}:
        errors.append("privacy_signoff.telemetry_state must be DISABLED or APPROVED")
    if len(str(privacy.get("jurisdiction", "")).strip()) < 2:
        errors.append("privacy_signoff.jurisdiction is required")

    privacy_path_text = str(privacy.get("evidence_path", "")).strip()
    if not privacy_path_text:
        errors.append("privacy_signoff.evidence_path is required")
    else:
        privacy_path = resolve(privacy_path_text)
        if not privacy_path.exists():
            errors.append(f"privacy sign-off file not found: {privacy_path}")
        else:
            try:
                privacy_record = json.loads(privacy_path.read_text(encoding="utf-8"))
                if str(privacy_record.get("git_sha", "")).lower() != build_sha.lower():
                    errors.append("privacy sign-off git_sha must match build.git_sha")
                if str(privacy_record.get("signoff_id", "")) != str(privacy.get("signoff_id", "")):
                    errors.append("privacy signoff_id mismatch")
                if str(privacy_record.get("evidence_digest", "")).lower() != privacy_digest.lower():
                    errors.append("privacy sign-off digest mismatch")
                if str(privacy_record.get("jurisdiction", "")) != str(privacy.get("jurisdiction", "")):
                    errors.append("privacy sign-off jurisdiction mismatch")
                if str(privacy_record.get("controls", {}).get("telemetry_state", "")) != str(privacy.get("telemetry_state", "")):
                    errors.append("privacy sign-off telemetry state mismatch")
                proc = subprocess.run(
                    [sys.executable, str(ROOT / "tools" / "validate_privacy_signoff.py"), str(privacy_path)],
                    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
                )
                if proc.returncode != 0:
                    errors.append("privacy sign-off validator failed: " + proc.stdout.replace("\n", " | ").strip())
            except Exception as exc:
                errors.append(f"could not validate privacy sign-off: {exc}")

    gates = data.get("gates", {})
    if gates.get("compile_evidence") is not True:
        errors.append("gates.compile_evidence must be true")
    if gates.get("privacy_signoff") is not True:
        errors.append("gates.privacy_signoff must be true")

    if errors:
        return fail(errors)

    base = ROOT / "tools" / "validate_release_evidence_r7.py"
    proc = subprocess.run(
        [sys.executable, str(base), str(evidence)],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )
    if proc.returncode != 0:
        return fail(["base R7/R6 release evidence validator failed"], proc.stdout)

    text = "R10 RELEASE EVIDENCE: PASS\n" + proc.stdout
    text += "COMPILE_EVIDENCE_SHA256: " + compile_digest + "\n"
    text += "PRIVACY_SIGNOFF_SHA256: " + privacy_digest + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
