#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from validate_api_transport_evidence import validate_api_transport
from validate_ci_bundle import validate_bundle
from validate_ci_evidence import validate_ci_value
from validate_five_day_soak_record import validate_record
from validate_runner_recovery_evidence import validate_runner_recovery
from validate_soak_evidence import validate_soak

ROOT=Path(__file__).resolve().parents[1]
PART28=ROOT/"GPT_EA_Part28_ReleaseCertification.mqh"
SOAK_SCHEMA=ROOT/"SOAK_EVIDENCE_SCHEMA.json"
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def resolve(path_text:str)->Path:
    p=Path(path_text)
    return p if p.is_absolute() else ROOT/p

def current_release_id()->str:
    text=PART28.read_text(encoding="utf-8")
    m=re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"',text)
    if not m: raise RuntimeError("release validation ID not found in Part28")
    return m.group(1)

def git_head()->str|None:
    try: return subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except Exception: return None

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def validate_ci_release_record(ci:dict,build_sha:str)->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,ci.get("schema_version")=="github_actions_static_evidence_v1","ci_static.schema_version must be github_actions_static_evidence_v1")
    for key in ("run_id","run_attempt","job_id","runner_id","steps_executed"):
        try: value=int(ci.get(key,0) or 0)
        except Exception: value=0
        require(errors,value>0,f"ci_static.{key} must be > 0")
    require(errors,int(ci.get("steps_executed",0) or 0)>=7,"ci_static.steps_executed must be >= 7")
    require(errors,bool(str(ci.get("runner_name","")).strip()),"ci_static.runner_name is required")
    head=str(ci.get("head_sha",""))
    require(errors,bool(HEX40.fullmatch(head)),"ci_static.head_sha must be 40 hexadecimal characters")
    if HEX40.fullmatch(head) and HEX40.fullmatch(build_sha):
        require(errors,head.lower()==build_sha.lower(),"ci_static.head_sha must match build.git_sha")
    require(errors,ci.get("conclusion")=="success","ci_static.conclusion must be success")
    require(errors,ci.get("artifact_archived") is True,"ci_static.artifact_archived must be true")
    require(errors,ci.get("attestation_verified") is True,"ci_static.attestation_verified must be true")
    require(errors,len(str(ci.get("artifact_name","")).strip())>=8,"ci_static.artifact_name is required")
    require(errors,str(ci.get("run_id","")) in str(ci.get("run_url","")),"ci_static.run_url must reference ci_static.run_id")
    require(errors,str(ci.get("job_id","")) in str(ci.get("job_url","")),"ci_static.job_url must reference ci_static.job_id")
    expected_digest=str(ci.get("evidence_digest",""))
    require(errors,bool(HEX64.fullmatch(expected_digest)),"ci_static.evidence_digest must be 64 hexadecimal characters")

    metadata_raw=str(ci.get("job_metadata_path","")).strip()
    require(errors,bool(metadata_raw),"ci_static.job_metadata_path is required")
    metadata_path=resolve(metadata_raw) if metadata_raw else None
    if metadata_path is not None: require(errors,metadata_path.exists(),f"CI job metadata file not found: {metadata_path}")

    evidence_raw=str(ci.get("evidence_path","")).strip()
    require(errors,bool(evidence_raw),"ci_static.evidence_path is required")
    if evidence_raw:
        evidence_path=resolve(evidence_raw)
        require(errors,evidence_path.exists(),f"CI evidence file not found: {evidence_path}")
        if evidence_path.exists():
            try:
                value=json.loads(evidence_path.read_text(encoding="utf-8"))
                ci_errors,digest=validate_ci_value(value,expected_sha=build_sha,job_metadata=metadata_path if metadata_path and metadata_path.exists() else None)
                errors.extend(f"ci_static evidence: {e}" for e in ci_errors)
                require(errors,digest.lower()==expected_digest.lower(),"ci_static.evidence_digest does not match ci-evidence.json")
                for key in ("run_id","run_attempt","job_id","runner_id","steps_executed","head_sha","runner_name"):
                    if str(ci.get(key,""))!=str(value.get(key,"")): errors.append(f"ci_static.{key} does not match ci-evidence.json")
                if str(ci.get("conclusion",""))!=str(value.get("static_job_conclusion","")):
                    errors.append("ci_static.conclusion does not match ci-evidence static_job_conclusion")
            except Exception as exc: errors.append(f"could not validate ci_static.evidence_path: {exc}")

    verify_raw=str(ci.get("attestation_verification_path","")).strip()
    require(errors,bool(verify_raw),"ci_static.attestation_verification_path is required")
    if verify_raw:
        p=resolve(verify_raw)
        require(errors,p.exists(),f"CI attestation verification output not found: {p}")
        if p.exists(): require(errors,"CI ATTESTATION VERIFY: PASS" in p.read_text(encoding="utf-8",errors="replace"),"CI attestation verification output does not contain PASS marker")

    require(errors,ci.get("bundle_schema_version")=="ci_evidence_bundle_v1","ci_static.bundle_schema_version must be ci_evidence_bundle_v1")
    expected_bundle_digest=str(ci.get("bundle_digest",""))
    require(errors,bool(HEX64.fullmatch(expected_bundle_digest)),"ci_static.bundle_digest must be 64 hexadecimal characters")
    require(errors,ci.get("bundle_validated") is True,"ci_static.bundle_validated must be true")
    bundle_digest=""
    bundle_raw=str(ci.get("bundle_manifest_path","")).strip()
    require(errors,bool(bundle_raw),"ci_static.bundle_manifest_path is required")
    if bundle_raw:
        bundle_path=resolve(bundle_raw)
        require(errors,bundle_path.exists(),f"CI bundle manifest not found: {bundle_path}")
        if bundle_path.exists():
            try:
                manifest=json.loads(bundle_path.read_text(encoding="utf-8"))
                bundle_errors,bundle_digest=validate_bundle(manifest,bundle_path.parent,expected_sha=build_sha)
                errors.extend(f"ci_static bundle: {e}" for e in bundle_errors)
                require(errors,bundle_digest.lower()==expected_bundle_digest.lower(),"ci_static.bundle_digest does not match ci-bundle-manifest.json")
                for key in ("run_id","run_attempt","job_id","runner_id","steps_executed"):
                    if str(ci.get(key,""))!=str(manifest.get(key,"")): errors.append(f"ci_static.{key} does not match CI bundle manifest")
                require(errors,str(ci.get("artifact_name",""))==str(manifest.get("artifact_name","")),"ci_static.artifact_name does not match CI bundle manifest")
            except Exception as exc: errors.append(f"could not validate CI bundle manifest: {exc}")

    bundle_validation_raw=str(ci.get("bundle_validation_path","")).strip()
    require(errors,bool(bundle_validation_raw),"ci_static.bundle_validation_path is required")
    if bundle_validation_raw:
        p=resolve(bundle_validation_raw)
        require(errors,p.exists(),f"CI bundle validation output not found: {p}")
        if p.exists(): require(errors,"CI BUNDLE VALIDATION: PASS" in p.read_text(encoding="utf-8",errors="replace"),"CI bundle validation output does not contain PASS marker")
    return errors,bundle_digest

