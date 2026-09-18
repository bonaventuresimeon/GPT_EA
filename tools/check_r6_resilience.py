#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
errors:list[str]=[]

def read(name:str)->str:
    p=ROOT/name
    if not p.exists():
        errors.append(f"missing R6 resilience artifact: {name}")
        return ""
    return p.read_text(encoding="utf-8")

required=[
    "GPT_EA.mq5","GPT_EA_Part01.mqh","GPT_EA_Part05.mqh","GPT_EA_Part10_BrokerUniversalRecovery.mqh",
    "GPT_EA_Part15_StrategyIntelligence.mqh","GPT_EA_Part22_IntelligenceFreshness.mqh",
    "GPT_EA_Part27_StrategyCompletion.mqh","GPT_EA_Part28B_CIReleaseEvidence.mqh",
    "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh","GPT_EA_Part31B_ExecutionFinalizer.mqh",
    "GPT_EA_Part32_ChampionChallenger.mqh","GPT_EA_Part35_AdaptiveIntegration.mqh",
    "GPT_EA_Part37_APITransport.mqh","GPT_EA_Part39_DataIntegrityQuarantine.mqh",
    "GPT_EA_Part40_ModelClockTrust.mqh","GPT_EA_Part41_PortfolioStressLatency.mqh",
    "GPT_EA_Part42_ExecutionReliability.mqh","GPT_EA_Part43_CausalAttribution.mqh",
    "GPT_EA_Part44_ChaosFaultInjection.mqh","R6_RESILIENCE_HARDENING_TEST_MATRIX.md",
    "RESILIENCE_HARDENING_EVIDENCE_SCHEMA.json","RESILIENCE_HARDENING_EVIDENCE_TEMPLATE.json",
    "MT5_VALIDATION_EVIDENCE_SCHEMA.json","MT5_VALIDATION_EVIDENCE_TEMPLATE.json",
    "MT5_VALIDATION_ACCEPTANCE_MATRIX.md","CHAOS_FAULT_INJECTION_TEST_MATRIX.md",
    "MT5_RESILIENCE_RUNTIME_REPORT_TEMPLATE.md","ROLLBACK_PACKAGE_CONTRACT.md",
    "ROLLBACK_PACKAGE_MANIFEST_SCHEMA.json","tools/validate_resilience_hardening_evidence.py",
    "tools/validate_rollback_readiness.py","tools/build_release_rollback_package.py",
    "tools/validate_release_rollback_package.py",
]
for name in required:
    read(name)

main=read("GPT_EA.mq5")
main_tokens=[
    '#include "GPT_EA_Part44_ChaosFaultInjection.mqh"',
    '#include "GPT_EA_Part40_ModelClockTrust.mqh"',
    '#include "GPT_EA_Part41_PortfolioStressLatency.mqh"',
    '#include "GPT_EA_Part39_DataIntegrityQuarantine.mqh"',
    '#include "GPT_EA_Part42_ExecutionReliability.mqh"',
    '#include "GPT_EA_Part43_CausalAttribution.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR10Privacy',
]
for t in main_tokens:
    if t not in main: errors.append(f"main missing resilience wiring: {t}")

def require_tokens(name:str,tokens:list[str])->None:
    text=read(name)
    for t in tokens:
        if t not in text: errors.append(f"{name} missing resilience token: {t}")

