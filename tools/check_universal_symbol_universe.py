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
require("SYMBOL_TRADE_MODE_DISABLED" in text, "disabled-symbol handling must be explicit")
require("SYMBOL_TRADE_MODE_CLOSEONLY" in text, "close-only handling must be explicit")
require("SymbolExist(sym,isCustom)" in text and "InpIncludeCustomSymbols" in text,
        "broker/server discovery must distinguish local custom symbols")
require("InpAnalyzeNonTradableSymbols" in text and "BrokerSymbolTradeableNow" in text,
        "analysis eligibility must be separated from live entry tradability")
require("InpRefreshBrokerUniverse" in text and "RefreshFullBrokerUniverseIfDue" in text,
        "full broker universe must refresh while the EA is running")
require("symbolTradeableNow && strategyActionOK" in text,
        "analysis-only symbols must remain blocked from entry authorization")
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
for token in (
    "InpRequireSynchronizedMarketData",
    "InpMinBarsD1","InpMinBarsH4","InpMinBarsH1","InpMinBarsM30","InpMinBarsM15","InpMinBarsM5",
    "SymbolAnalysisDataReady","TimeframeAnalysisDataReady","SERIES_SYNCHRONIZED",
    "TradeSetupGeometrySafe","DATA LOADING / INSUFFICIENT HISTORY",
):
    require(token in text, f"runtime data-readiness/geometry guard missing token: {token}")
scan_start=text.find("void ScanSymbol(")
scan_end=text.find("void ScanAll(",scan_start)
scan_body=text[scan_start:scan_end] if scan_start>=0 and scan_end>scan_start else ""
require(scan_body.find("SymbolAnalysisDataReady(sym,dataWhy)")>=0 and
        scan_body.find("SymbolAnalysisDataReady(sym,dataWhy)")<scan_body.find("MultiTFScore(sym"),
        "ScanSymbol must fail closed on synchronized market data before multi-timeframe analysis")
require(scan_body.find("TradeSetupGeometrySafe(primary,geometryWhy)")>=0 and
        scan_body.find("TradeSetupGeometrySafe(primary,geometryWhy)")<scan_body.find("EvaluateConfluence(primary)"),
        "ScanSymbol must reject invalid entry/SL/TP geometry before confluence/news/AI/risk work")
require('hi=0; lo=0;' in text and 'double localHi=-1.0e100,localLo=1.0e100;' in text,
        "AsianRange must contain sentinels locally and expose 0/N/A when unavailable")
require('daily/weekly available %s/%s' in text and 'daily/weekly available %.2f/%.2f' not in text,
        "adaptive risk UI must not render unlimited 1e100 budget sentinels as currency")
require("g_fullBrokerUniverseMode" in text and
        "Full broker universe uses live per-symbol execution validation." in text,
        "release/deployment safety must be dynamic-universe aware")
require("ReleaseSafetyAllows(s.symbol" in text,
        "per-symbol release safety must remain enforced before execution")
for token in (
    "InpAutoResolveBrokerSymbols?1:0",
    "InpUseMarketWatchUniverse?1:0",
    "InpMaxMarketWatchSymbols",
    "InpIncludeCloseOnlySymbols?1:0",
    "InpAnalyzeNonTradableSymbols?1:0",
    "InpIncludeCustomSymbols?1:0",
    "InpRefreshBrokerUniverse?1:0",
    "InpBrokerUniverseRefreshSeconds",
    "InpMaxBrokerUniverseSymbols",
    "InpUniversalScanBatchSize",
    "InpUniverseClockProbeSymbols",
    "InpAutoMajorUniverse);",
):
    require(token in text, f"universal config fingerprint missing: {token}")
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
    "US100","USTEC","NAS100","US30","US500","SPX500","US2000","GER40","DE40","DE30","JP225","HK50","AUS200","FRA40","EU50","STOXX50","DXY",
    "XAUUSD","XAGUSD","XPTUSD","XPDUSD","USOIL","UKOIL","NATGAS","XNGUSD","COPPER","COCOA","COFFEE","WHEAT","CORN",
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
