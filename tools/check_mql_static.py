#!/usr/bin/env python3
"""Repository-level static release checks for the current GPT_EA release chain.

Base evidence identity remains R6 while the active runtime additionally layers
supplemental CI/five-day evidence and the Part37 API transport guard. This is
not a substitute for MetaEditor compilation, Strategy Tester, broker validation,
WebRequest failure injection or the required demo soak.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "GPT_EA.mq5"
RELEASE_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917"

REQUIRED_FILES = [
    "GPT_EA_Part15_StrategyIntelligence.mqh",
    "GPT_EA_Part15B_StrategyFrameworks.mqh",
    "GPT_EA_Part15C_StrategyContextAnalytics.mqh",
    "GPT_EA_Part15D_StructureTargets.mqh",
    "GPT_EA_Part16_NewsIntermarket.mqh",
    "GPT_EA_Part16A_StrictRevalidation.mqh",
    "GPT_EA_Part17_ThesisEngine.mqh",
    "GPT_EA_Part18_StopBrokerObservability.mqh",
    "GPT_EA_Part19_ContinuousIntelligence.mqh",
    "GPT_EA_Part20_RealisticCostModel.mqh",
    "GPT_EA_Part21_ResearchValidation.mqh",
    "GPT_EA_Part22A_IntermarketForward.mqh",
    "GPT_EA_Part22P_ResponseParser.mqh",
    "GPT_EA_Part22_IntelligenceFreshness.mqh",
    "GPT_EA_Part23_IntelligenceObservability.mqh",
    "GPT_EA_Part24_SessionStrategyHardening.mqh",
    "GPT_EA_Part25_ThesisHardening.mqh",
    "GPT_EA_Part26_DeepGPTPolicy.mqh",
    "GPT_EA_Part27_StrategyCompletion.mqh",
    "GPT_EA_Part28_ReleaseCertification.mqh",
    "GPT_EA_Part28B_CIReleaseEvidence.mqh",
    "GPT_EA_Part29_DeploymentDriftGuard.mqh",
    "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh",
    "GPT_EA_Part31_ExecutionLearning.mqh",
    "GPT_EA_Part31A_RegimeSizing.mqh",
    "GPT_EA_Part31B_ExecutionFinalizer.mqh",
    "GPT_EA_Part32_ChampionChallenger.mqh",
    "GPT_EA_Part33_LifecycleIntegrityReplay.mqh",
    "GPT_EA_Part34_StrategyHealthDashboard.mqh",
    "GPT_EA_Part35_AdaptiveIntegration.mqh",
    "GPT_EA_Part36_DemoSoakEvidence.mqh",
    "GPT_EA_Part37_APITransport.mqh",
    "INTELLIGENCE_TEST_MATRIX.md",
    "INTELLIGENCE_HARDENING_TESTS.md",
    "FULL_INTELLIGENCE_COVERAGE.md",
    "OPENAI_INTELLIGENCE_POLICY.md",
    "STOP_MANAGEMENT_TEST_MATRIX.md",
    "PARTIAL_PROTECTION_RELEASE_TEST.md",
    "STOP_FAILURE_OBSERVABILITY.md",
    "BROKER_STOP_RELEASE_EVIDENCE.md",
    "RELEASE_CERTIFICATION.md",
    "METAEDITOR_COMPILE_GATE.md",
    "DEMO_SOAK_ACCEPTANCE.md",
    "DEMO_SOAK_EVIDENCE.md",
    "DEMO_SOAK_REPORT_TEMPLATE.md",
    "FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json",
    "FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json",
    "FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md",
    "FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md",
    "CI_EVIDENCE_SCHEMA.json",
    "CI_EVIDENCE_BUNDLE_SCHEMA.json",
    "CI_EVIDENCE_CONTRACT.md",
    "SOAK_EVIDENCE_SCHEMA.json",
    "DEPLOYMENT_DRIFT_TESTS.md",
    "API_TRANSPORT_ARCHITECTURE.md",
    "API_TRANSPORT_TEST_MATRIX.md",
    "MT5_WEBREQUEST_REQUIREMENTS.md",
    "RELEASE_GO_NO_GO.md",
    "RELEASE_EVIDENCE_MANIFEST.md",
    "ADAPTIVE_EXECUTION_ARCHITECTURE.md",
    "ADAPTIVE_EXECUTION_TEST_MATRIX.md",
    "tools/import_soak_snapshot.py",
    "tools/fetch_ci_job_metadata.py",
    "tools/build_ci_evidence.py",
    "tools/validate_ci_evidence.py",
    "tools/build_ci_bundle_manifest.py",
    "tools/validate_ci_bundle.py",
]

REQUIRED_MAIN_WIRING = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"',
    '#include "GPT_EA_Part37_APITransport.mqh"',
    '#include "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh"',
    '#include "GPT_EA_Part31_ExecutionLearning.mqh"',
    '#include "GPT_EA_Part31A_RegimeSizing.mqh"',
    '#include "GPT_EA_Part31B_ExecutionFinalizer.mqh"',
    '#include "GPT_EA_Part32_ChampionChallenger.mqh"',
    '#include "GPT_EA_Part33_LifecycleIntegrityReplay.mqh"',
    '#include "GPT_EA_Part34_StrategyHealthDashboard.mqh"',
    '#include "GPT_EA_Part36_DemoSoakEvidence.mqh"',
    '#include "GPT_EA_Part35_AdaptiveIntegration.mqh"',
    "#define ReleaseSafetyAllows ReleaseSafetyAllowsR7API",
    "#define ReleaseGateSummary ReleaseGateSummaryR7API",
    "#define StopFailureObservabilityInit StopFailureObservabilityInitR7API",
    "#define AdvancedSafetyInit AdvancedSafetyInitR7API",
    "#define AdvancedSafetyTimer AdvancedSafetyTimerR7API",
    "#define WebRequest GPTAPIWebRequest",
    "#undef WebRequest",
    "#define SelectDynamicStrategy SelectDynamicStrategyR5",
    "#define PreAuthorizationRiskAllows AdaptivePreAuthorizationRiskAllowsR5",
    "#define AdaptiveLotSizeForRisk AdaptiveLotSizeForRiskFinal",
    "#define LotSizeForRisk AdaptiveLotSizeForRiskFinal",
    "#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5",
    "#define AIReviewAllowsExecution AIReviewAllowsExecutionR5",
    "#define MarkSignalCooldown MarkSignalCooldownR5",
    "#define NewsIntermarketInit NewsIntermarketInitR5",
    "#define NewsIntermarketTimer NewsIntermarketTimerR5",
    "#define NotifyCard NotifyCardR5",
    "#define BuildMandatory25PointThesis BuildMandatory25PointThesisFinal",
    "#define CallOpenAI CallOpenAIDeep",
    "#define GetLiveWebIntel GetLiveWebIntelHardened",
    "#define AssessIntermarket AssessIntermarketHardened",
]

REQUIRED_TOKENS = {
    "GPT_EA_Part15_StrategyIntelligence.mqh": [
        "STRATEGY_TREND_CONTINUATION", "STRATEGY_RETRACEMENT_ENTRY", "STRATEGY_COUNTER_TREND_SCALP",
        "STRATEGY_COUNTER_TREND_SWING", "STRATEGY_POTENTIAL_REVERSAL", "STRATEGY_BREAKOUT",
        "STRATEGY_BREAKOUT_RETEST", "STRATEGY_RANGE_TRADE", "STRATEGY_MEAN_REVERSION",
        "STATE_HEALTHY_RETRACEMENT", "STATE_DEEP_RETRACEMENT", "STATE_TREND_FAILURE",
        "STATE_FALSE_BREAKOUT", "STATE_LIQUIDITY_SWEEP", "STATE_ACCUMULATION", "STATE_DISTRIBUTION",
    ],
    "GPT_EA_Part21_ResearchValidation.mqh": [
        "StrategyWalkForwardEvidence", "CurrentStrategyContextEvidence", "RetracementIntelligenceText",
        "ChaseRiskDetected", "ExtremeRegimeDetected",
    ],
    "GPT_EA_Part22_IntelligenceFreshness.mqh": [
        "CallOpenAIWebIntelStructured", "json_schema", "GetLiveWebIntelHardened",
        "AssessIntermarketHardened", "WEB-INTELLIGENCE CIRCUIT BREAKER OPEN",
    ],
    "GPT_EA_Part26_DeepGPTPolicy.mqh": ["gpt-5.6-sol", "reasoning", "effort", "CallOpenAIDeep"],
    "GPT_EA_Part27_StrategyCompletion.mqh": ["BuildDirectBreakoutCandidate", "SelectDynamicStrategyUltimate"],
    "GPT_EA_Part28_ReleaseCertification.mqh": [
        RELEASE_ID, "GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION", "InpReleaseSoakEvidenceDigest",
        "InpReleaseAdaptivePortfolioPassed", "InpReleaseExecutionLearningPassed",
        "InpReleaseChampionChallengerPassed", "InpReleaseLifecycleIntegrityPassed",
    ],
    "GPT_EA_Part28B_CIReleaseEvidence.mqh": [
        "GPT_EA_REQUIRED_CI_SCHEMA_VERSION", "GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA",
        "InpReleaseCIJobId", "InpReleaseCIRunnerId", "InpReleaseCIStepsExecuted",
        "InpReleaseCIBundleDigest", "InpReleaseCIBundleValidated", "ReleaseSafetyAllowsR6Evidence",
    ],
    "GPT_EA_Part29_DeploymentDriftGuard.mqh": [
        "ReleaseSafetyAllowsR6", "ReleaseGateSummaryR6", "AdvancedSafetyInitR6",
        "AdvancedSafetyTimerR6", "StopFailureObservabilityInitR6",
    ],
    "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh": [
        "StrategyRiskBudgetAllows", "RollingM15Correlation", "AdvancedPortfolioRiskAllows",
        "AbnormalMarketConditionScore", "BrokerHealthScore", "IndependentRiskSupervisorAllows",
        "AdaptiveRiskMultiplier", "AdaptivePreEntryAllows",
    ],
    "GPT_EA_Part31_ExecutionLearning.mqh": [
        "CalibratedConfidenceValue", "ExecutionSlippageForecastPoints", "RegisterAdaptiveExecutionFill",
        "UpdateOpenMAEMFE", "EventSpecificBehaviorAllows", "LearnedStrategyExpiryM15",
        "RefreshStrategyHealthModes", "RefreshRegimeTransition", "GPT_EA_ExecutionLearning.csv",
    ],
    "GPT_EA_Part31A_RegimeSizing.mqh": ["AdaptiveLotSizeForRiskFinal", "REGIME_RISK_MULT"],
    "GPT_EA_Part31B_ExecutionFinalizer.mqh": ["FinalizeAdaptiveLearningHistoryR5", "ExecutionLearningTimerR5"],
    "GPT_EA_Part32_ChampionChallenger.mqh": [
        "ChallengerEligibleForPromotion", "ChampionChallengerScanHook", "SHADOW_REJECTED_COUNTERFACTUAL",
        "InpAutoPromoteChallenger", "GPT_EA_ShadowValidation.csv",
    ],
    "GPT_EA_Part33_LifecycleIntegrityReplay.mqh": [
        "LIFE_CANDIDATE", "LIFE_WAIT_CONFIRMATION", "LIFE_APPROVED", "LIFE_SENT", "LIFE_FILLED",
        "GPTDisagreementAllowsHighConfidence", "GPTReviewIntegrityAllows", "WriteDecisionSnapshot",
    ],
    "GPT_EA_Part34_StrategyHealthDashboard.mqh": ["REDUCED_RISK", "SHADOW", "DISABLED", "GPT_EA_StrategyHealth.csv"],
    "GPT_EA_Part35_AdaptiveIntegration.mqh": [
        "LIFECYCLE_WAIT_HUMAN_APPROVAL", "LIFECYCLE_WAIT_MARKET_CONFIRMATION",
        "SelectDynamicStrategyR5", "AdaptivePreAuthorizationRiskAllowsR5", "AIReviewAllowsExecutionR5",
        "NotifyCardR5", "DemoSoakEvidenceInit", "DemoSoakEvidenceTimer", "DemoSoakEvidenceShutdown",
    ],
    "GPT_EA_Part36_DemoSoakEvidence.mqh": [
        "demo_soak_evidence_v1", "ReconcileStaleApprovalWaitStates", "WriteDemoSoakJsonSnapshot",
        "SCHEDULED_SCANS", "CONTINUOUS_SCANS", "CHECKPOINT_UPDATES", "BACKUP_CHECKPOINT_UPDATES",
        "RecordDemoSoakIncident", "InpExecutionJournalFile", "InpStopFailureObservabilityFile",
        "InpReleaseEvidenceSnapshotFile",
    ],
    "GPT_EA_Part37_APITransport.mqh": [
        "GPTAPIWebRequest", "APITransportReleaseEvidenceAllows", "ReleaseSafetyAllowsR7API",
        "InpReleaseAPITransportPassed", "GPT_API_DIRECT_OPENAI", "GPT_API_SECURE_PROXY",
        "APITrustedDirectEndpoint", "X-Client-Request-Id", "X-GPT-EA-Token",
    ],
}

RELEASE_FLAGS = [
    "InpReleaseMetaEditorCompilePassed", "InpReleaseArtifactIdentityArchived", "InpReleaseStrategyTesterPassed",
    "InpReleaseIntelligenceMatrixPassed", "InpReleaseAdaptivePortfolioPassed", "InpReleaseExecutionLearningPassed",
    "InpReleaseChampionChallengerPassed", "InpReleaseLifecycleIntegrityPassed", "InpReleaseBrokerMatrixPassed",
    "InpReleaseDeploymentProfilePassed", "InpReleaseRecoveryTestsPassed", "InpReleaseStopMatrixPassed",
    "InpReleaseBrokerStopPolicyPassed", "InpReleasePartialProtectionPassed", "InpReleaseStopObservabilityPassed",
    "InpReleaseLiveNewsIntermarketPassed", "InpReleaseWebFailureInjectionPassed", "InpReleaseDemoSoakPassed",
    "InpReleaseOperatorReviewPassed",
]


def strip_comments_and_strings(text: str) -> str:
    out: list[str] = []
    i = 0
    state = "code"
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if state == "code":
            if ch == "/" and nxt == "/": state = "line"; out.extend("  "); i += 2; continue
            if ch == "/" and nxt == "*": state = "block"; out.extend("  "); i += 2; continue
            if ch == '"': state = "string"; out.append(" "); i += 1; continue
            out.append(ch); i += 1; continue
        if state == "line":
            if ch == "\n": state = "code"; out.append("\n")
            else: out.append(" ")
            i += 1; continue
        if state == "block":
            if ch == "*" and nxt == "/": state = "code"; out.extend("  "); i += 2
            else: out.append("\n" if ch == "\n" else " "); i += 1
            continue
        if state == "string":
            if ch == "\\" and i + 1 < len(text): out.extend("  "); i += 2; continue
            if ch == '"': state = "code"
            out.append(" "); i += 1
    return "".join(out)


def check_balanced(path: Path, errors: list[str]) -> None:
    text = strip_comments_and_strings(path.read_text(encoding="utf-8"))
    pairs = {"{": "}", "(": ")", "[": "]"}
    reverse = {v: k for k, v in pairs.items()}
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in text:
        if ch == "\n": line += 1
        elif ch in pairs: stack.append((ch, line))
        elif ch in reverse:
            if not stack or stack[-1][0] != reverse[ch]:
                errors.append(f"{path.name}:{line}: unmatched {ch}")
                return
            stack.pop()
    if stack:
        ch, ln = stack[-1]
        errors.append(f"{path.name}:{ln}: unclosed {ch}")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    if not MAIN.exists():
        print("STATIC CURRENT RELEASE CHECK: FAILED\nERROR: GPT_EA.mq5 missing")
        return 1

    main_text = MAIN.read_text(encoding="utf-8")
    for name in REQUIRED_FILES:
        if not (ROOT / name).exists(): errors.append(f"required file missing: {name}")
    for token in REQUIRED_MAIN_WIRING:
        if token not in main_text: errors.append(f"main wiring missing: {token}")

    includes = re.findall(r'^\s*#include\s+"([^"]+)"', main_text, re.M)
    for inc in includes:
        if not (ROOT / inc).exists(): errors.append(f"local include missing: {inc}")

    source_files = [MAIN] + [ROOT / inc for inc in includes if (ROOT / inc).exists()]
    seen_inputs: dict[str, str] = {}
    input_re = re.compile(r'^\s*input\s+[A-Za-z_][\w<>]*\s+([A-Za-z_]\w*)', re.M)
    for path in source_files:
        text = path.read_text(encoding="utf-8")
        check_balanced(path, errors)
        for name in input_re.findall(text):
            if name in seen_inputs: errors.append(f"duplicate input {name}: {seen_inputs[name]} and {path.name}")
            else: seen_inputs[name] = path.name
        if re.search(r'\bsk-[A-Za-z0-9_-]{12,}', text):
            errors.append(f"possible OpenAI API secret committed in {path.name}")

    for filename, tokens in REQUIRED_TOKENS.items():
        path = ROOT / filename
        if not path.exists(): continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text: errors.append(f"{filename} missing contract token: {token}")

    thesis_path = ROOT / "GPT_EA_Part17_ThesisEngine.mqh"
    if thesis_path.exists():
        thesis = thesis_path.read_text(encoding="utf-8")
        missing = [str(i) for i in range(1, 26) if f"{i}. " not in thesis]
        if missing: errors.append("mandatory thesis points missing: " + ", ".join(missing))

    critical_order = [
        "GPT_EA_Part28_ReleaseCertification.mqh", "GPT_EA_Part29_DeploymentDriftGuard.mqh",
        "GPT_EA_Part28B_CIReleaseEvidence.mqh", "GPT_EA_Part37_APITransport.mqh",
        "GPT_EA_Part15_StrategyIntelligence.mqh", "GPT_EA_Part21_ResearchValidation.mqh",
        "GPT_EA_Part27_StrategyCompletion.mqh", "GPT_EA_Part16_NewsIntermarket.mqh",
        "GPT_EA_Part22_IntelligenceFreshness.mqh", "GPT_EA_Part16A_StrictRevalidation.mqh",
        "GPT_EA_Part17_ThesisEngine.mqh", "GPT_EA_Part25_ThesisHardening.mqh",
        "GPT_EA_Part26_DeepGPTPolicy.mqh", "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh",
        "GPT_EA_Part31_ExecutionLearning.mqh", "GPT_EA_Part31A_RegimeSizing.mqh",
        "GPT_EA_Part31B_ExecutionFinalizer.mqh", "GPT_EA_Part32_ChampionChallenger.mqh",
        "GPT_EA_Part33_LifecycleIntegrityReplay.mqh", "GPT_EA_Part34_StrategyHealthDashboard.mqh",
        "GPT_EA_Part36_DemoSoakEvidence.mqh", "GPT_EA_Part35_AdaptiveIntegration.mqh",
        "GPT_EA_Part05.mqh", "GPT_EA_Part23_IntelligenceObservability.mqh",
        "GPT_EA_Part13_AdvancedPositionManager.mqh", "GPT_EA_Part07.mqh",
    ]
    positions = [main_text.find(f'#include "{name}"') for name in critical_order]
    if any(p < 0 for p in positions) or positions != sorted(positions):
        errors.append("critical include order is invalid")

    if main_text.count("#define ExtractOpenAIText ExtractOpenAITextWide") < 2:
        errors.append("wide OpenAI parser must cover both structured news and deep GPT review")

    release = (ROOT / "GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
    for flag in RELEASE_FLAGS:
        if not re.search(rf'input\s+bool\s+{flag}\s*=\s*false\s*;', release):
            errors.append(f"release attestation must default false: {flag}")
    m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', release)
    if not m or m.group(1) != RELEASE_ID:
        errors.append(f"base release validation ID must be {RELEASE_ID}")
    if 'GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION   = "demo_soak_evidence_v1"' not in release:
        errors.append("R6 soak schema version contract is missing")

    part28b = (ROOT / "GPT_EA_Part28B_CIReleaseEvidence.mqh").read_text(encoding="utf-8")
    for flag in ("InpReleaseCIStaticEvidencePassed", "InpReleaseCIBundleValidated"):
        if not re.search(rf'input\s+bool\s+{flag}\s*=\s*false\s*;', part28b):
            errors.append(f"supplemental release attestation must default false: {flag}")

    part37 = (ROOT / "GPT_EA_Part37_APITransport.mqh").read_text(encoding="utf-8")
    if not re.search(r'input\s+bool\s+InpReleaseAPITransportPassed\s*=\s*false\s*;', part37):
        errors.append("API transport release attestation must default false")

    p32 = (ROOT / "GPT_EA_Part32_ChampionChallenger.mqh").read_text(encoding="utf-8")
    if not re.search(r'InpAutoPromoteChallenger\s*=\s*false\s*;', p32):
        errors.append("champion/challenger auto-promotion must default false")

    part05 = (ROOT / "GPT_EA_Part05.mqh").read_text(encoding="utf-8")
    for token in ["AdaptivePreEntryAllows", "RegisterAdaptiveExecutionRequest", "RegisterAdaptiveExecutionFill", "StoredAIIntegrityAllows"]:
        if token not in part05: errors.append(f"Part05 execution wiring missing: {token}")

    part01 = (ROOT / "GPT_EA_Part01.mqh").read_text(encoding="utf-8")
    if not re.search(r'input\s+string\s+InpOpenAIAPIKey\s*=\s*""\s*;', part01):
        warnings.append("OpenAI API key default is not the expected blank literal; review manually")

    if errors:
        print("STATIC CURRENT RELEASE CHECK: FAILED")
        for e in errors: print("ERROR:", e)
        for w in warnings: print("WARNING:", w)
        return 1

    print("STATIC CURRENT RELEASE CHECK: PASS")
    print(f"Checked {len(source_files)} directly included MQL files and {len(seen_inputs)} unique inputs.")
    for w in warnings: print("WARNING:", w)
    print("MetaEditor compile, Strategy Tester, adaptive matrix, broker tests, API/WebRequest validation and five-day demo soak remain external hard gates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
