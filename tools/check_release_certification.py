#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT = Path(__file__).resolve().parents[1]
MQH = ROOT / "mqh"
MAIN = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8")
PART28 = (MQH / "GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
PART28B = (MQH / "GPT_EA_Part28B_CIReleaseEvidence.mqh").read_text(encoding="utf-8")
PART29 = (MQH / "GPT_EA_Part29_DeploymentDriftGuard.mqh").read_text(encoding="utf-8")
PART37 = (MQH / "GPT_EA_Part37_APITransport.mqh").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/static-quality.yml").read_text(encoding="utf-8")
errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"',
    '#include "GPT_EA_Part37_APITransport.mqh"',
    '#include "GPT_EA_Part38_LegalLicenseGate.mqh"',
    '#include "GPT_EA_Part39_CustomerRiskAcknowledgement.mqh"',
    '#include "GPT_EA_Part40_PrivacyReleaseGate.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR10Privacy',
    '#define ReleaseGateSummary ReleaseGateSummaryR10Privacy',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR10Privacy',
    '#define AdvancedSafetyInit AdvancedSafetyInitR10Privacy',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR10Privacy',
    '#define WebRequest GPTAPIWebRequest',
    '#undef WebRequest',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing current R10 release wiring: {token}")

required_false_flags = [
    "InpReleaseMetaEditorCompilePassed", "InpReleaseArtifactIdentityArchived", "InpReleaseStrategyTesterPassed",
    "InpReleaseIntelligenceMatrixPassed", "InpReleaseAdaptivePortfolioPassed", "InpReleaseExecutionLearningPassed",
    "InpReleaseChampionChallengerPassed", "InpReleaseLifecycleIntegrityPassed", "InpReleaseBrokerMatrixPassed",
    "InpReleaseDeploymentProfilePassed", "InpReleaseRecoveryTestsPassed", "InpReleaseStopMatrixPassed",
    "InpReleaseBrokerStopPolicyPassed", "InpReleasePartialProtectionPassed", "InpReleaseStopObservabilityPassed",
    "InpReleaseLiveNewsIntermarketPassed", "InpReleaseWebFailureInjectionPassed", "InpReleaseDemoSoakPassed",
    "InpReleaseOperatorReviewPassed",
]
for name in required_false_flags:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART28):
        errors.append(f"release evidence flag must default false: {name}")
for name in ["InpReleaseRunnerRecoveryPassed", "InpReleaseRunnerRecoveryAcceptancePassed", "InpReleaseCIStaticEvidencePassed", "InpReleaseCIBundleValidated", "InpReleaseMT5ValidationPassed", "InpReleaseResilienceHardeningPassed"]:
    if not re.search(rf"input\s+bool\s+{name}\s*=\s*false\s*;", PART28B):
        errors.append(f"{name} must default false")
if not re.search(r"input\s+bool\s+InpReleaseAPITransportPassed\s*=\s*false\s*;", PART37):
    errors.append("InpReleaseAPITransportPassed must default false")

m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', PART28)
release_id = m.group(1) if m else ""
if release_id != "GPT_EA_FULL_INTELLIGENCE_R6_20260917":
    errors.append("current base release validation ID must be GPT_EA_FULL_INTELLIGENCE_R6_20260917")

for token in ["ReleaseArtifactIdentityAllows", "ReleaseDemoSoakEvidenceAllows", "ReleaseFinalReviewAllows",
              "StopObservabilityAllowsNewEntries", "ReleaseSafetyAllowsCertified", "GPT_EA_ReleaseEvidence.csv",
              "GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION"]:
    if token not in PART28: errors.append(f"Part28 missing R6 release contract token: {token}")
for token in ["CaptureDeploymentBaseline", "StructuralSymbolDriftAllows", "DeploymentDriftAllows", "ReleaseSafetyAllowsR6", "RefreshR6ReleaseState"]:
    if token not in PART29: errors.append(f"Part29 missing deployment-drift token: {token}")
