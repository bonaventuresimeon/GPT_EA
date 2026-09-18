#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path
from typing import Any
from release_contract import load_release_contract

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
RELEASE_ID=CONTRACT["release_validation_id"]
SCHEMA_VERSION=CONTRACT["soak_acceptance_schema"]
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")
ZERO_FIELDS=[
    "duplicate_orders","duplicate_partials","sl_regressions","unprotected_new_authorizations",
    "release_gate_bypasses","analytics_duplicate_finalizations","stop_failure_join_failures",
    "dashboard_gate_mismatches","runtime_critical_errors","secrets_exposed",
]

def canonical_digest(value:dict[str,Any])->str:
    basis=copy.deepcopy(value)
    basis.pop("record_digest",None)
    return hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def parse_date(value:str)->date|None:
    try: return date.fromisoformat(value)
    except Exception: return None

def next_weekday(d:date)->date:
    n=d+timedelta(days=1)
    while n.weekday()>=5: n+=timedelta(days=1)
    return n

def resolve_path(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def validate_day_checklist(day:dict[str,Any],index:int,git_sha:str)->list[str]:
    errors:list[str]=[]
    raw=str(day.get("reconciliation_checklist_path","")).strip()
    if not raw:
        return [f"days[{index}].reconciliation_checklist_path is required"]
    p=resolve_path(raw)
    if not p.exists():
        return [f"days[{index}] reconciliation checklist not found: {p}"]
    text=p.read_text(encoding="utf-8",errors="replace")
    if len(text.strip())<600:
        errors.append(f"days[{index}] reconciliation checklist is empty/too short")
    if "Decision: **ACCEPT DAY**" not in text:
        errors.append(f"days[{index}] reconciliation checklist must contain literal Decision: **ACCEPT DAY**")
    d=str(day.get("date","")).strip()
    if d and d not in text:
        errors.append(f"days[{index}] reconciliation checklist must contain date {d}")
    if git_sha and git_sha not in text:
        errors.append(f"days[{index}] reconciliation checklist must contain candidate Git SHA")
    return errors

def validate_record(record:dict[str,Any],require_digest:bool=True)->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,record.get("schema_version")==SCHEMA_VERSION,f"schema_version must be {SCHEMA_VERSION}")
    require(errors,record.get("release_validation_id")==RELEASE_ID,f"release_validation_id must be {RELEASE_ID}")
    require(errors,len(str(record.get("record_id","")).strip())>=8,"record_id must contain at least 8 characters")
    require(errors,len(str(record.get("evidence_id","")).strip())>=8,"evidence_id must contain at least 8 characters")

    candidate=record.get("candidate",{})
    git_sha=str(candidate.get("git_sha",""))
    ex5=str(candidate.get("ex5_sha256",""))
    set_hash=str(candidate.get("set_sha256",""))
    require(errors,bool(HEX40.fullmatch(git_sha)),"candidate.git_sha must be 40 hex characters")
    require(errors,bool(HEX64.fullmatch(ex5)),"candidate.ex5_sha256 must be 64 hex characters")
    require(errors,set_hash=="NONE" or bool(HEX64.fullmatch(set_hash)),"candidate.set_sha256 must be 64 hex characters or NONE")
    for key in ("broker_company","trade_server","account_currency","margin_mode","mt5_build","metaeditor_build"):
        require(errors,bool(str(candidate.get(key,"")).strip()),f"candidate.{key} is required")
    require(errors,str(candidate.get("account_mode","")).upper() in {"DEMO","CONTEST"},"candidate.account_mode must be DEMO or CONTEST")

    days=record.get("days")
    if not isinstance(days,list) or len(days)!=5:
        errors.append("days must contain exactly five accepted trading-day records")
        days=[]
    parsed:list[date]=[]
    checklist_paths:set[str]=set()
    count_fields=("scheduled_scans","continuous_scans","manual_scans","checkpoint_updates","backup_checkpoint_updates",
                  "restarts","reconnects","high_confidence_decisions","wait_reanalyze_decisions","no_trade_decisions")
    for i,day in enumerate(days,start=1):
        if not isinstance(day,dict):
            errors.append(f"days[{i}] must be an object"); continue
        d=parse_date(str(day.get("date","")))
        if d is None: errors.append(f"days[{i}].date must be YYYY-MM-DD")
        else: parsed.append(d)
        require(errors,day.get("fresh_quotes") is True,f"days[{i}].fresh_quotes must be true")
        for key in ("execution_log_present","stop_log_present","release_log_present"):
            require(errors,day.get(key) is True,f"days[{i}].{key} must be true")
        try: require(errors,int(day.get("zero_tolerance_failures",-1))==0,f"days[{i}].zero_tolerance_failures must be 0")
        except Exception: errors.append(f"days[{i}].zero_tolerance_failures must be an integer")
        try: require(errors,int(day.get("unresolved_critical_states_end",-1))==0,f"days[{i}].unresolved_critical_states_end must be 0")
        except Exception: errors.append(f"days[{i}].unresolved_critical_states_end must be an integer")
        for key in count_fields:
            try: require(errors,int(day.get(key,0))>=0,f"days[{i}].{key} must be >= 0")
            except Exception: errors.append(f"days[{i}].{key} must be an integer")
        require(errors,day.get("day_reconciled") is True,f"days[{i}].day_reconciled must be true")
        require(errors,len(str(day.get("reconciled_by","")).strip())>=2,f"days[{i}].reconciled_by is required")
        require(errors,len(str(day.get("reconciled_at","")).strip())>=8,f"days[{i}].reconciled_at is required")
        raw=str(day.get("reconciliation_checklist_path","")).strip()
        require(errors,bool(raw),f"days[{i}].reconciliation_checklist_path is required")
        if raw:
            if raw in checklist_paths: errors.append(f"days[{i}] reconciliation checklist path must be unique")
            checklist_paths.add(raw)
        errors.extend(validate_day_checklist(day,i,git_sha))

    if len(parsed)==5:
        if len(set(parsed))!=5 or parsed!=sorted(parsed):
            errors.append("day dates must be unique and increasing")
        for i in range(1,5):
            expected=next_weekday(parsed[i-1])
            if parsed[i]!=expected and not str(days[i].get("gap_justification","")).strip():
                errors.append(f"{parsed[i-1]} -> {parsed[i]} is not the next normal trading weekday; days[{i+1}].gap_justification is required")

    if days:
        require(errors,sum(1 for d in days if d.get("london_observed") is True)>=3,"at least 3 of the 5 days must observe London")
        require(errors,sum(1 for d in days if d.get("ny_observed") is True)>=3,"at least 3 of the 5 days must observe New York/U.S. cash")
        require(errors,any(d.get("overlap_observed") is True for d in days),"at least one day must observe London/New York overlap")
        require(errors,any(d.get("high_impact_news_observed") is True for d in days),"at least one day must observe relevant high-impact news")
        require(errors,any(d.get("rollover_spread_expansion_observed") is True for d in days),"at least one day must observe rollover spread expansion")
        for field,label in (("restarts","restart"),("reconnects","reconnect"),("scheduled_scans","scheduled scans"),
                            ("continuous_scans","continuous scans"),("manual_scans","manual SCAN NOW"),
                            ("checkpoint_updates","primary checkpoint updates"),("backup_checkpoint_updates","validated backup checkpoint updates")):
            require(errors,sum(int(d.get(field,0)) for d in days)>=1,f"five-day record must include {label}")

    reconciliation=record.get("reconciliation",{})
    for key in ZERO_FIELDS:
        try: require(errors,int(reconciliation.get(key,-1))==0,f"reconciliation.{key} must be 0")
        except Exception: errors.append(f"reconciliation.{key} must be an integer")

    lifecycle=record.get("lifecycle_checks",{})
    for key in ("stale_human_wait_closed","market_confirmation_wait_preserved","denial_timeout_terminal",
                "restart_reconstruction_passed","no_illegal_transition_accepted"):
        require(errors,lifecycle.get(key) is True,f"lifecycle_checks.{key} must be true")

    operator_record_path=str(record.get("operator_record_path","")).strip()
    require(errors,bool(operator_record_path),"operator_record_path is required")
    if operator_record_path:
        p=resolve_path(operator_record_path)
        require(errors,p.exists(),f"operator_record_path not found: {p}")
        if p.exists():
            text=p.read_text(encoding="utf-8",errors="replace")
            require(errors,len(text.strip())>=500,"operator_record_path is empty/too short")
            require(errors,"Decision: ACCEPT" in text,"operator record must contain literal Decision: ACCEPT")
            if git_sha: require(errors,git_sha in text,"operator record must contain candidate Git SHA")

    report_path=str(record.get("report_path","")).strip()
    require(errors,bool(report_path),"report_path is required")
    if report_path:
        p=resolve_path(report_path)
        require(errors,p.exists(),f"report_path not found: {p}")
        if p.exists(): require(errors,len(p.read_text(encoding="utf-8",errors="replace").strip())>=300,"report_path is empty/too short")

    operator=record.get("operator_review",{})
    require(errors,operator.get("decision")=="ACCEPT","operator_review.decision must be ACCEPT")
    require(errors,len(str(operator.get("reviewer","")).strip())>=2,"operator_review.reviewer is required")
    require(errors,len(str(operator.get("timestamp","")).strip())>=8,"operator_review.timestamp is required")

    digest=canonical_digest(record)
    stored=str(record.get("record_digest",""))
    if require_digest:
        require(errors,bool(HEX64.fullmatch(stored)),"record_digest must be a 64-character SHA-256 digest")
        if HEX64.fullmatch(stored):
            require(errors,stored.lower()==digest.lower(),f"record_digest mismatch: expected {digest}, found {stored}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 five-day demo-soak acceptance record v2")
    ap.add_argument("record",nargs="?",default="five-day-soak-acceptance.json")
    ap.add_argument("--finalize",action="store_true",help="write canonical record_digest after all other checks pass")
    args=ap.parse_args()
    path=resolve_path(args.record)
    if not path.exists():
        print(f"FIVE-DAY SOAK RECORD: FAILED\nERROR: record not found: {path}"); return 1
    record=json.loads(path.read_text(encoding="utf-8"))
    errors,digest=validate_record(record,require_digest=not args.finalize)
    if args.finalize and not errors:
        record["record_digest"]=digest
        path.write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
        errors,digest=validate_record(record,require_digest=True)
    out=ROOT/"five-day-soak-record-validation.txt"
    if errors:
        text="FIVE-DAY SOAK RECORD: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nRECORD_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"FIVE-DAY SOAK RECORD: PASS\nSCHEMA: {SCHEMA_VERSION}\nRECORD_ID: {record['record_id']}\nRECORD_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
