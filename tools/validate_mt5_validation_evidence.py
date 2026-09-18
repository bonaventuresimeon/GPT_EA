#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from datetime import date
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[1]
RELEASE_ID="GPT_EA_FULL_INTELLIGENCE_R6_20260917"
SCHEMA_VERSION="mt5_validation_evidence_v2"
MATRIX_LAST_ID=53  # acceptance contract ends at M5-053
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

TRUE_FIELDS={
    "compile":("passed","load_smoke_passed","symbols_resolved_or_safely_rejected","timer_started","dashboard_initialized","release_blocked_before_attestation","no_order_on_attach"),
    "strategy_tester":("passed","no_runtime_critical_errors","no_duplicate_orders","no_duplicate_partials","no_sl_regressions","no_unprotected_authorizations"),
    "broker_runtime":("broker_matrix_passed","symbol_profiles_archived","stops_freeze_geometry_verified","tick_value_size_verified","volume_geometry_verified","filling_order_modes_verified","margin_lot_normalization_verified","restart_reconstruction_passed","reconnect_reconstruction_passed","primary_checkpoint_passed","backup_checkpoint_passed","no_duplicate_after_recovery"),
    "protection":("stop_matrix_passed","broker_stop_policy_passed","partial_protection_passed","stop_observability_passed","buy_lifecycle_passed","sell_lifecycle_passed","zero_unprotected_end_states"),
    "live_api_news":("webrequest_allow_list_verified","deep_review_path_passed","web_search_path_passed","failure_injection_passed","recovery_after_failure_passed","request_trace_observed","required_failure_fail_closed"),
    "resilience_runtime":(
        "direct_breakout_separation_passed","atomic_intent_ordering_passed","exactly_once_restart_passed",
        "ambiguous_submit_reconciliation_passed","broker_reconciliation_passed","manual_intervention_detection_passed",
        "storage_failure_fail_closed","config_drift_fail_closed","clock_drift_passed","chaos_real_account_refusal_passed",
        "chaos_fault_matrix_passed","macro_scenario_stress_passed","gap_risk_passed","margin_stress_passed",
        "decision_half_life_passed","model_degradation_fallback_passed","news_provenance_timestamp_passed",
        "learning_quarantine_passed","promotion_rollback_passed"
    ),
}

