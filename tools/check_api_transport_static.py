#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8")
PART37=(ROOT/"GPT_EA_Part37_APITransport.mqh").read_text(encoding="utf-8") if (ROOT/"GPT_EA_Part37_APITransport.mqh").exists() else ""
COMPAT=(ROOT/"GPT_EA_Part37A_APICompat.mqh").read_text(encoding="utf-8") if (ROOT/"GPT_EA_Part37A_APICompat.mqh").exists() else ""
TEMPLATE=json.loads((ROOT/"RELEASE_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
errors=[]

for token in [
    '#include "GPT_EA_Part37A_APICompat.mqh"',
    '#include "GPT_EA_Part37_APITransport.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR7API',
    '#define ReleaseGateSummary ReleaseGateSummaryR7API',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR7API',
    '#define AdvancedSafetyInit AdvancedSafetyInitR7API',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR7API',
    '#define InpOpenAIAPIKey APITransportLegacyCredential()',
    '#define WebRequest GPTAPIWebRequest',
    '#undef WebRequest',
    '#undef InpOpenAIAPIKey',
]:
    if token not in MAIN:
        errors.append(f"GPT_EA.mq5 missing API transport wiring: {token}")

if "APITrim" not in COMPAT or "StringTrimLeft" not in COMPAT or "StringTrimRight" not in COMPAT:
    errors.append("Part37A compatibility helper is missing self-contained MQL5 trimming")

for token in [
    "GPT_API_DIRECT_OPENAI","GPT_API_SECURE_PROXY","InpAPIProxyEndpoint","InpAPIProxyToken",
    "InpAPIRequireProxyOnReal","InpReleaseAPITransportPassed","APITrustedDirectEndpoint",
    "APITransportLegacyCredential","APITransportConfigurationAllows","GPTAPIWebRequest",
    "X-Client-Request-Id","X-GPT-EA-Token","ReleaseSafetyAllowsR7API","GPT_EA_APIHealth.csv",
]:
    if token not in PART37:
        errors.append(f"Part37 missing API transport contract token: {token}")

for name in ["docs/API_TRANSPORT_docs/ARCHITECTURE.md","docs/MT5_WEBREQUEST_REQUIREMENTS.md","docs/API_TRANSPORT_TEST_MATRIX.md"]:
    path=ROOT/name
    if not path.exists() or len(path.read_text(encoding="utf-8").strip())<300:
        errors.append(f"missing/too-small API transport contract: {name}")

validator=ROOT/"tools"/"validate_api_transport_evidence.py"
if not validator.exists():
    errors.append("tools/validate_api_transport_evidence.py is missing")
else:
    text=validator.read_text(encoding="utf-8")
    for token in ["api_transport_evidence_v1","secret_leak_count","gates.api_transport","API TRANSPORT EVIDENCE"]:
        if token not in text:
            errors.append(f"API evidence validator missing token: {token}")

api=TEMPLATE.get("api_transport",{})
if api.get("schema_version")!="api_transport_evidence_v1":
    errors.append("release evidence template missing api_transport_evidence_v1")
if "api_transport" not in TEMPLATE.get("gates",{}):
    errors.append("release evidence template missing gates.api_transport")

if errors:
    print("API TRANSPORT STATIC CHECK: FAILED")
    for e in errors:
        print("ERROR:",e)
    sys.exit(1)
print("API TRANSPORT STATIC CHECK: PASS")
