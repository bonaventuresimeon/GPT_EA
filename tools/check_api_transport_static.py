#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT=Path(__file__).resolve().parents[1]
MQH=ROOT/"mqh"
MAIN=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8")
PART37=(MQH/"GPT_EA_Part37_APITransport.mqh").read_text(encoding="utf-8") if (MQH/"GPT_EA_Part37_APITransport.mqh").exists() else ""
COMPAT=(MQH/"GPT_EA_Part37A_APICompat.mqh").read_text(encoding="utf-8") if (MQH/"GPT_EA_Part37A_APICompat.mqh").exists() else ""
TEMPLATE=json.loads((ROOT/"RELEASE_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
errors=[]

# User-facing OpenAI inputs must remain at the very top of the MT5 Inputs list,
# directly after the ALL/universe selector. The key default must remain blank.
ordered=[
    'input string InpSymbols                 = "ALL";',
    'input bool   InpUseOpenAI               = true;',
    'input string InpOpenAIAPIKey            = "";',
    'input string InpOpenAIModel             = "gpt-5.6-sol";',
    'input string InpOpenAIEndpoint          = "https://api.openai.com/v1/responses";',
]
positions=[MAIN.find(token) for token in ordered]
if any(p<0 for p in positions) or positions!=sorted(positions):
    errors.append("OpenAI Symbols/Use/Key/Model/Endpoint inputs are not in the required top-of-input order")
risk_pos=MAIN.find("input double InpRiskPercent")
if risk_pos<0 or positions[-1]>risk_pos:
    errors.append("OpenAI Key/Model/Endpoint must appear before the trading/risk inputs")
if MAIN.count('input string InpOpenAIAPIKey')!=1:
    errors.append("InpOpenAIAPIKey must have exactly one user input declaration")

for token in [
    "InpOpenAIModelAutoResolve","InpOpenAIModelFallbacks","InpOpenAIModelScanMinutes",
    "OpenAIModelsEndpoint","FetchOpenAIModelCatalog","ExtractOpenAIModelIds",
    "SelectAvailableOpenAIModel","ResolveOpenAIModels","RefreshOpenAIModelResolutionIfDue",
    "ActiveOpenAIModel","ActiveDeepOpenAIModel","OpenAIModelHUDState",
    "https://api.openai.com/v1/models","FALLBACK ACTIVE",
]:
    if token not in MAIN:
        errors.append(f"GPT_EA.mq5 missing automatic OpenAI model-resolution token: {token}")

if MAIN.count("JsonEscape(ActiveOpenAIModel())") < 3:
    errors.append("all standard/web-intelligence OpenAI request bodies must use ActiveOpenAIModel()")
if 'InpUseDeepGPTReviewModel?ActiveDeepOpenAIModel():ActiveOpenAIModel()' not in MAIN:
    errors.append("deep GPT review must use the resolved deep/active model")
if 'input string InpOpenAIAPIKey            = "";' not in MAIN:
    errors.append("OpenAI API key source default must remain blank")

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

for name in ["docs/API_TRANSPORT_ARCHITECTURE.md","docs/MT5_WEBREQUEST_REQUIREMENTS.md","docs/API_TRANSPORT_TEST_MATRIX.md"]:
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
