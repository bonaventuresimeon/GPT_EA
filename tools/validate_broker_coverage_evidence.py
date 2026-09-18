#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from json_bundle import load_json_document

ROOT = Path(__file__).resolve().parents[1]
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
SCHEMA_VERSION = "broker_agnostic_coverage_v1"

RISK = {
    "FX": ("MODERATE", "MODERATE"),
    "METAL": ("MODERATE", "HIGH"),
    "INDEX": ("HIGH", "HIGH"),
    "ENERGY": ("HIGH", "HIGH"),
    "COMMODITY": ("HIGH", "VERY_HIGH"),
    "CRYPTO": ("HIGH", "HIGH"),
    "STOCK": ("HIGH", "VERY_HIGH"),
    "ETF": ("HIGH", "VERY_HIGH"),
    "FUTURE": ("VERY_HIGH", "VERY_HIGH"),
    "BOND_RATE": ("VERY_HIGH", "VERY_HIGH"),
    "OTHER": ("CRITICAL", "CRITICAL"),
}

CATALOG_TRUE = (
    "full_catalog_enumeration_passed",
    "selection_recheck_passed",
    "market_watch_independence_passed",
    "unknown_generic_analyzable_passed",
    "generic_live_fail_closed_passed",
    "service_collateral_excluded_passed",
)

CONTROL_TRUE = (
    "exact_symbol_preserved",
    "suffix_prefix_resolution_passed",
    "description_path_metadata_passed",
    "calc_mode_fallback_passed",
    "currency_metadata_fallback_passed",
    "trade_mode_filter_passed",
    "tick_volume_stop_geometry_passed",
    "ordercheck_margin_passed",
    "calendar_macro_mapping_passed",
    "round_robin_scan_passed",
)


