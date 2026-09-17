#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8")
PART38=(ROOT/"GPT_EA_Part38_LegalLicenseGate.mqh").read_text(encoding="utf-8")
errors=[]

for token in [
    '#include "GPT_EA_Part38_LegalLicenseGate.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR8Legal',
    '#define ReleaseGateSummary ReleaseGateSummaryR8Legal',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR8Legal',
    '#define AdvancedSafetyInit AdvancedSafetyInitR8Legal',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR8Legal',
]:
    if token not in MAIN:
        errors.append(f"GPT_EA.mq5 missing legal rollout wiring: {token}")

for token in [
    'GPT_EA_LEGAL_TERMS_VERSION',
    'GPT_EA_REQUIRED_ACCEPTANCE_PHRASE',
    'InpAcceptGPTCommercialTerms',
    'InpAcceptGPTTradingRisk',
    'InpGPTTermsAcceptancePhrase',
    'InpCustomerLicenseReference',
    'GPTLegalAcknowledgementAllows',
    'ReleaseSafetyAllowsR8Legal',
]:
    if token not in PART38:
        errors.append(f"Part38 missing legal gate token: {token}")

for name in ["InpAcceptGPTCommercialTerms","InpAcceptGPTTradingRisk"]:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART38):
        errors.append(f"{name} must default false")

if 'I ACCEPT GPT_EA TERMS AND TRADING RISK' not in PART38:
    errors.append("required acceptance phrase missing")

docs=[
    "COMMERCIAL_LICENSE.md",
    "TERMS_AND_CONDITIONS.md",
    "TRADING_RISK_DISCLOSURE.md",
    "DISCLAIMER.md",
    "ANTI_PIRACY_LICENSE_ENFORCEMENT.md",
    "CUSTOMER_SUPPORT_RUNBOOK.md",
    "CUSTOMER_RELEASE_READINESS_CHECKLIST.md",
]
for name in docs:
    p=ROOT/name
    if not p.exists() or len(p.read_text(encoding="utf-8").strip())<300:
        errors.append(f"missing/too-small rollout document: {name}")

if errors:
    print("LEGAL/ROLLOUT STATIC CHECK: FAILED")
    for e in errors:
        print("ERROR:",e)
    sys.exit(1)
print("LEGAL/ROLLOUT STATIC CHECK: PASS")
