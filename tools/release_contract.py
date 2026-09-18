from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_PATH = ROOT / "GPT_EA_DATA.json"
_REQUIRED_KEYS = {
    "contract_version",
    "release_validation_id",
    "demo_soak_schema",
    "runner_recovery_schema",
    "runner_acceptance_schema",
    "ci_schema",
    "ci_job_metadata_schema",
    "ci_bundle_schema",
    "mt5_validation_schema",
    "resilience_schema",
    "soak_acceptance_schema",
    "api_transport_schema",
    "compile_evidence_schema",
    "final_review_schema",
    "risk_ack_schema",
    "legal_terms_version",
    "legal_acceptance_phrase",
    "privacy_schema",
    "mt5_minimum_proof_schema",
    "release_readiness_schema",
    "production_incident_schema",
    "operator_status_schema",
    "evidence_retention_register_schema",
    "drift_baseline_schema",
    "demo_validation_run_schema",
    "release_candidate_smoke_schema",
    "fail_closed_recovery_drill_schema",
    "signed_entitlement_schema",
}
_cache: dict[str, Any] | None = None


def load_release_contract() -> dict[str, Any]:
    global _cache
    if _cache is None:
        payload = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))
        contract = payload.get("release_contract")
        if not isinstance(contract, dict):
            raise RuntimeError(f"{BUNDLE_PATH.name} is missing release_contract")
        missing = sorted(_REQUIRED_KEYS - set(contract))
        if missing:
            raise RuntimeError("release_contract missing key(s): " + ", ".join(missing))
        for key in _REQUIRED_KEYS:
            if not str(contract.get(key, "")).strip():
                raise RuntimeError(f"release_contract.{key} must be non-empty")
        _cache = contract
    return dict(_cache)


def release_value(key: str) -> str:
    contract = load_release_contract()
    if key not in contract:
        raise KeyError(f"release_contract has no key {key!r}")
    return str(contract[key])
