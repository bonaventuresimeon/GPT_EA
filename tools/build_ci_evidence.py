#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = "github_actions_static_evidence_v1"
JOB_METADATA_SCHEMA = "github_actions_job_metadata_v1"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()


def source_manifest_digest() -> str:
    rows: list[str] = []
    for rel in git("ls-files").splitlines():
        p = ROOT / rel
        if p.is_file():
            rows.append(f"{sha256_file(p)}  {rel}")
    return hashlib.sha256(("\n".join(rows) + "\n").encode("utf-8")).hexdigest()


def canonical_digest(value: dict) -> str:
    basis = dict(value)
    basis.pop("evidence_digest", None)
    payload = json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def resolve(value: str) -> Path:
    p = Path(value)
    return p if p.is_absolute() else ROOT / p


def main() -> int:
    ap = argparse.ArgumentParser(description="Build GPT_EA GitHub Actions static evidence")
    ap.add_argument("--static-check", default="static-check.txt")
    ap.add_argument("--ci-log", default="static-check-ci.txt")
    ap.add_argument("--job-metadata", default="ci-job-metadata.json")
    ap.add_argument("--output", default="ci-evidence.json")
    ap.add_argument("--static-outcome", default=os.getenv("STATIC_OUTCOME", "unknown"))
    args = ap.parse_args()

    static_path = resolve(args.static_check)
    ci_log_path = resolve(args.ci_log)
    metadata_path = resolve(args.job_metadata)
    errors: list[str] = []
    if not static_path.exists():
        errors.append(f"missing {args.static_check}")
    if not ci_log_path.exists():
        errors.append(f"missing {args.ci_log}")
    if not metadata_path.exists():
        errors.append(f"missing {args.job_metadata}")

    metadata: dict = {}
    if metadata_path.exists():
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"invalid job metadata JSON: {exc}")
    if metadata and metadata.get("schema_version") != JOB_METADATA_SCHEMA:
        errors.append(f"job metadata schema must be {JOB_METADATA_SCHEMA}")

    static_text = static_path.read_text(encoding="utf-8", errors="replace") if static_path.exists() else ""
    head_sha = os.getenv("GITHUB_SHA", "") or git("rev-parse", "HEAD")
    tree_sha = git("rev-parse", "HEAD^{tree}")

    if metadata:
        if str(metadata.get("head_sha", "")).lower() != head_sha.lower():
            errors.append("completed job metadata head SHA does not match checked-out source")
        if int(metadata.get("runner_id", 0) or 0) <= 0:
            errors.append("completed job metadata has runner_id <= 0")
        if str(metadata.get("conclusion", "")) != "success":
            errors.append("completed static job conclusion is not success")
        if int(metadata.get("steps_executed", 0) or 0) < 7:
            errors.append("completed static job executed fewer than 7 required steps")

    result = (
        "PASS"
        if args.static_outcome == "success"
        and "RESULT=PASS" in static_text
        and not errors
        else "FAIL"
    )

    evidence = {
        "schema_version": SCHEMA_VERSION,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "repository": os.getenv("GITHUB_REPOSITORY", "") or str(metadata.get("repository", "")),
        "workflow": os.getenv("GITHUB_WORKFLOW", ""),
        "job": str(metadata.get("job_name", "")),
        "event": os.getenv("GITHUB_EVENT_NAME", ""),
        "ref": os.getenv("GITHUB_REF", ""),
        "run_id": int(metadata.get("run_id", 0) or 0),
        "run_attempt": int(metadata.get("run_attempt", 0) or 0),
        "run_url": str(metadata.get("run_url", "")),
        "job_id": int(metadata.get("job_id", 0) or 0),
        "job_url": str(metadata.get("job_url", "")),
        "runner_id": int(metadata.get("runner_id", 0) or 0),
        "runner_name": str(metadata.get("runner_name", "")),
        "runner_group_id": int(metadata.get("runner_group_id", 0) or 0),
        "runner_group_name": str(metadata.get("runner_group_name", "")),
        "steps_executed": int(metadata.get("steps_executed", 0) or 0),
        "static_job_conclusion": str(metadata.get("conclusion", "")),
        "head_sha": head_sha,
        "tree_sha": tree_sha,
        "runner_os": os.getenv("RUNNER_OS", ""),
        "runner_arch": os.getenv("RUNNER_ARCH", ""),
        "static_outcome": args.static_outcome,
        "result": result,
        "static_check_sha256": sha256_file(static_path) if static_path.exists() else "",
        "ci_log_sha256": sha256_file(ci_log_path) if ci_log_path.exists() else "",
        "job_metadata_sha256": sha256_file(metadata_path) if metadata_path.exists() else "",
        "source_manifest_sha256": source_manifest_digest(),
        "errors": errors,
        "evidence_digest": "",
    }
    evidence["evidence_digest"] = canonical_digest(evidence)

    out = resolve(args.output)
    out.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(f"CI_EVIDENCE_RESULT={result}")
    print(f"CI_EVIDENCE_SHA256={evidence['evidence_digest']}")
    print(f"CI_EVIDENCE_FILE_SHA256={sha256_file(out)}")
    return 0 if result == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
