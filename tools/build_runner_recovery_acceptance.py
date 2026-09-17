#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from validate_runner_recovery_evidence import validate_runner_recovery

ROOT=Path(__file__).resolve().parents[1]
TEMPLATE=ROOT/"RUNNER_RECOVERY_ACCEPTANCE_TEMPLATE.json"

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def rel(path:Path)->str:
    try: return str(path.relative_to(ROOT)).replace("\\","/")
    except ValueError: return str(path)

def main()->int:
    ap=argparse.ArgumentParser(description="Build a draft GPT_EA R6 runner-recovery acceptance record")
    ap.add_argument("--runner-recovery",default="artifacts/runner-recovery-evidence.json")
    ap.add_argument("--matrix",default="artifacts/runner-recovery-acceptance.md")
    ap.add_argument("--candidate-sha",required=True)
    ap.add_argument("--ci-bundle-digest",required=True)
    ap.add_argument("--output",default="artifacts/runner-recovery-acceptance.json")
    args=ap.parse_args()

    recovery_path=resolve(args.runner_recovery)
    matrix_path=resolve(args.matrix)
    if not recovery_path.exists():
        print(f"RUNNER RECOVERY ACCEPTANCE BUILD: FAILED\nERROR: recovery evidence not found: {recovery_path}"); return 1
    if not matrix_path.exists():
        print(f"RUNNER RECOVERY ACCEPTANCE BUILD: FAILED\nERROR: acceptance matrix not found: {matrix_path}"); return 1

    recovery=json.loads(recovery_path.read_text(encoding="utf-8"))
    rr_errors,rr_digest=validate_runner_recovery(
        recovery,True,expected_sha=args.candidate_sha,expected_bundle_digest=args.ci_bundle_digest
    )
    if rr_errors:
        print("RUNNER RECOVERY ACCEPTANCE BUILD: FAILED")
        for e in rr_errors: print("ERROR:",e)
        return 1

    data=json.loads(TEMPLATE.read_text(encoding="utf-8"))
    data["acceptance_id"]=f"runner-acceptance-{args.candidate_sha[:12]}"
    data["runner_recovery_evidence_path"]=rel(recovery_path)
    data["runner_recovery_evidence_id"]=str(recovery.get("evidence_id",""))
    data["runner_recovery_evidence_digest"]=rr_digest
    data["candidate_git_sha"]=args.candidate_sha
    data["ci_bundle_digest"]=args.ci_bundle_digest
    data["matrix_path"]=rel(matrix_path)
    data["matrix_sha256"]=sha256_file(matrix_path)

    incident=recovery.get("incident",{})
    probe=recovery.get("recovery_probe",{})
    static=recovery.get("release_static",{})
    checks=data["checks"]
    checks["incident_preserved"]=int(incident.get("runner_id",-1) or 0)==0 and int(incident.get("steps_executed",-1))==0
    checks["incident_classified_pre_runner"]=incident.get("observed_signature")=="PRE_RUNNER_NO_STEPS"
    checks["recovery_probe_allocated"]=int(probe.get("runner_id",0) or 0)>0 and int(probe.get("job_id",0) or 0)>0
    checks["recovery_probe_success"]=probe.get("conclusion")=="success"
    checks["recovery_attempt_pinned"]=int(probe.get("run_attempt",0) or 0)>0
    checks["candidate_static_runner_allocated"]=int(static.get("runner_id",0) or 0)>0
    checks["candidate_static_steps_executed"]=int(static.get("steps_executed",0) or 0)>=7
    checks["candidate_static_success"]=static.get("conclusion")=="success"
    checks["candidate_sha_match"]=str(static.get("head_sha","")).lower()==args.candidate_sha.lower()
    checks["recovery_bundle_digest_match"]=str(static.get("ci_bundle_digest","")).lower()==args.ci_bundle_digest.lower()
    checks["evidence_digests_valid"]=True

    out=resolve(args.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    print("RUNNER RECOVERY ACCEPTANCE DRAFT: CREATED")
    print(f"OUTPUT={out}")
    print("Machine-derived checks were populated. Complete the remaining evidence-dependent checks and operator ACCEPT only from actual archived proof.")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
