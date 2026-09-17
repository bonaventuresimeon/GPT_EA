#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8")
PART40 = (ROOT / "GPT_EA_Part40_PrivacyReleaseGate.mqh").read_text(encoding="utf-8")
errors: list[str] = []

for token in [
    '#include "GPT_EA_Part40_PrivacyReleaseGate.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR10Privacy',
    '#define ReleaseGateSummary ReleaseGateSummaryR10Privacy',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR10Privacy',
    '#define AdvancedSafetyInit AdvancedSafetyInitR10Privacy',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR10Privacy',
]:
    if token not in MAIN:
        errors.append(f"GPT_EA.mq5 missing R10 privacy wiring: {token}")

for token in [
    "GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION",
    "InpReleasePrivacySignoffPassed",
    "InpReleasePrivacySignoffSchemaVersion",
    "InpReleasePrivacySignoffId",
    "InpReleasePrivacySignoffDigest",
    "InpReleasePrivacyReviewer",
    "InpReleasePrivacyReviewerRole",
    "InpReleasePrivacySignedAt",
    "InpReleasePrivacyJurisdiction",
    "InpReleasePrivacyDataInventoryApproved",
    "InpReleasePrivacyRetentionApproved",
    "InpReleasePrivacyCustomerNoticeApproved",
    "InpReleasePrivacySecretHandlingApproved",
    "InpReleasePrivacyCrossBorderApproved",
    "InpReleasePrivacyDeletionWorkflowApproved",
    "InpReleasePrivacyIncidentResponseApproved",
    "InpReleasePrivacyTelemetryState",
    "InpReleasePrivacyUnresolvedCriticalFindings",
    "GPTPrivacySignoffAllows",
    "ReleaseSafetyAllowsR10Privacy",
    "GPT_EA_PrivacyRelease.csv",
]:
    if token not in PART40:
        errors.append(f"Part40 missing privacy gate token: {token}")

for name in [
    "InpReleasePrivacySignoffPassed",
    "InpReleasePrivacyDataInventoryApproved",
    "InpReleasePrivacyRetentionApproved",
    "InpReleasePrivacyCustomerNoticeApproved",
    "InpReleasePrivacySecretHandlingApproved",
    "InpReleasePrivacyCrossBorderApproved",
    "InpReleasePrivacyDeletionWorkflowApproved",
    "InpReleasePrivacyIncidentResponseApproved",
]:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART40):
        errors.append(f"{name} must default false")

for name in [
    "PRIVACY_DATA_RETENTION_REVIEW.md",
    "PRIVACY_SIGN_OFF.md",
    "PRIVACY_SIGN_OFF_TEMPLATE.json",
    "tools/validate_privacy_signoff.py",
    "COMPILE_EVIDENCE_CHECKLIST.md",
    "COMPILE_EVIDENCE_TEMPLATE.json",
    "tools/validate_compile_evidence.py",
]:
    p = ROOT / name
    if not p.exists() or len(p.read_text(encoding="utf-8").strip()) < 100:
        errors.append(f"missing/too-small R10 evidence artifact: {name}")

if errors:
    print("R10 PRIVACY/COMPILE RELEASE CHECK: FAILED")
    for e in errors:
        print("ERROR:", e)
    sys.exit(1)

print("R10 PRIVACY/COMPILE RELEASE CHECK: PASS")
