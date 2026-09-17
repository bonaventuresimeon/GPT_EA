#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8")
PART05=(ROOT/"GPT_EA_Part05.mqh").read_text(encoding="utf-8")
PART28=(ROOT/"GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
PART35=(ROOT/"GPT_EA_Part35_AdaptiveIntegration.mqh").read_text(encoding="utf-8")
PART36=(ROOT/"GPT_EA_Part36_DemoSoakEvidence.mqh").read_text(encoding="utf-8")
errors=[]

files=[
 "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh","GPT_EA_Part31_ExecutionLearning.mqh",
 "GPT_EA_Part31A_RegimeSizing.mqh","GPT_EA_Part31B_ExecutionFinalizer.mqh",
 "GPT_EA_Part32_ChampionChallenger.mqh","GPT_EA_Part33_LifecycleIntegrityReplay.mqh",
 "GPT_EA_Part34_StrategyHealthDashboard.mqh","GPT_EA_Part35_AdaptiveIntegration.mqh",
 "GPT_EA_Part36_DemoSoakEvidence.mqh","ADAPTIVE_EXECUTION_ARCHITECTURE.md",
 "ADAPTIVE_EXECUTION_TEST_MATRIX.md","DEMO_SOAK_EVIDENCE.md","DEMO_SOAK_REPORT_TEMPLATE.md",
]
for f in files:
 if not (ROOT/f).exists(): errors.append(f"missing adaptive/release file: {f}")

main_tokens=[
 '#include "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh"',
 '#include "GPT_EA_Part31_ExecutionLearning.mqh"',
 '#include "GPT_EA_Part31A_RegimeSizing.mqh"',
 '#include "GPT_EA_Part31B_ExecutionFinalizer.mqh"',
 '#include "GPT_EA_Part32_ChampionChallenger.mqh"',
 '#include "GPT_EA_Part33_LifecycleIntegrityReplay.mqh"',
 '#include "GPT_EA_Part34_StrategyHealthDashboard.mqh"',
 '#include "GPT_EA_Part36_DemoSoakEvidence.mqh"',
 '#include "GPT_EA_Part35_AdaptiveIntegration.mqh"',
 '#define SelectDynamicStrategy SelectDynamicStrategyR5',
 '#define PreAuthorizationRiskAllows AdaptivePreAuthorizationRiskAllowsR5',
 '#define AdaptiveLotSizeForRisk AdaptiveLotSizeForRiskFinal',
 '#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5',
 '#define AIReviewAllowsExecution AIReviewAllowsExecutionR5',
 '#define NotifyCard NotifyCardR5',
 '#define NewsIntermarketInit NewsIntermarketInitR5',
 '#define NewsIntermarketTimer NewsIntermarketTimerR5',
 '#define ReleaseSafetyAllows ReleaseSafetyAllowsR6',
]
for t in main_tokens:
 if t not in MAIN: errors.append(f"missing adaptive main wiring: {t}")

contracts={
 "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh":["StrategyRiskBudgetAllows","RollingM15Correlation","AdvancedPortfolioRiskAllows","BrokerHealthScore","IndependentRiskSupervisorAllows"],
 "GPT_EA_Part31_ExecutionLearning.mqh":["CalibratedConfidenceValue","ExecutionSlippageForecastPoints","EventSpecificBehaviorAllows","UpdateOpenMAEMFE","LearnedStrategyExpiryM15","RefreshStrategyHealthModes","RefreshRegimeTransition"],
 "GPT_EA_Part31A_RegimeSizing.mqh":["AdaptiveLotSizeForRiskFinal","REGIME_RISK_MULT"],
 "GPT_EA_Part31B_ExecutionFinalizer.mqh":["FinalizeAdaptiveLearningHistoryR5","AdaptivePositionCommission","ExecutionLearningTimerR5"],
 "GPT_EA_Part32_ChampionChallenger.mqh":["ChallengerEligibleForPromotion","SHADOW_REJECTED_COUNTERFACTUAL","ChampionChallengerScanHook","InpAutoPromoteChallenger"],
 "GPT_EA_Part33_LifecycleIntegrityReplay.mqh":["LIFE_CANDIDATE","LIFE_FILLED","GPTDisagreementAllowsHighConfidence","GPTReviewIntegrityAllows","WriteDecisionSnapshot"],
 "GPT_EA_Part34_StrategyHealthDashboard.mqh":["GPT_EA_StrategyHealth.csv","AdaptiveCardAddendum"],
 "GPT_EA_Part35_AdaptiveIntegration.mqh":["SelectDynamicStrategyR5","AdaptivePreAuthorizationRiskAllowsR5","AIReviewAllowsExecutionR5","NotifyCardR5","ExecutionLearningInitR5","ExecutionLearningTimerR5","LIFECYCLE_WAIT_HUMAN_APPROVAL","LIFECYCLE_WAIT_MARKET_CONFIRMATION"],
 "GPT_EA_Part36_DemoSoakEvidence.mqh":["ReconcileStaleApprovalWaitStates","demo_soak_evidence_v1","WriteDemoSoakJsonSnapshot","SCHEDULED_SCANS","CONTINUOUS_SCANS","CHECKPOINT_UPDATES","BACKUP_CHECKPOINT_UPDATES"],
}
for f,tokens in contracts.items():
 p=ROOT/f
 if not p.exists(): continue
 text=p.read_text(encoding="utf-8")
 for t in tokens:
  if t not in text: errors.append(f"{f} missing adaptive contract token: {t}")

for t in ["AdaptivePreEntryAllows","StoredAIIntegrityAllows","RegisterAdaptiveExecutionRequest","RegisterAdaptiveExecutionFailure","RegisterAdaptiveExecutionFill","AttachLifecycleToNewestPosition"]:
 if t not in PART05: errors.append(f"Part05 missing adaptive execution token: {t}")

flags=["InpReleaseAdaptivePortfolioPassed","InpReleaseExecutionLearningPassed","InpReleaseChampionChallengerPassed","InpReleaseLifecycleIntegrityPassed"]
for flag in flags:
 if not re.search(rf"input\s+bool\s+{flag}\s*=\s*false\s*;",PART28):
  errors.append(f"adaptive release flag missing or not fail-closed: {flag}")
if "GPT_EA_FULL_INTELLIGENCE_R6_20260917" not in PART28:
 errors.append("R6 release validation ID missing")
if "demo_soak_evidence_v1" not in PART28:
 errors.append("R6 demo-soak schema contract missing")

p32=(ROOT/"GPT_EA_Part32_ChampionChallenger.mqh").read_text(encoding="utf-8")
if not re.search(r"InpAutoPromoteChallenger\s*=\s*false\s*;",p32):
 errors.append("challenger auto-promotion must default false")

if "ExecutionLearningInitR5();" not in PART35 or "ExecutionLearningTimerR5();" not in PART35:
 errors.append("history-safe adaptive execution finalizer is not the active runtime path")
if "DemoSoakEvidenceTimer();" not in PART35 or "ReconcileStaleApprovalWaitStates" not in PART36:
 errors.append("R6 demo-soak/lifecycle reconciliation runtime path is incomplete")

arch=(ROOT/"ADAPTIVE_EXECUTION_ARCHITECTURE.md").read_text(encoding="utf-8") if (ROOT/"ADAPTIVE_EXECUTION_ARCHITECTURE.md").exists() else ""
for i in range(1,21):
 if f"## {i}." not in arch: errors.append(f"adaptive architecture mapping missing item {i}")

tests=(ROOT/"ADAPTIVE_EXECUTION_TEST_MATRIX.md").read_text(encoding="utf-8") if (ROOT/"ADAPTIVE_EXECUTION_TEST_MATRIX.md").exists() else ""
for prefix in ["AR-001","AR-020","AR-030","AR-040","AR-060","AR-080","AR-110","AR-130","AR-160","AR-170","AR-180","AR-190","AR-212"]:
 if prefix not in tests: errors.append(f"adaptive release matrix missing {prefix}")

if errors:
 print("ADAPTIVE R6 STATIC CHECK: FAILED")
 for e in errors: print("ERROR:",e)
 sys.exit(1)
print("ADAPTIVE R6 STATIC CHECK: PASS")