for token in [
    "GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA", "GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA", "GPT_EA_REQUIRED_CI_SCHEMA_VERSION", "GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA", "GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA", "GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA",
    "ReleaseRunnerRecoveryEvidenceAllows", "ReleaseRunnerRecoveryAcceptanceAllows", "ReleaseCIStaticEvidenceAllows", "ReleaseMT5ValidationEvidenceAllows", "ReleaseFiveDaySoakRecordAllows", "ReleaseSafetyAllowsR6Evidence",
    "InpReleaseRunnerRecoveryEvidenceId", "InpReleaseRunnerRecoveryDigest", "InpReleaseRunnerRecoveryAcceptanceId", "InpReleaseRunnerRecoveryAcceptanceDigest", "InpReleaseMT5ValidationEvidenceId", "InpReleaseMT5ValidationDigest", "InpReleaseSoakAcceptanceSchemaVersion",
    "InpReleaseCIJobId", "InpReleaseCIRunnerId", "InpReleaseCIStepsExecuted", "InpReleaseCIAttestationVerified",
    "InpReleaseCIBundleSchemaVersion", "InpReleaseCIBundleDigest", "InpReleaseCIBundleValidated",
    "InpReleaseSoakAcceptanceRecordDigest",
    "InpReleaseResilienceHardeningPassed", "InpReleaseResilienceSchemaVersion", "InpReleaseResilienceEvidenceId",
    "InpReleaseResilienceDigest", "InpReleaseCertifiedConfigFingerprint", "ReleaseResilienceHardeningAllows",
    "GPT_EA_R6SupplementalEvidence.csv",
]:
    if token not in PART28B: errors.append(f"Part28B missing supplemental R6 evidence token: {token}")
for token in ["APITransportReleaseEvidenceAllows", "ReleaseSafetyAllowsR7API", "InpReleaseAPITransportPassed", "GPTAPIWebRequest",
              "GPT_API_DIRECT_OPENAI", "GPT_API_SECURE_PROXY", "APITrustedDirectEndpoint", "X-Client-Request-Id", "X-GPT-EA-Token"]:
    if token not in PART37: errors.append(f"Part37 missing current API release token: {token}")

for token in [
    "static-release-gate:", "ci-evidence-bundle:", "tools/fetch_ci_job_metadata.py", "tools/build_ci_evidence.py",
    "tools/validate_ci_evidence.py", "tools/build_ci_bundle_manifest.py", "tools/validate_ci_bundle.py",
    "gh attestation verify", "ci-job-metadata.json", "ci-bundle-manifest.json", "ci-bundle-validation.txt",
]:
    if token not in WORKFLOW: errors.append(f"static-quality workflow missing CI bundle token: {token}")

docs = [
    "docs/RELEASE_CERTIFICATION.md", "docs/METAEDITOR_COMPILE_GATE.md", "docs/DEMO_SOAK_ACCEPTANCE.md", "docs/DEMO_SOAK_EVIDENCE.md",
    "docs/CI_EVIDENCE_CONTRACT.md", "docs/RUNNER_RECOVERY_EVIDENCE.md", "docs/RUNNER_RECOVERY_TEST_MATRIX.md", "docs/RUNNER_RECOVERY_ACCEPTANCE_MATRIX.md", "docs/MT5_VALIDATION_EVIDENCE.md", "docs/MT5_VALIDATION_ACCEPTANCE_MATRIX.md", "docs/FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md", "docs/FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md", "docs/SOAK_DAY_RECONCILIATION_CHECKLIST.md",
    "docs/RELEASE_GO_NO_GO.md", "docs/FINAL_GO_NO_GO_REVIEW.md", "docs/DEPLOYMENT_DRIFT_TESTS.md", "docs/RELEASE_EVIDENCE_VALIDATION.md",
    "docs/RELEASE_EVIDENCE_MANIFEST.md", "docs/API_TRANSPORT_ARCHITECTURE.md", "docs/MT5_WEBREQUEST_REQUIREMENTS.md", "docs/API_TRANSPORT_TEST_MATRIX.md",
    "docs/R6_RESILIENCE_HARDENING_TEST_MATRIX.md", "docs/ROLLBACK_PACKAGE_CONTRACT.md",
    "docs/BROKER_AGNOSTIC_RELEASE_ACCEPTANCE.md",
]
combined = ""
for name in docs:
    p = ROOT / name
    if not p.exists(): errors.append(f"release contract document missing: {name}"); continue
    text = p.read_text(encoding="utf-8")
    if len(text.strip()) < 200: errors.append(f"release contract document too small: {name}")
    combined += "\n" + text

