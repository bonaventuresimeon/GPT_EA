#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "GPT_EA.mq5"

text = MAIN.read_text(encoding="utf-8", errors="strict")
errors: list[str] = []

def require(cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)

require(bool(re.search(r'input\s+string\s+InpSymbols\s*=\s*"ALL"', text)),
        'InpSymbols must default to "ALL" for full broker-universe discovery')
require(bool(re.search(r'InpMaxBrokerUniverseSymbols\s*=\s*0\s*;', text)),
        "full broker universe must be unlimited by default (cap=0)")
require("SymbolsTotal(false)" in text, "broker-universe discovery must enumerate the complete symbol catalog")
require("SymbolName(i,false)" in text, "broker-universe discovery must read symbols outside Market Watch")
require("BrokerSymbolEligibleForUniverse" in text, "universal eligibility filter is missing")
require("SYMBOL_TRADE_MODE_DISABLED" in text, "disabled symbols must be filtered")
require("SYMBOL_TRADE_MODE_CLOSEONLY" in text, "close-only handling must be explicit")
require("DiscoverFullBrokerUniverse" in text, "full broker-universe discovery function is missing")
require('u=="ALL"' in text and 'u=="BROKER"' in text and 'u=="UNIVERSE"' in text,
        "ALL/BROKER/UNIVERSE aliases must activate full discovery")
require("InpUniversalScanBatchSize" in text and "g_universalScanCursor" in text,
        "round-robin scan batching is missing")
require(bool(re.search(r'int\s+batch\s*=\s*\(InpUniversalScanBatchSize<=0\?total:MathMin\(total,InpUniversalScanBatchSize\)\)', text)),
        "ScanAll must bound full-universe work by InpUniversalScanBatchSize")
require("InpUniverseClockProbeSymbols" in text,
        "continuous M5 scheduling must use bounded universe probes")
require("g_fullBrokerUniverseMode" in text and
        "Full broker universe uses live per-symbol execution validation." in text,
        "release/deployment safety must be dynamic-universe aware")
require("ReleaseSafetyAllows(s.symbol" in text,
        "per-symbol release safety must remain enforced before execution")
require("|universe=%d:%d:%d:%d:%d:%d:%d:%s" in text and
        "InpAutoMajorUniverse);" in text,
        "universal symbol controls must be bound into the configuration fingerprint")
require('return "GEN:"+c;' in text,
        "unknown but tradeable broker symbols must remain generically analyzable")

for token in (
    "US100","US30","US500","GER40","JP225",
    "XAUUSD","XAGUSD","USOIL","UKOIL","NATGAS",
    "BTCUSD","ETHUSD","SOLUSD","XRPUSD","LTCUSD","UNIUSD","BNBUSD",
    "EURUSD","GBPUSD","GBPCAD","USDJPY",
):
    require(token in text, f"expected common broker alias missing from universal/major recognition: {token}")

for category in ("CRYPTO:", "ENERGY:", "INDEX:", "STOCK:", "ETF:", "FUTURE:", "FX:"):
    require(category in text, f"canonical asset recognition missing category {category}")

if errors:
    print("UNIVERSAL SYMBOL UNIVERSE CHECK: FAILED")
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)

print("UNIVERSAL SYMBOL UNIVERSE CHECK: PASS")
print("Default universe: ALL tradeable broker symbols")
print("Scan mode: bounded round-robin full-intelligence batches")
