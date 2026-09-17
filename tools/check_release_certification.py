#!/usr/bin/env python3
from __future__ import annotations

import json
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
FINAL_REVIEW_DOC = (ROOT / "FINAL_GO_NO_GO_REVIEW.md").read_text(encoding="utf-8")
DRIFT_DOC = (ROOT / "DEPLOYMENT_DRIFT_TESTS.md").read_text(encoding="utf-8")
EVIDENCE_DOC = (ROOT / "RELEASE_EVIDENCE_VALIDATION.md").read_text(encoding="utf-8")
MANIFEST = (ROOT / "RELEASE_EVIDENCE_MANIFEST.md").read_text(encoding="utf-8")
TEMPLATE_PATH = ROOT / "RELEASE_EVIDENCE_TEMPLATE.json"
SOAK_SCHEMA_PATH = ROOT / "SOAK_EVIDENCE_SCHEMA.json"
FINAL_TEMPLATE_PATH = ROOT / "FINAL_RELEASE_REVIEW_TEMPLATE.json"
VALIDATOR_PATH = ROOT / "tools" / "validate_release_evidence.py"
SOAK_VALIDATOR_PATH = ROOT / "tools" / "validate_soak_evidence.py"
FINAL_VALIDATOR_PATH = ROOT / "tools" / "validate_final_release_review.py"

errors: list[str] = []

required_main = [
    '#include "GPT_EA_Part28_ReleaseCertification.mqh"',
    '#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR6',
    '#define ReleaseGateSummary ReleaseGateSummaryR6',
    '#define StopFailureObservabilityInit StopFailureObservabilityInitR6',
    '#define AdvancedSafetyInit AdvancedSafetyInitR6',
    '#define AdvancedSafetyTimer AdvancedSafetyTimerR6',
]
for token in required_main:
    if token not in MAIN:
        errors.append(f"missing R6 release wiring: {token}")

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
        errors.append(f"release evidence flag must exist and default false: {name}")

required_concrete_inputs = [
    "InpReleaseSourceCommitSha", "InpReleaseEx5Sha256", "InpReleaseSetSha256", "InpReleaseCompileEvidenceId",
    "InpReleaseMetaEditorBuild", "InpReleaseMT5Build", "InpReleaseSoakSchemaVersion", "InpReleaseSoakEvidenceId",
    "InpReleaseSoakEvidenceDigest", "InpReleaseSoakTradingDays", "InpReleaseSoakLondonSessions", "InpReleaseSoakNYSessions",
    "InpReleaseSoakOverlapObserved", "InpReleaseSoakNewsDayObserved", "InpReleaseSoakRolloverObserved",
    "InpReleaseSoakRestartObserved", "InpReleaseSoakReconnectObserved", "InpReleaseSoakScheduledScans",
    "InpReleaseSoakContinuousScans", "InpReleaseSoakCheckpointUpdates", "InpReleaseSoakBackupCheckpointUpdates",
    "InpReleaseSoakZeroToleranceFailures", "InpReleaseSoakUnresolvedCriticalStates", "InpReleaseSoakDuplicateOrders",
    "InpReleaseSoakDuplicatePartials", "InpReleaseSoakSLRegressions", "InpReleaseSoakUnprotectedAuthorizations",
    "InpReleaseSoakReleaseGateBypasses", "InpReleaseSoakAnalyticsDuplicateFinal", "InpReleaseSoakStopJoinFailures",
    "InpReleaseSoakDashboardMismatches", "InpReleaseSoakRuntimeCriticalErrors", "InpReleaseSoakSecretsExposed",
    "InpReleaseSoakExecutionLogPresent", "InpReleaseSoakStopLogPresent", "InpReleaseSoakReleaseLogPresent",
    "InpReleaseFinalReviewEvidenceId", "InpReleaseFinalReviewDigest", "InpReleaseFinalDecision",
    "InpReleaseFinalReviewer", "InpReleaseFinalReviewTimestamp",
]
for name in required_concrete_inputs:
    if name not in PART28:
        errors.append(f"Part28 missing concrete R6 release-evidence input: {name}")

for token in ["ReleaseArtifactIdentityAllows", "ReleaseDemoSoakEvidenceAllows", "ReleaseFinalReviewAllows", "ReleaseHexString"]:
    if token not in PART28:
        errors.append(f"Part28 missing concrete evidence validator: {token}")

m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', PART28)
release_id = ""
if not m:
    errors.append("required release validation ID not found")
else:
    release_id = m.group(1)
    if "R6" not in release_id:
        errors.append("current release validation ID is not R6")
    if release_id not in DOC:
        errors.append("RELEASE_CERTIFICATION.md is not synchronized with current R6 release validation ID")

for token in [
    "StopObservabilityAllowsNewEntries", "RefreshCertifiedReleaseState", "ReleaseSafetyAllowsCertified",
    "InpReleaseArtifactIdentityArchived", "InpReleaseAdaptivePortfolioPassed", "InpReleaseExecutionLearningPassed",
    "InpReleaseChampionChallengerPassed", "InpReleaseLifecycleIntegrityPassed", "InpReleaseDeploymentProfilePassed",
    "GPT_EA_ReleaseEvidence.csv", "GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION",
]:
    if token not in PART28:
        errors.append(f"Part28 missing R6 release contract token: {token}")

