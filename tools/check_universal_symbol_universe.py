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
require(bool(re.search(r'InpMaxMarketWatchSymbols\s*=\s*0\s*;', text)),
        "Market Watch supplementation must be unlimited when cap=0")
require("SymbolsTotal(false)" in text, "broker-universe discovery must enumerate the complete symbol catalog")
require("SymbolName(i,false)" in text, "broker-universe discovery must read symbols outside Market Watch")
require("SymbolsTotal(true)" in text and "SymbolName(i,true)" in text,
        "optional Market Watch supplementation is missing")
require("BrokerSymbolEligibleForUniverse" in text, "universal eligibility filter is missing")
require('if(!(bool)SymbolInfoInteger(sym,SYMBOL_SELECT)) return true;' in text,
        "full-catalog discovery must defer entry-eligibility checks until unselected symbols are selected")
require("if(!BrokerSymbolEligibleForUniverse(sym))" in text,
        "ScanSymbol must recheck exact broker eligibility after EnsureSymbol selects the instrument")
require("SYMBOL_TRADE_MODE_DISABLED" in text, "disabled symbols must be filtered")
require("SYMBOL_TRADE_MODE_CLOSEONLY" in text, "close-only handling must be explicit")
require("SYMBOL_CALC_MODE_SERV_COLLATERAL" in text,
        "non-executable service-collateral symbols must be excluded")
require("DiscoverFullBrokerUniverse" in text, "full broker-universe discovery function is missing")
require('u=="ALL"' in text and 'u=="BROKER"' in text and 'u=="UNIVERSE"' in text,
        "ALL/BROKER/UNIVERSE aliases must activate full discovery")
require("InpUniversalScanBatchSize" in text and "g_universalScanCursor" in text,
        "round-robin scan batching is missing")
require(bool(re.search(r'int\s+batch\s*=\s*\(InpUniversalScanBatchSize<=0\?total:MathMin\(total,InpUniversalScanBatchSize\)\)\s*;', text)),
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
require("CleanCryptoPairContains" in text,
        "crypto classification must require token/quote structure rather than arbitrary ticker substrings")
require("Strong broker-native product identity comes first" in text,
        "stock/ETF/future/bond product identity must outrank descriptive underlying aliases")

# Broker-native classification must combine names/metadata with MT5 contract metadata.
for token in (
    "SYMBOL_TRADE_CALC_MODE",
    "SYMBOL_CURRENCY_BASE",
    "SYMBOL_CURRENCY_PROFIT",
    "SYMBOL_CURRENCY_MARGIN",
    "SYMBOL_CALC_MODE_FOREX",
    "SYMBOL_CALC_MODE_CFDINDEX",
    "SYMBOL_CALC_MODE_EXCH_STOCKS",
    "SYMBOL_CALC_MODE_FUTURES",
    "SYMBOL_CALC_MODE_EXCH_FUTURES",
    "SYMBOL_CALC_MODE_EXCH_BONDS",
):
    require(token in text, f"broker-native classification metadata missing: {token}")

for token in (
    "US100","US30","US500","US2000","GER40","JP225","HK50","AUS200","FRA40","EU50",
    "XAUUSD","XAGUSD","USOIL","UKOIL","NATGAS","COPPER","COCOA","COFFEE","WHEAT","CORN",
    "BTCUSD","ETHUSD","SOLUSD","XRPUSD","LTCUSD","UNIUSD","BNBUSD",
    "EURUSD","GBPUSD","GBPCAD","USDJPY",
):
    require(token in text, f"expected common broker alias missing from universal/major recognition: {token}")

for category in (
    "CRYPTO:", "ENERGY:", "INDEX:", "METAL:", "COMMODITY:",
    "STOCK:", "ETF:", "FUTURE:", "BOND_RATE:", "FX:"
):
    require(category in text, f"canonical asset recognition missing category {category}")

# Economic-calendar mapping must use broker currencies and regional/global macro fallbacks.
require("AddCalendarCurrencyIfKnown" in text,
        "economic-calendar currency normalization helper is missing")
for token in ("SYMBOL_CURRENCY_BASE", "SYMBOL_CURRENCY_PROFIT", "SYMBOL_CURRENCY_MARGIN"):
    require(token in text, f"economic-calendar mapping must consume {token}")
for token in ("US2000", "GER40", "UK100", "JP225", "HK50", "AUS200", "CH20", "TREASURY", "BUND", "GILT"):
    require(token in text, f"regional macro mapping missing alias: {token}")

if errors:
    print("UNIVERSAL SYMBOL UNIVERSE CHECK: FAILED")
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)

print("UNIVERSAL SYMBOL UNIVERSE CHECK: PASS")
print("Default universe: ALL executable broker symbols")
print("Asset classes: FX / METAL / INDEX / ENERGY / COMMODITY / CRYPTO / STOCK / ETF / FUTURE / BOND_RATE / OTHER")
print("Scan mode: bounded round-robin full-intelligence batches")
print("Macro mapping: broker currencies + regional/global event fallbacks")
