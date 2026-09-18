#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from datetime import datetime
from pathlib import Path
from release_contract import load_release_contract

CONTRACT=load_release_contract()
EXPECTED_SCHEMA=CONTRACT["risk_ack_schema"]
EXPECTED_TERMS=CONTRACT["legal_terms_version"]

def fail(msg:str)->None:
    print("CUSTOMER RISK ACKNOWLEDGEMENT: FAILED")
    print("ERROR:",msg)
    raise SystemExit(1)

def main()->int:
    if len(sys.argv)!=2:
        print("Usage: python tools/validate_customer_risk_acknowledgement.py <record.json>")
        return 2
    p=Path(sys.argv[1])
    if not p.exists(): fail("record file not found")
    try:
        rec=json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON: {exc}")

    if rec.get("schema_version")!=EXPECTED_SCHEMA: fail("schema_version mismatch")
    if rec.get("terms_version")!=EXPECTED_TERMS: fail("terms_version mismatch")
    if len(str(rec.get("acknowledgement_id","")).strip())<8: fail("acknowledgement_id missing/too short")
    if len(str(rec.get("jurisdiction","")).strip())<2: fail("jurisdiction missing")
    if len(str(rec.get("license_reference_masked","")).strip())<4: fail("masked license reference missing")
    if rec.get("decision")!="ACCEPTED": fail("decision must be ACCEPTED")

    try:
        datetime.fromisoformat(str(rec.get("accepted_at_utc","")).replace("Z","+00:00"))
    except Exception:
        fail("accepted_at_utc must be ISO-8601")

    a=rec.get("acknowledgements",{})
    required=[
      "commercial_terms","trading_risk","no_profit_guarantee","possible_total_loss",
      "ai_limitations","broker_third_party_risk","personal_responsibility","demo_first"
    ]
    for k in required:
        if a.get(k) is not True: fail(f"acknowledgement must be true: {k}")

    supplied=str(rec.get("record_sha256","")).lower()
    if len(supplied)!=64: fail("record_sha256 must be 64 lowercase hex characters")
    basis=dict(rec); basis.pop("record_sha256",None)
    raw=json.dumps(basis,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    digest=hashlib.sha256(raw).hexdigest()
    if supplied!=digest: fail("record_sha256 mismatch")

    print("CUSTOMER RISK ACKNOWLEDGEMENT: PASS")
    print("RECORD_SHA256="+digest)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
