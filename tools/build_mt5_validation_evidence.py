#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TEMPLATE=ROOT/"MT5_VALIDATION_EVIDENCE_TEMPLATE.json"

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def set_file(data:dict,section:str,path_key:str,hash_key:str,value:str)->None:
    p=resolve(value)
    if not p.exists(): raise FileNotFoundError(p)
    data[section][path_key]=str(p.relative_to(ROOT)).replace("\\","/") if p.is_relative_to(ROOT) else str(p)
    data[section][hash_key]=sha256_file(p)

def main()->int:
    ap=argparse.ArgumentParser(description="Build a draft GPT_EA MT5 validation evidence v2 record and hash retained artifacts")
    ap.add_argument("--git-sha",required=True)
    ap.add_argument("--ex5-sha256",required=True)
    ap.add_argument("--set-sha256",default="NONE")
    ap.add_argument("--metaeditor-build",required=True)
    ap.add_argument("--mt5-build",required=True)
    ap.add_argument("--broker-company",required=True)
    ap.add_argument("--trade-server",required=True)
    ap.add_argument("--account-mode",choices=["DEMO","CONTEST"],default="DEMO")
    ap.add_argument("--account-currency",required=True)
    ap.add_argument("--margin-mode",required=True)
    ap.add_argument("--compile-log",required=True)
    ap.add_argument("--tester-report",required=True)
    ap.add_argument("--experts-log",required=True)
    ap.add_argument("--journal-log",required=True)
    ap.add_argument("--broker-history",required=True)
    ap.add_argument("--matrix-bundle",required=True)
    ap.add_argument("--intent-ledger",required=True)
    ap.add_argument("--reconciliation",required=True)
    ap.add_argument("--web-provenance",required=True)
    ap.add_argument("--model-health",required=True)
    ap.add_argument("--resilience-runtime-report",required=True)
    ap.add_argument("--output",default="artifacts/mt5-validation-evidence.json")
    args=ap.parse_args()

    data=json.loads(TEMPLATE.read_text(encoding="utf-8"))
    data["evidence_id"]="mt5-validation-"+args.git_sha[:12]
    data["candidate"]={"git_sha":args.git_sha,"ex5_sha256":args.ex5_sha256,"set_sha256":args.set_sha256}
    data["environment"].update({
        "metaeditor_build":args.metaeditor_build,"mt5_build":args.mt5_build,"broker_company":args.broker_company,
        "trade_server":args.trade_server,"account_mode":args.account_mode,"account_currency":args.account_currency,
        "margin_mode":args.margin_mode,
    })
    set_file(data,"compile","compile_log_path","compile_log_sha256",args.compile_log)
    set_file(data,"strategy_tester","report_path","report_sha256",args.tester_report)
    set_file(data,"artifacts","experts_log_path","experts_log_sha256",args.experts_log)
    set_file(data,"artifacts","journal_log_path","journal_log_sha256",args.journal_log)
    set_file(data,"artifacts","broker_history_path","broker_history_sha256",args.broker_history)
    set_file(data,"artifacts","matrix_bundle_path","matrix_bundle_sha256",args.matrix_bundle)
    set_file(data,"artifacts","intent_ledger_path","intent_ledger_sha256",args.intent_ledger)
    set_file(data,"artifacts","reconciliation_path","reconciliation_sha256",args.reconciliation)
    set_file(data,"artifacts","web_provenance_path","web_provenance_sha256",args.web_provenance)
    set_file(data,"artifacts","model_health_path","model_health_sha256",args.model_health)
    set_file(data,"artifacts","resilience_runtime_report_path","resilience_runtime_report_sha256",args.resilience_runtime_report)

    out=resolve(args.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    print("MT5 VALIDATION EVIDENCE DRAFT: CREATED")
    print(f"OUTPUT={out}")
    print("Complete only PASS fields supported by actual MT5/MetaEditor evidence, then run the validator with --finalize.")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
