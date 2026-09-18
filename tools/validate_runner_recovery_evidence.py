#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any
from release_contract import load_release_contract

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
SCHEMA_VERSION=CONTRACT["runner_recovery_schema"]
RELEASE_ID=CONTRACT["release_validation_id"]
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

def canonical_digest(value:dict[str,Any])->str:
    basis=copy.deepcopy(value)
    basis.pop("evidence_digest",None)
    return hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def validate_runner_recovery(data:dict[str,Any],require_digest:bool=True,expected_sha:str="",expected_bundle_digest:str="")->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,data.get("schema_version")==SCHEMA_VERSION,f"schema_version must be {SCHEMA_VERSION}")
    require(errors,data.get("release_validation_id")==RELEASE_ID,f"release_validation_id must be {RELEASE_ID}")
    require(errors,len(str(data.get("evidence_id","")).strip())>=8,"evidence_id must contain at least 8 characters")

    incident=data.get("incident",{})
    require(errors,incident.get("conclusion")=="failure","incident.conclusion must be failure")
    require(errors,int(incident.get("runner_id",-1) or 0)==0,"incident.runner_id must be 0")
    require(errors,str(incident.get("runner_name",""))=="","incident.runner_name must be empty")
    require(errors,int(incident.get("steps_executed",-1))==0,"incident.steps_executed must be 0")
    require(errors,incident.get("observed_signature")=="PRE_RUNNER_NO_STEPS","incident.observed_signature must be PRE_RUNNER_NO_STEPS")
    require(errors,int(incident.get("run_id",0) or 0)>0 and int(incident.get("job_id",0) or 0)>0,"incident run/job IDs must be > 0")

    probe=data.get("recovery_probe",{})
    require(errors,probe.get("workflow")=="GPT_EA Runner Provisioning Probe","recovery_probe.workflow mismatch")
    require(errors,probe.get("conclusion")=="success","recovery_probe.conclusion must be success")
    require(errors,int(probe.get("run_id",0) or 0)>0 and int(probe.get("run_attempt",0) or 0)>0 and int(probe.get("job_id",0) or 0)>0,"recovery probe run/attempt/job IDs must be > 0")
    require(errors,int(probe.get("runner_id",0) or 0)>0,"recovery_probe.runner_id must be > 0")
    require(errors,len(str(probe.get("runner_name","")).strip())>0,"recovery_probe.runner_name is required")
    require(errors,int(probe.get("steps_executed",0) or 0)>=1,"recovery_probe.steps_executed must be >= 1")
    require(errors,str(probe.get("run_id","")) in str(probe.get("run_url","")),"recovery_probe.run_url must reference run_id")

    static=data.get("release_static",{})
    require(errors,static.get("workflow")=="GPT_EA Static Release Gate","release_static.workflow mismatch")
    require(errors,static.get("conclusion")=="success","release_static.conclusion must be success")
    require(errors,int(static.get("run_id",0) or 0)>0 and int(static.get("run_attempt",0) or 0)>0 and int(static.get("job_id",0) or 0)>0,"release static run/attempt/job IDs must be > 0")
    require(errors,int(static.get("runner_id",0) or 0)>0,"release_static.runner_id must be > 0")
    require(errors,len(str(static.get("runner_name","")).strip())>0,"release_static.runner_name is required")
    require(errors,int(static.get("steps_executed",0) or 0)>=7,"release_static.steps_executed must be >= 7")
    head=str(static.get("head_sha",""))
    bundle=str(static.get("ci_bundle_digest",""))
    require(errors,bool(HEX40.fullmatch(head)),"release_static.head_sha must be a 40-character Git SHA")
    require(errors,static.get("ci_bundle_schema_version")=="ci_evidence_bundle_v1","release_static.ci_bundle_schema_version mismatch")
    require(errors,bool(HEX64.fullmatch(bundle)),"release_static.ci_bundle_digest must be SHA-256")
    require(errors,str(static.get("run_id","")) in str(static.get("run_url","")),"release_static.run_url must reference run_id")
    if expected_sha:
        require(errors,head.lower()==expected_sha.lower(),"release_static.head_sha does not match expected candidate SHA")
    if expected_bundle_digest:
        require(errors,bundle.lower()==expected_bundle_digest.lower(),"release_static.ci_bundle_digest does not match accepted CI bundle")

    remediation=data.get("remediation",{})
    for key in ("github_status_checked","billing_usage_checked","budgets_checked","payment_state_checked"):
        require(errors,remediation.get(key) is True,f"remediation.{key} must be true")

    operator=data.get("operator_review",{})
    require(errors,operator.get("decision")=="ACCEPT","operator_review.decision must be ACCEPT")
    require(errors,len(str(operator.get("reviewer","")).strip())>=2,"operator_review.reviewer is required")
    require(errors,len(str(operator.get("timestamp","")).strip())>=8,"operator_review.timestamp is required")

    digest=canonical_digest(data)
    stored=str(data.get("evidence_digest",""))
    if require_digest:
        require(errors,bool(HEX64.fullmatch(stored)),"evidence_digest must be a SHA-256 digest")
        if HEX64.fullmatch(stored):
            require(errors,stored.lower()==digest.lower(),f"evidence_digest mismatch: expected {digest}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 runner-recovery evidence")
    ap.add_argument("evidence",nargs="?",default="artifacts/runner-recovery-evidence.json")
    ap.add_argument("--expected-sha",default="")
    ap.add_argument("--expected-bundle-digest",default="")
    ap.add_argument("--finalize",action="store_true")
    args=ap.parse_args()
    p=Path(args.evidence)
    if not p.is_absolute(): p=ROOT/p
    if not p.exists():
        print(f"RUNNER RECOVERY EVIDENCE: FAILED\nERROR: evidence file not found: {p}")
        return 1
    data=json.loads(p.read_text(encoding="utf-8"))
    errors,digest=validate_runner_recovery(data,require_digest=not args.finalize,expected_sha=args.expected_sha,expected_bundle_digest=args.expected_bundle_digest)
    if args.finalize and not errors:
        data["evidence_digest"]=digest
        p.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        errors,digest=validate_runner_recovery(data,True,args.expected_sha,args.expected_bundle_digest)
    out=ROOT/"runner-recovery-evidence-validation.txt"
    if errors:
        text="RUNNER RECOVERY EVIDENCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nRUNNER_RECOVERY_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"RUNNER RECOVERY EVIDENCE: PASS\nEVIDENCE_ID: {data['evidence_id']}\nRUNNER_RECOVERY_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
