#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, re, sys
from pathlib import Path

EXPECTED_SCHEMA="gpt_ea_fail_closed_recovery_drill_v1"
EXPECTED_IDS=[f"FCR-{i:03d}" for i in range(1,16)]
SHA40=re.compile(r"^[0-9a-fA-F]{40}$")
SHA64=re.compile(r"^[0-9a-f]{64}$")

def fail(msg:str)->None:
    print("FAIL-CLOSED RECOVERY DRILL: FAILED")
    print("ERROR:",msg)
    raise SystemExit(1)

def main()->int:
    if len(sys.argv)!=2:
        print("Usage: python tools/validate_fail_closed_recovery_drill.py <drill.json>")
        return 2
    p=Path(sys.argv[1])
    if not p.exists(): fail("evidence file not found")
    try: rec=json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc: fail(f"invalid JSON: {exc}")

    if rec.get("schema_version")!=EXPECTED_SCHEMA: fail("schema_version mismatch")
    cand=rec.get("candidate",{})
    if not SHA40.fullmatch(str(cand.get("git_sha",""))): fail("candidate.git_sha must be 40 hex characters")
    if not SHA64.fullmatch(str(cand.get("ex5_sha256","")).lower()): fail("candidate.ex5_sha256 must be 64 lowercase hex characters")
    if cand.get("account_mode")!="DEMO": fail("candidate.account_mode must be DEMO")

    scenarios=rec.get("scenarios",[])
    ids=[str(x.get("id","")) for x in scenarios]
    if ids!=EXPECTED_IDS: fail("scenarios must contain FCR-001..FCR-015 exactly in order")
    for s in scenarios:
        sid=s["id"]
        if s.get("executed") is not True: fail(f"{sid}: executed must be true")
        if s.get("result")!="PASS": fail(f"{sid}: result must be PASS")
        if len(str(s.get("started_at_utc","")).strip())<10 or len(str(s.get("completed_at_utc","")).strip())<10:
            fail(f"{sid}: timestamps missing")
        refs=s.get("evidence_refs",[])
        if not isinstance(refs,list) or not refs: fail(f"{sid}: evidence_refs required")
        if not str(s.get("observed_result","")).strip(): fail(f"{sid}: observed_result required")

    z=rec.get("zero_tolerance",{})
    required=["duplicate_orders","duplicate_partials","backward_stop_moves","stale_approval_executions","unsafe_new_entries","phantom_positions","foreign_state_accepted","abandoned_open_positions","unreconciled_critical_clears","secrets_exposed"]
    for k in required:
        if z.get(k)!=0: fail(f"zero_tolerance.{k} must be 0")
    if rec.get("decision")!="PASS": fail("decision must be PASS")

    supplied=str(rec.get("evidence_digest","")).lower()
    if not SHA64.fullmatch(supplied): fail("evidence_digest must be 64 lowercase hex characters")
    basis=dict(rec); basis.pop("evidence_digest",None)
    digest=hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
    if digest!=supplied: fail("evidence_digest mismatch")
    print("FAIL-CLOSED RECOVERY DRILL: PASS")
    print("EVIDENCE_DIGEST="+digest)
    return 0

if __name__=="__main__": raise SystemExit(main())
