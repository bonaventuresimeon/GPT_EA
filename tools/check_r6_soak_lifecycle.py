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
    "five_schema": ROOT/"FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json",
    "five_template": ROOT/"FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json",
    "five_record_doc": ROOT/"FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md",
    "operator_template": ROOT/"FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md",
    "day_checklist": ROOT/"SOAK_DAY_RECONCILIATION_CHECKLIST.md",
    "evidence_doc": ROOT/"DEMO_SOAK_EVIDENCE.md",
    "report": ROOT/"DEMO_SOAK_REPORT_TEMPLATE.md",
    "matrix": ROOT/"R6_LIFECYCLE_SOAK_TEST_MATRIX.md",
    "importer": ROOT/"tools/import_soak_snapshot.py",
    "five_validator": ROOT/"tools/validate_five_day_soak_record.py",
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
five_validator=paths["five_validator"].read_text(encoding="utf-8")

for token in [
    '#include "GPT_EA_Part36_DemoSoakEvidence.mqh"',
    '#include "GPT_EA_Part35_AdaptiveIntegration.mqh"',
    '#include "GPT_EA_Part37_APITransport.mqh"',
    '#define ReleaseSafetyAllows ReleaseSafetyAllowsR7API',
]:
    if token not in main: errors.append(f"main missing current soak/release token: {token}")

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
        "schema_version","evidence_id","acceptance_record_schema_version","start","end","trading_days","london_sessions","ny_sessions",
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

try:
    five_schema=json.loads(paths["five_schema"].read_text(encoding="utf-8"))
    required=set(five_schema.get("required",[]))
    for field in ("operator_record_path","report_path","operator_review","lifecycle_checks","reconciliation","days"):
        if field not in required: errors.append(f"five-day acceptance schema must require {field}")
    day_props=five_schema.get("properties",{}).get("days",{}).get("items",{}).get("properties",{})
    for field in ("reconciliation_checklist_path","day_reconciled","reconciled_by","reconciled_at"):
        if field not in day_props: errors.append(f"five-day acceptance day schema missing {field}")
    if five_schema.get("properties",{}).get("schema_version",{}).get("const")!="five_day_soak_acceptance_v2":
        errors.append("five-day acceptance schema version mismatch")
except Exception as exc:
    errors.append(f"FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json invalid: {exc}")

try:
    five_template=json.loads(paths["five_template"].read_text(encoding="utf-8"))
    if len(five_template.get("days",[]))!=5: errors.append("five-day template must have exactly five day rows")
    if five_template.get("schema_version")!="five_day_soak_acceptance_v2": errors.append("five-day template must use v2 reconciliation schema")
    for i,day in enumerate(five_template.get("days",[]),start=1):
        for key in ("reconciliation_checklist_path","day_reconciled","reconciled_by","reconciled_at"):
            if key not in day: errors.append(f"five-day template day {i} missing {key}")
    if not str(five_template.get("operator_record_path","")).strip(): errors.append("five-day template operator_record_path is missing")
    if five_template.get("operator_review",{}).get("decision")!="HOLD": errors.append("five-day template operator decision must default HOLD")
except Exception as exc:
    errors.append(f"FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json invalid: {exc}")

for token in [
    "machine observations", "stale approval", "WAIT_CONFIRMATION", "SOAK_EVIDENCE_SCHEMA.json",
    "import_soak_snapshot.py", "validate_soak_evidence.py", "validate_release_evidence.py",
    "5 consecutive trading days", "checkpoint", "zero-tolerance",
]:
    if token.lower() not in doc.lower(): errors.append(f"DEMO_SOAK_EVIDENCE.md missing concept: {token}")

for token in ["Candidate identity","Zero-tolerance reconciliation","Schema and digest","Operator conclusion"]:
    if token not in report: errors.append(f"DEMO_SOAK_REPORT_TEMPLATE.md missing section: {token}")

operator_doc=paths["operator_template"].read_text(encoding="utf-8")
day_doc=paths["day_checklist"].read_text(encoding="utf-8")
for token in ["Daily reconciliation","Lifecycle acceptance","Zero-tolerance reconciliation","Operator decision"]:
    if token not in operator_doc: errors.append(f"operator record template missing section: {token}")

for token in ["Day identity","Order/deal/execution reconciliation","Protection and stop-management reconciliation","Day decision","ACCEPT DAY"]:
    if token not in day_doc: errors.append(f"soak-day checklist missing section/token: {token}")

five_doc=paths["five_record_doc"].read_text(encoding="utf-8")
for token in ["operator_record_path","FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md","validate_five_day_soak_record.py"]:
    if token not in five_doc: errors.append(f"five-day acceptance record doc missing token: {token}")

for token in ["LS-001","LS-002","LS-008","DS-010","DS-020","DS-030","DS-040","DS-050","DS-070","DS-073","DS-080","DS-085"]:
    if token not in matrix: errors.append(f"R6_LIFECYCLE_SOAK_TEST_MATRIX.md missing release case: {token}")

for token in ["canonical_digest", "validate_soak", "evidence_digest", "No release-evidence file was modified"]:
    if token not in importer: errors.append(f"import_soak_snapshot.py missing safety token: {token}")
for token in ["five_day_soak_acceptance_v2","reconciliation_checklist_path","day_reconciled","ACCEPT DAY","operator_record_path","record_digest"]:
    if token not in five_validator: errors.append(f"five-day validator missing contract token: {token}")

if errors:
    print("R6 SOAK/LIFECYCLE STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)

print("R6 SOAK/LIFECYCLE STATIC CHECK: PASS")