template_path = ROOT / "RELEASE_EVIDENCE_TEMPLATE.json"
if not template_path.exists(): errors.append("RELEASE_EVIDENCE_TEMPLATE.json missing")
else:
    try:
        template = json.loads(template_path.read_text(encoding="utf-8"))
        if template.get("release_validation_id") != release_id: errors.append("release evidence template release ID mismatch")
        ci = template.get("ci_static", {})
        if ci.get("schema_version") != "github_actions_static_evidence_v1": errors.append("release template missing CI evidence schema")
        if ci.get("bundle_schema_version") != "ci_evidence_bundle_v1": errors.append("release template missing CI bundle schema")
        for key in ("job_metadata_path", "bundle_manifest_path", "bundle_digest", "bundle_validated", "bundle_validation_path"):
            if key not in ci: errors.append(f"release template ci_static missing {key}")
        if template.get("gates", {}).get("runner_recovery") is not False: errors.append("release template runner_recovery gate must default false")
        if template.get("gates", {}).get("runner_recovery_acceptance") is not False: errors.append("release template runner_recovery_acceptance gate must default false")
        if template.get("gates", {}).get("mt5_validation") is not False: errors.append("release template mt5_validation gate must default false")
        if template.get("gates", {}).get("resilience_hardening") is not False: errors.append("release template resilience_hardening gate must default false")
        if template.get("gates", {}).get("rollback_package") is not False: errors.append("release template rollback_package gate must default false")
        rr = template.get("runner_recovery", {})
        ra = template.get("runner_recovery_acceptance", {})
        mt5 = template.get("mt5_validation", {})
        if rr.get("schema_version") != "runner_recovery_evidence_v1": errors.append("release template missing runner recovery schema")
        if ra.get("schema_version") != "runner_recovery_acceptance_v1": errors.append("release template missing runner recovery acceptance schema")
        if mt5.get("schema_version") != "mt5_validation_evidence_v2": errors.append("release template missing MT5 validation v2 schema")
        rh = template.get("resilience_hardening", {})
        if rh.get("schema_version") != "resilience_hardening_evidence_v1": errors.append("release template missing resilience hardening schema")
        if "rollback_package" not in template: errors.append("release template missing rollback package readiness object")
        if template.get("gates", {}).get("ci_static") is not False: errors.append("release template ci_static gate must default false")
        if template.get("api_transport", {}).get("schema_version") != "api_transport_evidence_v1": errors.append("release template missing API transport evidence schema")
        if template.get("gates", {}).get("api_transport") is not False: errors.append("release template api_transport gate must default false")
        bc = template.get("broker_coverage", {})
        if bc.get("schema_version") != "broker_agnostic_coverage_v1": errors.append("release template missing broker coverage schema")
        if template.get("gates", {}).get("broker_coverage") is not False: errors.append("release template broker_coverage gate must default false")
        for cls in ("FX","METAL","INDEX","ENERGY","COMMODITY","CRYPTO","STOCK","ETF","FUTURE","BOND_RATE","OTHER"):
            if cls not in bc.get("asset_classes", {}): errors.append(f"release template broker_coverage missing class {cls}")
        soak = template.get("demo_soak", {})
        if soak.get("acceptance_record_schema_version") != "five_day_soak_acceptance_v2": errors.append("release template demo_soak must bind five_day_soak_acceptance_v2")
        for key in ("acceptance_record_id", "acceptance_record_digest", "acceptance_record_path"):
            if key not in soak: errors.append(f"release template demo_soak missing {key}")
    except Exception as exc: errors.append(f"RELEASE_EVIDENCE_TEMPLATE.json invalid: {exc}")

record_template = ROOT / "FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json"
if not record_template.exists(): errors.append("FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json missing")
else:
    try:
        rt = json.loads(record_template.read_text(encoding="utf-8"))
        if rt.get("schema_version") != "five_day_soak_acceptance_v2": errors.append("five-day template schema mismatch")
        if len(rt.get("days", [])) != 5: errors.append("five-day template must contain exactly five day rows")
        if rt.get("operator_review", {}).get("decision") != "HOLD": errors.append("five-day template must default operator decision to HOLD")
        if not str(rt.get("operator_record_path", "")).strip(): errors.append("five-day template must reference operator_record_path")
        for i, day in enumerate(rt.get("days", []), start=1):
            for key in ("reconciliation_checklist_path", "day_reconciled", "reconciled_by", "reconciled_at"):
                if key not in day: errors.append(f"five-day template day {i} missing {key}")
    except Exception as exc: errors.append(f"FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json invalid: {exc}")

