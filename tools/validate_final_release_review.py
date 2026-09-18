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
MQH=ROOT/"mqh"
PART28=MQH/"GPT_EA_Part28_ReleaseCertification.mqh"
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

def canonical_digest(value:Any)->str:
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def current_release_id()->str:
    text=PART28.read_text(encoding="utf-8")
    m=re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"',text)
    if not m: raise RuntimeError("release validation ID not found in Part28")
    return m.group(1)

def release_basis(data:dict[str,Any])->dict[str,Any]:
    """Stable pre-review basis. Material runner/CI/MT5/API/soak changes invalidate review."""
    gates=dict(data.get("gates",{}))
    gates.pop("operator_review",None)
    return {
        "release_validation_id":data.get("release_validation_id"),
        "build":data.get("build",{}),
        "runner_recovery":data.get("runner_recovery",{}),
        "runner_recovery_acceptance":data.get("runner_recovery_acceptance",{}),
        "ci_static":data.get("ci_static",{}),
        "mt5_validation":data.get("mt5_validation",{}),
        "resilience_hardening":data.get("resilience_hardening",{}),
        "rollback_package":data.get("rollback_package",{}),
        "deployment":data.get("deployment",{}),
        "api_transport":data.get("api_transport",{}),
        "demo_soak":data.get("demo_soak",{}),
        "gates":gates,
    }

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA final GO/NO-GO review")
    ap.add_argument("evidence",nargs="?",default="release_evidence.json")
    ap.add_argument("review",nargs="?",default="final_release_review.json")
    args=ap.parse_args()
    evidence_path=Path(args.evidence); review_path=Path(args.review)
    if not evidence_path.is_absolute(): evidence_path=ROOT/evidence_path
    if not review_path.is_absolute(): review_path=ROOT/review_path
    missing=[str(p) for p in (evidence_path,review_path) if not p.exists()]
    if missing:
        print("FINAL RELEASE REVIEW: FAILED")
        for p in missing: print("ERROR: file not found:",p)
        return 1

    evidence=json.loads(evidence_path.read_text(encoding="utf-8"))
    review=json.loads(review_path.read_text(encoding="utf-8"))
    errors:list[str]=[]
    required_id=current_release_id()
    require(errors,review.get("schema_version")=="final_release_review_v1","review schema_version must be final_release_review_v1")
    require(errors,review.get("release_validation_id")==required_id,f"review release_validation_id must equal {required_id}")
    require(errors,evidence.get("release_validation_id")==required_id,f"evidence release_validation_id must equal {required_id}")
    require(errors,str(review.get("decision",""))=="GO","final decision must be literal GO")
    require(errors,len(str(review.get("review_evidence_id","")).strip())>=4,"review_evidence_id is required")
    require(errors,len(str(review.get("reviewer","")).strip())>=2,"reviewer is required")
    require(errors,len(str(review.get("review_timestamp","")).strip())>=8,"review_timestamp is required")

    candidate=review.get("candidate",{}); build=evidence.get("build",{})
    require(errors,candidate.get("git_sha")==build.get("git_sha"),"review candidate.git_sha must match release evidence")
    require(errors,candidate.get("ex5_sha256")==build.get("ex5_sha256"),"review candidate.ex5_sha256 must match release evidence")
    require(errors,candidate.get("set_sha256")==build.get("set_sha256"),"review candidate.set_sha256 must match release evidence")
    require(errors,bool(HEX40.fullmatch(str(candidate.get("git_sha","")))),"candidate.git_sha must be 40 hexadecimal characters")
    require(errors,bool(HEX64.fullmatch(str(candidate.get("ex5_sha256","")))),"candidate.ex5_sha256 must be 64 hexadecimal characters")
    set_hash=str(candidate.get("set_sha256",""))
    require(errors,set_hash=="NONE" or bool(HEX64.fullmatch(set_hash)),"candidate.set_sha256 must be 64 hexadecimal characters or NONE")

    basis_digest=canonical_digest(release_basis(evidence))
    require(errors,candidate.get("release_evidence_digest")==basis_digest,f"candidate.release_evidence_digest must equal {basis_digest}")

    dep_r=review.get("deployment",{}); dep_e=evidence.get("deployment",{})
    for key in ("broker_company","trade_server","account_currency","margin_mode","account_leverage"):
        require(errors,dep_r.get(key)==dep_e.get(key),f"review deployment.{key} must match release evidence")
    require(errors,dep_r.get("deployment_profile_match") is True,"deployment_profile_match must be true")

    checks=review.get("review",{})
    required_checks=[
        "compile_contract_pass","runner_recovery_pass","runner_recovery_acceptance_pass","ci_bundle_pass",
        "ci_attestation_verified","mt5_validation_pass","resilience_hardening_pass","rollback_package_ready",
        "api_transport_pass","five_day_acceptance_pass",
        "soak_day_reconciliation_pass","five_day_operator_record_complete","soak_schema_pass",
        "release_evidence_validator_pass","all_release_gates_pass","zero_unresolved_critical_states",
        "zero_zero_tolerance_failures","artifact_identity_match","deployment_identity_match",
        "no_source_change_after_validation","no_unreviewed_known_issue","initial_live_risk_conservative",
        "approval_required_initially",
    ]
    for key in required_checks: require(errors,checks.get(key) is True,f"review.{key} must be true")

    rr=evidence.get("runner_recovery",{})
    require(errors,isinstance(rr,dict),"release evidence runner_recovery must be an object")
    if isinstance(rr,dict):
        require(errors,rr.get("schema_version")=="runner_recovery_evidence_v1","runner recovery schema must be current")
        require(errors,rr.get("validated") is True,"runner recovery evidence must be validated before final review")
        require(errors,bool(HEX64.fullmatch(str(rr.get("evidence_digest","")))),"runner recovery digest must be valid")
        require(errors,len(str(rr.get("evidence_id","")).strip())>=8,"runner recovery evidence ID is required")

    ra=evidence.get("runner_recovery_acceptance",{})
    require(errors,isinstance(ra,dict),"release evidence runner_recovery_acceptance must be an object")
    if isinstance(ra,dict):
        require(errors,ra.get("schema_version")=="runner_recovery_acceptance_v1","runner recovery acceptance schema must be current")
        require(errors,ra.get("validated") is True,"runner recovery acceptance must be validated before final review")
        require(errors,bool(HEX64.fullmatch(str(ra.get("acceptance_digest","")))),"runner recovery acceptance digest must be valid")
        require(errors,len(str(ra.get("acceptance_id","")).strip())>=8,"runner recovery acceptance ID is required")

    ci=evidence.get("ci_static",{})
    require(errors,isinstance(ci,dict),"release evidence ci_static must be an object")
    if isinstance(ci,dict):
        require(errors,ci.get("bundle_validated") is True,"release evidence CI bundle must be validated before final review")
        require(errors,ci.get("attestation_verified") is True,"release evidence CI attestation must be verified before final review")
        require(errors,bool(HEX64.fullmatch(str(ci.get("bundle_digest","")))),"release evidence CI bundle digest must be valid")
        require(errors,str(ci.get("head_sha","")).lower()==str(build.get("git_sha","")).lower(),"release evidence CI head SHA must match build Git SHA")

    mt5=evidence.get("mt5_validation",{})
    require(errors,isinstance(mt5,dict),"release evidence mt5_validation must be an object")
    if isinstance(mt5,dict):
        require(errors,mt5.get("schema_version")=="mt5_validation_evidence_v2","MT5 validation schema must be current")
        require(errors,mt5.get("validated") is True,"MT5 validation evidence must be validated before final review")
        require(errors,bool(HEX64.fullmatch(str(mt5.get("evidence_digest","")))),"MT5 validation digest must be valid")
        require(errors,len(str(mt5.get("evidence_id","")).strip())>=8,"MT5 validation evidence ID is required")

    rh=evidence.get("resilience_hardening",{})
    require(errors,isinstance(rh,dict),"release evidence resilience_hardening must be an object")
    if isinstance(rh,dict):
        require(errors,rh.get("schema_version")=="resilience_hardening_evidence_v1","resilience hardening schema must be current")
        require(errors,rh.get("validated") is True,"resilience hardening must be validated before final review")
        require(errors,bool(HEX64.fullmatch(str(rh.get("evidence_digest","")))),"resilience hardening digest must be valid")
        require(errors,len(str(rh.get("evidence_id","")).strip())>=8,"resilience hardening evidence ID is required")
        require(errors,bool(re.fullmatch(r"[0-9a-fA-F]{8}",str(rh.get("config_fingerprint","")))) and str(rh.get("config_fingerprint",""))!="00000000",
                "resilience hardening configuration fingerprint must be valid")

    rollback=evidence.get("rollback_package",{})
    require(errors,isinstance(rollback,dict),"release evidence rollback_package must be an object")
    if isinstance(rollback,dict):
        require(errors,rollback.get("validated") is True,"rollback readiness must be validated before final review")
        require(errors,rollback.get("mode") in {"VALIDATED_PACKAGE","FIRST_CERTIFIED_RELEASE"},
                "rollback readiness mode must be VALIDATED_PACKAGE or FIRST_CERTIFIED_RELEASE")

    api=evidence.get("api_transport",{})
    require(errors,isinstance(api,dict),"release evidence api_transport must be an object")
    if isinstance(api,dict):
        require(errors,api.get("high_priority_matrix_passed") is True,"API transport high-priority matrix must pass before final review")
        require(errors,int(api.get("secret_leak_count",-1))==0,"API transport secret_leak_count must be 0")

    soak=evidence.get("demo_soak",{})
    require(errors,isinstance(soak,dict),"release evidence demo_soak must be an object")
    if isinstance(soak,dict):
        require(errors,soak.get("acceptance_record_schema_version")=="five_day_soak_acceptance_v2","five-day acceptance schema v2 is required before final review")
        require(errors,len(str(soak.get("acceptance_record_id","")).strip())>=8,"five-day acceptance record ID is required before final review")
        require(errors,bool(HEX64.fullmatch(str(soak.get("acceptance_record_digest","")))),"five-day acceptance record digest must be valid before final review")
        require(errors,bool(str(soak.get("acceptance_record_path","")).strip()),"five-day acceptance record path is required before final review")

    require(errors,int(review.get("unresolved_critical_count",-1))==0,"unresolved_critical_count must be 0")
    require(errors,int(review.get("zero_tolerance_failure_count",-1))==0,"zero_tolerance_failure_count must be 0")

    gates=evidence.get("gates",{})
    for key,value in gates.items():
        if key=="operator_review": continue
        require(errors,value is True,f"release evidence gate {key} must be true before final review")

    review_for_digest=copy.deepcopy(review); review_for_digest.pop("review_digest",None)
    review_digest=canonical_digest(review_for_digest)
    if "review_digest" in review:
        require(errors,str(review.get("review_digest","")).lower()==review_digest.lower(),f"review_digest mismatch: expected {review_digest}")

    out=ROOT/"final-release-review-validation.txt"
    if errors:
        text="FINAL RELEASE REVIEW: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nRELEASE_EVIDENCE_BASIS_SHA256: {basis_digest}\nFINAL_REVIEW_SHA256: {review_digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"FINAL RELEASE REVIEW: PASS\nRELEASE_ID: {required_id}\nRELEASE_EVIDENCE_BASIS_SHA256: {basis_digest}\nFINAL_REVIEW_SHA256: {review_digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
