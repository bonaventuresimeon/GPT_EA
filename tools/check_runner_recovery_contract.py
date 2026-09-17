#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
errors:list[str]=[]

required=[
    "ACTIONS_RUNNER_DIAGNOSTICS.md",
    "RUNNER_RECOVERY_EVIDENCE.md",
    "RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json",
    "RUNNER_RECOVERY_EVIDENCE_SCHEMA.json",
    "tools/validate_runner_recovery_evidence.py",
    "tools/build_runner_recovery_evidence.py",
    "RUNNER_RECOVERY_TEST_MATRIX.md",
    "GPT_EA_Part28B_CIReleaseEvidence.mqh",
    "RELEASE_EVIDENCE_TEMPLATE.json",
]
for name in required:
    if not (ROOT/name).exists(): errors.append(f"missing runner-recovery artifact: {name}")

if not errors:
    schema=json.loads((ROOT/"RUNNER_RECOVERY_EVIDENCE_SCHEMA.json").read_text(encoding="utf-8"))
    if schema.get("properties",{}).get("schema_version",{}).get("const")!="runner_recovery_evidence_v1":
        errors.append("runner recovery schema version mismatch")
    template=json.loads((ROOT/"RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
    if template.get("schema_version")!="runner_recovery_evidence_v1":
        errors.append("runner recovery template schema mismatch")
    inc=template.get("incident",{})
    if inc.get("runner_id")!=0 or inc.get("steps_executed")!=0 or inc.get("observed_signature")!="PRE_RUNNER_NO_STEPS":
        errors.append("runner recovery template must preserve pre-runner failure signature")
    if template.get("operator_review",{}).get("decision")!="HOLD":
        errors.append("runner recovery template must default HOLD")

    validator=(ROOT/"tools/validate_runner_recovery_evidence.py").read_text(encoding="utf-8")
    builder=(ROOT/"tools/build_runner_recovery_evidence.py").read_text(encoding="utf-8")
    matrix=(ROOT/"RUNNER_RECOVERY_TEST_MATRIX.md").read_text(encoding="utf-8")
    for token in ["PRE_RUNNER_NO_STEPS","runner_id","steps_executed","ci_bundle_digest","expected_bundle_digest","RUNNER RECOVERY EVIDENCE"]:
        if token not in validator: errors.append(f"runner recovery validator missing token: {token}")
    for token in ["attempts/{attempt}/jobs","ci_bundle_manifest","runner-probe","static-release-gate","GITHUB_TOKEN"]:
        if token not in builder: errors.append(f"runner recovery builder missing token: {token}")
    for token in ["RR-001","RR-004","RR-009","RR-013","RR-018"]:
        if token not in matrix: errors.append(f"runner recovery test matrix missing {token}")

    part=(ROOT/"GPT_EA_Part28B_CIReleaseEvidence.mqh").read_text(encoding="utf-8")
    for token in ["GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA","ReleaseRunnerRecoveryEvidenceAllows",
                  "InpReleaseRunnerRecoveryPassed","InpReleaseRunnerRecoverySchemaVersion",
                  "InpReleaseRunnerRecoveryEvidenceId","InpReleaseRunnerRecoveryDigest"]:
        if token not in part: errors.append(f"Part28B missing runner recovery token: {token}")
    if not re.search(r"input\s+bool\s+InpReleaseRunnerRecoveryPassed\s*=\s*false\s*;",part):
        errors.append("InpReleaseRunnerRecoveryPassed must default false")

    release=json.loads((ROOT/"RELEASE_EVIDENCE_TEMPLATE.json").read_text(encoding="utf-8"))
    if release.get("runner_recovery",{}).get("schema_version")!="runner_recovery_evidence_v1":
        errors.append("release evidence template missing runner recovery object")
    if release.get("gates",{}).get("runner_recovery") is not False:
        errors.append("release evidence runner_recovery gate must default false")

if errors:
    print("RUNNER RECOVERY STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)
print("RUNNER RECOVERY STATIC CHECK: PASS")