require_tokens("GPT_EA_Part01.mqh",["SETUP_PULLBACK=1","SETUP_BREAKOUT_RETEST=2","SETUP_BREAKOUT=3"])
require_tokens("GPT_EA_Part27_StrategyCompletion.mqh",["InitSetup(s,x.symbol,SETUP_BREAKOUT,bull)","BuildDirectBreakoutCandidate"])
require_tokens("GPT_EA_Part15_StrategyIntelligence.mqh",["s.kind!=SETUP_BREAKOUT","s.kind!=SETUP_BREAKOUT_RETEST"])
require_tokens("GPT_EA_Part05.mqh",[
    "ExecutionReliabilityPreEntryAllows","PrepareAtomicTradeIntent","MarkTradeIntentSent",
    "MarkTradeIntentUncertain","TradeIntentComment","BindTradeIntentToPosition","ChaosInjectBeforeOrderSend",
    "ChaosInjectPostFillPreBind",
])
require_tokens("GPT_EA_Part10_BrokerUniversalRecovery.mqh",["ChaosInjectCorruptCheckpoint","RECOVERY_CHECKPOINT_ANOMALY"])
require_tokens("GPT_EA_Part22_IntelligenceFreshness.mqh",[
    "ExtractResponseAnnotationURLs","WebIntelAsOfFresh","PROVENANCE_HARD_FAIL","RESPONSE_URL_ANNOTATIONS",
])
require_tokens("GPT_EA_Part30_AdaptiveRiskPortfolio.mqh",[
    "ModelClockExecutionAllows","PortfolioStressLatencyAllows","ModelTrustRiskMultiplier",
])
require_tokens("GPT_EA_Part31B_ExecutionFinalizer.mqh",["LearningSampleShouldQuarantine","MarkLearningQuarantine","QUARANTINED"])
require_tokens("GPT_EA_Part32_ChampionChallenger.mqh",[
    "ChallengerSignificanceAllows","PromotionProbationShouldRollback","EvaluateChampionRollback",
    "InpUsePromotionSignificance","InpUsePromotionProbationRollback",
])
require_tokens("GPT_EA_Part35_AdaptiveIntegration.mqh",[
    "ModelClockTrustInit","DataIntegrityInit","ExecutionReliabilityInit","CausalAttributionInit",
    "ModelClockTrustTimer","ExecutionReliabilityTimer","CausalAttributionTimer",
])
require_tokens("GPT_EA_Part37_APITransport.mqh",["ChaosInjectAPITimeout","MODEL_REQ","MODEL_FAIL","MODEL_LATENCY_EWMA_MS"])
require_tokens("GPT_EA_Part39_DataIntegrityQuarantine.mqh",[
    "CurrentConfigFingerprint","SymbolContractFingerprint","StrategyConfigVersion","WriteStrategyConfigRegistry",
    "LearningSampleShouldQuarantine","GPT_EA_QuarantinedLearning.csv",
])
require_tokens("GPT_EA_Part40_ModelClockTrust.mqh",[
    "ClockDriftAllows","MODEL_TRUST_NORMAL","MODEL_TRUST_REDUCED","MODEL_TRUST_DETERMINISTIC_ONLY",
    "DeterministicEmergencyStrategyAllowed","GPT_EA_ModelHealth.csv",
])
require_tokens("GPT_EA_Part41_PortfolioStressLatency.mqh",[
    "PORT_STRESS_USD_UP","PORT_STRESS_YIELDS_UP","PORT_STRESS_EQUITY_RISK_OFF","PORT_STRESS_GOLD_UP",
    "PORT_STRESS_GOLD_DOWN","PORT_STRESS_OIL_UP","PORT_STRESS_OIL_DOWN","PORT_STRESS_VOLATILITY_SPIKE",
    "PORT_STRESS_CORRELATED_GAP_DOWN","PORT_STRESS_CORRELATED_GAP_UP","WorstMacroScenarioPortfolioLoss",
    "GapRiskAllows","MarginStressAllows","DecisionAgeLatencyAllows",
])
require_tokens("GPT_EA_Part42_ExecutionReliability.mqh",[
    "INTENT_PREPARED","INTENT_SENT","INTENT_FILLED","INTENT_UNCERTAIN","PrepareAtomicTradeIntent",
    "MarkTradeIntentSent","PositionOrHistoryMatchesIntent","ReconcileBrokerAgainstEA",
    "CriticalStorageHealthCheck","ConfigurationDriftAllows","MarkManualIntervention",
    "HandleReliabilityTradeTransaction","GPT_EA_TradeIntentLedger.csv","GPT_EA_BrokerReconciliation.csv",
])
require_tokens("GPT_EA_Part43_CausalAttribution.mqh",["CausalAttributionForPosition","FinalizeCausalAttributionHistory","GPT_EA_CausalAttribution.csv"])
require_tokens("GPT_EA_Part44_ChaosFaultInjection.mqh",[
    "ACCOUNT_TRADE_MODE_REAL","ChaosEnvironmentAllows","CHAOS_API_TIMEOUT","CHAOS_STALE_QUOTE",
    "CHAOS_STORAGE_WRITE_FAIL","CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS","CHAOS_POST_FILL_PRE_BIND",
    "CHAOS_DROP_TRADE_TRANSACTION","CHAOS_DUPLICATE_TRADE_TRANSACTION","CHAOS_STOP_MODIFY_FAIL",
    "CHAOS_CORRUPT_CHECKPOINT","CHAOS_CONNECTION_LOSS",
])
require_tokens("GPT_EA_Part28B_CIReleaseEvidence.mqh",[
    'GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA        = "mt5_validation_evidence_v2"',
    "InpReleaseResilienceHardeningPassed","ReleaseResilienceHardeningAllows",
    "InpReleaseCertifiedConfigFingerprint",
])

