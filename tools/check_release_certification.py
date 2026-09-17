#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8")
PART28 = (ROOT / "GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
PART29 = (ROOT / "GPT_EA_Part29_DeploymentDriftGuard.mqh").read_text(encoding="utf-8")
DOC = (ROOT / "RELEASE_CERTIFICATION.md").read_text(encoding="utf-8")
COMPILE_DOC = (ROOT / "METAEDITOR_COMPILE_GATE.md").read_text(encoding="utf-8")
SOAK_DOC = (ROOT / "DEMO_SOAK_ACCEPTANCE.md").read_text(encoding="utf-8")
GO_NO_GO = (ROOT / "RELEASE_GO_NO_GO.md").read_text(encoding="utf-8")
DRIFT_DOC = (ROOT / "DEPLOYMENT_DRIFT_TESTS.md").read_text(encoding="utf-8")
MANIFEST = (ROOT / "RELEASE_EVIDENCE_MANIFEST.md").read_text(encoding="utf-8")

errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR4',
    '#define ReleaseGateSummary ReleaseGateSummaryR4',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR4',
    '#define AdvancedSafetyInit AdvancedSafetyInitR4',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR4',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing R4 release wiring: {token}")

required_false_flags = [
    "InpReleaseMetaEditorCompilePassed",
    "InpReleaseArtifactIdentityArchived",
    "InpReleaseStrategyTesterPassed",
    "InpReleaseIntelligenceMatrixPassed",
    "InpReleaseBrokerMatrixPassed",
    "InpReleaseDeploymentProfilePassed",
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
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART28):
        errors.append(f"release evidence flag must exist and default false: {name}")

m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', PART28)
if not m:
    errors.append("required release validation ID not found")
else:
    release_id = m.group(1)
    if "R4" not in release_id:
        errors.append("current release validation ID is not R4")
    if release_id not in DOC:
        errors.append("RELEASE_CERTIFICATION.md is not synchronized with current release validation ID")

for token in [
    "StopObservabilityAllowsNewEntries",
    "RefreshCertifiedReleaseState",
    "ReleaseSafetyAllowsCertified",
    "InpReleaseArtifactIdentityArchived",
    "InpReleaseDeploymentProfilePassed",
    "GPT_EA_ReleaseEvidence.csv",
]:
    if token not in PART28:
        errors.append(f"Part28 missing release contract token: {token}")

for token in [
    "CaptureDeploymentBaseline",
    "StructuralSymbolDriftAllows",
    "DeploymentDriftAllows",
    "ReleaseSafetyAllowsR4",
    "AdvancedSafetyInitR4",
    "AdvancedSafetyTimerR4",
    "StopFailureObservabilityInitR4",
]:
    if token not in PART29:
        errors.append(f"Part29 missing deployment-drift token: {token}")

required_docs = {
    "METAEDITOR_COMPILE_GATE.md": COMPILE_DOC,
    "DEMO_SOAK_ACCEPTANCE.md": SOAK_DOC,
    "RELEASE_GO_NO_GO.md": GO_NO_GO,
    "DEPLOYMENT_DRIFT_TESTS.md": DRIFT_DOC,
}
for name, text in required_docs.items():
    if len(text.strip()) < 200:
        errors.append(f"release contract document missing/too small: {name}")
    if name not in MANIFEST:
        errors.append(f"RELEASE_EVIDENCE_MANIFEST.md does not reference {name}")

for token in [
    "SHA-256",
    "5 consecutive trading days",
    "zero",
]:
    if token.lower() not in (COMPILE_DOC + "\n" + SOAK_DOC + "\n" + GO_NO_GO).lower():
        errors.append(f"release contracts missing expected evidence concept: {token}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors:
        print("ERROR:", err)
    sys.exit(1)

print("RELEASE CERTIFICATION STATIC CHECK: PASS")
