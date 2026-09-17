#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
errors=[]

paths={
    "main": ROOT/"GPT_EA.mq5",
    "part28": ROOT/"GPT_EA_Part28_ReleaseCertification.mqh",
    "part35": ROOT/"GPT_EA_Part35_AdaptiveIntegration.mqh",
    "part36": ROOT/"GPT_EA_Part36_DemoSoakEvidence.mqh",
    "schema": ROOT/"SOAK_EVIDENCE_SCHEMA.json",
    "evidence_doc": ROOT/"DEMO_SOAK_EVIDENCE.md",
    "report": ROOT/"DEMO_SOAK_REPORT_TEMPLATE.md",
    "matrix": ROOT/"R6_LIFECYCLE_SOAK_TEST_MATRIX.md",
    "importer": ROOT/"tools/import_soak_snapshot.py",
    "soak_validator": ROOT/"tools/validate_soak_evidence.py",
    "release_validator": ROOT/"tools/validate_release_evidence.py",
}
for name,path in paths.items():
    if not path.exists(): errors.append(f"missing R6 soak/lifecycle artifact: {path.relative_to(ROOT)}")

if errors:
    print("R6 SOAK/LIFECYCLE STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)

main=paths["main"].read_text(encoding="utf-8")
p28=paths["part28"].read_text(encoding="utf-8")
p35=paths["part35"].read_text(encoding="utf-8")
p36=paths["part36"].read_text(encoding="utf-8")
doc=paths["evidence_doc"].read_text(encoding="utf-8")
report=paths["report"].read_text(encoding="utf-8")
matrix=paths["matrix"].read_text(encoding="utf-8")
importer=paths["importer"].read_text(encoding="utf-8")

for token in [
    '#include "GPT_EA_Part36_DemoSoakEvidence.mqh"',
    '#include "GPT_EA_Part35_AdaptiveIntegration.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR6',
]:
    if token not in main: errors.append(f"main missing R6 soak/release token: {token}")

p36pos=main.find('#include "GPT_EA_Part36_DemoSoakEvidence.mqh"')
p35pos=main.find('#include "GPT_EA_Part35_AdaptiveIntegration.mqh"')
if p36pos<0 or p35pos<0 or p36pos>p35pos:
    errors.append("Part36 must be included before Part35 because Part35 invokes the soak/lifecycle hooks")

for token in [
    "LIFECYCLE_WAIT_HUMAN_APPROVAL", "LIFECYCLE_WAIT_MARKET_CONFIRMATION",
    "DemoSoakEvidenceInit();", "DemoSoakEvidenceTimer();", "DemoSoakEvidenceShutdown();",
    "ObserveDemoSoakScanCard", "LIFECYCLE_WAIT_KIND",
]:
    if token not in p35: errors.append(f"Part35 missing lifecycle/soak integration token: {token}")

for token in [
    'GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA="demo_soak_evidence_v1"',
    "ReconcileStaleApprovalWaitStates", "LIFECYCLE_WAIT_HUMAN_APPROVAL",
    "DemoSoakPendingApprovalActive", "WriteDemoSoakJsonSnapshot", "RecordDemoSoakIncident",
    "SCHEDULED_SCANS", "CONTINUOUS_SCANS", "CHECKPOINT_UPDATES", "BACKUP_CHECKPOINT_UPDATES",
    "DUP_ORDERS", "DUP_PARTIALS", "SL_REGRESSIONS", "UNPROTECTED_AUTH", "RELEASE_BYPASS",
    "ANALYTICS_DUP_FINAL", "STOP_JOIN_FAIL", "DASH_MISMATCH", "RUNTIME_CRITICAL", "SECRETS",
    "InpExecutionJournalFile", "InpStopFailureObservabilityFile", "InpReleaseEvidenceSnapshotFile",
    "RecoveryCheckpointHeaderValid", "RecoveryBackupFileName", "DemoSoakCoverageReady",
]:
    if token not in p36: errors.append(f"Part36 missing R6 soak/lifecycle token: {token}")

if re.search(r"Machine-observed R5 demo-soak|R5 soak gate",p36,re.I):
    errors.append("Part36 still contains stale R5 release wording")

for token in [
    'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917"',
    'GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION   = "demo_soak_evidence_v1"',
    "InpReleaseSoakEvidenceDigest", "InpReleaseSoakScheduledScans", "InpReleaseSoakContinuousScans",
    "InpReleaseSoakCheckpointUpdates", "InpReleaseSoakBackupCheckpointUpdates",
    "InpReleaseSoakDuplicateOrders", "InpReleaseSoakDuplicatePartials", "InpReleaseSoakSLRegressions",
    "InpReleaseSoakUnprotectedAuthorizations", "InpReleaseSoakReleaseGateBypasses",
    "InpReleaseSoakAnalyticsDuplicateFinal", "InpReleaseSoakStopJoinFailures",
    "InpReleaseSoakDashboardMismatches", "InpReleaseSoakRuntimeCriticalErrors", "InpReleaseSoakSecretsExposed",
]:
    if token not in p28: errors.append(f"Part28 missing R6 soak contract token: {token}")

try:
    schema=json.loads(paths["schema"].read_text(encoding="utf-8"))
    props=schema.get("properties",{})
    required=set(schema.get("required",[]))
    expected={
        "schema_version","evidence_id","start","end","trading_days","london_sessions","ny_sessions",
        "overlap_observed","news_day_observed","rollover_observed","restart_observed","reconnect_observed",
        "scheduled_scans","continuous_scans","checkpoint_updates","backup_checkpoint_updates",
        "zero_tolerance_failures","unresolved_critical_states","duplicate_orders","duplicate_partials",
        "sl_regressions","unprotected_new_authorizations","release_gate_bypasses",
        "analytics_duplicate_finalizations","stop_failure_join_failures","dashboard_gate_mismatches",
        "runtime_critical_errors","secrets_exposed","execution_log_present","stop_log_present",
        "release_evidence_log_present","report_path",
    }
    missing=sorted(expected-required)
    if missing: errors.append("SOAK_EVIDENCE_SCHEMA.json missing required fields: "+", ".join(missing))
    if props.get("schema_version",{}).get("const")!="demo_soak_evidence_v1":
        errors.append("SOAK_EVIDENCE_SCHEMA.json has wrong schema version")
except Exception as exc:
    errors.append(f"SOAK_EVIDENCE_SCHEMA.json invalid: {exc}")

for token in [
    "machine observations", "stale approval", "WAIT_CONFIRMATION", "SOAK_EVIDENCE_SCHEMA.json",
    "import_soak_snapshot.py", "validate_soak_evidence.py", "validate_release_evidence.py",
    "5 consecutive trading days", "checkpoint", "zero-tolerance",
]:
    if token.lower() not in doc.lower(): errors.append(f"DEMO_SOAK_EVIDENCE.md missing concept: {token}")

for token in ["Candidate identity","Zero-tolerance reconciliation","Schema and digest","Operator conclusion"]:
    if token not in report: errors.append(f"DEMO_SOAK_REPORT_TEMPLATE.md missing section: {token}")

for token in ["LS-001","LS-002","LS-008","DS-010","DS-020","DS-030","DS-040","DS-050","DS-070","DS-073","DS-080","DS-085"]:
    if token not in matrix: errors.append(f"R6_LIFECYCLE_SOAK_TEST_MATRIX.md missing release case: {token}")

for token in ["canonical_digest", "validate_soak", "evidence_digest", "No release-evidence file was modified"]:
    if token not in importer: errors.append(f"import_soak_snapshot.py missing safety token: {token}")

if errors:
    print("R6 SOAK/LIFECYCLE STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)

print("R6 SOAK/LIFECYCLE STATIC CHECK: PASS")
