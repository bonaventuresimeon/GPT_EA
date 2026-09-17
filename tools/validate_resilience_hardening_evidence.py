#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[1]
RELEASE_ID="GPT_EA_FULL_INTELLIGENCE_R6_20260917"
SCHEMA_VERSION="resilience_hardening_evidence_v1"
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")
HEX8=re.compile(r"^[0-9a-fA-F]{8}$")
CHECK_KEYS=(
    "direct_breakout","broker_reconciliation","atomic_intent_exactly_once","news_provenance_timestamp",
    "clock_model_degradation","data_versioning_quarantine","promotion_significance_rollback","strategy_registry",
    "portfolio_gap_margin_latency","chaos_fault_injection","storage_config_manual_integrity",
    "causal_attribution","rollback_package",
)

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def canonical_digest(value:dict[str,Any])->str:
    basis=copy.deepcopy(value)
    basis.pop("evidence_digest",None)
    return hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def validate_matrix(path:Path)->list[str]:
    errors:list[str]=[]
    text=path.read_text(encoding="utf-8",errors="replace")
    lines=text.splitlines()
    for n in range(1,49):
        rid=f"RH-{n:03d}"
        matches=[line for line in lines if f"| {rid} |" in line]
        if len(matches)!=1:
            errors.append(f"resilience matrix must contain exactly one row for {rid}")
            continue
        cells=[c.strip() for c in matches[0].split("|")]
        if len(cells)<7:
            errors.append(f"resilience matrix row {rid} is malformed")
            continue
        status=cells[4]
        evidence=cells[5]
        if status!="PASS": errors.append(f"resilience matrix {rid} status must be PASS")
        if not evidence: errors.append(f"resilience matrix {rid} evidence/reference is required")
    return errors

def validate_resilience(data:dict[str,Any],require_digest:bool=True,expected_sha:str="",expected_config:str="")->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,data.get("schema_version")==SCHEMA_VERSION,f"schema_version must be {SCHEMA_VERSION}")
    require(errors,data.get("release_validation_id")==RELEASE_ID,f"release_validation_id must be {RELEASE_ID}")
    require(errors,len(str(data.get("evidence_id","")).strip())>=8,"evidence_id must contain at least 8 characters")
    candidate=str(data.get("candidate_git_sha",""))
    cfg=str(data.get("config_fingerprint",""))
    require(errors,bool(HEX40.fullmatch(candidate)),"candidate_git_sha must be 40 hexadecimal characters")
    require(errors,bool(HEX8.fullmatch(cfg)) and cfg!="00000000","config_fingerprint must be a non-zero 8-hex runtime fingerprint")
    if expected_sha: require(errors,candidate.lower()==expected_sha.lower(),"candidate_git_sha does not match release build")
    if expected_config: require(errors,cfg.upper()==expected_config.upper(),"config_fingerprint does not match expected certified fingerprint")

    matrix_raw=str(data.get("matrix_path","")).strip()
    matrix_digest=str(data.get("matrix_sha256",""))
    require(errors,bool(matrix_raw),"matrix_path is required")
    require(errors,bool(HEX64.fullmatch(matrix_digest)),"matrix_sha256 must be SHA-256")
    if matrix_raw:
        p=resolve(matrix_raw)
        require(errors,p.exists(),f"resilience matrix not found: {p}")
        if p.exists():
            actual=sha256_file(p)
            if HEX64.fullmatch(matrix_digest):
                require(errors,actual.lower()==matrix_digest.lower(),f"matrix_sha256 mismatch: expected {matrix_digest}, actual {actual}")
            errors.extend(validate_matrix(p))

    checks=data.get("checks",{})
    require(errors,isinstance(checks,dict),"checks must be an object")
    if isinstance(checks,dict):
        for key in CHECK_KEYS: require(errors,checks.get(key) is True,f"checks.{key} must be true")

    op=data.get("operator_review",{})
    require(errors,op.get("decision")=="ACCEPT","operator_review.decision must be ACCEPT")
    require(errors,len(str(op.get("reviewer","")).strip())>=2,"operator_review.reviewer is required")
    require(errors,len(str(op.get("timestamp","")).strip())>=8,"operator_review.timestamp is required")

    digest=canonical_digest(data)
    stored=str(data.get("evidence_digest",""))
    if require_digest:
        require(errors,bool(HEX64.fullmatch(stored)),"evidence_digest must be SHA-256")
        if HEX64.fullmatch(stored): require(errors,stored.lower()==digest.lower(),f"evidence_digest mismatch: expected {digest}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 resilience hardening evidence")
    ap.add_argument("evidence",nargs="?",default="artifacts/r6-resilience-hardening.json")
    ap.add_argument("--expected-sha",default="")
    ap.add_argument("--expected-config",default="")
    ap.add_argument("--finalize",action="store_true")
    args=ap.parse_args()
    p=resolve(args.evidence)
    if not p.exists():
        print(f"RESILIENCE HARDENING EVIDENCE: FAILED\nERROR: file not found: {p}"); return 1
    data=json.loads(p.read_text(encoding="utf-8"))
    errors,digest=validate_resilience(data,not args.finalize,args.expected_sha,args.expected_config)
    if args.finalize and not errors:
        data["evidence_digest"]=digest
        p.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        errors,digest=validate_resilience(data,True,args.expected_sha,args.expected_config)
    out=ROOT/"resilience-hardening-evidence-validation.txt"
    if errors:
        text="RESILIENCE HARDENING EVIDENCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nRESILIENCE_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"RESILIENCE HARDENING EVIDENCE: PASS\nEVIDENCE_ID: {data['evidence_id']}\nCONFIG_FINGERPRINT: {data['config_fingerprint']}\nRESILIENCE_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
