#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8")
PART = (ROOT / "GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
DOC = (ROOT / "RELEASE_CERTIFICATION.md").read_text(encoding="utf-8")

errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsCertified',
    '#define ReleaseGateSummary ReleaseGateSummaryCertified',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitCertified',
    '#define AdvancedSafetyInit AdvancedSafetyInitCertified',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerCertified',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing certified release wiring: {token}")

required_false_flags = [
    "InpReleaseMetaEditorCompilePassed",
    "InpReleaseStrategyTesterPassed",
    "InpReleaseIntelligenceMatrixPassed",
    "InpReleaseBrokerMatrixPassed",
    "InpReleaseRecoveryTestsPassed",
    "InpReleaseStopMatrixPassed",
    "InpReleaseBrokerStopPolicyPassed",
    "InpReleasePartialProtectionPassed",
    "InpReleaseStopObservabilityPassed",
    "InpReleaseLiveNewsIntermarketPassed",
    "InpReleaseWebFailureInjectionPassed",
    "InpReleaseDemoSoakPassed",
    "InpReleaseOperatorReviewPassed",
]
for name in required_false_flags:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART):
        errors.append(f"release evidence flag must exist and default false: {name}")

m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', PART)
if not m:
    errors.append("required release validation ID not found")
else:
    release_id = m.group(1)
    if release_id not in DOC:
        errors.append("RELEASE_CERTIFICATION.md is not synchronized with current release validation ID")

for token in [
    "StopObservabilityAllowsNewEntries",
    "RefreshCertifiedReleaseState",
    "ReleaseSafetyAllowsCertified",
    "GPT_EA_ReleaseEvidence.csv",
]:
    if token not in PART:
        errors.append(f"Part28 missing certified release contract token: {token}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors:
        print("ERROR:", err)
    sys.exit(1)

print("RELEASE CERTIFICATION STATIC CHECK: PASS")
