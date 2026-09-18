#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "GPT_EA.mq5"
BUNDLE = ROOT / "GPT_EA_DATA.json"
DOC = ROOT / "docs" / "BROKER_AGNOSTIC_RELEASE_ACCEPTANCE.md"
VALIDATOR = ROOT / "tools" / "validate_broker_coverage_evidence.py"
RELEASE_VALIDATOR = ROOT / "tools" / "validate_release_evidence.py"
FINAL_REVIEW = ROOT / "tools" / "validate_final_release_review.py"
EXPORTER = ROOT / "tools" / "export_mt5_release_inputs.py"

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


source = MAIN.read_text(encoding="utf-8", errors="strict") if MAIN.exists() else ""
require(bool(source), "GPT_EA.mq5 missing")

require(bool(re.search(r'InpReleaseBrokerDiscoveryPassed\s*=\s*false\s*;', source)),
        "broker discovery release flag must default false")
for name in (
    "InpReleaseAssetClassFXPassed",
    "InpReleaseAssetClassMetalPassed",
    "InpReleaseAssetClassIndexPassed",
    "InpReleaseAssetClassEnergyPassed",
    "InpReleaseAssetClassCommodityPassed",
    "InpReleaseAssetClassCryptoPassed",
    "InpReleaseAssetClassStockPassed",
    "InpReleaseAssetClassETFPassed",
    "InpReleaseAssetClassFuturePassed",
    "InpReleaseAssetClassBondRatePassed",
    "InpReleaseAssetClassOtherPassed",
):
    require(bool(re.search(rf'{name}\s*=\s*false\s*;', source)), f"{name} must default false")

for token in (
    'GPT_EA_REQUIRED_BROKER_COVERAGE_SCHEMA      = "broker_agnostic_coverage_v1"',
    "ReleaseBrokerCoverageAllows",
    "ReleaseAssetClassCertified",
    "CanonicalBrokerInstrumentKey(sym)",
    "AssetClassFromCanonical",
    "if(!ReleaseBrokerCoverageAllows(sym,brokerCoverage))",
    "REAL account blocked: asset class ",
    "GEN/OTHER stays analysis-only unless explicitly certified",
):
    require(token in source, f"runtime broker-coverage contract missing token: {token}")

if BUNDLE.exists():
    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    documents = bundle.get("documents", {})
    contract = bundle.get("release_contract", {})
    for name in ("BROKER_COVERAGE_EVIDENCE_SCHEMA.json", "BROKER_COVERAGE_EVIDENCE_TEMPLATE.json"):
        require(name in documents, f"GPT_EA_DATA.json missing {name}")
    release = documents.get("RELEASE_EVIDENCE_TEMPLATE.json", {})
    require("broker_coverage" in release, "release evidence template missing broker_coverage")
    require(release.get("gates", {}).get("broker_coverage") is False,
            "broker_coverage release gate must default false")
    final = documents.get("FINAL_RELEASE_REVIEW_TEMPLATE.json", {}).get("review", {})
    require(final.get("broker_coverage_pass") is False,
            "final review broker_coverage_pass must default false")
    require(contract.get("broker_coverage_schema") == "broker_agnostic_coverage_v1",
            "release_contract broker_coverage_schema mismatch")
else:
    errors.append("GPT_EA_DATA.json missing")

for path in (DOC, VALIDATOR, RELEASE_VALIDATOR, FINAL_REVIEW, EXPORTER):
    require(path.exists(), f"missing broker-coverage release artifact: {path.relative_to(ROOT)}")

if DOC.exists():
    text = DOC.read_text(encoding="utf-8")
    for token in (
        "Asset-class discovery and execution risk comparison",
        "OTHER / GEN",
        "FUTURE",
        "BOND_RATE",
        "Automatic NO-GO conditions",
        "broker_agnostic_coverage_v1",
    ):
        require(token in text, f"broker coverage release document missing: {token}")

if VALIDATOR.exists():
    text = VALIDATOR.read_text(encoding="utf-8")
    for token in (
        "BROKER COVERAGE EVIDENCE: PASS",
        "classification_passed",
        "broker_runtime_required",
        "live_execution_certified",
        "generic_live_fail_closed_passed",
        "misclassification_count",
    ):
        require(token in text, f"broker coverage evidence validator missing token: {token}")

if RELEASE_VALIDATOR.exists():
    text = RELEASE_VALIDATOR.read_text(encoding="utf-8")
    for token in ("validate_broker_coverage_release_record", '"broker_coverage"', "BROKER_COVERAGE_SHA256"):
        require(token in text, f"release evidence validator missing broker coverage token: {token}")

if FINAL_REVIEW.exists():
    text = FINAL_REVIEW.read_text(encoding="utf-8")
    require('"broker_coverage":data.get("broker_coverage",{})' in text,
            "final review basis must bind broker_coverage")
    require('"broker_coverage_pass"' in text,
            "final review must require broker_coverage_pass")

if EXPORTER.exists():
    text = EXPORTER.read_text(encoding="utf-8")
    for token in (
        "InpReleaseBrokerDiscoveryPassed",
        "InpReleaseBrokerCoverageSchemaVersion",
        "InpReleaseAssetClassFuturePassed",
        "InpReleaseAssetClassOtherPassed",
    ):
        require(token in text, f"MT5 release exporter missing {token}")

if errors:
    print("BROKER COVERAGE RELEASE CHECK: FAILED")
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)

print("BROKER COVERAGE RELEASE CHECK: PASS")
print("Runtime: full discovery evidence + per-class REAL execution authorization")
print("Evidence: broker_agnostic_coverage_v1")
print("OTHER/GEN: analysis allowed, REAL execution fail-closed unless explicitly certified")
