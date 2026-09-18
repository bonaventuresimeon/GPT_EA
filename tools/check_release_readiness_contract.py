#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT=Path(__file__).resolve().parents[1]
errors:list[str]=[]

required=[
    "docs/MT5_MINIMUM_PROOF_SET.md",
    "MT5_MINIMUM_PROOF_SUMMARY_SCHEMA.json",
    "MT5_MINIMUM_PROOF_SUMMARY_TEMPLATE.json",
    "tools/build_mt5_minimum_proof_summary.py",
    "tools/validate_mt5_minimum_proof_summary.py",
    "docs/RELEASE_READINESS_MODEL.md",
    "RELEASE_READINESS_STATUS_SCHEMA.json",
    "RELEASE_READINESS_STATUS_TEMPLATE.json",
    "tools/build_release_readiness_status.py",
    "tools/validate_release_readiness_status.py",
]
for name in required:
    p=ROOT/name
    if not p.exists(): errors.append(f"missing readiness artifact: {name}")
    elif p.suffix in {".md",".py"} and len(p.read_text(encoding="utf-8").strip())<100:
        errors.append(f"readiness artifact too small: {name}")

for name,version in (
    ("MT5_MINIMUM_PROOF_SUMMARY_SCHEMA.json","mt5_minimum_proof_summary_v1"),
    ("RELEASE_READINESS_STATUS_SCHEMA.json","release_readiness_status_v1"),
):
    p=ROOT/name
    if p.exists():
        try:
            obj=json.loads(p.read_text(encoding="utf-8"))
            actual=obj.get("properties",{}).get("schema_version",{}).get("const")
            if actual!=version: errors.append(f"{name} schema version mismatch")
        except Exception as exc:
            errors.append(f"{name} invalid JSON: {exc}")

min_builder=(ROOT/"tools/build_mt5_minimum_proof_summary.py")
if min_builder.exists():
    text=min_builder.read_text(encoding="utf-8")
    for token in ("validate_mt5","require_digest=True","MP-01","MP-08","overall"):
        if token not in text: errors.append(f"minimum proof builder missing token: {token}")

min_validator=(ROOT/"tools/validate_mt5_minimum_proof_summary.py")
if min_validator.exists():
    text=min_validator.read_text(encoding="utf-8")
    for token in ("validate_mt5","expected_sha=candidate","source_mt5_evidence_digest","MP-08"):
        if token not in text: errors.append(f"minimum proof validator missing token: {token}")

readiness=(ROOT/"tools/build_release_readiness_status.py")
if readiness.exists():
    text=readiness.read_text(encoding="utf-8")
    for token in (
        "CODE_STATIC_HOLD","CODE_STATIC_READY","EVIDENCE_HOLD",
        "EVIDENCE_READY_FOR_FINAL_REVIEW","PRODUCTION_GO",
        "validate_release_evidence_r10.py","validate_final_release_review_r10.py",
        "validate_ci_release_record","SOURCE_GIT_SHA","CI_BUNDLE",
    ):
        if token not in text: errors.append(f"readiness builder missing token: {token}")

status_validator=(ROOT/"tools/validate_release_readiness_status.py")
if status_validator.exists():
    text=status_validator.read_text(encoding="utf-8")
    for token in ("PRODUCTION_GO requires authoritative_validation_passed=true","overall GO is allowed only with PRODUCTION_GO"):
        if token not in text: errors.append(f"readiness validator missing invariant: {token}")

runner=(ROOT/"tools/run_release_checks.py")
if runner.exists():
    text=runner.read_text(encoding="utf-8")
    for token in ("SOURCE_GIT_SHA=","SOURCE_LAYOUT=MONOLITHIC","SOURCE_FILE_SHA256="):
        if token not in text: errors.append(f"aggregate static runner missing source-binding token: {token}")

mt5_doc=(ROOT/"docs/MT5_MINIMUM_PROOF_SET.md")
if mt5_doc.exists():
    text=mt5_doc.read_text(encoding="utf-8")
    for token in ("MP-01","MP-08","M5-001","M5-053","does **not** reduce or replace"):
        if token not in text: errors.append(f"minimum proof document missing token: {token}")

ready_doc=(ROOT/"docs/RELEASE_READINESS_MODEL.md")
if ready_doc.exists():
    text=ready_doc.read_text(encoding="utf-8")
    for token in ("CODE_STATIC_READY + EVIDENCE_HOLD","PRODUCTION_GO","does **not** mean MetaEditor compiled"):
        if token not in text: errors.append(f"readiness document missing token: {token}")

if errors:
    print("RELEASE READINESS CONTRACT CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)
print("RELEASE READINESS CONTRACT CHECK: PASS")
