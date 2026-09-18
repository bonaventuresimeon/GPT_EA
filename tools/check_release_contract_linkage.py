#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from release_contract import load_release_contract

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "GPT_EA_DATA.json"
MAIN = ROOT / "GPT_EA.mq5"
EXPORTER = ROOT / "tools" / "export_mt5_release_inputs.py"

errors: list[str] = []
contract = load_release_contract()
payload = json.loads(BUNDLE.read_text(encoding="utf-8"))
documents = payload.get("documents", {})

if "FIVE_DAY_SOAK_ACCEPTANCE_RECORD_TEMPLATE.json" in documents:
    errors.append("stale FIVE_DAY_SOAK_ACCEPTANCE_RECORD_TEMPLATE.json must not remain in GPT_EA_DATA.json")

if int(payload.get("_meta", {}).get("document_count", -1)) != len(documents):
    errors.append("GPT_EA_DATA.json _meta.document_count does not match documents length")

main = MAIN.read_text(encoding="utf-8")
checks = {
    "release_validation_id": r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"',
    "demo_soak_schema": r'GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION\s*=\s*"([^"]+)"',
    "broker_coverage_schema": r'GPT_EA_REQUIRED_BROKER_COVERAGE_SCHEMA\s*=\s*"([^"]+)"',
    "runner_recovery_schema": r'GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA\s*=\s*"([^"]+)"',
    "runner_acceptance_schema": r'GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA\s*=\s*"([^"]+)"',
    "ci_schema": r'GPT_EA_REQUIRED_CI_SCHEMA_VERSION\s*=\s*"([^"]+)"',
    "ci_bundle_schema": r'GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA\s*=\s*"([^"]+)"',
    "mt5_validation_schema": r'GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA\s*=\s*"([^"]+)"',
    "resilience_schema": r'GPT_EA_REQUIRED_RESILIENCE_SCHEMA\s*=\s*"([^"]+)"',
    "soak_acceptance_schema": r'GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA\s*=\s*"([^"]+)"',
    "legal_terms_version": r'GPT_EA_LEGAL_TERMS_VERSION\s*=\s*"([^"]+)"',
    "legal_acceptance_phrase": r'GPT_EA_REQUIRED_ACCEPTANCE_PHRASE\s*=\s*"([^"]+)"',
    "risk_ack_schema": r'GPT_EA_RISK_ACK_SCHEMA_VERSION\s*=\s*"([^"]+)"',
    "privacy_schema": r'GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION\s*=\s*"([^"]+)"',
}
for key, pattern in checks.items():
    m = re.search(pattern, main)
    if not m:
        errors.append(f"GPT_EA.mq5 missing contract constant for {key}")
    elif m.group(1) != str(contract[key]):
        errors.append(f"GPT_EA.mq5 {key}={m.group(1)!r} but release_contract has {contract[key]!r}")

def schema_const(name: str) -> str:
    obj = documents.get(name)
    if not isinstance(obj, dict):
        errors.append(f"missing bundled JSON document: {name}")
        return ""
    if "schema_version" in obj:
        return str(obj.get("schema_version", ""))
    return str(obj.get("properties", {}).get("schema_version", {}).get("const", ""))

json_contracts = {
    "SOAK_EVIDENCE_SCHEMA.json": "demo_soak_schema",
    "RUNNER_RECOVERY_EVIDENCE_SCHEMA.json": "runner_recovery_schema",
    "RUNNER_RECOVERY_ACCEPTANCE_SCHEMA.json": "runner_acceptance_schema",
    "CI_EVIDENCE_SCHEMA.json": "ci_schema",
    "CI_EVIDENCE_BUNDLE_SCHEMA.json": "ci_bundle_schema",
    "MT5_VALIDATION_EVIDENCE_SCHEMA.json": "mt5_validation_schema",
    "RESILIENCE_HARDENING_EVIDENCE_SCHEMA.json": "resilience_schema",
    "BROKER_COVERAGE_EVIDENCE_SCHEMA.json": "broker_coverage_schema",
    "FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json": "soak_acceptance_schema",
    "CUSTOMER_RISK_ACKNOWLEDGEMENT_SCHEMA.json": "risk_ack_schema",
    "PRIVACY_SIGN_OFF_TEMPLATE.json": "privacy_schema",
    "COMPILE_EVIDENCE_TEMPLATE.json": "compile_evidence_schema",
    "FINAL_RELEASE_REVIEW_TEMPLATE.json": "final_review_schema",
    "MT5_MINIMUM_PROOF_SUMMARY_SCHEMA.json": "mt5_minimum_proof_schema",
    "RELEASE_READINESS_STATUS_SCHEMA.json": "release_readiness_schema",
    "SIGNED_LICENSE_ENTITLEMENT_SCHEMA.json": "signed_entitlement_schema",
    "FAIL_CLOSED_RECOVERY_DRILL_TEMPLATE.json": "fail_closed_recovery_drill_schema",
    "RELEASE_CANDIDATE_SMOKE_TEMPLATE.json": "release_candidate_smoke_schema",
    "DEMO_VALIDATION_RUN_TEMPLATE.json": "demo_validation_run_schema",
    "DRIFT_BASELINE_TEMPLATE.json": "drift_baseline_schema",
    "EVIDENCE_RETENTION_REGISTER_TEMPLATE.json": "evidence_retention_register_schema",
    "OPERATOR_STATUS_TEMPLATE.json": "operator_status_schema",
    "PRODUCTION_INCIDENT_TEMPLATE.json": "production_incident_schema",
}
for doc, key in json_contracts.items():
    actual = schema_const(doc)
    if actual != str(contract[key]):
        errors.append(f"{doc} schema {actual!r} does not match release_contract.{key}={contract[key]!r}")

