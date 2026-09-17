#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PART28 = ROOT / "GPT_EA_Part28_ReleaseCertification.mqh"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def canonical_digest(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def current_release_id() -> str:
    text = PART28.read_text(encoding="utf-8")
    m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', text)
    if not m:
        raise RuntimeError("release validation ID not found in Part28")
    return m.group(1)


def release_basis(data: dict[str, Any]) -> dict[str, Any]:
    gates = dict(data.get("gates", {}))
    gates.pop("operator_review", None)
    return {
        "release_validation_id": data.get("release_validation_id"),
        "build": data.get("build", {}),
        "deployment": data.get("deployment", {}),
        "demo_soak": data.get("demo_soak", {}),
        "gates": gates,
    }


def require(errors: list[str], cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA final GO/NO-GO review")
    ap.add_argument("evidence", nargs="?", default="release_evidence.json")
    ap.add_argument("review", nargs="?", default="final_release_review.json")
    args = ap.parse_args()

    evidence_path = Path(args.evidence)
    review_path = Path(args.review)
    if not evidence_path.is_absolute(): evidence_path = ROOT / evidence_path
    if not review_path.is_absolute(): review_path = ROOT / review_path

    missing = [str(p) for p in (evidence_path, review_path) if not p.exists()]
    if missing:
        print("FINAL RELEASE REVIEW: FAILED")
        for p in missing: print("ERROR: file not found:", p)
        return 1

    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    review = json.loads(review_path.read_text(encoding="utf-8"))
    errors: list[str] = []
    required_id = current_release_id()

    require(errors, review.get("schema_version") == "final_release_review_v1", "review schema_version must be final_release_review_v1")
    require(errors, review.get("release_validation_id") == required_id, f"review release_validation_id must equal {required_id}")
    require(errors, evidence.get("release_validation_id") == required_id, f"evidence release_validation_id must equal {required_id}")
    require(errors, str(review.get("decision", "")) == "GO", "final decision must be literal GO")
    require(errors, len(str(review.get("review_evidence_id", "")).strip()) >= 4, "review_evidence_id is required")
    require(errors, len(str(review.get("reviewer", "")).strip()) >= 2, "reviewer is required")
    require(errors, len(str(review.get("review_timestamp", "")).strip()) >= 8, "review_timestamp is required")

    candidate = review.get("candidate", {})
    build = evidence.get("build", {})
    require(errors, candidate.get("git_sha") == build.get("git_sha"), "review candidate.git_sha must match release evidence")
    require(errors, candidate.get("ex5_sha256") == build.get("ex5_sha256"), "review candidate.ex5_sha256 must match release evidence")
    require(errors, candidate.get("set_sha256") == build.get("set_sha256"), "review candidate.set_sha256 must match release evidence")
    require(errors, bool(HEX40.fullmatch(str(candidate.get("git_sha", "")))), "candidate.git_sha must be 40 hexadecimal characters")
    require(errors, bool(HEX64.fullmatch(str(candidate.get("ex5_sha256", "")))), "candidate.ex5_sha256 must be 64 hexadecimal characters")
    set_hash = str(candidate.get("set_sha256", ""))
    require(errors, set_hash == "NONE" or bool(HEX64.fullmatch(set_hash)), "candidate.set_sha256 must be 64 hexadecimal characters or NONE")

    basis_digest = canonical_digest(release_basis(evidence))
    require(errors, candidate.get("release_evidence_digest") == basis_digest,
            f"candidate.release_evidence_digest must equal {basis_digest}")

    dep_r = review.get("deployment", {})
    dep_e = evidence.get("deployment", {})
    for key in ["broker_company", "trade_server", "account_currency", "margin_mode", "account_leverage"]:
        require(errors, dep_r.get(key) == dep_e.get(key), f"review deployment.{key} must match release evidence")
    require(errors, dep_r.get("deployment_profile_match") is True, "deployment_profile_match must be true")

    checks = review.get("review", {})
    required_checks = [
        "compile_contract_pass", "soak_schema_pass", "release_evidence_validator_pass", "all_release_gates_pass",
        "zero_unresolved_critical_states", "zero_zero_tolerance_failures", "artifact_identity_match",
        "deployment_identity_match", "no_source_change_after_validation", "no_unreviewed_known_issue",
        "initial_live_risk_conservative", "approval_required_initially",
    ]
    for key in required_checks:
        require(errors, checks.get(key) is True, f"review.{key} must be true")

    require(errors, int(review.get("unresolved_critical_count", -1)) == 0, "unresolved_critical_count must be 0")
    require(errors, int(review.get("zero_tolerance_failure_count", -1)) == 0, "zero_tolerance_failure_count must be 0")

    gates = evidence.get("gates", {})
    for key, value in gates.items():
        if key == "operator_review":
            continue
        require(errors, value is True, f"release evidence gate {key} must be true before final review")

    review_for_digest = copy.deepcopy(review)
    review_for_digest.pop("review_digest", None)
    review_digest = canonical_digest(review_for_digest)
    if "review_digest" in review:
        require(errors, str(review.get("review_digest", "")).lower() == review_digest.lower(),
                f"review_digest mismatch: expected {review_digest}")

    out = ROOT / "final-release-review-validation.txt"
    if errors:
        text = "FINAL RELEASE REVIEW: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nRELEASE_EVIDENCE_BASIS_SHA256: {basis_digest}\nFINAL_REVIEW_SHA256: {review_digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = f"FINAL RELEASE REVIEW: PASS\nRELEASE_ID: {required_id}\nRELEASE_EVIDENCE_BASIS_SHA256: {basis_digest}\nFINAL_REVIEW_SHA256: {review_digest}\n"
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
