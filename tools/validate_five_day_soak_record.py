#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
RELEASE_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917"
SCHEMA_VERSION = "five_day_soak_acceptance_v1"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
ZERO_FIELDS = [
    "duplicate_orders",
    "duplicate_partials",
    "sl_regressions",
    "unprotected_new_authorizations",
    "release_gate_bypasses",
    "analytics_duplicate_finalizations",
    "stop_failure_join_failures",
    "dashboard_gate_mismatches",
    "runtime_critical_errors",
    "secrets_exposed",
]


def canonical_digest(value: dict[str, Any]) -> str:
    basis = copy.deepcopy(value)
    basis.pop("record_digest", None)
    return hashlib.sha256(json.dumps(basis, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def parse_date(value: str) -> date | None:
    try:
        return date.fromisoformat(value)
    except Exception:
        return None


def next_weekday(d: date) -> date:
    n = d + timedelta(days=1)
    while n.weekday() >= 5:
        n += timedelta(days=1)
    return n


def resolve_path(value: str) -> Path:
    p = Path(value)
    return p if p.is_absolute() else ROOT / p


def validate_record(record: dict[str, Any], require_digest: bool = True) -> tuple[list[str], str]:
    errors: list[str] = []
    if record.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if record.get("release_validation_id") != RELEASE_ID:
        errors.append(f"release_validation_id must be {RELEASE_ID}")
    if len(str(record.get("record_id", "")).strip()) < 8:
        errors.append("record_id must contain at least 8 characters")
    if len(str(record.get("evidence_id", "")).strip()) < 8:
        errors.append("evidence_id must contain at least 8 characters")

    candidate = record.get("candidate", {})
    git_sha = str(candidate.get("git_sha", ""))
    ex5 = str(candidate.get("ex5_sha256", ""))
    set_hash = str(candidate.get("set_sha256", ""))
    if not HEX40.fullmatch(git_sha):
        errors.append("candidate.git_sha must be 40 hex characters")
    if not HEX64.fullmatch(ex5):
        errors.append("candidate.ex5_sha256 must be 64 hex characters")
    if set_hash != "NONE" and not HEX64.fullmatch(set_hash):
        errors.append("candidate.set_sha256 must be 64 hex characters or NONE")
    for key in ("broker_company", "trade_server", "account_currency", "margin_mode", "mt5_build", "metaeditor_build"):
        if not str(candidate.get(key, "")).strip():
            errors.append(f"candidate.{key} is required")
    if str(candidate.get("account_mode", "")).upper() not in {"DEMO", "CONTEST"}:
        errors.append("candidate.account_mode must be DEMO or CONTEST")

    days = record.get("days")
    if not isinstance(days, list) or len(days) != 5:
        errors.append("days must contain exactly five accepted trading-day records")
        days = []
    parsed: list[date] = []
    for i, day in enumerate(days, start=1):
        if not isinstance(day, dict):
            errors.append(f"days[{i}] must be an object")
            continue
        d = parse_date(str(day.get("date", "")))
        if d is None:
            errors.append(f"days[{i}].date must be YYYY-MM-DD")
        else:
            parsed.append(d)
        if day.get("fresh_quotes") is not True:
            errors.append(f"days[{i}].fresh_quotes must be true")
        for key in ("execution_log_present", "stop_log_present", "release_log_present"):
            if day.get(key) is not True:
                errors.append(f"days[{i}].{key} must be true")
        if int(day.get("zero_tolerance_failures", -1)) != 0:
            errors.append(f"days[{i}].zero_tolerance_failures must be 0")
        if int(day.get("unresolved_critical_states_end", -1)) != 0:
            errors.append(f"days[{i}].unresolved_critical_states_end must be 0")
        for key in ("scheduled_scans", "continuous_scans", "manual_scans", "checkpoint_updates", "backup_checkpoint_updates",
                    "restarts", "reconnects", "high_confidence_decisions", "wait_reanalyze_decisions", "no_trade_decisions"):
            try:
                if int(day.get(key, 0)) < 0:
                    errors.append(f"days[{i}].{key} must be >= 0")
            except Exception:
                errors.append(f"days[{i}].{key} must be an integer")

    if len(parsed) == 5:
        if len(set(parsed)) != 5 or parsed != sorted(parsed):
            errors.append("day dates must be unique and increasing")
        for i in range(1, 5):
            expected = next_weekday(parsed[i - 1])
            if parsed[i] != expected:
                justification = str(days[i].get("gap_justification", "")).strip()
                if not justification:
                    errors.append(
                        f"{parsed[i-1]} -> {parsed[i]} is not the next normal trading weekday; days[{i+1}].gap_justification is required"
                    )

    if days:
        london = sum(1 for d in days if d.get("london_observed") is True)
        ny = sum(1 for d in days if d.get("ny_observed") is True)
        if london < 3:
            errors.append("at least 3 of the 5 days must observe London")
        if ny < 3:
            errors.append("at least 3 of the 5 days must observe New York/U.S. cash")
        if not any(d.get("overlap_observed") is True for d in days):
            errors.append("at least one day must observe London/New York overlap")
        if not any(d.get("high_impact_news_observed") is True for d in days):
            errors.append("at least one day must observe relevant high-impact news")
        if not any(d.get("rollover_spread_expansion_observed") is True for d in days):
            errors.append("at least one day must observe rollover spread expansion")
        if sum(int(d.get("restarts", 0)) for d in days) < 1:
            errors.append("five-day record must include at least one restart")
        if sum(int(d.get("reconnects", 0)) for d in days) < 1:
            errors.append("five-day record must include at least one reconnect")
        if sum(int(d.get("scheduled_scans", 0)) for d in days) < 1:
            errors.append("five-day record must include scheduled scans")
        if sum(int(d.get("continuous_scans", 0)) for d in days) < 1:
            errors.append("five-day record must include continuous scans")
        if sum(int(d.get("manual_scans", 0)) for d in days) < 1:
            errors.append("five-day record must include a manual SCAN NOW")
        if sum(int(d.get("checkpoint_updates", 0)) for d in days) < 1:
            errors.append("five-day record must include primary checkpoint updates")
        if sum(int(d.get("backup_checkpoint_updates", 0)) for d in days) < 1:
            errors.append("five-day record must include validated backup checkpoint updates")

    reconciliation = record.get("reconciliation", {})
    for key in ZERO_FIELDS:
        try:
            if int(reconciliation.get(key, -1)) != 0:
                errors.append(f"reconciliation.{key} must be 0")
        except Exception:
            errors.append(f"reconciliation.{key} must be an integer")

    lifecycle = record.get("lifecycle_checks", {})
    for key in ("stale_human_wait_closed", "market_confirmation_wait_preserved", "denial_timeout_terminal",
                "restart_reconstruction_passed", "no_illegal_transition_accepted"):
        if lifecycle.get(key) is not True:
            errors.append(f"lifecycle_checks.{key} must be true")

    report_path = str(record.get("report_path", "")).strip()
    if not report_path:
        errors.append("report_path is required")
    elif not resolve_path(report_path).exists():
        errors.append(f"report_path not found: {resolve_path(report_path)}")

    operator = record.get("operator_review", {})
    if operator.get("decision") != "ACCEPT":
        errors.append("operator_review.decision must be ACCEPT")
    if len(str(operator.get("reviewer", "")).strip()) < 2:
        errors.append("operator_review.reviewer is required")
    if len(str(operator.get("timestamp", "")).strip()) < 8:
        errors.append("operator_review.timestamp is required")

    digest = canonical_digest(record)
    stored = str(record.get("record_digest", ""))
    if require_digest:
        if not HEX64.fullmatch(stored):
            errors.append("record_digest must be a 64-character SHA-256 digest")
        elif stored.lower() != digest.lower():
            errors.append(f"record_digest mismatch: expected {digest}, found {stored}")
    return errors, digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate/finalize GPT_EA R6 five-day demo-soak acceptance record")
    ap.add_argument("record", nargs="?", default="five-day-soak-acceptance.json")
    ap.add_argument("--finalize", action="store_true", help="write the canonical record_digest after all other checks pass")
    args = ap.parse_args()
    path = resolve_path(args.record)
    if not path.exists():
        print(f"FIVE-DAY SOAK RECORD: FAILED\nERROR: record not found: {path}")
        return 1
    record = json.loads(path.read_text(encoding="utf-8"))
    errors, digest = validate_record(record, require_digest=not args.finalize)
    if args.finalize and not errors:
        record["record_digest"] = digest
        path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        errors, digest = validate_record(record, require_digest=True)

    out = ROOT / "five-day-soak-record-validation.txt"
    if errors:
        text = "FIVE-DAY SOAK RECORD: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nRECORD_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1
    text = f"FIVE-DAY SOAK RECORD: PASS\nRECORD_ID: {record['record_id']}\nRECORD_SHA256: {digest}\n"
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