def validate_runner_release_record(rr:dict,build_sha:str,ci_bundle_digest:str,ci:dict)->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,rr.get("schema_version")=="runner_recovery_evidence_v1","runner_recovery.schema_version must be runner_recovery_evidence_v1")
    require(errors,len(str(rr.get("evidence_id","")).strip())>=8,"runner_recovery.evidence_id is required")
    expected=str(rr.get("evidence_digest",""))
    require(errors,bool(HEX64.fullmatch(expected)),"runner_recovery.evidence_digest must be SHA-256")
    require(errors,rr.get("validated") is True,"runner_recovery.validated must be true")
    path_raw=str(rr.get("evidence_path","")).strip()
    require(errors,bool(path_raw),"runner_recovery.evidence_path is required")
    digest=""
    if path_raw:
        p=resolve(path_raw)
        require(errors,p.exists(),f"runner recovery evidence file not found: {p}")
        if p.exists():
            try:
                value=json.loads(p.read_text(encoding="utf-8"))
                rr_errors,digest=validate_runner_recovery(value,True,expected_sha=build_sha,expected_bundle_digest=ci_bundle_digest)
                errors.extend(f"runner_recovery evidence: {e}" for e in rr_errors)
                require(errors,digest.lower()==expected.lower(),"runner_recovery.evidence_digest does not match evidence file")
                require(errors,str(value.get("evidence_id",""))==str(rr.get("evidence_id","")),"runner_recovery.evidence_id does not match evidence file")
                static=value.get("release_static",{})
                for key in ("run_id","run_attempt","job_id","runner_id","steps_executed"):
                    require(errors,str(static.get(key,""))==str(ci.get(key,"")),f"runner_recovery release_static.{key} must match ci_static.{key}")
            except Exception as exc: errors.append(f"could not validate runner recovery evidence: {exc}")
    validation_raw=str(rr.get("validation_path","")).strip()
    require(errors,bool(validation_raw),"runner_recovery.validation_path is required")
    if validation_raw:
        p=resolve(validation_raw)
        require(errors,p.exists(),f"runner recovery validation output not found: {p}")
        if p.exists(): require(errors,"RUNNER RECOVERY EVIDENCE: PASS" in p.read_text(encoding="utf-8",errors="replace"),"runner recovery validation output does not contain PASS marker")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA current compile/runner/CI/API/demo-soak/final-review release evidence")
    ap.add_argument("evidence",nargs="?",default="release_evidence.json")
    args=ap.parse_args()
    evidence_path=Path(args.evidence)
    if not evidence_path.is_absolute(): evidence_path=ROOT/evidence_path
    if not evidence_path.exists():
        print(f"RELEASE EVIDENCE VALIDATION: FAILED\nERROR: evidence file not found: {evidence_path}"); return 1

    data=json.loads(evidence_path.read_text(encoding="utf-8"))
    errors:list[str]=[]
    required_id=current_release_id()
    require(errors,data.get("release_validation_id")==required_id,f"release_validation_id must equal {required_id}")

    build=data.get("build",{})
    git_sha=str(build.get("git_sha","")); ex5_hash=str(build.get("ex5_sha256","")); set_hash=str(build.get("set_sha256",""))
    require(errors,bool(HEX40.fullmatch(git_sha)),"build.git_sha must be 40 hexadecimal characters")
    require(errors,bool(HEX64.fullmatch(ex5_hash)),"build.ex5_sha256 must be 64 hexadecimal characters")
    require(errors,set_hash=="NONE" or bool(HEX64.fullmatch(set_hash)),"build.set_sha256 must be 64 hexadecimal characters or NONE")
    require(errors,int(build.get("compile_errors",-1))==0,"compile_errors must be 0")
    require(errors,int(build.get("compile_warnings",-1))==0,"compile_warnings must be 0 for production certification")
    require(errors,bool(str(build.get("metaeditor_build","")).strip()),"metaeditor_build is required")
    require(errors,bool(str(build.get("mt5_build","")).strip()),"mt5_build is required")
    require(errors,bool(str(build.get("compile_evidence_id","")).strip()),"compile_evidence_id is required")

    head=git_head()
    if head and HEX40.fullmatch(git_sha): require(errors,head.lower()==git_sha.lower(),f"evidence Git SHA {git_sha} does not match repository HEAD {head}")

    ex5_raw=str(build.get("ex5_path","")).strip()
    require(errors,bool(ex5_raw),"build.ex5_path is required")
    if ex5_raw:
        p=resolve(ex5_raw); require(errors,p.exists(),f"EX5 file not found: {p}")
        if p.exists() and HEX64.fullmatch(ex5_hash): require(errors,sha256_file(p).lower()==ex5_hash.lower(),"EX5 SHA-256 mismatch")

    set_raw=str(build.get("set_path","")).strip()
    if set_hash!="NONE":
        require(errors,bool(set_raw),"set_path is required when set_sha256 is not NONE")
        if set_raw:
            p=resolve(set_raw); require(errors,p.exists(),f"SET file not found: {p}")
            if p.exists() and HEX64.fullmatch(set_hash): require(errors,sha256_file(p).lower()==set_hash.lower(),"SET SHA-256 mismatch")

    compile_raw=str(build.get("compile_log_path","")).strip()
    require(errors,bool(compile_raw),"compile_log_path is required")
    if compile_raw: require(errors,resolve(compile_raw).exists(),f"compile log not found: {resolve(compile_raw)}")

    ci=data.get("ci_static")
    ci_bundle_digest=""
    if not isinstance(ci,dict): errors.append("ci_static must be an object"); ci={}
    else:
        ci_errors,ci_bundle_digest=validate_ci_release_record(ci,git_sha); errors.extend(ci_errors)

    rr=data.get("runner_recovery")
    runner_digest=""
    if not isinstance(rr,dict): errors.append("runner_recovery must be an object")
    else:
        rr_errors,runner_digest=validate_runner_release_record(rr,git_sha,ci_bundle_digest,ci); errors.extend(rr_errors)

    deployment=data.get("deployment",{})
    for key in ("broker_company","trade_server","account_currency","margin_mode","account_leverage"):
        require(errors,bool(str(deployment.get(key,"")).strip()),f"deployment.{key} is required")
    require(errors,isinstance(deployment.get("symbols"),list) and len(deployment.get("symbols",[]))>0,"deployment.symbols must contain at least one validated symbol")

    api_errors,api_digest=validate_api_transport(data); errors.extend(api_errors)

    schema=json.loads(SOAK_SCHEMA.read_text(encoding="utf-8"))
    soak=data.get("demo_soak")
    soak_digest=""
    if not isinstance(soak,dict): errors.append("demo_soak must be an object")
    else:
        soak_errors,soak_digest=validate_soak(soak,schema); errors.extend(soak_errors)
        require(errors,soak.get("acceptance_record_schema_version")=="five_day_soak_acceptance_v2","demo_soak.acceptance_record_schema_version must be five_day_soak_acceptance_v2")
        record_raw=str(soak.get("acceptance_record_path","")).strip()
        require(errors,bool(record_raw),"demo_soak.acceptance_record_path is required")
        if record_raw:
            p=resolve(record_raw)
            require(errors,p.exists(),f"five-day acceptance record not found: {p}")
            if p.exists():
                try:
                    record=json.loads(p.read_text(encoding="utf-8"))
                    record_errors,record_digest=validate_record(record,require_digest=True)
                    errors.extend(f"five-day record: {e}" for e in record_errors)
                    require(errors,record.get("schema_version")==soak.get("acceptance_record_schema_version"),"five-day record schema must match demo_soak.acceptance_record_schema_version")
                    candidate=record.get("candidate",{})
                    for rk,bk in (("git_sha","git_sha"),("ex5_sha256","ex5_sha256"),("set_sha256","set_sha256")):
                        require(errors,str(candidate.get(rk,"")).lower()==str(build.get(bk,"")).lower(),f"five-day record candidate.{rk} must match build.{bk}")
                    require(errors,record_digest.lower()==str(soak.get("acceptance_record_digest","")).lower(),"five-day record digest must match demo_soak.acceptance_record_digest")
                    require(errors,str(record.get("record_id",""))==str(soak.get("acceptance_record_id","")),"five-day record ID must match demo_soak.acceptance_record_id")
                except Exception as exc: errors.append(f"could not cross-check five-day acceptance record: {exc}")

    gates=data.get("gates",{})
    required_gates=[
        "metaeditor_compile","artifact_identity","runner_recovery","ci_static","strategy_tester","intelligence_matrix",
        "adaptive_portfolio","execution_learning","champion_challenger","lifecycle_integrity","broker_matrix",
        "deployment_profile","recovery","stop_matrix","broker_stop_policy","partial_protection","stop_observability",
        "live_news_intermarket","web_failure_injection","api_transport","demo_soak","operator_review",
    ]
    for key in required_gates: require(errors,gates.get(key) is True,f"gates.{key} must be true")

    final_review=data.get("final_review",{})
    require(errors,final_review.get("schema_version")=="final_release_review_v1","final_review.schema_version must be final_release_review_v1")
    require(errors,len(str(final_review.get("review_evidence_id","")).strip())>=4,"final_review.review_evidence_id is required")
    require(errors,bool(HEX64.fullmatch(str(final_review.get("review_digest","")))),"final_review.review_digest must be 64 hexadecimal characters")
    require(errors,final_review.get("decision")=="GO","final_review.decision must be GO")
    require(errors,len(str(final_review.get("reviewer","")).strip())>=2,"final_review.reviewer is required")
    require(errors,len(str(final_review.get("review_timestamp","")).strip())>=8,"final_review.review_timestamp is required")

    digest=hashlib.sha256(json.dumps(data,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()
    out=ROOT/"release-evidence-validation.txt"
    if errors:
        text="RELEASE EVIDENCE VALIDATION: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)
        if runner_digest: text+=f"\nRUNNER_RECOVERY_SHA256: {runner_digest}"
        if ci_bundle_digest: text+=f"\nCI_BUNDLE_SHA256: {ci_bundle_digest}"
        if api_digest: text+=f"\nAPI_TRANSPORT_SHA256: {api_digest}"
        if soak_digest: text+=f"\nSOAK_EVIDENCE_SHA256: {soak_digest}"
        text+=f"\nEVIDENCE_JSON_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=(f"RELEASE EVIDENCE VALIDATION: PASS\nRELEASE_ID: {required_id}\n"
          f"RUNNER_RECOVERY_SHA256: {runner_digest}\nCI_EVIDENCE_SHA256: {ci['evidence_digest']}\n"
          f"CI_BUNDLE_SHA256: {ci_bundle_digest}\nAPI_TRANSPORT_SHA256: {api_digest}\n"
          f"SOAK_EVIDENCE_SHA256: {soak_digest}\nEVIDENCE_JSON_SHA256: {digest}\n")
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
