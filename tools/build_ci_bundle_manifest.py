#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = "ci_evidence_bundle_v1"
RELEASE_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917"
REQUIRED_FILES = [
    "static-check.txt",
    "static-check-ci.txt",
    "ci-job-metadata.json",
    "ci-evidence.json",
    "ci-evidence-validation.txt",
    "ci-evidence-manifest.txt",
    "ci-attestation-verify.txt",
]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_digest(value: dict) -> str:
    basis = copy.deepcopy(value)
    basis.pop("bundle_digest", None)
    return hashlib.sha256(json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def resolve(value: str) -> Path:
    p = Path(value)
    return p if p.is_absolute() else ROOT / p


def main() -> int:
    ap = argparse.ArgumentParser(description="Build GPT_EA CI evidence bundle manifest")
    ap.add_argument("--artifact-name", required=True)
    ap.add_argument("--output", default="ci-bundle-manifest.json")
    ap.add_argument("--base-dir", default=".")
    args = ap.parse_args()

    base = resolve(args.base_dir)
    evidence_path = base / "ci-evidence.json"
    metadata_path = base / "ci-job-metadata.json"
    attest_path = base / "ci-attestation-verify.txt"
    errors: list[str] = []
    for name in REQUIRED_FILES:
        if not (base / name).exists():
            errors.append(f"missing required bundle file: {name}")
    if errors:
        print("CI BUNDLE MANIFEST: FAILED")
        for e in errors:
            print("ERROR:", e)
        return 1

    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"CI BUNDLE MANIFEST: FAILED\nERROR: invalid evidence/metadata JSON: {exc}")
        return 1

    attest_text = attest_path.read_text(encoding="utf-8", errors="replace")
    attestation_verified = "CI ATTESTATION VERIFY: PASS" in attest_text
    if not attestation_verified:
        print("CI BUNDLE MANIFEST: FAILED\nERROR: ci-attestation-verify.txt does not contain CI ATTESTATION VERIFY: PASS")
        return 1

    identity_pairs = [
        ("run_id", evidence.get("run_id"), metadata.get("run_id")),
        ("run_attempt", evidence.get("run_attempt"), metadata.get("run_attempt")),
        ("job_id", evidence.get("job_id"), metadata.get("job_id")),
        ("runner_id", evidence.get("runner_id"), metadata.get("runner_id")),
        ("steps_executed", evidence.get("steps_executed"), metadata.get("steps_executed")),
        ("head_sha", evidence.get("head_sha"), metadata.get("head_sha")),
    ]
    mismatches = [name for name, a, b in identity_pairs if str(a) != str(b)]
    if mismatches:
        print("CI BUNDLE MANIFEST: FAILED")
        for name in mismatches:
            print(f"ERROR: ci-evidence and job metadata disagree on {name}")
        return 1

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "release_validation_id": RELEASE_ID,
        "candidate_sha": str(evidence.get("head_sha", "")),
        "artifact_name": args.artifact_name,
        "run_id": int(evidence.get("run_id", 0) or 0),
        "run_attempt": int(evidence.get("run_attempt", 0) or 0),
        "job_id": int(evidence.get("job_id", 0) or 0),
        "runner_id": int(evidence.get("runner_id", 0) or 0),
        "steps_executed": int(evidence.get("steps_executed", 0) or 0),
        "attestation_verified": True,
        "files": {name: sha256_file(base / name) for name in REQUIRED_FILES},
        "bundle_digest": "",
    }
    manifest["bundle_digest"] = canonical_digest(manifest)

    out = resolve(args.output)
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("CI BUNDLE MANIFEST: PASS")
    print(f"BUNDLE_DIGEST={manifest['bundle_digest']}")
    print(f"MANIFEST_FILE_SHA256={sha256_file(out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
