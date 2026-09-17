#!/usr/bin/env python3
"""Static release checks for GPT_EA.

This is not a substitute for MetaEditor compilation or Strategy Tester.
It catches repository-level wiring regressions, missing modules, duplicate inputs,
unbalanced source, committed API secrets, and loss of mandatory intelligence contracts.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "GPT_EA.mq5"

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
    "GPT_EA_Part22_IntelligenceFreshness.mqh",
    "GPT_EA_Part23_IntelligenceObservability.mqh",
    "GPT_EA_Part24_SessionStrategyHardening.mqh",
    "GPT_EA_Part25_ThesisHardening.mqh",
    "GPT_EA_Part26_DeepGPTPolicy.mqh",
    "INTELLIGENCE_TEST_MATRIX.md",
    "INTELLIGENCE_HARDENING_TESTS.md",
    "FULL_INTELLIGENCE_COVERAGE.md",
    "STOP_MANAGEMENT_TEST_MATRIX.md",
    "PARTIAL_PROTECTION_RELEASE_TEST.md",
    "STOP_FAILURE_OBSERVABILITY.md",
]

REQUIRED_TOKENS = {
    "GPT_EA_Part15_StrategyIntelligence.mqh": [
        "STRATEGY_TREND_CONTINUATION", "STRATEGY_RETRACEMENT_ENTRY",
        "STRATEGY_COUNTER_TREND_SCALP", "STRATEGY_COUNTER_TREND_SWING",
        "STRATEGY_POTENTIAL_REVERSAL", "STRATEGY_BREAKOUT",
        "STRATEGY_BREAKOUT_RETEST", "STRATEGY_RANGE_TRADE",
        "STRATEGY_MEAN_REVERSION", "STATE_HEALTHY_RETRACEMENT",
        "STATE_DEEP_RETRACEMENT", "STATE_TREND_FAILURE",
        "STATE_FALSE_BREAKOUT", "STATE_LIQUIDITY_SWEEP",
        "STATE_ACCUMULATION", "STATE_DISTRIBUTION",
    ],
    "GPT_EA_Part21_ResearchValidation.mqh": [
        "StrategyWalkForwardEvidence", "CurrentStrategyContextEvidence",
        "RetracementIntelligenceText", "RetracementDestinationText",
        "ChaseRiskDetected", "ExtremeRegimeDetected",
    ],
    "GPT_EA_Part22_IntelligenceFreshness.mqh": [
        "CallOpenAIWebIntelStructured", "json_schema",
        "GetLiveWebIntelHardened", "AssessIntermarketHardened",
        "WEB-INTELLIGENCE CIRCUIT BREAKER OPEN",
    ],
    "GPT_EA_Part24_SessionStrategyHardening.mqh": [
        "AccurateSessionBucket", "LONDON_NY_OVERLAP",
        "AccurateSessionEvidenceAllows", "LateSessionLiquidityRisk",
        "StrategyAdaptiveExpiry",
    ],
    "GPT_EA_Part25_ThesisHardening.mqh": [
        "RealisticRiskReward(pb)", "RealisticRiskReward(br)",
        "DeterministicDisproofChecklist",
    ],
    "GPT_EA_Part26_DeepGPTPolicy.mqh": [
        "gpt-5.6-sol", "reasoning", "effort", "CallOpenAIDeep",
    ],
}

REQUIRED_MAIN_WIRING = [
    '#include "GPT_EA_Part21_ResearchValidation.mqh"',
    '#include "GPT_EA_Part22A_IntermarketForward.mqh"',
    '#include "GPT_EA_Part22_IntelligenceFreshness.mqh"',
    '#include "GPT_EA_Part23_IntelligenceObservability.mqh"',
    '#include "GPT_EA_Part24_SessionStrategyHardening.mqh"',
    '#include "GPT_EA_Part25_ThesisHardening.mqh"',
    '#include "GPT_EA_Part26_DeepGPTPolicy.mqh"',
    "#define SelectDynamicStrategy SelectDynamicStrategyFinal",
    "#define GetLiveWebIntel GetLiveWebIntelHardened",
    "#define AssessIntermarket AssessIntermarketHardened",
    "#define PreEntryIntelligenceRevalidation PreEntryIntelligenceRevalidationStrict",
    "#define EffectiveRRDynamic EffectiveRRFullRatio",
    "#define ScheduledScanDue ScheduledOrContinuousScanDue",
    "#define CallOpenAI CallOpenAIDeep",
    "#define NotifyCard NotifyCardObserved",
    "#define BuildMandatory25PointThesis BuildMandatory25PointThesisFinal",
]


def strip_comments_and_strings(text: str) -> str:
    out: list[str] = []
    i = 0
    state = "code"
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if state == "code":
            if ch == "/" and nxt == "/":
                state = "line_comment"; out.extend("  "); i += 2; continue
            if ch == "/" and nxt == "*":
                state = "block_comment"; out.extend("  "); i += 2; continue
            if ch == '"':
                state = "string"; out.append(" "); i += 1; continue
            out.append(ch); i += 1; continue
        if state == "line_comment":
            if ch == "\n": state = "code"; out.append("\n")
            else: out.append(" ")
            i += 1; continue
        if state == "block_comment":
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
    closing = {v: k for k, v in pairs.items()}
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in text:
        if ch == "\n": line += 1
        elif ch in pairs: stack.append((ch, line))
        elif ch in closing:
            if not stack or stack[-1][0] != closing[ch]:
                errors.append(f"{path.name}:{line}: unmatched {ch}")
                return
            stack.pop()
    if stack:
        ch, ln = stack[-1]
        errors.append(f"{path.name}:{ln}: unclosed {ch}")


def collect_includes(main_text: str) -> list[str]:
    return re.findall(r'^\s*#include\s+"([^"]+)"', main_text, re.M)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    if not MAIN.exists():
        print("ERROR: GPT_EA.mq5 missing")
        return 1

    main_text = MAIN.read_text(encoding="utf-8")
    for name in REQUIRED_FILES:
        if not (ROOT / name).exists(): errors.append(f"required file missing: {name}")
    for token in REQUIRED_MAIN_WIRING:
        if token not in main_text: errors.append(f"main wiring missing: {token}")

    includes = collect_includes(main_text)
    for inc in includes:
        if not (ROOT / inc).exists(): errors.append(f"local include missing: {inc}")

    source_files = [MAIN] + [ROOT / i for i in includes if (ROOT / i).exists()]
    seen_inputs: dict[str, str] = {}
    input_re = re.compile(r'^\s*input\s+[A-Za-z_][\w<>]*\s+([A-Za-z_]\w*)', re.M)
    for path in source_files:
        text = path.read_text(encoding="utf-8")
        check_balanced(path, errors)
        for name in input_re.findall(text):
            if name in seen_inputs:
                errors.append(f"duplicate input {name}: {seen_inputs[name]} and {path.name}")
            else:
                seen_inputs[name] = path.name
        if re.search(r'\bsk-[A-Za-z0-9_-]{12,}', text):
            errors.append(f"possible OpenAI API secret committed in {path.name}")

    for filename, tokens in REQUIRED_TOKENS.items():
        path = ROOT / filename
        if not path.exists(): continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text: errors.append(f"{filename} missing required contract token: {token}")

    thesis = (ROOT / "GPT_EA_Part17_ThesisEngine.mqh").read_text(encoding="utf-8")
    missing_points = [str(i) for i in range(1, 26) if f'{i}. ' not in thesis]
    if missing_points: errors.append("mandatory thesis points missing: " + ", ".join(missing_points))

    order = [
        "GPT_EA_Part15_StrategyIntelligence.mqh",
        "GPT_EA_Part15D_StructureTargets.mqh",
        "GPT_EA_Part21_ResearchValidation.mqh",
        "GPT_EA_Part24_SessionStrategyHardening.mqh",
        "GPT_EA_Part16_NewsIntermarket.mqh",
        "GPT_EA_Part22A_IntermarketForward.mqh",
        "GPT_EA_Part22_IntelligenceFreshness.mqh",
        "GPT_EA_Part16A_StrictRevalidation.mqh",
        "GPT_EA_Part17_ThesisEngine.mqh",
        "GPT_EA_Part25_ThesisHardening.mqh",
        "GPT_EA_Part26_DeepGPTPolicy.mqh",
        "GPT_EA_Part07.mqh",
    ]
    positions = [main_text.find(f'#include "{x}"') for x in order]
    if any(p < 0 for p in positions) or positions != sorted(positions):
        errors.append("critical intelligence include order is invalid")

    if 'input string InpOpenAIAPIKey            = ""' not in (ROOT / "GPT_EA_Part01.mqh").read_text(encoding="utf-8"):
        warnings.append("OpenAI API key default is not the expected blank literal; review manually")

    if errors:
        print("STATIC RELEASE CHECK: FAILED")
        for e in errors: print("ERROR:", e)
        for w in warnings: print("WARNING:", w)
        return 1

    print("STATIC RELEASE CHECK: PASS")
    print(f"Checked {len(source_files)} directly included MQL files and {len(seen_inputs)} unique EA inputs.")
    for w in warnings: print("WARNING:", w)
    print("MetaEditor compilation, Strategy Tester, broker matrix, failure injection and demo soak remain separate hard release gates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
