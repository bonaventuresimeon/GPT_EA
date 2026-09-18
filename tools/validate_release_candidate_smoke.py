#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, re, sys
from pathlib import Path

EXPECTED_SCHEMA="gpt_ea_release_candidate_smoke_v1"
EXPECTED_IDS=[f"RCS-{i:03d}" for i in range(1,16)]
SHA40=re.compile(r"^[0-9a-fA-F]{40}$")
SHA64=re.compile(r"^[0-9a-f]{64}$")

def fail(msg:str)->None:
    print("RELEASE-CANDIDATE SMOKE: FAILED")
    print("ERROR:",msg)
    raise SystemExit(1)

def main()->int:
    if len(sys.argv)!=2:
        print("Usage: python tools/validate_release_candidate_smoke.py <smoke.json>")
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
    if c.get("feature_freeze_active") is not True: fail("feature_freeze_active must be true")
    if c.get("compile_evidence_validated") is not True: fail("compile_evidence_validated must be true")
    cases=rec.get("cases",[])
    if [str(x.get("id","")) for x in cases]!=EXPECTED_IDS: fail("cases must contain RCS-001..RCS-015 exactly in order")
    for x in cases:
        cid=x["id"]
        if x.get("executed") is not True: fail(f"{cid}: executed must be true")
        if x.get("result")!="PASS": fail(f"{cid}: result must be PASS")
        if not x.get("evidence_refs"): fail(f"{cid}: evidence_refs required")
        if not str(x.get("observed_result","")).strip(): fail(f"{cid}: observed_result required")
    for k in ["critical_errors","duplicate_orders","phantom_orders","release_bypasses","secrets_exposed","abandoned_open_positions"]:
        if rec.get("zero_tolerance",{}).get(k)!=0: fail(f"zero_tolerance.{k} must be 0")
    if rec.get("decision")!="PASS": fail("decision must be PASS")
    supplied=str(rec.get("evidence_digest","")).lower()
    if not SHA64.fullmatch(supplied): fail("evidence_digest must be 64 lowercase hex characters")
    basis=dict(rec); basis.pop("evidence_digest",None)
    digest=hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
    if digest!=supplied: fail("evidence_digest mismatch")
    print("RELEASE-CANDIDATE SMOKE: PASS")
    print("EVIDENCE_DIGEST="+digest)
    return 0

if __name__=="__main__": raise SystemExit(main())
