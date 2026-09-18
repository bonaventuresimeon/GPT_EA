#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from validate_release_evidence import validate_ci_release_record
from release_contract import load_release_contract

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
SCHEMA=CONTRACT["release_readiness_schema"]
RELEASE_ID=CONTRACT["release_validation_id"]
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def parse_static(path:Path,candidate:str)->tuple[str,str,str,str,str]:
    if not path.exists():
        return "CODE_STATIC_HOLD","NONE","UNKNOWN","","static-check.txt is absent."
    text=path.read_text(encoding="utf-8",errors="replace")
    result="PASS" if re.search(r"^RESULT=PASS$",text,re.M) else ("FAILED" if re.search(r"^RESULT=FAILED$",text,re.M) else "UNKNOWN")
    m=re.search(r"^SOURCE_GIT_SHA=([0-9a-fA-F]{40})$",text,re.M)
    source_sha=m.group(1) if m else ""
    if result=="PASS" and source_sha and source_sha.lower()==candidate.lower():
        return "CODE_STATIC_READY","LOCAL_STATIC","PASS",source_sha,"Aggregate local static suite passed for the exact candidate SHA."
    if result=="PASS" and not source_sha:
        return "CODE_STATIC_HOLD","LOCAL_STATIC","PASS","","Static PASS is not bound to a source SHA."
    if result=="PASS":
        return "CODE_STATIC_HOLD","LOCAL_STATIC","PASS",source_sha,"Static PASS belongs to a different source SHA."
    return "CODE_STATIC_HOLD","LOCAL_STATIC",result,source_sha,"Aggregate local static suite has not passed for the exact candidate."

def ci_static_ready(data:dict,candidate:str)->bool:
    ci=data.get("ci_static",{})
    if not isinstance(ci,dict):
        return False
    try:
        errors,_=validate_ci_release_record(ci,candidate)
        return not errors
    except Exception:
        return False

def run_validator(script:str,*args:str)->tuple[bool,str]:
    p=ROOT/"tools"/script
    if not p.exists(): return False,f"validator missing: {p}"
    proc=subprocess.run([sys.executable,str(p),*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
    return proc.returncode==0,proc.stdout.strip()

def main()->int:
    ap=argparse.ArgumentParser(description="Build GPT_EA code-vs-evidence readiness status")
    ap.add_argument("--release-evidence",default="artifacts/release-evidence.json")
    ap.add_argument("--static-check",default="static-check.txt")
    ap.add_argument("--final-review",default="artifacts/final-release-review.json")
    ap.add_argument("--output",default="artifacts/release-readiness-status.json")
    args=ap.parse_args()

    evidence_path=resolve(args.release_evidence)
    if not evidence_path.exists():
        print(f"RELEASE READINESS STATUS: FAILED\nERROR: release evidence not found: {evidence_path}")
        return 1
    try:
        data=json.loads(evidence_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"RELEASE READINESS STATUS: FAILED\nERROR: invalid release evidence JSON: {exc}")
        return 1

    if data.get("release_validation_id")!=RELEASE_ID:
        print(f"RELEASE READINESS STATUS: FAILED\nERROR: release_validation_id must be {RELEASE_ID}")
        return 1
    candidate=str(data.get("build",{}).get("git_sha",""))
    if not HEX40.fullmatch(candidate):
        print("RELEASE READINESS STATUS: FAILED\nERROR: build.git_sha must be a 40-character Git SHA")
        return 1

    code_state,basis,static_result,source_sha,code_reason=parse_static(resolve(args.static_check),candidate)
    if code_state!="CODE_STATIC_READY" and ci_static_ready(data,candidate):
        code_state="CODE_STATIC_READY"
        basis="CI_BUNDLE"
        static_result="PASS"
        source_sha=candidate
        code_reason="Validated executed CI bundle proves the aggregate static suite passed on the exact candidate SHA."

    gates=data.get("gates",{}) if isinstance(data.get("gates",{}),dict) else {}
    non_operator=[k for k in gates.keys() if k!="operator_review"]
    missing=sorted(k for k in non_operator if gates.get(k) is not True)
    review_decision=str(data.get("final_review",{}).get("decision","UNKNOWN")).upper()
    if review_decision not in {"HOLD","GO"}: review_decision="UNKNOWN"

    evidence_state="EVIDENCE_HOLD"
    authoritative=False
    evidence_reason=""
    review_path=resolve(args.final_review)

    if missing:
        evidence_reason="Release-blocking evidence gates remain incomplete: "+", ".join(missing)
    elif gates.get("operator_review") is not True or review_decision!="GO":
        evidence_state="EVIDENCE_READY_FOR_FINAL_REVIEW"
        evidence_reason="All non-operator evidence gates are true; final operator GO review is still pending."
    else:
        release_ok,release_output=run_validator("validate_release_evidence_r10.py",str(evidence_path))
        review_ok=False
        review_output=""
        if review_path.exists():
            review_ok,review_output=run_validator("validate_final_release_review_r10.py",str(evidence_path),str(review_path))
        if release_ok and review_ok:
            evidence_state="PRODUCTION_GO"
            authoritative=True
            evidence_reason="Active R10 release-evidence and final-review validators both PASS."
        else:
            evidence_state="EVIDENCE_HOLD"
            parts=[]
            if not release_ok: parts.append("R10 release evidence validator did not pass")
            if not review_path.exists(): parts.append("final review file is missing")
            elif not review_ok: parts.append("R10 final review validator did not pass")
            evidence_reason="; ".join(parts)+"."
            if release_output: evidence_reason+=" Release validator output retained by its normal artifact."
            if review_output: evidence_reason+=" Final-review validator output retained by its normal artifact."

    overall="GO" if evidence_state=="PRODUCTION_GO" else "HOLD"
    status={
        "schema_version":SCHEMA,
        "release_validation_id":RELEASE_ID,
        "candidate_git_sha":candidate,
        "generated_utc":datetime.now(timezone.utc).isoformat(),
        "code_readiness":{
            "state":code_state,"basis":basis,"static_result":static_result,
            "source_git_sha":source_sha,"reason":code_reason,
        },
        "evidence_readiness":{
            "state":evidence_state,"missing_gates":missing,
            "final_review_decision":review_decision,
            "authoritative_validation_passed":authoritative,
            "reason":evidence_reason,
        },
        "overall_state":overall,
    }

    out=resolve(args.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(status,indent=2)+"\n",encoding="utf-8")
    print("RELEASE READINESS STATUS:",overall)
    print("CODE_READINESS:",code_state)
    print("EVIDENCE_READINESS:",evidence_state)
    if missing: print("MISSING_GATES:",",".join(missing))
    print("OUTPUT:",out)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
