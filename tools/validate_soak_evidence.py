#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "SOAK_EVIDENCE_SCHEMA.json"


def canonical_digest(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def parse_time(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def validate_subset_schema(value: dict[str, Any], schema: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    required = schema.get("required", [])
    props = schema.get("properties", {})
    for key in required:
        if key not in value:
            errors.append(f"demo_soak missing required field: {key}")

    if schema.get("additionalProperties") is False:
        unknown = sorted(set(value) - set(props) - {"evidence_digest"})
        if unknown:
            errors.append("demo_soak contains unknown field(s): " + ", ".join(unknown))

    for key, rules in props.items():
        if key not in value:
            continue
        item = value[key]
        if "const" in rules and item != rules["const"]:
            errors.append(f"demo_soak.{key} must equal {rules['const']!r}")
        typ = rules.get("type")
        if typ == "string" and not isinstance(item, str):
            errors.append(f"demo_soak.{key} must be a string")
        elif typ == "integer" and (not isinstance(item, int) or isinstance(item, bool)):
            errors.append(f"demo_soak.{key} must be an integer")
        if isinstance(item, str) and "minLength" in rules and len(item) < int(rules["minLength"]):
            errors.append(f"demo_soak.{key} must contain at least {rules['minLength']} characters")
        if isinstance(item, int) and not isinstance(item, bool) and "minimum" in rules and item < int(rules["minimum"]):
            errors.append(f"demo_soak.{key} must be >= {rules['minimum']}")
    return errors


def validate_soak(soak: dict[str, Any], schema: dict[str, Any]) -> tuple[list[str], str]:
    errors = validate_subset_schema(soak, schema)

    start = parse_time(str(soak.get("start", "")))
    end = parse_time(str(soak.get("end", "")))
    if start is None:
        errors.append("demo_soak.start must be an ISO-8601 timestamp")
    if end is None:
        errors.append("demo_soak.end must be an ISO-8601 timestamp")
    if start is not None and end is not None:
        try:
            if end <= start:
                errors.append("demo_soak.end must be later than demo_soak.start")
        except TypeError:
            errors.append("demo_soak.start and demo_soak.end must use compatible timezone forms")

    report = str(soak.get("report_path", "")).strip()
    if report:
        p = Path(report)
        if not p.is_absolute():
            p = ROOT / p
        if not p.exists():
            errors.append(f"demo soak report not found: {p}")

    basis = copy.deepcopy(soak)
    stored = str(basis.pop("evidence_digest", ""))
    digest = canonical_digest(basis)
    if len(stored) != 64 or any(c not in "0123456789abcdefABCDEF" for c in stored):
        errors.append("demo_soak.evidence_digest must be a 64-character SHA-256 digest")
    elif stored.lower() != digest.lower():
        errors.append(f"demo_soak.evidence_digest mismatch: expected {digest}, found {stored}")

    return errors, digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA demo-soak evidence against the versioned schema")
    ap.add_argument("evidence", nargs="?", default="release_evidence.json")
    args = ap.parse_args()

    evidence_path = Path(args.evidence)
    if not evidence_path.is_absolute():
        evidence_path = ROOT / evidence_path
    if not evidence_path.exists():
        print(f"SOAK EVIDENCE SCHEMA CHECK: FAILED\nERROR: evidence file not found: {evidence_path}")
        return 1

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    data = json.loads(evidence_path.read_text(encoding="utf-8"))
    soak = data.get("demo_soak")
    if not isinstance(soak, dict):
        print("SOAK EVIDENCE SCHEMA CHECK: FAILED\nERROR: demo_soak must be an object")
        return 1

    errors, digest = validate_soak(soak, schema)
    out = ROOT / "soak-evidence-validation.txt"
    if errors:
        text = "SOAK EVIDENCE SCHEMA CHECK: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nSOAK_EVIDENCE_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = f"SOAK EVIDENCE SCHEMA CHECK: PASS\nSCHEMA_VERSION: {soak['schema_version']}\nSOAK_EVIDENCE_SHA256: {digest}\n"
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
