#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8")
PART28 = (ROOT / "GPT_EA_Part28_ReleaseCertification.mqh").read_text(encoding="utf-8")
PART28B = (ROOT / "GPT_EA_Part28B_CIReleaseEvidence.mqh").read_text(encoding="utf-8")
PART29 = (ROOT / "GPT_EA_Part29_DeploymentDriftGuard.mqh").read_text(encoding="utf-8")
PART37 = (ROOT / "GPT_EA_Part37_APITransport.mqh").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/static-quality.yml").read_text(encoding="utf-8")
errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"',
    '#include "GPT_EA_Part37_APITransport.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR7API',
    '#define ReleaseGateSummary ReleaseGateSummaryR7API',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR7API',
    '#define AdvancedSafetyInit AdvancedSafetyInitR7API',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR7API',
    '#define WebRequest GPTAPIWebRequest',
    '#undef WebRequest',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing current R6/R7 release wiring: {token}")

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
for name in ["InpReleaseRunnerRecoveryPassed", "InpReleaseCIStaticEvidencePassed", "InpReleaseCIBundleValidated"]:
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
    "GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA", "GPT_EA_REQUIRED_CI_SCHEMA_VERSION", "GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA", "GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA",
    "ReleaseRunnerRecoveryEvidenceAllows", "ReleaseCIStaticEvidenceAllows", "ReleaseFiveDaySoakRecordAllows", "ReleaseSafetyAllowsR6Evidence",
    "InpReleaseRunnerRecoveryEvidenceId", "InpReleaseRunnerRecoveryDigest", "InpReleaseSoakAcceptanceSchemaVersion",\n    "InpReleaseCIJobId", "InpReleaseCIRunnerId", "InpReleaseCIStepsExecuted", "InpReleaseCIAttestationVerified",
    "InpReleaseCIBundleSchemaVersion", "InpReleaseCIBundleDigest", "InpReleaseCIBundleValidated",
    "InpReleaseSoakAcceptanceRecordDigest", "GPT_EA_R6SupplementalEvidence.csv",
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
    "RELEASE_CERTIFICATION.md", "METAEDITOR_COMPILE_GATE.md", "DEMO_SOAK_ACCEPTANCE.md", "DEMO_SOAK_EVIDENCE.md",
    "CI_EVIDENCE_CONTRACT.md", "RUNNER_RECOVERY_EVIDENCE.md", "FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md", "FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md", "SOAK_DAY_RECONCILIATION_CHECKLIST.md",
    "RELEASE_GO_NO_GO.md", "FINAL_GO_NO_GO_REVIEW.md", "DEPLOYMENT_DRIFT_TESTS.md", "RELEASE_EVIDENCE_VALIDATION.md",
    "RELEASE_EVIDENCE_MANIFEST.md", "API_TRANSPORT_ARCHITECTURE.md", "MT5_WEBREQUEST_REQUIREMENTS.md", "API_TRANSPORT_TEST_MATRIX.md",
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
        if template.get("gates", {}).get("runner_recovery") is not False: errors.append("release template runner_recovery gate must default false")\n        rr = template.get("runner_recovery", {})\n        if rr.get("schema_version") != "runner_recovery_evidence_v1": errors.append("release template missing runner recovery schema")\n        if template.get("gates", {}).get("ci_static") is not False: errors.append("release template ci_static gate must default false")
        if template.get("api_transport", {}).get("schema_version") != "api_transport_evidence_v1": errors.append("release template missing API transport evidence schema")
        if template.get("gates", {}).get("api_transport") is not False: errors.append("release template api_transport gate must default false")
        soak = template.get("demo_soak", {})
        if soak.get("acceptance_record_schema_version") != "five_day_soak_acceptance_v2": errors.append("release template demo_soak must bind five_day_soak_acceptance_v2")\n        for key in ("acceptance_record_id", "acceptance_record_digest", "acceptance_record_path"):
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
        if not str(rt.get("operator_record_path", "")).strip(): errors.append("five-day template must reference operator_record_path")\n        for i, day in enumerate(rt.get("days", []), start=1):\n            for key in ("reconciliation_checklist_path", "day_reconciled", "reconciled_by", "reconciled_at"):\n                if key not in day: errors.append(f"five-day template day {i} missing {key}")
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
        for key in ("ci_bundle_pass", "ci_attestation_verified", "api_transport_pass", "five_day_acceptance_pass", "five_day_operator_record_complete"):
            if key not in checks: errors.append(f"final review template missing {key}")
            elif checks.get(key) is not False: errors.append(f"final review template {key} must default false")
    except Exception as exc:
        errors.append(f"FINAL_RELEASE_REVIEW_TEMPLATE.json invalid: {exc}")