# Fail-closed defaults.
p44=read("GPT_EA_Part44_ChaosFaultInjection.mqh")
if not re.search(r"InpEnableChaosFaultInjections*=s*falses*;",p44):
    errors.append("chaos fault injection must default false")
p32=read("GPT_EA_Part32_ChampionChallenger.mqh")
if not re.search(r"InpAutoPromoteChallengers*=s*falses*;",p32):
    errors.append("automatic challenger promotion must default false")
p28b=read("GPT_EA_Part28B_CIReleaseEvidence.mqh")
if not re.search(r"InpReleaseResilienceHardeningPasseds*=s*falses*;",p28b):
    errors.append("resilience release attestation must default false")

# Include order: chaos must exist before recovery; model/stress before Part30; reliability after lifecycle.
order=[
    "GPT_EA_Part09_RiskRecoveryAnalytics.mqh","GPT_EA_Part44_ChaosFaultInjection.mqh",
    "GPT_EA_Part10_BrokerUniversalRecovery.mqh","GPT_EA_Part40_ModelClockTrust.mqh",
    "GPT_EA_Part41_PortfolioStressLatency.mqh","GPT_EA_Part30_AdaptiveRiskPortfolio.mqh",
    "GPT_EA_Part39_DataIntegrityQuarantine.mqh","GPT_EA_Part33_LifecycleIntegrityReplay.mqh",
    "GPT_EA_Part42_ExecutionReliability.mqh","GPT_EA_Part43_CausalAttribution.mqh",
]
pos=[main.find(f'#include "{n}"') for n in order]
if any(p<0 for p in pos) or pos!=sorted(pos):
    errors.append("R6 resilience include/dependency order is invalid")

# Evidence/matrix contracts.
chaos_text=read("CHAOS_FAULT_INJECTION_TEST_MATRIX.md")
for i in range(1,17):
    token=f"CF-{i:03d}"
    if token not in chaos_text: errors.append(f"CHAOS_FAULT_INJECTION_TEST_MATRIX.md missing {token}")
runtime_template=read("MT5_RESILIENCE_RUNTIME_REPORT_TEMPLATE.md")
for marker in ("DUPLICATE_ORDER_COUNT=0","UNRESOLVED_INTENT_COUNT=0","UNRECONCILED_POSITION_COUNT=0",
               "CHAOS_REAL_ACCOUNT_REFUSAL=PASS","MACRO_STRESS_MATRIX=PASS","PROVENANCE_FRESHNESS=PASS",
               "STORAGE_FAILURE_FAIL_CLOSED=PASS","CONFIG_DRIFT_FAIL_CLOSED=PASS"):
    if marker not in runtime_template: errors.append(f"MT5 resilience runtime template missing final marker: {marker}")

for matrix_name,prefix,last in [
    ("R6_RESILIENCE_HARDENING_TEST_MATRIX.md","RH-",48),
    ("MT5_VALIDATION_ACCEPTANCE_MATRIX.md","M5-",53),
]:
    text=read(matrix_name)
    for i in range(1,last+1):
        token=f"{prefix}{i:03d}"
        if token not in text: errors.append(f"{matrix_name} missing {token}")

try:
    mt5_schema=json.loads(read("MT5_VALIDATION_EVIDENCE_SCHEMA.json"))
    if mt5_schema.get("properties",{}).get("schema_version",{}).get("const")!="mt5_validation_evidence_v2":
        errors.append("MT5 schema must be mt5_validation_evidence_v2")
    if "resilience_runtime" not in set(mt5_schema.get("required",[])):
        errors.append("MT5 v2 schema must require resilience_runtime")
    mt5_template=json.loads(read("MT5_VALIDATION_EVIDENCE_TEMPLATE.json"))
    if mt5_template.get("schema_version")!="mt5_validation_evidence_v2":
        errors.append("MT5 template must use v2 schema")
    if any(v is not False for v in mt5_template.get("resilience_runtime",{}).values()):
        errors.append("MT5 resilience runtime attestations must default false")
except Exception as exc:
    errors.append(f"MT5 v2 JSON contract invalid: {exc}")

try:
    release=json.loads(read("RELEASE_EVIDENCE_TEMPLATE.json"))
    if release.get("mt5_validation",{}).get("schema_version")!="mt5_validation_evidence_v2":
        errors.append("release evidence must bind MT5 v2")
    for gate in ("mt5_validation","resilience_hardening","rollback_package"):
        if release.get("gates",{}).get(gate) is not False:
            errors.append(f"release gate {gate} must default false")
except Exception as exc:
    errors.append(f"release evidence template invalid: {exc}")

if errors:
    print("R6 RESILIENCE STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)

print("R6 RESILIENCE STATIC CHECK: PASS")
