#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PART28 = ROOT / "GPT_EA_Part28_ReleaseCertification.mqh"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def current_release_id() -> str:
    text = PART28.read_text(encoding="utf-8")
    m = re.search(r'GPT_EA_REQUIRED_RELEASE_VALIDATION_ID\s*=\s*"([^"]+)"', text)
    if not m:
        raise RuntimeError("release validation ID not found in Part28")
    return m.group(1)


def git_head() -> str | None:
    try:
        out = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL)
        return out.strip()
    except Exception:
        return None


def require(errors: list[str], cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA compile/demo-soak release evidence")
    ap.add_argument("evidence", nargs="?", default="release_evidence.json")
    args = ap.parse_args()

    evidence_path = Path(args.evidence)
    if not evidence_path.is_absolute():
        evidence_path = ROOT / evidence_path
    if not evidence_path.exists():
        print(f"RELEASE EVIDENCE VALIDATION: FAILED\nERROR: evidence file not found: {evidence_path}")
        return 1

    data = json.loads(evidence_path.read_text(encoding="utf-8"))
    errors: list[str] = []
    required_id = current_release_id()

    require(errors, data.get("release_validation_id") == required_id,
            f"release_validation_id must equal {required_id}")

    build = data.get("build", {})
    git_sha = str(build.get("git_sha", ""))
    ex5_hash = str(build.get("ex5_sha256", ""))
    set_hash = str(build.get("set_sha256", ""))
    require(errors, bool(HEX40.fullmatch(git_sha)), "build.git_sha must be 40 hexadecimal characters")
    require(errors, bool(HEX64.fullmatch(ex5_hash)), "build.ex5_sha256 must be 64 hexadecimal characters")
    require(errors, set_hash == "NONE" or bool(HEX64.fullmatch(set_hash)),
            "build.set_sha256 must be 64 hexadecimal characters or NONE")
    require(errors, int(build.get("compile_errors", -1)) == 0, "compile_errors must be 0")
    require(errors, int(build.get("compile_warnings", -1)) == 0, "compile_warnings must be 0 for production certification")
    require(errors, bool(str(build.get("metaeditor_build", "")).strip()), "metaeditor_build is required")
    require(errors, bool(str(build.get("mt5_build", "")).strip()), "mt5_build is required")
    require(errors, bool(str(build.get("compile_evidence_id", "")).strip()), "compile_evidence_id is required")

    head = git_head()
    if head and HEX40.fullmatch(git_sha):
        require(errors, head.lower() == git_sha.lower(), f"evidence Git SHA {git_sha} does not match repository HEAD {head}")

    ex5_path_raw = str(build.get("ex5_path", "")).strip()
    if ex5_path_raw:
        ex5_path = Path(ex5_path_raw)
        if not ex5_path.is_absolute():
            ex5_path = ROOT / ex5_path
        require(errors, ex5_path.exists(), f"EX5 file not found: {ex5_path}")
        if ex5_path.exists() and HEX64.fullmatch(ex5_hash):
            actual = sha256_file(ex5_path)
            require(errors, actual.lower() == ex5_hash.lower(), f"EX5 SHA-256 mismatch: expected {ex5_hash}, actual {actual}")

    set_path_raw = str(build.get("set_path", "")).strip()
    if set_hash != "NONE":
        require(errors, bool(set_path_raw), "set_path is required when set_sha256 is not NONE")
        if set_path_raw:
            set_path = Path(set_path_raw)
            if not set_path.is_absolute():
                set_path = ROOT / set_path
            require(errors, set_path.exists(), f"SET file not found: {set_path}")
            if set_path.exists() and HEX64.fullmatch(set_hash):
                actual = sha256_file(set_path)
                require(errors, actual.lower() == set_hash.lower(), f"SET SHA-256 mismatch: expected {set_hash}, actual {actual}")

    compile_log_raw = str(build.get("compile_log_path", "")).strip()
    require(errors, bool(compile_log_raw), "compile_log_path is required")
    if compile_log_raw:
        compile_log = Path(compile_log_raw)
        if not compile_log.is_absolute():
            compile_log = ROOT / compile_log
        require(errors, compile_log.exists(), f"compile log not found: {compile_log}")

    soak = data.get("demo_soak", {})
    require(errors, bool(str(soak.get("evidence_id", "")).strip()), "demo_soak.evidence_id is required")
    require(errors, int(soak.get("trading_days", 0)) >= 5, "demo soak requires at least 5 consecutive trading days")
    require(errors, int(soak.get("london_sessions", 0)) >= 3, "demo soak requires at least 3 London sessions")
    require(errors, int(soak.get("ny_sessions", 0)) >= 3, "demo soak requires at least 3 New York/U.S. cash sessions")
    for key in ["overlap_observed", "news_day_observed", "rollover_observed", "restart_observed", "reconnect_observed"]:
        require(errors, soak.get(key) is True, f"demo_soak.{key} must be true")
    require(errors, int(soak.get("zero_tolerance_failures", -1)) == 0, "demo soak zero_tolerance_failures must be 0")
    require(errors, int(soak.get("unresolved_critical_states", -1)) == 0, "demo soak unresolved_critical_states must be 0")

    deployment = data.get("deployment", {})
    for key in ["broker_company", "trade_server", "account_currency", "margin_mode", "account_leverage"]:
        require(errors, bool(str(deployment.get(key, "")).strip()), f"deployment.{key} is required")

    gates = data.get("gates", {})
    required_gates = [
        "metaeditor_compile", "artifact_identity", "strategy_tester", "intelligence_matrix",
        "adaptive_portfolio", "execution_learning", "champion_challenger", "lifecycle_integrity",
        "broker_matrix", "deployment_profile", "recovery", "stop_matrix", "broker_stop_policy",
        "partial_protection", "stop_observability", "live_news_intermarket", "web_failure_injection",
        "demo_soak", "operator_review",
    ]
    for key in required_gates:
        require(errors, gates.get(key) is True, f"gates.{key} must be true")

    canonical = json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()

    out = ROOT / "release-evidence-validation.txt"
    if errors:
        text = "RELEASE EVIDENCE VALIDATION: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors) + f"\nEVIDENCE_JSON_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = f"RELEASE EVIDENCE VALIDATION: PASS\nRELEASE_ID: {required_id}\nEVIDENCE_JSON_SHA256: {digest}\n"
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
