#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from datetime import datetime
from pathlib import Path
from typing import Any

from validate_five_day_soak_record import validate_record
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT=Path(__file__).resolve().parents[1]
SCHEMA_PATH=ROOT/"SOAK_EVIDENCE_SCHEMA.json"

def canonical_digest(value:Any)->str:
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def parse_time(value:str)->datetime|None:
    try: return datetime.fromisoformat(value.replace("Z","+00:00"))
    except Exception: return None

def resolve_path(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def validate_subset_schema(value:dict[str,Any],schema:dict[str,Any])->list[str]:
    errors:list[str]=[]
    required=schema.get("required",[]); props=schema.get("properties",{})
    for key in required:
        if key not in value: errors.append(f"demo_soak missing required field: {key}")
    if schema.get("additionalProperties") is False:
        unknown=sorted(set(value)-set(props)-{"evidence_digest"})
        if unknown: errors.append("demo_soak contains unknown field(s): "+", ".join(unknown))
    for key,rules in props.items():
        if key not in value: continue
        item=value[key]
        if "const" in rules and item!=rules["const"]: errors.append(f"demo_soak.{key} must equal {rules['const']!r}")
        typ=rules.get("type")
        if typ=="string" and not isinstance(item,str): errors.append(f"demo_soak.{key} must be a string")
        elif typ=="integer" and (not isinstance(item,int) or isinstance(item,bool)): errors.append(f"demo_soak.{key} must be an integer")
        if isinstance(item,str) and "minLength" in rules and len(item)<int(rules["minLength"]): errors.append(f"demo_soak.{key} must contain at least {rules['minLength']} characters")
        if isinstance(item,int) and not isinstance(item,bool) and "minimum" in rules and item<int(rules["minimum"]): errors.append(f"demo_soak.{key} must be >= {rules['minimum']}")
    return errors

def validate_soak(soak:dict[str,Any],schema:dict[str,Any])->tuple[list[str],str]:
    errors=validate_subset_schema(soak,schema)
    start=parse_time(str(soak.get("start",""))); end=parse_time(str(soak.get("end","")))
    if start is None: errors.append("demo_soak.start must be an ISO-8601 timestamp")
    if end is None: errors.append("demo_soak.end must be an ISO-8601 timestamp")
    if start is not None and end is not None:
        try:
            if end<=start: errors.append("demo_soak.end must be later than demo_soak.start")
        except TypeError: errors.append("demo_soak.start and demo_soak.end must use compatible timezone forms")

    report=str(soak.get("report_path","")).strip()
    if report and not resolve_path(report).exists(): errors.append(f"demo soak report not found: {resolve_path(report)}")

    record_raw=str(soak.get("acceptance_record_path","")).strip()
    if not record_raw: errors.append("demo_soak.acceptance_record_path is required")
    else:
        p=resolve_path(record_raw)
        if not p.exists(): errors.append(f"five-day soak acceptance record not found: {p}")
        else:
            try:
                record=json.loads(p.read_text(encoding="utf-8"))
                record_errors,record_digest=validate_record(record,require_digest=True)
                errors.extend(f"five-day record: {e}" for e in record_errors)
                if str(record.get("schema_version",""))!=str(soak.get("acceptance_record_schema_version","")):
                    errors.append("demo_soak.acceptance_record_schema_version does not match five-day record.schema_version")
                if str(record.get("record_id",""))!=str(soak.get("acceptance_record_id","")):
                    errors.append("demo_soak.acceptance_record_id does not match five-day record.record_id")
                if str(record.get("evidence_id",""))!=str(soak.get("evidence_id","")):
                    errors.append("five-day record.evidence_id does not match demo_soak.evidence_id")
                if record_digest.lower()!=str(soak.get("acceptance_record_digest","")).lower():
                    errors.append("demo_soak.acceptance_record_digest does not match five-day record digest")
            except Exception as exc: errors.append(f"could not validate five-day soak acceptance record: {exc}")

    basis=copy.deepcopy(soak); stored=str(basis.pop("evidence_digest","")); digest=canonical_digest(basis)
    if len(stored)!=64 or any(c not in "0123456789abcdefABCDEF" for c in stored):
        errors.append("demo_soak.evidence_digest must be a 64-character SHA-256 digest")
    elif stored.lower()!=digest.lower(): errors.append(f"demo_soak.evidence_digest mismatch: expected {digest}, found {stored}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA demo-soak evidence against the versioned schema and five-day acceptance record")
    ap.add_argument("evidence",nargs="?",default="release_evidence.json")
    args=ap.parse_args()
    p=Path(args.evidence)
    if not p.is_absolute(): p=ROOT/p
    if not p.exists():
        print(f"SOAK EVIDENCE SCHEMA CHECK: FAILED\nERROR: evidence file not found: {p}"); return 1
    schema=json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    data=json.loads(p.read_text(encoding="utf-8"))
    soak=data.get("demo_soak")
    if not isinstance(soak,dict):
        print("SOAK EVIDENCE SCHEMA CHECK: FAILED\nERROR: demo_soak must be an object"); return 1
    errors,digest=validate_soak(soak,schema)
    out=ROOT/"soak-evidence-validation.txt"
    if errors:
        text="SOAK EVIDENCE SCHEMA CHECK: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nSOAK_EVIDENCE_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"SOAK EVIDENCE SCHEMA CHECK: PASS\nSCHEMA_VERSION: {soak['schema_version']}\nACCEPTANCE_SCHEMA: {soak['acceptance_record_schema_version']}\nACCEPTANCE_RECORD_ID: {soak['acceptance_record_id']}\nSOAK_EVIDENCE_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
