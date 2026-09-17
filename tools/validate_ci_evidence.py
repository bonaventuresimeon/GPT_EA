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
JOB_METADATA_SCHEMA = "github_actions_job_metadata_v1"
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


def validate_job_metadata(meta: dict[str, Any], expected_sha: str = "") -> list[str]:
    errors: list[str] = []
    if meta.get("schema_version") != JOB_METADATA_SCHEMA:
        errors.append(f"job metadata schema_version must be {JOB_METADATA_SCHEMA}")
    if meta.get("repository") != "bonaventuresimeon/GPT_EA":
        errors.append("job metadata repository must be bonaventuresimeon/GPT_EA")
    for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed"):
        try:
            value = int(meta.get(key, 0) or 0)
        except Exception:
            value = 0
        if value <= 0:
            errors.append(f"job metadata {key} must be > 0")
    if int(meta.get("steps_executed", 0) or 0) < 7:
        errors.append("job metadata steps_executed must be >= 7")
    if meta.get("job_name") != "static-release-gate":
        errors.append("job metadata must describe static-release-gate")
    if meta.get("status") != "completed":
        errors.append("job metadata status must be completed")
    if meta.get("conclusion") != "success":
        errors.append("job metadata conclusion must be success")
    if not str(meta.get("runner_name", "")).strip():
        errors.append("job metadata runner_name is empty")
    head = str(meta.get("head_sha", ""))
    if not HEX40.fullmatch(head):
        errors.append("job metadata head_sha must be 40 hexadecimal characters")
    elif expected_sha and head.lower() != expected_sha.lower():
        errors.append("job metadata head_sha does not match expected candidate SHA")
    return errors


def validate_ci_value(
    data: dict[str, Any],
    expected_sha: str = "",
    static_check: Path | None = None,
    ci_log: Path | None = None,
    job_metadata: Path | None = None,
    check_current_manifest: bool = False,
) -> tuple[list[str], str]:
    errors: list[str] = []
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if data.get("repository") != "bonaventuresimeon/GPT_EA":
        errors.append("repository must be bonaventuresimeon/GPT_EA")
    if not str(data.get("workflow", "")).strip():
        errors.append("workflow is required")
    if data.get("job") != "static-release-gate":
        errors.append("job must be static-release-gate")
    for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed"):
        try:
            value = int(data.get(key, 0) or 0)
        except Exception:
            value = 0
        if value <= 0:
            errors.append(f"{key} must be > 0")
    if int(data.get("steps_executed", 0) or 0) < 7:
        errors.append("steps_executed must be >= 7")
    if not str(data.get("run_url", "")).strip() or str(data.get("run_id", "")) not in str(data.get("run_url", "")):
        errors.append("run_url must reference run_id")
    if not str(data.get("job_url", "")).strip() or str(data.get("job_id", "")) not in str(data.get("job_url", "")):
        errors.append("job_url must reference job_id")
    if data.get("static_job_conclusion") != "success":
        errors.append("static_job_conclusion must be success")

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
    if not str(data.get("runner_arch", "")).strip():
        errors.append("runner_arch is required")
    if data.get("static_outcome") != "success":
        errors.append("static_outcome must be success")
    if data.get("result") != "PASS":
        errors.append("result must be PASS")
    for key in ("static_check_sha256", "ci_log_sha256", "job_metadata_sha256", "source_manifest_sha256"):
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

    if job_metadata is not None:
        if not job_metadata.exists():
            errors.append(f"CI job metadata file not found: {job_metadata}")
        else:
            try:
                meta = json.loads(job_metadata.read_text(encoding="utf-8"))
                errors.extend(validate_job_metadata(meta, expected_sha=expected_sha or head))
                if sha256_file(job_metadata).lower() != str(data.get("job_metadata_sha256", "")).lower():
                    errors.append("job metadata hash mismatch")
                pairs = (
                    ("run_id", "run_id"), ("run_attempt", "run_attempt"), ("job_id", "job_id"),
                    ("runner_id", "runner_id"), ("runner_name", "runner_name"),
                    ("runner_group_id", "runner_group_id"), ("steps_executed", "steps_executed"),
                    ("head_sha", "head_sha"), ("conclusion", "static_job_conclusion"),
                )
                for mk, ek in pairs:
                    if str(meta.get(mk, "")) != str(data.get(ek, "")):
                        errors.append(f"ci-evidence {ek} does not match job metadata {mk}")
            except Exception as exc:
                errors.append(f"could not validate job metadata: {exc}")

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
    ap.add_argument("--job-metadata", default="ci-job-metadata.json")
    ap.add_argument("--check-current-manifest", action="store_true")
    args = ap.parse_args()

    p = Path(args.evidence)
    if not p.is_absolute():
        p = ROOT / p
    if not p.exists():
        print(f"CI EVIDENCE VALIDATION: FAILED\nERROR: evidence file not found: {p}")
        return 1
    data = json.loads(p.read_text(encoding="utf-8"))

    def resolve(value: str) -> Path:
        q = Path(value)
        return q if q.is_absolute() else ROOT / q

    errors, digest = validate_ci_value(
        data,
        expected_sha=args.expected_sha,
        static_check=resolve(args.static_check),
        ci_log=resolve(args.ci_log),
        job_metadata=resolve(args.job_metadata),
        check_current_manifest=args.check_current_manifest,
    )
    out = ROOT / "ci-evidence-validation.txt"
    if errors:
        text = "CI EVIDENCE VALIDATION: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nCI_EVIDENCE_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1
    text = (
        f"CI EVIDENCE VALIDATION: PASS\nHEAD_SHA: {data['head_sha']}\nRUN_ID: {data['run_id']}\n"
        f"JOB_ID: {data['job_id']}\nRUNNER_ID: {data['runner_id']}\nSTEPS_EXECUTED: {data['steps_executed']}\n"
        f"CI_EVIDENCE_SHA256: {digest}\n"
    )
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
