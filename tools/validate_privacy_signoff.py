#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from release_contract import load_release_contract

CONTRACT=load_release_contract()
SCHEMA = CONTRACT["privacy_schema"]
SHA40 = re.compile(r"^[0-9a-fA-F]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")


def fail(msg: str) -> None:
    print("PRIVACY SIGN-OFF: FAILED")
    print("ERROR:", msg)
    raise SystemExit(1)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python tools/validate_privacy_signoff.py <privacy-signoff.json>")
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        fail("privacy sign-off file not found")

    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON: {exc}")

    if record.get("schema_version") != SCHEMA:
        fail("schema_version mismatch")
    if not str(record.get("release_id", "")).strip():
        fail("release_id missing")
    if not SHA40.fullmatch(str(record.get("git_sha", ""))):
        fail("git_sha must be exactly 40 hexadecimal characters")
    if len(str(record.get("signoff_id", "")).strip()) < 6:
        fail("signoff_id missing/too short")
    if len(str(record.get("reviewer", "")).strip()) < 2:
        fail("reviewer missing")
    if len(str(record.get("reviewer_role", "")).strip()) < 2:
        fail("reviewer_role missing")
    if len(str(record.get("jurisdiction", "")).strip()) < 2:
        fail("jurisdiction missing")
    if record.get("decision") != "APPROVED":
        fail("decision must be APPROVED")

    try:
        datetime.fromisoformat(str(record.get("signed_at_utc", "")).replace("Z", "+00:00"))
    except Exception:
        fail("signed_at_utc must be ISO-8601")

    controls = record.get("controls", {})
    for key in (
        "data_inventory_approved",
        "retention_schedule_approved",
        "customer_notice_approved",
        "secret_handling_approved",
        "cross_border_review_approved",
        "deletion_workflow_approved",
        "incident_response_approved",
    ):
        if controls.get(key) is not True:
            fail(f"mandatory control not approved: {key}")

    if controls.get("telemetry_state") not in {"DISABLED", "APPROVED"}:
        fail("telemetry_state must be DISABLED or APPROVED")
    if controls.get("unresolved_critical_findings") != 0:
        fail("unresolved_critical_findings must be 0")

    supplied = str(record.get("evidence_digest", "")).lower()
    if not SHA64.fullmatch(supplied):
        fail("evidence_digest must be 64 lowercase hexadecimal characters")

    basis = dict(record)
    basis.pop("evidence_digest", None)
    raw = json.dumps(basis, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    digest = hashlib.sha256(raw).hexdigest()

    if supplied != digest:
        fail("evidence_digest mismatch")

    print("PRIVACY SIGN-OFF: PASS")
    print("EVIDENCE_DIGEST=" + digest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
