#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

from validate_five_day_soak_record import validate_record
from validate_soak_evidence import validate_soak
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

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
        description="Import a completed GPT_EA Part36 snapshot plus five-day acceptance record into R6 release evidence"
    )
    ap.add_argument("snapshot", help="Part36 GPT_EA_DemoSoakSnapshot.json path")
    ap.add_argument("acceptance_record", help="Finalized five-day soak acceptance JSON")
    ap.add_argument("release_evidence", help="Release-evidence JSON to update")
    ap.add_argument("--output", default="", help="Optional output path; default overwrites release_evidence")
    args = ap.parse_args()

    snapshot_path = resolve(args.snapshot)
    record_path = resolve(args.acceptance_record)
    release_path = resolve(args.release_evidence)
    output_path = resolve(args.output) if args.output else release_path

    errors: list[str] = []
    for label, path in (("snapshot", snapshot_path), ("acceptance record", record_path), ("release evidence", release_path), ("schema", SCHEMA_PATH)):
        if not path.exists():
            errors.append(f"{label} not found: {path}")
    if errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in errors:
            print("ERROR:", err)
        return 1

    try:
        soak = json.loads(snapshot_path.read_text(encoding="utf-8"))
        record = json.loads(record_path.read_text(encoding="utf-8"))
        release = json.loads(release_path.read_text(encoding="utf-8"))
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"SOAK SNAPSHOT IMPORT: FAILED\nERROR: invalid JSON/schema: {exc}")
        return 1

    if not isinstance(soak, dict):
        errors.append("Part36 snapshot must be a JSON object")
    if not isinstance(record, dict):
        errors.append("five-day acceptance record must be a JSON object")
    if not isinstance(release, dict):
        errors.append("release evidence must be a JSON object")
    if errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in errors:
            print("ERROR:", err)
        print("No release-evidence file was modified.")
        return 1

    if soak.get("schema_version") != "demo_soak_evidence_v1":
        errors.append("snapshot.schema_version must be demo_soak_evidence_v1")
    if len(str(soak.get("evidence_id", "")).strip()) < 8:
        errors.append("snapshot.evidence_id must contain at least 8 characters")
    report_raw = str(soak.get("report_path", "")).strip()
    if not report_raw:
        errors.append("snapshot.report_path is required")
    elif not resolve(report_raw).exists():
        errors.append(f"soak report not found: {resolve(report_raw)}")

    record_errors, record_digest = validate_record(record, require_digest=True)
    errors.extend(f"five-day record: {e}" for e in record_errors)
    if str(record.get("evidence_id", "")) != str(soak.get("evidence_id", "")):
        errors.append("five-day record evidence_id does not match Part36 snapshot evidence_id")

    release_build = release.get("build", {}) if isinstance(release, dict) else {}
    candidate = record.get("candidate", {}) if isinstance(record, dict) else {}
    for record_key, build_key in (("git_sha", "git_sha"), ("ex5_sha256", "ex5_sha256"), ("set_sha256", "set_sha256")):
        if str(candidate.get(record_key, "")).lower() != str(release_build.get(build_key, "")).lower():
            errors.append(f"five-day record candidate.{record_key} does not match release build.{build_key}")

    if errors:
        print("SOAK SNAPSHOT IMPORT: FAILED")
        for err in errors:
            print("ERROR:", err)
        print("No release-evidence file was modified.")
        return 1

    soak["acceptance_record_schema_version"] = str(record.get("schema_version", ""))
    soak["acceptance_record_id"] = str(record.get("record_id", ""))
    soak["acceptance_record_digest"] = record_digest
    try:
        soak["acceptance_record_path"] = str(record_path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        soak["acceptance_record_path"] = str(record_path)
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
    print(f"ACCEPTANCE_RECORD: {record_path}")
    print(f"OUTPUT: {output_path}")
    print(f"SOAK_EVIDENCE_ID: {soak['evidence_id']}")
    print(f"ACCEPTANCE_RECORD_SHA256: {record_digest}")
    print(f"SOAK_EVIDENCE_SHA256: {digest}")
    print("Next: run tools/validate_soak_evidence.py and tools/validate_release_evidence.py on the updated release evidence.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