def canonical_digest(value: dict[str, Any]) -> str:
    payload = copy.deepcopy(value)
    payload["evidence_digest"] = ""
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def validate_record(
    value: dict[str, Any],
    expected_sha: str | None = None,
    expected_broker: dict[str, Any] | None = None,
) -> tuple[list[str], str]:
    errors: list[str] = []
    require(errors, value.get("schema_version") == SCHEMA_VERSION,
            f"schema_version must be {SCHEMA_VERSION}")
    require(errors, len(str(value.get("evidence_id", "")).strip()) >= 8,
            "evidence_id must contain at least 8 characters")

    candidate = value.get("candidate", {})
    git_sha = str(candidate.get("git_sha", ""))
    require(errors, bool(HEX40.fullmatch(git_sha)), "candidate.git_sha must be 40 hexadecimal characters")
    require(errors, bool(HEX64.fullmatch(str(candidate.get("ex5_sha256", "")))),
            "candidate.ex5_sha256 must be 64 hexadecimal characters")
    set_sha = str(candidate.get("set_sha256", ""))
    require(errors, set_sha == "NONE" or bool(HEX64.fullmatch(set_sha)),
            "candidate.set_sha256 must be 64 hexadecimal characters or NONE")
    if expected_sha and HEX40.fullmatch(expected_sha):
        require(errors, git_sha.lower() == expected_sha.lower(),
                "candidate.git_sha must match the release candidate Git SHA")

    broker = value.get("broker", {})
    for key in ("company", "server", "account_currency", "margin_mode", "catalog_timestamp_utc"):
        require(errors, bool(str(broker.get(key, "")).strip()), f"broker.{key} is required")
    if expected_broker:
        mapping = {
            "company": "broker_company",
            "server": "trade_server",
            "account_currency": "account_currency",
            "margin_mode": "margin_mode",
        }
        for bk, dk in mapping.items():
            expected = str(expected_broker.get(dk, "")).strip()
            actual = str(broker.get(bk, "")).strip()
            if expected:
                require(errors, actual == expected, f"broker.{bk} must match deployment.{dk}")

    catalog = value.get("catalog", {})
    for key in ("total_catalog_symbols", "discovered_symbols", "selected_rechecked_symbols"):
        try:
            number = int(catalog.get(key, 0) or 0)
        except Exception:
            number = 0
        require(errors, number > 0, f"catalog.{key} must be > 0")
    try:
        total = int(catalog.get("total_catalog_symbols", 0) or 0)
        discovered = int(catalog.get("discovered_symbols", 0) or 0)
        rechecked = int(catalog.get("selected_rechecked_symbols", 0) or 0)
        require(errors, discovered <= total, "catalog.discovered_symbols cannot exceed total_catalog_symbols")
        require(errors, rechecked <= discovered, "catalog.selected_rechecked_symbols cannot exceed discovered_symbols")
    except Exception:
        pass

    for key in CATALOG_TRUE:
        require(errors, catalog.get(key) is True, f"catalog.{key} must be true")
    require(errors, int(catalog.get("ambiguous_mapping_count", -1) or 0) == 0,
            "catalog.ambiguous_mapping_count must be 0")
    require(errors, int(catalog.get("misclassification_count", -1) or 0) == 0,
            "catalog.misclassification_count must be 0")

    controls = value.get("controls", {})
    for key in CONTROL_TRUE:
        require(errors, controls.get(key) is True, f"controls.{key} must be true")

    classes = value.get("asset_classes", {})
    for name, expected_risk in RISK.items():
        row = classes.get(name)
        require(errors, isinstance(row, dict), f"asset_classes.{name} must be an object")
        if not isinstance(row, dict):
            continue
        require(errors, row.get("discovery_risk") == expected_risk[0],
                f"asset_classes.{name}.discovery_risk must be {expected_risk[0]}")
        require(errors, row.get("execution_risk") == expected_risk[1],
                f"asset_classes.{name}.execution_risk must be {expected_risk[1]}")
        require(errors, row.get("classification_passed") is True,
                f"asset_classes.{name}.classification_passed must be true")

        runtime_required = row.get("broker_runtime_required") is True
        if runtime_required:
            require(errors, row.get("broker_runtime_passed") is True,
                    f"asset_classes.{name}.broker_runtime_passed must be true when runtime coverage is required")
            require(errors, row.get("execution_geometry_passed") is True,
                    f"asset_classes.{name}.execution_geometry_passed must be true when runtime coverage is required")
            require(errors, row.get("macro_context_passed") is True,
                    f"asset_classes.{name}.macro_context_passed must be true when runtime coverage is required")
            examples = row.get("examples", [])
            require(errors, isinstance(examples, list) and len(examples) > 0,
                    f"asset_classes.{name}.examples must identify tested symbols when runtime coverage is required")
            if name != "OTHER":
                require(errors, row.get("live_execution_certified") is True,
                        f"asset_classes.{name}.live_execution_certified must be true when the class exists on the release broker")

        if row.get("live_execution_certified") is True:
            require(errors, row.get("broker_runtime_passed") is True,
                    f"asset_classes.{name} cannot be live-certified without broker runtime PASS")
            require(errors, row.get("execution_geometry_passed") is True,
                    f"asset_classes.{name} cannot be live-certified without execution-geometry PASS")
            require(errors, row.get("macro_context_passed") is True,
                    f"asset_classes.{name} cannot be live-certified without macro/context PASS")

    review = value.get("operator_review", {})
    require(errors, review.get("decision") == "PASS", "operator_review.decision must be PASS")
    require(errors, len(str(review.get("reviewer", "")).strip()) >= 2, "operator_review.reviewer is required")
    require(errors, len(str(review.get("timestamp_utc", "")).strip()) >= 8, "operator_review.timestamp_utc is required")

    digest = canonical_digest(value)
    recorded = str(value.get("evidence_digest", ""))
    require(errors, bool(HEX64.fullmatch(recorded)), "evidence_digest must be 64 hexadecimal characters")
    if HEX64.fullmatch(recorded):
        require(errors, recorded.lower() == digest.lower(), "evidence_digest does not match canonical evidence content")
    return errors, digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA broker-agnostic coverage evidence")
    ap.add_argument("evidence", nargs="?", default="artifacts/broker-agnostic-coverage.json")
    ap.add_argument("--expected-sha", default="")
    ap.add_argument("--finalize", action="store_true",
                    help="Write the canonical evidence_digest before validating")
    args = ap.parse_args()

    path = Path(args.evidence)
    if not path.is_absolute():
        path = ROOT / path
    if not path.exists():
        print(f"BROKER COVERAGE EVIDENCE: FAILED\nERROR: file not found: {path}")
        return 1

    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        print("BROKER COVERAGE EVIDENCE: FAILED\nERROR: evidence must be a JSON object")
        return 1

    if args.finalize:
        value["evidence_digest"] = canonical_digest(value)
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    errors, digest = validate_record(value, expected_sha=args.expected_sha or None)
    if errors:
        print("BROKER COVERAGE EVIDENCE: FAILED")
        for error in errors:
            print("ERROR:", error)
        print("BROKER_COVERAGE_SHA256:", digest)
        return 1

    # Ensure the committed bundle retains the matching template/schema contract.
    try:
        schema = load_json_document("BROKER_COVERAGE_EVIDENCE_SCHEMA.json")
        template = load_json_document("BROKER_COVERAGE_EVIDENCE_TEMPLATE.json")
        if schema.get("properties", {}).get("schema_version", {}).get("const") != SCHEMA_VERSION:
            raise RuntimeError("bundled schema version mismatch")
        if template.get("schema_version") != SCHEMA_VERSION:
            raise RuntimeError("bundled template version mismatch")
    except Exception as exc:
        print("BROKER COVERAGE EVIDENCE: FAILED")
        print("ERROR:", exc)
        return 1

    print("BROKER COVERAGE EVIDENCE: PASS")
    print("SCHEMA:", SCHEMA_VERSION)
    print("BROKER_COVERAGE_SHA256:", digest)
    live = [name for name, row in value["asset_classes"].items() if row.get("live_execution_certified") is True]
    print("LIVE_CERTIFIED_CLASSES:", ",".join(live) if live else "NONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
