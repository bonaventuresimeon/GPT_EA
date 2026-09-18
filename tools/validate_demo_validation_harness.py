#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, re, sys
from pathlib import Path
from release_contract import load_release_contract

CONTRACT=load_release_contract()

EXPECTED_SCHEMA=CONTRACT["demo_validation_run_schema"]
EXPECTED_IDS=[f"DV-{i:03d}" for i in range(1,19)]
SHA40=re.compile(r"^[0-9a-fA-F]{40}$")
SHA64=re.compile(r"^[0-9a-f]{64}$")

def fail(msg:str)->None:
    print("DEMO VALIDATION HARNESS: FAILED")
    print("ERROR:",msg)
    raise SystemExit(1)

def main()->int:
    if len(sys.argv)!=2:
        print("Usage: python tools/validate_demo_validation_harness.py <run.json>")
        return 2
    p=Path(sys.argv[1])
    if not p.exists(): fail("evidence file not found")
    try: rec=json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc: fail(f"invalid JSON: {exc}")
    if rec.get("schema_version")!=EXPECTED_SCHEMA: fail("schema_version mismatch")
    c=rec.get("candidate",{})
    if not SHA40.fullmatch(str(c.get("git_sha",""))): fail("candidate.git_sha must be 40 hex characters")
    if not SHA64.fullmatch(str(c.get("ex5_sha256","")).lower()): fail("candidate.ex5_sha256 must be 64 lowercase hex characters")
    if c.get("account_mode")!="DEMO": fail("candidate.account_mode must be DEMO")
    scenarios=rec.get("scenarios",[])
    if [str(x.get("id","")) for x in scenarios]!=EXPECTED_IDS: fail("scenarios must contain DV-001..DV-018 exactly in order")
    for s in scenarios:
        sid=s["id"]
        if s.get("priority")!="HIGH": fail(f"{sid}: priority must be HIGH")
        if s.get("executed") is not True: fail(f"{sid}: executed must be true")
        if s.get("result")!="PASS": fail(f"{sid}: result must be PASS")
        if not s.get("evidence_refs"): fail(f"{sid}: evidence_refs required")
        if not str(s.get("observed_result","")).strip(): fail(f"{sid}: observed_result required")
    z=rec.get("zero_tolerance",{})
    for k in ["duplicate_orders","duplicate_partials","backward_stop_moves","unresolved_missing_sl","stale_approval_executions","gate_bypasses","secrets_exposed"]:
        if z.get(k)!=0: fail(f"zero_tolerance.{k} must be 0")
    if rec.get("decision")!="PASS": fail("decision must be PASS")
    supplied=str(rec.get("evidence_digest","")).lower()
    if not SHA64.fullmatch(supplied): fail("evidence_digest must be 64 lowercase hex characters")
    basis=dict(rec); basis.pop("evidence_digest",None)
    digest=hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
    if digest!=supplied: fail("evidence_digest mismatch")
    print("DEMO VALIDATION HARNESS: PASS")
    print("EVIDENCE_DIGEST="+digest)
    return 0

if __name__=="__main__": raise SystemExit(main())
