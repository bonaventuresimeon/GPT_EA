#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT=Path(__file__).resolve().parents[1]
MQH=ROOT/"mqh"
MAIN=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8")
PART38=(MQH/"GPT_EA_Part38_LegalLicenseGate.mqh").read_text(encoding="utf-8")
PART39=(MQH/"GPT_EA_Part39_CustomerRiskAcknowledgement.mqh").read_text(encoding="utf-8")
errors=[]

for token in [
    '#include "GPT_EA_Part38_LegalLicenseGate.mqh"',
    '#include "GPT_EA_Part39_CustomerRiskAcknowledgement.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR9CustomerAck',
    '#define ReleaseGateSummary ReleaseGateSummaryR9CustomerAck',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR9CustomerAck',
    '#define AdvancedSafetyInit AdvancedSafetyInitR9CustomerAck',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR9CustomerAck',
]:
    if token not in MAIN:
        errors.append(f"GPT_EA.mq5 missing legal rollout wiring: {token}")

for token in [
    "GPT_EA_LEGAL_TERMS_VERSION",
    "GPT_EA_REQUIRED_ACCEPTANCE_PHRASE",
    "InpAcceptGPTCommercialTerms",
    "InpAcceptGPTTradingRisk",
    "InpGPTTermsAcceptancePhrase",
    "InpCustomerLicenseReference",
    "GPTLegalAcknowledgementAllows",
    "ReleaseSafetyAllowsR8Legal",
]:
    if token not in PART38:
        errors.append(f"Part38 missing legal gate token: {token}")

for name in ["InpAcceptGPTCommercialTerms","InpAcceptGPTTradingRisk"]:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART38):
        errors.append(f"{name} must default false")

if "I ACCEPT GPT_EA TERMS AND TRADING RISK" not in PART38:
    errors.append("required acceptance phrase missing")

for token in [
    "GPT_EA_RISK_ACK_SCHEMA_VERSION",
    "InpAcknowledgeNoProfitGuarantee",
    "InpAcknowledgePossibleTotalLoss",
    "InpAcknowledgeAILimitations",
    "InpAcknowledgeBrokerThirdPartyRisk",
    "InpAcknowledgePersonalResponsibility",
    "InpAcknowledgeDemoFirst",
    "InpCustomerJurisdiction",
    "InpAcceptedGPTTermsVersion",
    "InpAcceptedGPTRiskAckVersion",
    "ReleaseSafetyAllowsR9CustomerAck",
    "GPT_EA_RiskAcknowledgements.csv",
]:
    if token not in PART39:
        errors.append(f"Part39 missing customer acknowledgement token: {token}")

for name in [
    "InpAcknowledgeNoProfitGuarantee",
    "InpAcknowledgePossibleTotalLoss",
    "InpAcknowledgeAILimitations",
    "InpAcknowledgeBrokerThirdPartyRisk",
    "InpAcknowledgePersonalResponsibility",
    "InpAcknowledgeDemoFirst",
]:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART39):
        errors.append(f"{name} must default false")

docs=[
    "COMMERCIAL_LICENSE.md",
    "docs/TERMS_AND_CONDITIONS.md",
    "docs/TRADING_RISK_DISCLOSURE.md",
    "docs/DISCLAIMER.md",
    "docs/ANTI_PIRACY_LICENSE_ENFORCEMENT.md",
    "docs/CUSTOMER_SUPPORT_RUNBOOK.md",
    "docs/CUSTOMER_RELEASE_READINESS_CHECKLIST.md",
    "docs/JURISDICTION_LEGAL_REVIEW_CHECKLIST.md",
    "docs/CUSTOMER_RISK_ACKNOWLEDGEMENT_FLOW.md",
]
for name in docs:
    p=ROOT/name
    if not p.exists() or len(p.read_text(encoding="utf-8").strip())<300:
        errors.append(f"missing/too-small rollout document: {name}")

for name in [
    "CUSTOMER_RISK_ACKNOWLEDGEMENT_SCHEMA.json",
    "CUSTOMER_RISK_ACKNOWLEDGEMENT_TEMPLATE.json",
    "tools/validate_customer_risk_acknowledgement.py",
]:
    p=ROOT/name
    if not p.exists() or len(p.read_text(encoding="utf-8").strip())<100:
        errors.append(f"missing/too-small acknowledgement evidence artifact: {name}")

if errors:
    print("LEGAL/ROLLOUT STATIC CHECK: FAILED")
    for e in errors:
        print("ERROR:",e)
    sys.exit(1)

print("LEGAL/ROLLOUT STATIC CHECK: PASS")
