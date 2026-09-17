#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from validate_runner_recovery_evidence import validate_runner_recovery

ROOT=Path(__file__).resolve().parents[1]
RELEASE_ID="GPT_EA_FULL_INTELLIGENCE_R6_20260917"
SCHEMA_VERSION="runner_recovery_acceptance_v1"
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

CHECKS=(
    "incident_preserved","incident_classified_pre_runner","github_status_checked","actions_eligibility_checked",
    "budget_checked","payment_state_checked","recovery_probe_allocated","recovery_probe_success",
    "recovery_attempt_pinned","candidate_static_runner_allocated","candidate_static_steps_executed",
    "candidate_static_success","candidate_sha_match","repository_static_result_pass","ci_evidence_validated",
    "attestation_verified","ci_bundle_validated","recovery_ci_identity_match","recovery_bundle_digest_match",
    "no_unreviewed_runner_regression","evidence_digests_valid",
)

def canonical_digest(value:dict[str,Any])->str:
    basis=copy.deepcopy(value)
    basis.pop("acceptance_digest",None)
    return hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def validate_acceptance(data:dict[str,Any],require_digest:bool=True,expected_sha:str="",expected_bundle_digest:str="")->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,data.get("schema_version")==SCHEMA_VERSION,f"schema_version must be {SCHEMA_VERSION}")
    require(errors,data.get("release_validation_id")==RELEASE_ID,f"release_validation_id must be {RELEASE_ID}")
    require(errors,len(str(data.get("acceptance_id","")).strip())>=8,"acceptance_id must contain at least 8 characters")

    recovery_id=str(data.get("runner_recovery_evidence_id",""))
    recovery_digest=str(data.get("runner_recovery_evidence_digest",""))
    candidate_sha=str(data.get("candidate_git_sha",""))
    bundle_digest=str(data.get("ci_bundle_digest",""))
    require(errors,len(recovery_id.strip())>=8,"runner_recovery_evidence_id is required")
    require(errors,bool(HEX64.fullmatch(recovery_digest)),"runner_recovery_evidence_digest must be SHA-256")
    require(errors,bool(HEX40.fullmatch(candidate_sha)),"candidate_git_sha must be 40 hexadecimal characters")
    require(errors,bool(HEX64.fullmatch(bundle_digest)),"ci_bundle_digest must be SHA-256")
    if expected_sha:
        require(errors,candidate_sha.lower()==expected_sha.lower(),"candidate_git_sha does not match expected candidate")
    if expected_bundle_digest:
        require(errors,bundle_digest.lower()==expected_bundle_digest.lower(),"ci_bundle_digest does not match accepted CI bundle")

    recovery_path_raw=str(data.get("runner_recovery_evidence_path","")).strip()
    require(errors,bool(recovery_path_raw),"runner_recovery_evidence_path is required")
    if recovery_path_raw:
        p=resolve(recovery_path_raw)
        require(errors,p.exists(),f"runner recovery evidence file not found: {p}")
        if p.exists():
            try:
                recovery=json.loads(p.read_text(encoding="utf-8"))
                rr_errors,rr_digest=validate_runner_recovery(
                    recovery,True,expected_sha=candidate_sha,expected_bundle_digest=bundle_digest
                )
                errors.extend(f"runner recovery: {e}" for e in rr_errors)
                require(errors,str(recovery.get("evidence_id",""))==recovery_id,
                        "runner_recovery_evidence_id does not match recovery record")
                require(errors,rr_digest.lower()==recovery_digest.lower(),
                        "runner_recovery_evidence_digest does not match recovery record")
            except Exception as exc:
                errors.append(f"could not validate runner recovery evidence: {exc}")

    checks=data.get("checks",{})
    require(errors,isinstance(checks,dict),"checks must be an object")
    if isinstance(checks,dict):
        for key in CHECKS:
            require(errors,checks.get(key) is True,f"checks.{key} must be true")

    operator=data.get("operator_review",{})
    require(errors,operator.get("decision")=="ACCEPT","operator_review.decision must be ACCEPT")
    require(errors,len(str(operator.get("reviewer","")).strip())>=2,"operator_review.reviewer is required")
    require(errors,len(str(operator.get("timestamp","")).strip())>=8,"operator_review.timestamp is required")

    digest=canonical_digest(data)
    stored=str(data.get("acceptance_digest",""))
    if require_digest:
        require(errors,bool(HEX64.fullmatch(stored)),"acceptance_digest must be SHA-256")
        if HEX64.fullmatch(stored):
            require(errors,stored.lower()==digest.lower(),f"acceptance_digest mismatch: expected {digest}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 runner-recovery acceptance")
    ap.add_argument("acceptance",nargs="?",default="artifacts/runner-recovery-acceptance.json")
    ap.add_argument("--expected-sha",default="")
    ap.add_argument("--expected-bundle-digest",default="")
    ap.add_argument("--finalize",action="store_true")
    args=ap.parse_args()
    p=resolve(args.acceptance)
    if not p.exists():
        print(f"RUNNER RECOVERY ACCEPTANCE: FAILED\nERROR: file not found: {p}")
        return 1
    data=json.loads(p.read_text(encoding="utf-8"))
    errors,digest=validate_acceptance(data,not args.finalize,args.expected_sha,args.expected_bundle_digest)
    if args.finalize and not errors:
        data["acceptance_digest"]=digest
        p.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        errors,digest=validate_acceptance(data,True,args.expected_sha,args.expected_bundle_digest)
    out=ROOT/"runner-recovery-acceptance-validation.txt"
    if errors:
        text="RUNNER RECOVERY ACCEPTANCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nACCEPTANCE_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"RUNNER RECOVERY ACCEPTANCE: PASS\nACCEPTANCE_ID: {data['acceptance_id']}\nACCEPTANCE_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
