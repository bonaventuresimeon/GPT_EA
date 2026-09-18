#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from validate_mt5_validation_evidence import validate_mt5

ROOT=Path(__file__).resolve().parents[1]
SCHEMA="mt5_minimum_proof_summary_v1"
RELEASE_ID="GPT_EA_FULL_INTELLIGENCE_R6_20260917"
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def main()->int:
    ap=argparse.ArgumentParser(description="Validate compact MT5 minimum-proof summary")
    ap.add_argument("summary",nargs="?",default="artifacts/mt5-minimum-proof-summary.json")
    args=ap.parse_args()
    p=resolve(args.summary)
    errors:list[str]=[]
    if not p.exists():
        print(f"MT5 MINIMUM PROOF SUMMARY: FAILED\nERROR: summary not found: {p}")
        return 1
    try:
        value=json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"MT5 MINIMUM PROOF SUMMARY: FAILED\nERROR: invalid JSON: {exc}")
        return 1

    if value.get("schema_version")!=SCHEMA: errors.append(f"schema_version must be {SCHEMA}")
    if value.get("release_validation_id")!=RELEASE_ID: errors.append(f"release_validation_id must be {RELEASE_ID}")
    candidate=str(value.get("candidate_git_sha",""))
    expected=str(value.get("source_mt5_evidence_digest",""))
    if not HEX40.fullmatch(candidate): errors.append("candidate_git_sha must be 40 hex")
    if not HEX64.fullmatch(expected): errors.append("source_mt5_evidence_digest must be SHA-256")
    bundles=value.get("bundles",{})
    for i in range(1,9):
        key=f"MP-{i:02d}"
        if bundles.get(key)!="PASS": errors.append(f"bundles.{key} must be PASS")
    if value.get("overall")!="PASS": errors.append("overall must be PASS")

    source_raw=str(value.get("source_mt5_evidence_path","")).strip()
    if not source_raw:
        errors.append("source_mt5_evidence_path is required")
    else:
        source=resolve(source_raw)
        if not source.exists():
            errors.append(f"authoritative MT5 evidence not found: {source}")
        else:
            try:
                data=json.loads(source.read_text(encoding="utf-8"))
                mt5_errors,digest=validate_mt5(data,require_digest=True,expected_sha=candidate)
                errors.extend(f"MT5 evidence: {e}" for e in mt5_errors)
                if expected and HEX64.fullmatch(expected) and digest.lower()!=expected.lower():
                    errors.append("source_mt5_evidence_digest does not match authoritative MT5 v2 evidence")
            except Exception as exc:
                errors.append(f"could not revalidate authoritative MT5 evidence: {exc}")

    if errors:
        print("MT5 MINIMUM PROOF SUMMARY: FAILED")
        for e in errors: print("ERROR:",e)
        return 1
    print("MT5 MINIMUM PROOF SUMMARY: PASS")
    print("CANDIDATE_GIT_SHA:",candidate)
    print("SOURCE_MT5_EVIDENCE_SHA256:",expected)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
