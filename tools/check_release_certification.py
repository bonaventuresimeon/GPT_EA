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
errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR6Evidence',
    '#define ReleaseGateSummary ReleaseGateSummaryR6Evidence',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR6Evidence',
    '#define AdvancedSafetyInit AdvancedSafetyInitR6Evidence',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR6Evidence',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing R6 evidence wiring: {token}")

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
if not re.search(r"input\s+bool\s+InpReleaseCIStaticEvidencePassed\s*=\s*false\s*;", PART28B):
    errors.append("InpReleaseCIStaticEvidencePassed must default false")

m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', PART28)
release_id = m.group(1) if m else ""
if release_id != "GPT_EA_FULL_INTELLIGENCE_R6_20260917":
    errors.append("current release validation ID must be GPT_EA_FULL_INTELLIGENCE_R6_20260917")

for token in [
    "ReleaseArtifactIdentityAllows", "ReleaseDemoSoakEvidenceAllows", "ReleaseFinalReviewAllows",
    "StopObservabilityAllowsNewEntries", "ReleaseSafetyAllowsCertified", "GPT_EA_ReleaseEvidence.csv",
    "GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION",
]:
    if token not in PART28:
        errors.append(f"Part28 missing R6 release contract token: {token}")

for token in [
    "CaptureDeploymentBaseline", "StructuralSymbolDriftAllows", "DeploymentDriftAllows",
    "ReleaseSafetyAllowsR6", "RefreshR6ReleaseState",
]:
    if token not in PART29:
        errors.append(f"Part29 missing deployment-drift token: {token}")

for token in [
    "GPT_EA_REQUIRED_CI_SCHEMA_VERSION", "GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA",
    "ReleaseCIStaticEvidenceAllows", "ReleaseFiveDaySoakRecordAllows",
    "ReleaseSafetyAllowsR6Evidence", "InpReleaseCIRunnerId", "InpReleaseCIStepsExecuted",
    "InpReleaseCIAttestationVerified", "InpReleaseSoakAcceptanceRecordDigest",
    "GPT_EA_R6SupplementalEvidence.csv",
]:
    if token not in PART28B:
        errors.append(f"Part28B missing supplemental R6 evidence token: {token}")

docs = [
    "RELEASE_CERTIFICATION.md", "METAEDITOR_COMPILE_GATE.md", "DEMO_SOAK_ACCEPTANCE.md",
    "DEMO_SOAK_EVIDENCE.md", "CI_EVIDENCE_CONTRACT.md", "FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md",
    "RELEASE_GO_NO_GO.md", "FINAL_GO_NO_GO_REVIEW.md", "DEPLOYMENT_DRIFT_TESTS.md",
    "RELEASE_EVIDENCE_VALIDATION.md", "RELEASE_EVIDENCE_MANIFEST.md",
]
combined = ""
for name in docs:
    p = ROOT / name
    if not p.exists():
        errors.append(f"release contract document missing: {name}")
        continue
    text = p.read_text(encoding="utf-8")
    if len(text.strip()) < 200:
        errors.append(f"release contract document too small: {name}")
    combined += "\n" + text

template_path = ROOT / "RELEASE_EVIDENCE_TEMPLATE.json"
if not template_path.exists():
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json missing")
else:
    try:
        template = json.loads(template_path.read_text(encoding="utf-8"))
        if template.get("release_validation_id") != release_id:
            errors.append("release evidence template release ID mismatch")
        if template.get("ci_static", {}).get("schema_version") != "github_actions_static_evidence_v1":
            errors.append("release template missing CI evidence schema")
        if template.get("gates", {}).get("ci_static") is not False:
            errors.append("release template ci_static gate must default false")
        soak = template.get("demo_soak", {})
        for key in ("acceptance_record_id", "acceptance_record_digest", "acceptance_record_path"):
            if key not in soak:
                errors.append(f"release template demo_soak missing {key}")
    except Exception as exc:
        errors.append(f"RELEASE_EVIDENCE_TEMPLATE.json invalid: {exc}")

for path_name, expected in [
    ("SOAK_EVIDENCE_SCHEMA.json", "demo_soak_evidence_v1"),
    ("CI_EVIDENCE_SCHEMA.json", "github_actions_static_evidence_v1"),
    ("FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json", "five_day_soak_acceptance_v1"),
]:
    p = ROOT / path_name
    if not p.exists():
        errors.append(f"missing schema: {path_name}")
        continue
    try:
        schema = json.loads(p.read_text(encoding="utf-8"))
        const = schema.get("properties", {}).get("schema_version", {}).get("const")
        if const != expected:
            errors.append(f"{path_name} schema version mismatch")
    except Exception as exc:
        errors.append(f"{path_name} invalid JSON: {exc}")

for path_name, tokens in {
    "tools/validate_release_evidence.py": ["validate_ci_release_record", "validate_soak", "validate_record", "ci_static"],
    "tools/validate_ci_evidence.py": ["validate_ci_value", "runner_name", "evidence_digest"],
    "tools/validate_soak_evidence.py": ["validate_record", "acceptance_record_digest", "SOAK EVIDENCE SCHEMA CHECK"],
    "tools/validate_five_day_soak_record.py": ["five_day_soak_acceptance_v1", "stale_human_wait_closed", "record_digest"],
    "tools/import_soak_snapshot.py": ["acceptance_record", "validate_record", "acceptance_record_digest"],
    "tools/validate_final_release_review.py": ["FINAL RELEASE REVIEW"],
}.items():
    p = ROOT / path_name
    if not p.exists():
        errors.append(f"missing validator/tool: {path_name}")
        continue
    text = p.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            errors.append(f"{path_name} missing required token: {token}")

for concept in [
    "SHA-256", "5 consecutive trading days", "GitHub Actions", "runner_id",
    "artifact attestation", "five-day", "zero-tolerance", "champion/challenger", "lifecycle",
]:
    if concept.lower() not in combined.lower():
        errors.append(f"R6 release docs missing concept: {concept}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors:
        print("ERROR:", err)
    sys.exit(1)

print("RELEASE CERTIFICATION STATIC CHECK: PASS")
