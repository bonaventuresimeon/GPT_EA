#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

from validate_soak_evidence import validate_soak

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "SOAK_EVIDENCE_SCHEMA.json"


def canonical_digest(value: dict) -> str:
    basis = copy.deepcopy(value)
    basis.pop("evidence_digest", None)
    payload = json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def resolve(path_text: str) -> Path:
    p = Path(path_text)
    return p if p.is_absolute() else ROOT / p


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Import a completed GPT_EA Part36 demo-soak snapshot into an R6 release-evidence JSON and finalize its digest"
    )
    ap.add_argument("snapshot", help="Part36 GPT_EA_DemoSoakSnapshot.json path")
    ap.add_argument("release_evidence", help="Release-evidence JSON to update")
    ap.add_argument("--output", default="", help="Optional output path; default overwrites release_evidence")
    args = ap.parse_args()

    snapshot_path = resolve(args.snapshot)
    release_path = resolve(args.release_evidence)
    output_path = resolve(args.output) if args.output else release_path

    errors: list[str] = []
    if not snapshot_path.exists():
        errors.append(f"snapshot not found: {snapshot_path}")
    if not release_path.exists():
        errors.append(f"release evidence not found: {release_path}")
    if not SCHEMA_PATH.exists():
        errors.append(f"schema not found: {SCHEMA_PATH}")
    if errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in errors:
            print("ERROR:", err)
        return 1

    try:
        soak = json.loads(snapshot_path.read_text(encoding="utf-8"))
        release = json.loads(release_path.read_text(encoding="utf-8"))
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"SOAK SNAPSHOT IMPORT: FAILED\nERROR: invalid JSON/schema: {exc}")
        return 1

    if not isinstance(soak, dict):
        print("SOAK SNAPSHOT IMPORT: FAILED\nERROR: Part36 snapshot must be a JSON object")
        return 1
    if not isinstance(release, dict):
        print("SOAK SNAPSHOT IMPORT: FAILED\nERROR: release evidence must be a JSON object")
        return 1

    if soak.get("schema_version") != "demo_soak_evidence_v1":
        errors.append("snapshot.schema_version must be demo_soak_evidence_v1")
    if len(str(soak.get("evidence_id", "")).strip()) < 8:
        errors.append("snapshot.evidence_id must contain at least 8 characters")
    report_raw = str(soak.get("report_path", "")).strip()
    if not report_raw:
        errors.append("snapshot.report_path is required")
    else:
        report_path = resolve(report_raw)
        if not report_path.exists():
            errors.append(f"soak report not found: {report_path}")

    if errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in errors:
            print("ERROR:", err)
        print("No release-evidence file was modified.")
        return 1

    soak["evidence_digest"] = canonical_digest(soak)
    validation_errors, digest = validate_soak(soak, schema)
    if validation_errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in validation_errors:
            print("ERROR:", err)
        print("No release-evidence file was modified.")
        return 1

    release["demo_soak"] = soak
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(release, indent=2, sort_keys=False) + "\n", encoding="utf-8")

    print("SOAK SNAPSHOT IMPORT: PASS")
    print(f"SOURCE: {snapshot_path}")
    print(f"OUTPUT: {output_path}")
    print(f"SOAK_EVIDENCE_ID: {soak['evidence_id']}")
    print(f"SOAK_EVIDENCE_SHA256: {digest}")
    print("Next: run tools/validate_soak_evidence.py and tools/validate_release_evidence.py on the updated release evidence.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