for token in [
    "CaptureDeploymentBaseline", "StructuralSymbolDriftAllows", "DeploymentDriftAllows", "ReleaseSafetyAllowsR6",
    "RefreshR6ReleaseState", "AdvancedSafetyInitR6", "AdvancedSafetyTimerR6", "StopFailureObservabilityInitR6",
]:
    if token not in PART29:
        errors.append(f"Part29 missing R6 deployment-drift token: {token}")

required_docs = {
    "METAEDITOR_COMPILE_GATE.md": COMPILE_DOC,
    "DEMO_SOAK_ACCEPTANCE.md": SOAK_DOC,
    "RELEASE_GO_NO_GO.md": GO_NO_GO,
    "FINAL_GO_NO_GO_REVIEW.md": FINAL_REVIEW_DOC,
    "DEPLOYMENT_DRIFT_TESTS.md": DRIFT_DOC,
    "RELEASE_EVIDENCE_VALIDATION.md": EVIDENCE_DOC,
}
for name, text in required_docs.items():
    if len(text.strip()) < 200:
        errors.append(f"release contract document missing/too small: {name}")
    if name not in MANIFEST and name not in {"FINAL_GO_NO_GO_REVIEW.md"}:
        errors.append(f"RELEASE_EVIDENCE_MANIFEST.md does not reference {name}")

if not TEMPLATE_PATH.exists():
    errors.append("RELEASE_EVIDENCE_TEMPLATE.json is missing")
else:
    try:
        template = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
        if release_id and template.get("release_validation_id") != release_id:
            errors.append("RELEASE_EVIDENCE_TEMPLATE.json release ID is not synchronized with Part28")
        if template.get("demo_soak", {}).get("schema_version") != "demo_soak_evidence_v1":
            errors.append("release evidence template does not use demo_soak_evidence_v1")
        if template.get("final_review", {}).get("schema_version") != "final_release_review_v1":
            errors.append("release evidence template does not use final_release_review_v1")
    except Exception as exc:
        errors.append(f"RELEASE_EVIDENCE_TEMPLATE.json is invalid JSON: {exc}")

if not SOAK_SCHEMA_PATH.exists():
    errors.append("SOAK_EVIDENCE_SCHEMA.json is missing")
else:
    try:
        schema = json.loads(SOAK_SCHEMA_PATH.read_text(encoding="utf-8"))
        if schema.get("properties", {}).get("schema_version", {}).get("const") != "demo_soak_evidence_v1":
            errors.append("SOAK_EVIDENCE_SCHEMA.json schema version is incorrect")
    except Exception as exc:
        errors.append(f"SOAK_EVIDENCE_SCHEMA.json is invalid JSON: {exc}")

if not FINAL_TEMPLATE_PATH.exists():
    errors.append("FINAL_RELEASE_REVIEW_TEMPLATE.json is missing")
else:
    try:
        final_template = json.loads(FINAL_TEMPLATE_PATH.read_text(encoding="utf-8"))
        if release_id and final_template.get("release_validation_id") != release_id:
            errors.append("FINAL_RELEASE_REVIEW_TEMPLATE.json release ID is not synchronized with Part28")
        if final_template.get("schema_version") != "final_release_review_v1":
            errors.append("FINAL_RELEASE_REVIEW_TEMPLATE.json schema version is incorrect")
    except Exception as exc:
        errors.append(f"FINAL_RELEASE_REVIEW_TEMPLATE.json is invalid JSON: {exc}")

for path, tokens in {
    VALIDATOR_PATH: ["validate_soak", "compile_errors", "compile_warnings", "final_review", "operator_review"],
    SOAK_VALIDATOR_PATH: ["validate_subset_schema", "evidence_digest", "SOAK EVIDENCE SCHEMA CHECK"],
    FINAL_VALIDATOR_PATH: ["release_basis", "release_evidence_digest", "FINAL RELEASE REVIEW"],
}.items():
    if not path.exists():
        errors.append(f"missing validator: {path.relative_to(ROOT)}")
        continue
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            errors.append(f"{path.name} missing required check/token: {token}")

for token in [
    "SHA-256", "5 consecutive trading days", "zero", "adaptive portfolio", "champion/challenger", "lifecycle",
    "release-evidence-validation.txt", "soak-evidence-validation.txt", "final-release-review-validation.txt",
]:
    combined = COMPILE_DOC + "\n" + SOAK_DOC + "\n" + GO_NO_GO + "\n" + FINAL_REVIEW_DOC + "\n" + EVIDENCE_DOC + "\n" + MANIFEST
    if token.lower() not in combined.lower():
        errors.append(f"R6 release contracts missing expected evidence concept: {token}")

if errors:
    print("RELEASE CERTIFICATION STATIC CHECK: FAILED")
    for err in errors:
        print("ERROR:", err)
    sys.exit(1)

print("RELEASE CERTIFICATION STATIC CHECK: PASS")
