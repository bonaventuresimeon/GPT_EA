#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from release_contract import load_release_contract

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
SCHEMA=CONTRACT["release_readiness_schema"]
RELEASE_ID=CONTRACT["release_validation_id"]
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA release readiness status semantics")
    ap.add_argument("status",nargs="?",default="artifacts/release-readiness-status.json")
    args=ap.parse_args()
    p=resolve(args.status)
    if not p.exists():
        print(f"RELEASE READINESS STATUS VALIDATION: FAILED\nERROR: file not found: {p}")
        return 1
    try: value=json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"RELEASE READINESS STATUS VALIDATION: FAILED\nERROR: invalid JSON: {exc}")
        return 1

    errors:list[str]=[]
    if value.get("schema_version")!=SCHEMA: errors.append(f"schema_version must be {SCHEMA}")
    if value.get("release_validation_id")!=RELEASE_ID: errors.append(f"release_validation_id must be {RELEASE_ID}")
    candidate=str(value.get("candidate_git_sha",""))
    if not HEX40.fullmatch(candidate): errors.append("candidate_git_sha must be 40 hex")
    if len(str(value.get("generated_utc","")).strip())<10: errors.append("generated_utc is required")

    code=value.get("code_readiness",{})
    cstate=code.get("state")
    if cstate not in {"CODE_STATIC_HOLD","CODE_STATIC_READY"}: errors.append("invalid code_readiness.state")
    if code.get("basis") not in {"NONE","LOCAL_STATIC","CI_BUNDLE"}: errors.append("invalid code_readiness.basis")
    if code.get("static_result") not in {"UNKNOWN","FAILED","PASS"}: errors.append("invalid code_readiness.static_result")
    if cstate=="CODE_STATIC_READY":
        if code.get("static_result")!="PASS": errors.append("CODE_STATIC_READY requires static_result PASS")
        if str(code.get("source_git_sha","")).lower()!=candidate.lower(): errors.append("CODE_STATIC_READY must bind the exact candidate SHA")
        if code.get("basis")=="NONE": errors.append("CODE_STATIC_READY requires LOCAL_STATIC or CI_BUNDLE basis")

    evidence=value.get("evidence_readiness",{})
    estate=evidence.get("state")
    if estate not in {"EVIDENCE_HOLD","EVIDENCE_READY_FOR_FINAL_REVIEW","PRODUCTION_GO"}:
        errors.append("invalid evidence_readiness.state")
    missing=evidence.get("missing_gates",[])
    if not isinstance(missing,list): errors.append("evidence_readiness.missing_gates must be an array")
    if evidence.get("final_review_decision") not in {"HOLD","GO","UNKNOWN"}:
        errors.append("invalid final_review_decision")
    authoritative=evidence.get("authoritative_validation_passed")
    if not isinstance(authoritative,bool): errors.append("authoritative_validation_passed must be boolean")
    if estate=="EVIDENCE_READY_FOR_FINAL_REVIEW" and missing:
        errors.append("EVIDENCE_READY_FOR_FINAL_REVIEW requires no missing non-operator gates")
    if estate=="PRODUCTION_GO":
        if missing: errors.append("PRODUCTION_GO requires no missing gates")
        if evidence.get("final_review_decision")!="GO": errors.append("PRODUCTION_GO requires final_review_decision GO")
        if authoritative is not True: errors.append("PRODUCTION_GO requires authoritative_validation_passed=true")

    overall=value.get("overall_state")
    if overall not in {"HOLD","GO"}: errors.append("overall_state must be HOLD or GO")
    if overall=="GO" and estate!="PRODUCTION_GO": errors.append("overall GO is allowed only with PRODUCTION_GO")
    if estate=="PRODUCTION_GO" and overall!="GO": errors.append("PRODUCTION_GO requires overall_state GO")
    if estate!="PRODUCTION_GO" and overall!="HOLD": errors.append("non-production evidence state requires overall HOLD")

    if errors:
        print("RELEASE READINESS STATUS VALIDATION: FAILED")
        for e in errors: print("ERROR:",e)
        return 1
    print("RELEASE READINESS STATUS VALIDATION: PASS")
    print("CODE_READINESS:",cstate)
    print("EVIDENCE_READINESS:",estate)
    print("OVERALL_STATE:",overall)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
