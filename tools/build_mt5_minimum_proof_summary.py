#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from validate_mt5_validation_evidence import validate_mt5

ROOT=Path(__file__).resolve().parents[1]
SCHEMA="mt5_minimum_proof_summary_v1"

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def rel(path:Path)->str:
    try: return str(path.resolve().relative_to(ROOT.resolve())).replace("\\","/")
    except Exception: return str(path)

def main()->int:
    ap=argparse.ArgumentParser(description="Build compact MT5 minimum-proof summary from authoritative MT5 v2 evidence")
    ap.add_argument("--mt5-evidence",default="artifacts/mt5-validation-evidence.json")
    ap.add_argument("--output",default="artifacts/mt5-minimum-proof-summary.json")
    args=ap.parse_args()

    source=resolve(args.mt5_evidence)
    if not source.exists():
        print(f"MT5 MINIMUM PROOF SUMMARY: FAILED\nERROR: MT5 evidence not found: {source}")
        return 1
    try:
        data=json.loads(source.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"MT5 MINIMUM PROOF SUMMARY: FAILED\nERROR: invalid MT5 evidence JSON: {exc}")
        return 1

    errors,digest=validate_mt5(data,require_digest=True)
    if errors:
        print("MT5 MINIMUM PROOF SUMMARY: FAILED")
        for e in errors: print("ERROR:",e)
        print("Authoritative MT5 v2 evidence must PASS before a minimum-proof summary can be created.")
        return 1

    candidate=data.get("candidate",{})
    summary={
        "schema_version":SCHEMA,
        "release_validation_id":data.get("release_validation_id"),
        "source_mt5_evidence_path":rel(source),
        "source_mt5_evidence_digest":digest,
        "candidate_git_sha":candidate.get("git_sha",""),
        "bundles":{f"MP-{i:02d}":"PASS" for i in range(1,9)},
        "overall":"PASS",
    }

    out=resolve(args.output)
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print("MT5 MINIMUM PROOF SUMMARY: PASS")
    print("SOURCE_MT5_EVIDENCE_SHA256:",digest)
    print("OUTPUT:",out)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
