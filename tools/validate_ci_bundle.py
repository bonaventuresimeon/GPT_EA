#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from validate_ci_evidence import validate_ci_value, validate_job_metadata
from release_contract import load_release_contract

ROOT = Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
SCHEMA_VERSION = CONTRACT["ci_bundle_schema"]
RELEASE_ID = CONTRACT["release_validation_id"]
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
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


def canonical_digest(value: dict[str, Any]) -> str:
    basis = copy.deepcopy(value)
    basis.pop("bundle_digest", None)
    return hashlib.sha256(json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def resolve(value: str) -> Path:
    p = Path(value)
    return p if p.is_absolute() else ROOT / p


def validate_bundle(manifest: dict[str, Any], base: Path, expected_sha: str = "") -> tuple[list[str], str]:
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if manifest.get("release_validation_id") != RELEASE_ID:
        errors.append(f"release_validation_id must be {RELEASE_ID}")
    candidate = str(manifest.get("candidate_sha", ""))
    if not HEX40.fullmatch(candidate):
        errors.append("candidate_sha must be 40 hexadecimal characters")
    elif expected_sha and candidate.lower() != expected_sha.lower():
        errors.append("candidate_sha does not match expected release candidate")
    if len(str(manifest.get("artifact_name", "")).strip()) < 8:
        errors.append("artifact_name is required")
    for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed"):
        try:
            value = int(manifest.get(key, 0) or 0)
        except Exception:
            value = 0
        if value <= 0:
            errors.append(f"{key} must be > 0")
    if int(manifest.get("steps_executed", 0) or 0) < 7:
        errors.append("steps_executed must be >= 7")
    if manifest.get("attestation_verified") is not True:
        errors.append("attestation_verified must be true")

    files = manifest.get("files", {})
    if not isinstance(files, dict):
        errors.append("files must be an object")
        files = {}
    for name in REQUIRED_FILES:
        stored = str(files.get(name, ""))
        if not HEX64.fullmatch(stored):
            errors.append(f"files[{name}] must be a SHA-256 digest")
            continue
        path = base / name
        if not path.exists():
            errors.append(f"required bundle file not found: {path}")
            continue
        actual = sha256_file(path)
        if actual.lower() != stored.lower():
            errors.append(f"bundle file hash mismatch: {name}")

    evidence_path = base / "ci-evidence.json"
    metadata_path = base / "ci-job-metadata.json"
    if evidence_path.exists() and metadata_path.exists():
        try:
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            errors.extend(validate_job_metadata(metadata, expected_sha=candidate))
            ci_errors, _ = validate_ci_value(
                evidence,
                expected_sha=candidate,
                static_check=base / "static-check.txt",
                ci_log=base / "static-check-ci.txt",
                job_metadata=metadata_path,
                check_current_manifest=False,
            )
            errors.extend(f"ci-evidence: {e}" for e in ci_errors)
            pairs = (
                ("run_id", "run_id"), ("run_attempt", "run_attempt"),
                ("job_id", "job_id"), ("runner_id", "runner_id"),
                ("steps_executed", "steps_executed"), ("candidate_sha", "head_sha"),
            )
            for mk, ek in pairs:
                if str(manifest.get(mk, "")) != str(evidence.get(ek, "")):
                    errors.append(f"bundle manifest {mk} does not match ci-evidence {ek}")
        except Exception as exc:
            errors.append(f"could not cross-check CI evidence files: {exc}")

    verify_path = base / "ci-attestation-verify.txt"
    if verify_path.exists():
        verify_text = verify_path.read_text(encoding="utf-8", errors="replace")
        if "CI ATTESTATION VERIFY: PASS" not in verify_text:
            errors.append("ci-attestation-verify.txt does not contain a PASS marker")

    stored_digest = str(manifest.get("bundle_digest", ""))
    digest = canonical_digest(manifest)
    if not HEX64.fullmatch(stored_digest):
        errors.append("bundle_digest must be a SHA-256 digest")
    elif stored_digest.lower() != digest.lower():
        errors.append(f"bundle_digest mismatch: expected {digest}, found {stored_digest}")
    return errors, digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA CI evidence bundle")
    ap.add_argument("manifest", nargs="?", default="ci-bundle-manifest.json")
    ap.add_argument("--base-dir", default=".")
    ap.add_argument("--expected-sha", default="")
    args = ap.parse_args()

    manifest_path = resolve(args.manifest)
    base = resolve(args.base_dir)
    if not manifest_path.exists():
        print(f"CI BUNDLE VALIDATION: FAILED\nERROR: manifest not found: {manifest_path}")
        return 1
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    errors, digest = validate_bundle(manifest, base, expected_sha=args.expected_sha)
    out = ROOT / "ci-bundle-validation.txt"
    if errors:
        text = "CI BUNDLE VALIDATION: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nBUNDLE_DIGEST: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1
    text = (
        f"CI BUNDLE VALIDATION: PASS\nCANDIDATE_SHA: {manifest['candidate_sha']}\n"
        f"RUN_ID: {manifest['run_id']}\nJOB_ID: {manifest['job_id']}\nRUNNER_ID: {manifest['runner_id']}\n"
        f"BUNDLE_DIGEST: {digest}\n"
    )
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
