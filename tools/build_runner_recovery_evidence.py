#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TEMPLATE=ROOT/"RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json"

def api_json(url:str,token:str)->dict:
    req=urllib.request.Request(url,headers={
        "Accept":"application/vnd.github+json",
        "Authorization":f"Bearer {token}",
        "X-GitHub-Api-Version":"2022-11-28",
        "User-Agent":"GPT_EA-Runner-Recovery",
    })
    with urllib.request.urlopen(req,timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

def job_for(repo:str,run_id:int,attempt:int,name:str,token:str)->dict:
    url=f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100"
    data=api_json(url,token)
    matches=[j for j in data.get("jobs",[]) if j.get("name")==name]
    if not matches: raise RuntimeError(f"job {name!r} not found in run {run_id} attempt {attempt}")
    return sorted(matches,key=lambda j:int(j.get("id",0)),reverse=True)[0]

def executed_steps(job:dict)->int:
    return sum(1 for s in (job.get("steps") or []) if s.get("status")=="completed" and s.get("conclusion") not in (None,"skipped"))

def main()->int:
    ap=argparse.ArgumentParser(description="Build GPT_EA runner-recovery evidence from GitHub completed jobs")
    ap.add_argument("--repository",default="bonaventuresimeon/GPT_EA")
    ap.add_argument("--probe-run-id",type=int,required=True)
    ap.add_argument("--probe-attempt",type=int,default=1)
    ap.add_argument("--static-run-id",type=int,required=True)
    ap.add_argument("--static-attempt",type=int,default=1)
    ap.add_argument("--candidate-sha",required=True)
    ap.add_argument("--ci-bundle-manifest",default="artifacts/ci-bundle-manifest.json")
    ap.add_argument("--output",default="artifacts/runner-recovery-evidence.json")
    args=ap.parse_args()
    token=os.getenv("GITHUB_TOKEN","").strip()
    if not token:
        print("RUNNER RECOVERY BUILD: FAILED\nERROR: GITHUB_TOKEN is required"); return 1

    probe=job_for(args.repository,args.probe_run_id,args.probe_attempt,"runner-probe",token)
    static=job_for(args.repository,args.static_run_id,args.static_attempt,"static-release-gate",token)
    manifest_path=Path(args.ci_bundle_manifest)
    if not manifest_path.is_absolute(): manifest_path=ROOT/manifest_path
    if not manifest_path.exists():
        print(f"RUNNER RECOVERY BUILD: FAILED\nERROR: CI bundle manifest not found: {manifest_path}"); return 1
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    bundle_digest=str(manifest.get("bundle_digest",""))
    if len(bundle_digest)!=64:
        print("RUNNER RECOVERY BUILD: FAILED\nERROR: CI bundle manifest has no valid bundle_digest"); return 1

    data=json.loads(TEMPLATE.read_text(encoding="utf-8"))
    data["evidence_id"]=f"runner-recovery-{args.static_run_id}-{args.static_attempt}"
    data["recovery_probe"]={
        "workflow":"GPT_EA Runner Provisioning Probe",
        "run_id":args.probe_run_id,
        "run_attempt":args.probe_attempt,
        "job_id":int(probe.get("id",0) or 0),
        "conclusion":str(probe.get("conclusion","")),
        "runner_id":int(probe.get("runner_id",0) or 0),
        "runner_name":str(probe.get("runner_name","")),
        "steps_executed":executed_steps(probe),
        "run_url":f"https://github.com/{args.repository}/actions/runs/{args.probe_run_id}",
        "observed_at_utc":datetime.now(timezone.utc).isoformat(),
    }
    data["release_static"]={
        "workflow":"GPT_EA Static Release Gate",
        "run_id":args.static_run_id,
        "run_attempt":args.static_attempt,
        "job_id":int(static.get("id",0) or 0),
        "conclusion":str(static.get("conclusion","")),
        "runner_id":int(static.get("runner_id",0) or 0),
        "runner_name":str(static.get("runner_name","")),
        "steps_executed":executed_steps(static),
        "head_sha":args.candidate_sha,
        "ci_bundle_schema_version":"ci_evidence_bundle_v1",
        "ci_bundle_digest":bundle_digest,
        "run_url":f"https://github.com/{args.repository}/actions/runs/{args.static_run_id}",
    }
    out=Path(args.output)
    if not out.is_absolute(): out=ROOT/out
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    print("RUNNER RECOVERY BUILD: CREATED")
    print(f"OUTPUT={out}")
    print("Operator must complete remediation booleans/reviewer/ACCEPT before --finalize.")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
