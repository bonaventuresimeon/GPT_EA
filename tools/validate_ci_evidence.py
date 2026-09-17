#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = "github_actions_static_evidence_v1"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_digest(value: dict[str, Any]) -> str:
    basis = copy.deepcopy(value)
    basis.pop("evidence_digest", None)
    payload = json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def git(*args: str) -> str | None:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return None


def source_manifest_digest() -> str | None:
    listing = git("ls-files")
    if listing is None:
        return None
    rows: list[str] = []
    for rel in listing.splitlines():
        p = ROOT / rel
        if p.is_file():
            rows.append(f"{sha256_file(p)}  {rel}")
    return hashlib.sha256(("\n".join(rows) + "\n").encode("utf-8")).hexdigest()


def validate_ci_value(
    data: dict[str, Any],
    expected_sha: str = "",
    static_check: Path | None = None,
    ci_log: Path | None = None,
    check_current_manifest: bool = False,
) -> tuple[list[str], str]:
    errors: list[str] = []
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if data.get("repository") != "bonaventuresimeon/GPT_EA":
        errors.append("repository must be bonaventuresimeon/GPT_EA")
    if not str(data.get("workflow", "")).strip():
        errors.append("workflow is required")
    if not str(data.get("job", "")).strip():
        errors.append("job is required")
    if int(data.get("run_id", 0) or 0) <= 0:
        errors.append("run_id must be > 0")
    if int(data.get("run_attempt", 0) or 0) <= 0:
        errors.append("run_attempt must be > 0")
    head = str(data.get("head_sha", ""))
    tree = str(data.get("tree_sha", ""))
    if not HEX40.fullmatch(head):
        errors.append("head_sha must be a 40-character Git SHA")
    if not HEX40.fullmatch(tree):
        errors.append("tree_sha must be a 40-character Git tree SHA")
    if expected_sha and head.lower() != expected_sha.lower():
        errors.append(f"head_sha {head} does not match expected {expected_sha}")
    if not str(data.get("runner_name", "")).strip():
        errors.append("runner_name is empty; evidence is not from an executed runner")
    if not str(data.get("runner_os", "")).strip():
        errors.append("runner_os is required")
    if data.get("static_outcome") != "success":
        errors.append("static_outcome must be success")
    if data.get("result") != "PASS":
        errors.append("result must be PASS")
    for key in ("static_check_sha256", "ci_log_sha256", "source_manifest_sha256"):
        if not HEX64.fullmatch(str(data.get(key, ""))):
            errors.append(f"{key} must be a SHA-256 digest")

    stored = str(data.get("evidence_digest", ""))
    digest = canonical_digest(data)
    if not HEX64.fullmatch(stored):
        errors.append("evidence_digest must be a SHA-256 digest")
    elif stored.lower() != digest.lower():
        errors.append(f"evidence_digest mismatch: expected {digest}, found {stored}")

    if static_check is not None:
        if not static_check.exists():
            errors.append(f"static check file not found: {static_check}")
        else:
            actual = sha256_file(static_check)
            if actual.lower() != str(data.get("static_check_sha256", "")).lower():
                errors.append("static-check hash mismatch")
            if "RESULT=PASS" not in static_check.read_text(encoding="utf-8", errors="replace"):
                errors.append("static-check.txt does not contain RESULT=PASS")
    if ci_log is not None:
        if not ci_log.exists():
            errors.append(f"CI log file not found: {ci_log}")
        elif sha256_file(ci_log).lower() != str(data.get("ci_log_sha256", "")).lower():
            errors.append("static-check-ci hash mismatch")

    if check_current_manifest:
        manifest = source_manifest_digest()
        if manifest and manifest.lower() != str(data.get("source_manifest_sha256", "")).lower():
            errors.append("source manifest digest does not match current checkout")
        current = git("rev-parse", "HEAD")
        if current and head.lower() != current.lower():
            errors.append(f"CI head {head} does not match current checkout {current}")

    return errors, digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA GitHub Actions static evidence")
    ap.add_argument("evidence", nargs="?", default="ci-evidence.json")
    ap.add_argument("--expected-sha", default="")
    ap.add_argument("--static-check", default="static-check.txt")
    ap.add_argument("--ci-log", default="static-check-ci.txt")
    ap.add_argument("--check-current-manifest", action="store_true")
    args = ap.parse_args()

    p = Path(args.evidence)
    if not p.is_absolute():
        p = ROOT / p
    if not p.exists():
        print(f"CI EVIDENCE VALIDATION: FAILED\nERROR: evidence file not found: {p}")
        return 1
    data = json.loads(p.read_text(encoding="utf-8"))
    static_path = Path(args.static_check)
    if not static_path.is_absolute():
        static_path = ROOT / static_path
    log_path = Path(args.ci_log)
    if not log_path.is_absolute():
        log_path = ROOT / log_path

    errors, digest = validate_ci_value(
        data,
        expected_sha=args.expected_sha,
        static_check=static_path,
        ci_log=log_path,
        check_current_manifest=args.check_current_manifest,
    )
    out = ROOT / "ci-evidence-validation.txt"
    if errors:
        text = "CI EVIDENCE VALIDATION: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nCI_EVIDENCE_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1
    text = f"CI EVIDENCE VALIDATION: PASS\nHEAD_SHA: {data['head_sha']}\nRUN_ID: {data['run_id']}\nCI_EVIDENCE_SHA256: {digest}\n"
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