for path_name, expected in [
    ("SOAK_EVIDENCE_SCHEMA.json", "demo_soak_evidence_v1"),
    ("CI_EVIDENCE_SCHEMA.json", "github_actions_static_evidence_v1"),
    ("CI_EVIDENCE_BUNDLE_SCHEMA.json", "ci_evidence_bundle_v1"),
    ("FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json", "five_day_soak_acceptance_v2"),\n    ("RUNNER_RECOVERY_EVIDENCE_SCHEMA.json", "runner_recovery_evidence_v1"),
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
    "tools/validate_release_evidence.py": ["validate_ci_release_record", "validate_bundle", "validate_api_transport", "ci_static", "api_transport"],
    "tools/fetch_ci_job_metadata.py": ["runner_id", "steps_executed", "static-release-gate", "GITHUB_TOKEN", "/attempts/{args.run_attempt}/jobs"],
    "tools/build_ci_evidence.py": ["job_metadata_sha256", "static_job_conclusion", "runner_id"],
    "tools/validate_ci_evidence.py": ["validate_ci_value", "validate_job_metadata", "runner_id", "evidence_digest"],
    "tools/build_ci_bundle_manifest.py": ["ci_evidence_bundle_v1", "CI ATTESTATION VERIFY: PASS", "bundle_digest"],
    "tools/validate_ci_bundle.py": ["validate_bundle", "ci_evidence_bundle_v1", "attestation_verified", "CI BUNDLE VALIDATION"],
    "tools/validate_soak_evidence.py": ["validate_record", "acceptance_record_digest", "SOAK EVIDENCE SCHEMA CHECK"],
    "tools/validate_five_day_soak_record.py": ["five_day_soak_acceptance_v2", "reconciliation_checklist_path", "day_reconciled", "ACCEPT DAY", "record_digest"],\n    "tools/validate_runner_recovery_evidence.py": ["runner_recovery_evidence_v1", "PRE_RUNNER_NO_STEPS", "recovery_probe", "release_static", "RUNNER RECOVERY EVIDENCE"],
    "tools/import_soak_snapshot.py": ["acceptance_record", "validate_record", "acceptance_record_digest"],
    "tools/validate_final_release_review.py": ["FINAL RELEASE REVIEW", '"ci_static": data.get("ci_static", {})', '"api_transport": data.get("api_transport", {})', "ci_bundle_pass", "five_day_operator_record_complete"],
    "tools/validate_api_transport_evidence.py": ["api_transport_evidence_v1", "secret_leak_count", "gates.api_transport", "API TRANSPORT EVIDENCE"],
}.items():
    p = ROOT / path_name
    if not p.exists(): errors.append(f"missing validator/tool: {path_name}"); continue
    text = p.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text: errors.append(f"{path_name} missing required token: {token}")

for concept in [
    "SHA-256", "5 consecutive trading days", "GitHub Actions", "runner_id", "runner recovery", "soak-day reconciliation", "artifact attestation", "CI evidence bundle",
    "five-day", "zero-tolerance", "champion/challenger", "lifecycle", "API transport", "WebRequest", "proxy",
]:
    if concept.lower() not in combined.lower(): errors.append(f"release docs missing concept: {concept}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors: print("ERROR:", err)
    sys.exit(1)
print("RELEASE CERTIFICATION STATIC CHECK: PASS")