final_template = ROOT / "FINAL_RELEASE_REVIEW_TEMPLATE.json"
if not final_template.exists():
    errors.append("FINAL_RELEASE_REVIEW_TEMPLATE.json missing")
else:
    try:
        fr = json.loads(final_template.read_text(encoding="utf-8"))
        if fr.get("schema_version") != "final_release_review_v1": errors.append("final review template schema mismatch")
        if fr.get("decision") != "HOLD": errors.append("final review template must default decision to HOLD")
        checks = fr.get("review", {})
        for key in ("runner_recovery_pass", "runner_recovery_acceptance_pass", "ci_bundle_pass", "ci_attestation_verified", "mt5_validation_pass",
                    "resilience_hardening_pass", "rollback_package_ready", "api_transport_pass", "five_day_acceptance_pass",
                    "soak_day_reconciliation_pass", "five_day_operator_record_complete"):
            if key not in checks: errors.append(f"final review template missing {key}")
            elif checks.get(key) is not False: errors.append(f"final review template {key} must default false")
    except Exception as exc:
        errors.append(f"FINAL_RELEASE_REVIEW_TEMPLATE.json invalid: {exc}")

for path_name, expected in [
    ("SOAK_EVIDENCE_SCHEMA.json", "demo_soak_evidence_v1"),
    ("CI_EVIDENCE_SCHEMA.json", "github_actions_static_evidence_v1"),
    ("CI_EVIDENCE_BUNDLE_SCHEMA.json", "ci_evidence_bundle_v1"),
    ("FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json", "five_day_soak_acceptance_v2"),
    ("RUNNER_RECOVERY_EVIDENCE_SCHEMA.json", "runner_recovery_evidence_v1"),
    ("RUNNER_RECOVERY_ACCEPTANCE_SCHEMA.json", "runner_recovery_acceptance_v1"),
    ("MT5_VALIDATION_EVIDENCE_SCHEMA.json", "mt5_validation_evidence_v2"),
    ("RESILIENCE_HARDENING_EVIDENCE_SCHEMA.json", "resilience_hardening_evidence_v1"),
    ("BROKER_COVERAGE_EVIDENCE_SCHEMA.json", "broker_agnostic_coverage_v1"),
]:
    p = ROOT / path_name
    if not p.exists(): errors.append(f"missing schema: {path_name}"); continue
    try:
        schema = json.loads(p.read_text(encoding="utf-8")); const = schema.get("properties", {}).get("schema_version", {}).get("const")
        if const != expected: errors.append(f"{path_name} schema version mismatch")
        if path_name == "FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json" and "operator_record_path" not in set(schema.get("required", [])):
            errors.append("FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json must require operator_record_path")
    except Exception as exc: errors.append(f"{path_name} invalid JSON: {exc}")

ci_schema_path = ROOT / "CI_EVIDENCE_SCHEMA.json"
if ci_schema_path.exists():
    try:
        ci_schema = json.loads(ci_schema_path.read_text(encoding="utf-8"))
        required = set(ci_schema.get("required", []))
        for field in ("job_id", "runner_id", "steps_executed", "static_job_conclusion", "job_metadata_sha256"):
            if field not in required: errors.append(f"CI_EVIDENCE_SCHEMA.json must require {field}")
    except Exception:
        pass