def canonical_digest(value:dict[str,Any])->str:
    basis=copy.deepcopy(value)
    basis.pop("evidence_digest",None)
    return hashlib.sha256(json.dumps(basis,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def require(errors:list[str],cond:bool,msg:str)->None:
    if not cond: errors.append(msg)

def check_hashed_file(errors:list[str],obj:dict[str,Any],path_key:str,hash_key:str,label:str)->None:
    raw=str(obj.get(path_key,"")).strip()
    expected=str(obj.get(hash_key,""))
    require(errors,bool(raw),f"{label} path is required")
    require(errors,bool(HEX64.fullmatch(expected)),f"{label} SHA-256 is invalid")
    if raw:
        p=resolve(raw)
        require(errors,p.exists(),f"{label} file not found: {p}")
        if p.exists() and HEX64.fullmatch(expected):
            actual=sha256_file(p)
            require(errors,actual.lower()==expected.lower(),f"{label} SHA-256 mismatch: expected {expected}, actual {actual}")

def parse_date(value:str)->date|None:
    try: return date.fromisoformat(value[:10])
    except Exception: return None

def validate_matrix_bundle(path:Path)->list[str]:
    errors:list[str]=[]
    text=path.read_text(encoding="utf-8",errors="replace")
    lines=text.splitlines()
    for n in range(1,MATRIX_LAST_ID+1):
        mid=f"M5-{n:03d}"
        matches=[line for line in lines if f"| {mid} |" in line]
        if len(matches)!=1:
            errors.append(f"MT5 matrix must contain exactly one row for {mid}")
            continue
        cells=[c.strip() for c in matches[0].split("|")]
        if len(cells)<7:
            errors.append(f"MT5 matrix row {mid} is malformed")
            continue
        status=cells[4]
        evidence=cells[5]
        if status!="PASS": errors.append(f"MT5 matrix {mid} status must be PASS")
        if not evidence: errors.append(f"MT5 matrix {mid} evidence/reference is required")
    return errors

def validate_mt5(data:dict[str,Any],require_digest:bool=True,expected_sha:str="",expected_ex5:str="",expected_set:str="")->tuple[list[str],str]:
    errors:list[str]=[]
    require(errors,data.get("schema_version")==SCHEMA_VERSION,f"schema_version must be {SCHEMA_VERSION}")
    require(errors,data.get("release_validation_id")==RELEASE_ID,f"release_validation_id must be {RELEASE_ID}")
    require(errors,len(str(data.get("evidence_id","")).strip())>=8,"evidence_id must contain at least 8 characters")

    candidate=data.get("candidate",{})
    git_sha=str(candidate.get("git_sha","")); ex5=str(candidate.get("ex5_sha256","")); set_hash=str(candidate.get("set_sha256",""))
    require(errors,bool(HEX40.fullmatch(git_sha)),"candidate.git_sha must be 40 hex characters")
    require(errors,bool(HEX64.fullmatch(ex5)),"candidate.ex5_sha256 must be SHA-256")
    require(errors,set_hash=="NONE" or bool(HEX64.fullmatch(set_hash)),"candidate.set_sha256 must be SHA-256 or NONE")
    if expected_sha: require(errors,git_sha.lower()==expected_sha.lower(),"candidate.git_sha does not match release build")
    if expected_ex5: require(errors,ex5.lower()==expected_ex5.lower(),"candidate.ex5_sha256 does not match release build")
    if expected_set: require(errors,set_hash.lower()==expected_set.lower(),"candidate.set_sha256 does not match release build")

    env=data.get("environment",{})
    for key in ("metaeditor_build","mt5_build","broker_company","trade_server","account_currency","margin_mode"):
        require(errors,bool(str(env.get(key,"")).strip()),f"environment.{key} is required")
    require(errors,str(env.get("account_mode","")).upper() in {"DEMO","CONTEST"},"environment.account_mode must be DEMO or CONTEST")

    for section,fields in TRUE_FIELDS.items():
        obj=data.get(section,{})
        require(errors,isinstance(obj,dict),f"{section} must be an object")
        if isinstance(obj,dict):
            for key in fields: require(errors,obj.get(key) is True,f"{section}.{key} must be true")

    compile_obj=data.get("compile",{})
    try: require(errors,int(compile_obj.get("errors",-1))==0,"compile.errors must be 0")
    except Exception: errors.append("compile.errors must be an integer")
    try: require(errors,int(compile_obj.get("warnings",-1))==0,"compile.warnings must be 0")
    except Exception: errors.append("compile.warnings must be an integer")
    try: require(errors,int(compile_obj.get("init_error_count",-1))==0,"compile.init_error_count must be 0")
    except Exception: errors.append("compile.init_error_count must be an integer")
    check_hashed_file(errors,compile_obj,"compile_log_path","compile_log_sha256","compile log")

    tester=data.get("strategy_tester",{})
    check_hashed_file(errors,tester,"report_path","report_sha256","Strategy Tester report")
    require(errors,bool(str(tester.get("model","")).strip()),"strategy_tester.model is required")
    d1=parse_date(str(tester.get("date_from",""))); d2=parse_date(str(tester.get("date_to","")))
    require(errors,d1 is not None,"strategy_tester.date_from must contain an ISO date")
    require(errors,d2 is not None,"strategy_tester.date_to must contain an ISO date")
    if d1 and d2: require(errors,d2>=d1,"strategy_tester.date_to must not precede date_from")
    require(errors,isinstance(tester.get("symbols"),list) and len(tester.get("symbols",[]))>=1,"strategy_tester.symbols must contain at least one symbol")
    try: require(errors,int(tester.get("completed_runs",0))>=1,"strategy_tester.completed_runs must be >= 1")
    except Exception: errors.append("strategy_tester.completed_runs must be an integer")

    live=data.get("live_api_news",{})
    try: require(errors,int(live.get("secret_leak_count",-1))==0,"live_api_news.secret_leak_count must be 0")
    except Exception: errors.append("live_api_news.secret_leak_count must be an integer")

    artifacts=data.get("artifacts",{})
    for pk,hk,label in (
        ("experts_log_path","experts_log_sha256","Experts log"),
        ("journal_log_path","journal_log_sha256","Journal log"),
        ("broker_history_path","broker_history_sha256","broker history"),
        ("matrix_bundle_path","matrix_bundle_sha256","MT5 matrix bundle"),
        ("intent_ledger_path","intent_ledger_sha256","atomic intent ledger"),
        ("reconciliation_path","reconciliation_sha256","broker/EA reconciliation journal"),
        ("web_provenance_path","web_provenance_sha256","web intelligence provenance journal"),
        ("model_health_path","model_health_sha256","model health journal"),
        ("resilience_runtime_report_path","resilience_runtime_report_sha256","MT5 resilience runtime report"),
    ):
        check_hashed_file(errors,artifacts,pk,hk,label)

    matrix_raw=str(artifacts.get("matrix_bundle_path","")).strip()
    if matrix_raw:
        matrix_path=resolve(matrix_raw)
        if matrix_path.exists():
            errors.extend(validate_matrix_bundle(matrix_path))

    runtime_raw=str(artifacts.get("resilience_runtime_report_path","")).strip()
    if runtime_raw:
        runtime_path=resolve(runtime_raw)
        if runtime_path.exists():
            runtime_text=runtime_path.read_text(encoding="utf-8",errors="replace")
            for marker in (
                "MT5 RESILIENCE RUNTIME: PASS",
                "DUPLICATE_ORDER_COUNT=0",
                "UNRESOLVED_INTENT_COUNT=0",
                "UNRECONCILED_POSITION_COUNT=0",
                "CHAOS_REAL_ACCOUNT_REFUSAL=PASS",
                "MACRO_STRESS_MATRIX=PASS",
                "PROVENANCE_FRESHNESS=PASS",
                "STORAGE_FAILURE_FAIL_CLOSED=PASS",
                "CONFIG_DRIFT_FAIL_CLOSED=PASS",
                "DETERMINISTIC_FALLBACK_BOUNDARY=PASS",
            ):
                require(errors,marker in runtime_text,f"resilience runtime report missing marker: {marker}")

    operator=data.get("operator_review",{})
    require(errors,operator.get("decision")=="ACCEPT","operator_review.decision must be ACCEPT")
    require(errors,len(str(operator.get("reviewer","")).strip())>=2,"operator_review.reviewer is required")
    require(errors,len(str(operator.get("timestamp","")).strip())>=8,"operator_review.timestamp is required")

    digest=canonical_digest(data)
    stored=str(data.get("evidence_digest",""))
    if require_digest:
        require(errors,bool(HEX64.fullmatch(stored)),"evidence_digest must be SHA-256")
        if HEX64.fullmatch(stored): require(errors,stored.lower()==digest.lower(),f"evidence_digest mismatch: expected {digest}")
    return errors,digest

def main()->int:
    ap=argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 MT5 validation evidence v2")
    ap.add_argument("evidence",nargs="?",default="artifacts/mt5-validation-evidence.json")
    ap.add_argument("--expected-sha",default="")
    ap.add_argument("--expected-ex5",default="")
    ap.add_argument("--expected-set",default="")
    ap.add_argument("--finalize",action="store_true")
    args=ap.parse_args()
    p=resolve(args.evidence)
    if not p.exists():
        print(f"MT5 VALIDATION EVIDENCE: FAILED\nERROR: file not found: {p}"); return 1
    data=json.loads(p.read_text(encoding="utf-8"))
    errors,digest=validate_mt5(data,not args.finalize,args.expected_sha,args.expected_ex5,args.expected_set)
    if args.finalize and not errors:
        data["evidence_digest"]=digest
        p.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        errors,digest=validate_mt5(data,True,args.expected_sha,args.expected_ex5,args.expected_set)
    out=ROOT/"mt5-validation-evidence-validation.txt"
    if errors:
        text="MT5 VALIDATION EVIDENCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nMT5_EVIDENCE_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"MT5 VALIDATION EVIDENCE: PASS\nEVIDENCE_ID: {data['evidence_id']}\nMT5_EVIDENCE_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())
