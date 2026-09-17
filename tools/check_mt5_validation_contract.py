#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
errors:list[str]=[]

required=[
    "MT5_VALIDATION_EVIDENCE.md",
    "MT5_VALIDATION_ACCEPTANCE_MATRIX.md",
    "MT5_VALIDATION_EVIDENCE_TEMPLATE.json",
    "MT5_VALIDATION_EVIDENCE_SCHEMA.json",
    "tools/validate_mt5_validation_evidence.py",
    "tools/build_mt5_validation_evidence.py",
    "GPT_EA_Part28B_CIReleaseEvidence.mqh",
    "RELEASE_EVIDENCE_TEMPLATE.json",
    "FINAL_RELEASE_REVIEW_TEMPLATE.json",
]
for name in required:
    if not (ROOT/name).exists(): errors.append(f"missing MT5 validation artifact: {name}")

if not errors:
    schema=json.loads((ROOT/"MT5_VALIDATION_EVIDENCE_SCHEMA.json").read_text(encoding="utf-8"))
    if schema.get("properties",{}).get("schema_version",{}).get("const")!="mt5_validation_evidence_v1":
        errors.append("MT5 validation schema version mismatch")

    template=json.loads((ROOT/"MT5_VALIDATION_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
    if template.get("schema_version")!="mt5_validation_evidence_v1":
        errors.append("MT5 validation template schema mismatch")
    for section,key in (
        ("compile","passed"),("strategy_tester","passed"),("broker_runtime","broker_matrix_passed"),
        ("protection","stop_matrix_passed"),("live_api_news","webrequest_allow_list_verified"),
    ):
        if template.get(section,{}).get(key) is not False:
            errors.append(f"MT5 validation template {section}.{key} must default false")
    if template.get("operator_review",{}).get("decision")!="HOLD":
        errors.append("MT5 validation template operator decision must default HOLD")

    validator=(ROOT/"tools/validate_mt5_validation_evidence.py").read_text(encoding="utf-8")
    for token in ["mt5_validation_evidence_v1","compile_log_sha256","report_sha256","broker_history_sha256",
                  "required_failure_fail_closed","secret_leak_count","MT5 VALIDATION EVIDENCE"]:
        if token not in validator: errors.append(f"MT5 validator missing token: {token}")

    builder=(ROOT/"tools/build_mt5_validation_evidence.py").read_text(encoding="utf-8")
    for token in ["--git-sha","--ex5-sha256","--compile-log","--tester-report","--experts-log","--journal-log","--broker-history","--matrix-bundle"]:
        if token not in builder: errors.append(f"MT5 evidence builder missing token: {token}")

    matrix=(ROOT/"MT5_VALIDATION_ACCEPTANCE_MATRIX.md").read_text(encoding="utf-8")
    for token in ["M5-001","M5-007","M5-016","M5-023","M5-029","M5-034"]:
        if token not in matrix: errors.append(f"MT5 acceptance matrix missing {token}")

    part=(ROOT/"GPT_EA_Part28B_CIReleaseEvidence.mqh").read_text(encoding="utf-8")
    for token in ["GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA","ReleaseMT5ValidationEvidenceAllows",
                  "InpReleaseMT5ValidationPassed","InpReleaseMT5ValidationSchemaVersion",
                  "InpReleaseMT5ValidationEvidenceId","InpReleaseMT5ValidationDigest"]:
        if token not in part: errors.append(f"Part28B missing MT5 validation token: {token}")
    if not re.search(r"input\s+bool\s+InpReleaseMT5ValidationPassed\s*=\s*false\s*;",part):
        errors.append("InpReleaseMT5ValidationPassed must default false")

    release=json.loads((ROOT/"RELEASE_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
    if release.get("mt5_validation",{}).get("schema_version")!="mt5_validation_evidence_v1":
        errors.append("release evidence template missing MT5 validation object")
    if release.get("gates",{}).get("mt5_validation") is not False:
        errors.append("release evidence mt5_validation gate must default false")

    final=json.loads((ROOT/"FINAL_RELEASE_REVIEW_TEMPLATE.json").read_text(encoding="utf-8"))
    if final.get("review",{}).get("mt5_validation_pass") is not False:
        errors.append("final review mt5_validation_pass must default false")

if errors:
    print("MT5 VALIDATION STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)
print("MT5 VALIDATION STATIC CHECK: PASS")