for path_name, tokens in {
    "tools/validate_release_evidence.py": ["validate_ci_release_record", "validate_runner_release_record", "validate_runner_acceptance_release_record", "validate_mt5_release_record", "validate_broker_coverage_release_record", "validate_runner_recovery", "validate_acceptance", "validate_mt5", "validate_bundle", "validate_api_transport", "broker_coverage", "runner_recovery_acceptance", "mt5_validation", "ci_static", "api_transport"],
    "tools/validate_broker_coverage_evidence.py": ["release_contract", "broker_coverage_schema", "BROKER COVERAGE EVIDENCE", "classification_passed", "broker_runtime_required", "live_execution_certified"],
    "tools/fetch_ci_job_metadata.py": ["runner_id", "steps_executed", "static-release-gate", "GITHUB_TOKEN", "/attempts/{args.run_attempt}/jobs"],
    "tools/build_ci_evidence.py": ["job_metadata_sha256", "static_job_conclusion", "runner_id"],
    "tools/validate_ci_evidence.py": ["validate_ci_value", "validate_job_metadata", "runner_id", "evidence_digest"],
    "tools/build_ci_bundle_manifest.py": ["ci_evidence_bundle_v1", "CI ATTESTATION VERIFY: PASS", "bundle_digest"],
    "tools/validate_ci_bundle.py": ["validate_bundle", "ci_evidence_bundle_v1", "attestation_verified", "CI BUNDLE VALIDATION"],
    "tools/validate_soak_evidence.py": ["validate_record", "acceptance_record_digest", "SOAK EVIDENCE SCHEMA CHECK"],
    "tools/validate_five_day_soak_record.py": ["five_day_soak_acceptance_v2", "reconciliation_checklist_path", "day_reconciled", "ACCEPT DAY", "record_digest"],
    "tools/validate_runner_recovery_evidence.py": ["runner_recovery_evidence_v1", "PRE_RUNNER_NO_STEPS", "recovery_probe", "release_static", "RUNNER RECOVERY EVIDENCE"],
    "tools/validate_runner_recovery_acceptance.py": ["runner_recovery_acceptance_v1", "validate_runner_recovery", "ci_bundle_digest", "matrix_sha256", "validate_matrix", "RUNNER RECOVERY ACCEPTANCE"],
    "tools/build_runner_recovery_acceptance.py": ["--runner-recovery", "--matrix", "--candidate-sha", "--ci-bundle-digest"],
    "tools/validate_mt5_validation_evidence.py": ["mt5_validation_evidence_v2", "compile_log_sha256", "report_sha256", "required_failure_fail_closed", "resilience_runtime", "M5-053", "validate_matrix_bundle", "MT5 VALIDATION EVIDENCE"],
    "tools/validate_resilience_hardening_evidence.py": ["resilience_hardening_evidence_v1", "RH-048", "RESILIENCE HARDENING EVIDENCE"],
    "tools/validate_rollback_readiness.py": ["VALIDATED_PACKAGE", "FIRST_CERTIFIED_RELEASE", "ROLLBACK READINESS"],
    "tools/build_mt5_validation_evidence.py": ["--git-sha", "--compile-log", "--tester-report", "--broker-history",
        "--intent-ledger", "--reconciliation", "--web-provenance", "--model-health", "--resilience-runtime-report"],
    "tools/build_runner_recovery_evidence.py": ["GITHUB_TOKEN", "runner-probe", "static-release-gate", "ci_bundle_manifest"],
    "tools/import_soak_snapshot.py": ["acceptance_record", "validate_record", "acceptance_record_digest"],
    "tools/validate_final_release_review.py": ["FINAL RELEASE REVIEW", '"runner_recovery":data.get("runner_recovery",{})',
        '"runner_recovery_acceptance":data.get("runner_recovery_acceptance",{})',
        '"mt5_validation":data.get("mt5_validation",{})',
        '"resilience_hardening":data.get("resilience_hardening",{})',
        '"rollback_package":data.get("rollback_package",{})',
        '"ci_static":data.get("ci_static",{})', '"broker_coverage":data.get("broker_coverage",{})', '"api_transport":data.get("api_transport",{})',
        "runner_recovery_acceptance_pass", "mt5_validation_pass", "broker_coverage_pass", "resilience_hardening_pass",
        "rollback_package_ready", "soak_day_reconciliation_pass"],
    "tools/validate_api_transport_evidence.py": ["api_transport_evidence_v1", "secret_leak_count", "gates.api_transport", "API TRANSPORT EVIDENCE"],
}.items():
    p = ROOT / path_name
    if not p.exists(): errors.append(f"missing validator/tool: {path_name}"); continue
    text = p.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text: errors.append(f"{path_name} missing required token: {token}")

for concept in [
    "SHA-256", "5 consecutive trading days", "GitHub Actions", "runner_id", "runner recovery", "runner-recovery acceptance", "MT5 validation", "soak-day reconciliation", "artifact attestation", "CI evidence bundle",
    "five-day", "zero-tolerance", "champion/challenger", "lifecycle", "API transport", "WebRequest", "proxy",
    "exactly-once", "resilience", "rollback", "provenance", "macro stress", "broker coverage",
]:
    if concept.lower() not in combined.lower(): errors.append(f"release docs missing concept: {concept}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors: print("ERROR:", err)
    sys.exit(1)
print("RELEASE CERTIFICATION STATIC CHECK: PASS")
