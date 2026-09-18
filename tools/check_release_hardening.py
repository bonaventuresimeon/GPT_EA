#!/usr/bin/env python3
from __future__ import annotations
import json, sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()
ROOT=Path(__file__).resolve().parents[1]
errors=[]
docs=[
 "docs/FEATURE_FREEZE_RELEASE_POLICY.md","docs/FAIL_CLOSED_RECOVERY_DRILL.md",
 "docs/RELEASE_CANDIDATE_SMOKE_TEST.md","docs/EVIDENCE_RETENTION_POLICY.md",
 "docs/DEMO_VALIDATION_HARNESS.md","docs/SECURITY_THREAT_MODEL.md",
 "docs/SIGNED_LICENSE_ARCHITECTURE.md","docs/REPRODUCIBLE_RELEASE_PACKAGING.md",
 "docs/SAFE_UPDATE_ROLLBACK_ARCHITECTURE.md","docs/BACKTEST_LIVE_DRIFT_MONITORING.md",
 "docs/PRODUCTION_INCIDENT_SYSTEM.md","docs/PROMPT_INJECTION_HARDENING.md",
 "docs/OPERATOR_DASHBOARD.md","docs/RELEASE_HARDENING_ROLLOUT.md",
]
tools=[
 "tools/validate_fail_closed_recovery_drill.py","tools/validate_release_candidate_smoke.py",
 "tools/validate_demo_validation_harness.py","tools/scan_release_secrets.py",
 "tools/build_customer_release_package.py","tools/validate_signed_license_entitlement.py",
]
for name in docs+tools:
    p=ROOT/name
    if not p.exists() or p.stat().st_size<100: errors.append(f"missing/too-small hardening artifact: {name}")

bundle=json.loads((ROOT/"GPT_EA_DATA.json").read_text(encoding="utf-8"))
j=bundle.get("documents",{})
for name in ["FAIL_CLOSED_RECOVERY_DRILL_TEMPLATE.json","RELEASE_CANDIDATE_SMOKE_TEMPLATE.json","DEMO_VALIDATION_RUN_TEMPLATE.json","SIGNED_LICENSE_ENTITLEMENT_SCHEMA.json","SIGNED_LICENSE_ENTITLEMENT_TEMPLATE.json","PRODUCTION_INCIDENT_TEMPLATE.json","DRIFT_BASELINE_TEMPLATE.json","EVIDENCE_RETENTION_REGISTER_TEMPLATE.json","OPERATOR_STATUS_TEMPLATE.json"]:
    if name not in j: errors.append(f"GPT_EA_DATA.json missing {name}")
rel=j.get("RELEASE_EVIDENCE_TEMPLATE.json",{})
gates=rel.get("gates",{})
for key in ["fail_closed_recovery_drill","release_candidate_smoke","demo_validation_harness"]:
    if key not in rel: errors.append(f"release evidence missing section: {key}")
    if gates.get(key) is not False: errors.append(f"default gate {key} must be false")
if "security_review" not in rel or gates.get("security_review") is not False: errors.append("security_review must exist and default false")
if "evidence_retention" not in rel or gates.get("evidence_retention") is not False: errors.append("evidence_retention must exist and default false")
final=j.get("FINAL_RELEASE_REVIEW_TEMPLATE.json",{}).get("review",{})
for key in ["fail_closed_recovery_drill_pass","release_candidate_smoke_pass","demo_validation_harness_pass","security_review_pass","evidence_retention_policy_reviewed"]:
    if final.get(key) is not False: errors.append(f"default final review {key} must be false")

if errors:
    print("RELEASE HARDENING STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)
print("RELEASE HARDENING STATIC CHECK: PASS")