release_template = documents.get("RELEASE_EVIDENCE_TEMPLATE.json", {})
if release_template.get("release_validation_id") != contract["release_validation_id"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json release_validation_id drift")
for section, key in (
    ("runner_recovery", "runner_recovery_schema"),
    ("runner_recovery_acceptance", "runner_acceptance_schema"),
    ("mt5_validation", "mt5_validation_schema"),
    ("resilience_hardening", "resilience_schema"),
    ("broker_coverage", "broker_coverage_schema"),
    ("compile_evidence", "compile_evidence_schema"),
    ("privacy_signoff", "privacy_schema"),
):
    if release_template.get(section, {}).get("schema_version") != contract[key]:
        errors.append(f"RELEASE_EVIDENCE_TEMPLATE.json {section}.schema_version drift")
if release_template.get("ci_static", {}).get("schema_version") != contract["ci_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json ci_static.schema_version drift")
if release_template.get("ci_static", {}).get("bundle_schema_version") != contract["ci_bundle_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json ci_static.bundle_schema_version drift")
if release_template.get("demo_soak", {}).get("schema_version") != contract["demo_soak_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json demo_soak.schema_version drift")
if release_template.get("demo_soak", {}).get("acceptance_record_schema_version") != contract["soak_acceptance_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json demo_soak.acceptance_record_schema_version drift")
if release_template.get("final_review", {}).get("schema_version") != contract["final_review_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json final_review.schema_version drift")
if release_template.get("api_transport", {}).get("schema_version") != contract["api_transport_schema"]:
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json api_transport.schema_version drift")

if not EXPORTER.exists():
    errors.append("tools/export_mt5_release_inputs.py missing")
else:
    exporter = EXPORTER.read_text(encoding="utf-8")
    release_inputs = sorted(set(re.findall(r"\bInpRelease[A-Za-z0-9_]+", main)))
    allowed_unexported = {"InpReleaseEvidenceSnapshotFile"}
    missing = [x for x in release_inputs if x not in allowed_unexported and f'"{x}"' not in exporter]
    if missing:
        errors.append("MT5 release exporter missing input(s): " + ", ".join(missing))
    for forbidden in ("InpOpenAIAPIKey", "InpAPIProxyToken"):
        if f'("{forbidden}",' in exporter:
            errors.append(f"exporter must never write secret input {forbidden}")

contract_consumers = [
    "validate_release_evidence.py",
    "validate_release_evidence_r10.py",
    "build_mt5_minimum_proof_summary.py",
    "validate_mt5_validation_evidence.py",
    "validate_runner_recovery_evidence.py",
    "validate_runner_recovery_acceptance.py",
    "validate_resilience_hardening_evidence.py",
    "validate_broker_coverage_evidence.py",
    "validate_five_day_soak_record.py",
    "validate_ci_evidence.py",
    "validate_ci_bundle.py",
    "validate_customer_risk_acknowledgement.py",
    "validate_privacy_signoff.py",
    "validate_compile_evidence.py",
    "build_release_readiness_status.py",
    "validate_release_readiness_status.py",
    "validate_mt5_minimum_proof_summary.py",
    "validate_demo_validation_harness.py",
    "validate_release_candidate_smoke.py",
    "validate_fail_closed_recovery_drill.py",
    "validate_signed_license_entitlement.py",
]
for name in contract_consumers:
    p = ROOT / "tools" / name
    if not p.exists():
        errors.append(f"missing contract consumer: {name}")
        continue
    text = p.read_text(encoding="utf-8")
    if "release_contract" not in text:
        errors.append(f"{name} must source version/release constants from release_contract")

if errors:
    print("RELEASE CONTRACT LINKAGE CHECK: FAILED")
    for e in errors:
        print("ERROR:", e)
    sys.exit(1)

print("RELEASE CONTRACT LINKAGE CHECK: PASS")
print("CONTRACT_VERSION:", contract["contract_version"])
print("RELEASE_VALIDATION_ID:", contract["release_validation_id"])
print("BUNDLED_DOCUMENTS:", len(documents))
