#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from validate_api_transport_evidence import validate_api_transport
from validate_ci_bundle import validate_bundle
from validate_ci_evidence import validate_ci_value
from validate_five_day_soak_record import validate_record
from validate_soak_evidence import validate_soak

ROOT = Path(__file__).resolve().parents[1]
PART28 = ROOT / "GPT_EA_Part28_ReleaseCertification.mqh"
SOAK_SCHEMA = ROOT / "SOAK_EVIDENCE_SCHEMA.json"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve(path_text: str) -> Path:
    p = Path(path_text)
    return p if p.is_absolute() else ROOT / p


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


def validate_ci_release_record(ci: dict, build_sha: str) -> tuple[list[str], str]:
    errors: list[str] = []
    require(errors, ci.get("schema_version") == "github_actions_static_evidence_v1",
            "ci_static.schema_version must be github_actions_static_evidence_v1")
    for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed"):
        try:
            value = int(ci.get(key, 0) or 0)
        except Exception:
            value = 0
        require(errors, value > 0, f"ci_static.{key} must be > 0")
    require(errors, int(ci.get("steps_executed", 0) or 0) >= 7,
            "ci_static.steps_executed must be >= 7")
    require(errors, str(ci.get("runner_name", "")).strip() != "", "ci_static.runner_name is required")
    head = str(ci.get("head_sha", ""))
    require(errors, bool(HEX40.fullmatch(head)), "ci_static.head_sha must be 40 hexadecimal characters")
    if HEX40.fullmatch(head) and HEX40.fullmatch(build_sha):
        require(errors, head.lower() == build_sha.lower(), "ci_static.head_sha must match build.git_sha")
    require(errors, ci.get("conclusion") == "success", "ci_static.conclusion must be success")
    require(errors, ci.get("artifact_archived") is True, "ci_static.artifact_archived must be true")
    require(errors, ci.get("attestation_verified") is True, "ci_static.attestation_verified must be true")
    require(errors, len(str(ci.get("artifact_name", "")).strip()) >= 8, "ci_static.artifact_name is required")
    require(errors, int(ci.get("run_id", 0) or 0) and str(ci.get("run_id")) in str(ci.get("run_url", "")),
            "ci_static.run_url must reference ci_static.run_id")
    require(errors, int(ci.get("job_id", 0) or 0) and str(ci.get("job_id")) in str(ci.get("job_url", "")),
            "ci_static.job_url must reference ci_static.job_id")
    expected_digest = str(ci.get("evidence_digest", ""))
    require(errors, bool(HEX64.fullmatch(expected_digest)), "ci_static.evidence_digest must be 64 hexadecimal characters")

    metadata_raw = str(ci.get("job_metadata_path", "")).strip()
    require(errors, bool(metadata_raw), "ci_static.job_metadata_path is required")
    metadata_path = resolve(metadata_raw) if metadata_raw else None
    if metadata_path is not None:
        require(errors, metadata_path.exists(), f"CI job metadata file not found: {metadata_path}")

    evidence_raw = str(ci.get("evidence_path", "")).strip()
    require(errors, bool(evidence_raw), "ci_static.evidence_path is required")
    if evidence_raw:
        evidence_path = resolve(evidence_raw)
        require(errors, evidence_path.exists(), f"CI evidence file not found: {evidence_path}")
        if evidence_path.exists():
            try:
                value = json.loads(evidence_path.read_text(encoding="utf-8"))
                ci_errors, digest = validate_ci_value(
                    value,
                    expected_sha=build_sha,
                    job_metadata=metadata_path if metadata_path and metadata_path.exists() else None,
                )
                errors.extend(f"ci_static evidence: {e}" for e in ci_errors)
                require(errors, digest.lower() == expected_digest.lower(),
                        "ci_static.evidence_digest does not match ci-evidence.json")
                for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed", "head_sha", "runner_name"):
                    if str(ci.get(key, "")) != str(value.get(key, "")):
                        errors.append(f"ci_static.{key} does not match ci-evidence.json")
                if str(ci.get("conclusion", "")) != str(value.get("static_job_conclusion", "")):
                    errors.append("ci_static.conclusion does not match ci-evidence static_job_conclusion")
            except Exception as exc:
                errors.append(f"could not validate ci_static.evidence_path: {exc}")

    verify_raw = str(ci.get("attestation_verification_path", "")).strip()
    require(errors, bool(verify_raw), "ci_static.attestation_verification_path is required")
    if verify_raw:
        verify_path = resolve(verify_raw)
        require(errors, verify_path.exists(), f"CI attestation verification output not found: {verify_path}")
        if verify_path.exists():
            text = verify_path.read_text(encoding="utf-8", errors="replace")
            require(errors, "CI ATTESTATION VERIFY: PASS" in text,
                    "CI attestation verification output does not contain PASS marker")

    require(errors, ci.get("bundle_schema_version") == "ci_evidence_bundle_v1",
            "ci_static.bundle_schema_version must be ci_evidence_bundle_v1")
    expected_bundle_digest = str(ci.get("bundle_digest", ""))
    require(errors, bool(HEX64.fullmatch(expected_bundle_digest)),
            "ci_static.bundle_digest must be 64 hexadecimal characters")
    require(errors, ci.get("bundle_validated") is True, "ci_static.bundle_validated must be true")

    bundle_digest = ""
    bundle_raw = str(ci.get("bundle_manifest_path", "")).strip()
    require(errors, bool(bundle_raw), "ci_static.bundle_manifest_path is required")
    if bundle_raw:
        bundle_path = resolve(bundle_raw)
        require(errors, bundle_path.exists(), f"CI bundle manifest not found: {bundle_path}")
        if bundle_path.exists():
            try:
                manifest = json.loads(bundle_path.read_text(encoding="utf-8"))
                bundle_errors, bundle_digest = validate_bundle(manifest, bundle_path.parent, expected_sha=build_sha)
                errors.extend(f"ci_static bundle: {e}" for e in bundle_errors)
                require(errors, bundle_digest.lower() == expected_bundle_digest.lower(),
                        "ci_static.bundle_digest does not match ci-bundle-manifest.json")
                for key in ("run_id", "run_attempt", "job_id", "runner_id", "steps_executed"):
                    if str(ci.get(key, "")) != str(manifest.get(key, "")):
                        errors.append(f"ci_static.{key} does not match CI bundle manifest")
                require(errors, str(ci.get("artifact_name", "")) == str(manifest.get("artifact_name", "")),
                        "ci_static.artifact_name does not match CI bundle manifest")
            except Exception as exc:
                errors.append(f"could not validate CI bundle manifest: {exc}")

    bundle_validation_raw = str(ci.get("bundle_validation_path", "")).strip()
    require(errors, bool(bundle_validation_raw), "ci_static.bundle_validation_path is required")
    if bundle_validation_raw:
        p = resolve(bundle_validation_raw)
        require(errors, p.exists(), f"CI bundle validation output not found: {p}")
        if p.exists():
            require(errors, "CI BUNDLE VALIDATION: PASS" in p.read_text(encoding="utf-8", errors="replace"),
                    "CI bundle validation output does not contain PASS marker")
    return errors, bundle_digest


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA current compile/CI/API/demo-soak/final-review release evidence")
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
    require(errors, bool(ex5_path_raw), "build.ex5_path is required")
    if ex5_path_raw:
        ex5_path = resolve(ex5_path_raw)
        require(errors, ex5_path.exists(), f"EX5 file not found: {ex5_path}")
        if ex5_path.exists() and HEX64.fullmatch(ex5_hash):
            actual = sha256_file(ex5_path)
            require(errors, actual.lower() == ex5_hash.lower(), f"EX5 SHA-256 mismatch: expected {ex5_hash}, actual {actual}")

    set_path_raw = str(build.get("set_path", "")).strip()
    if set_hash != "NONE":
        require(errors, bool(set_path_raw), "set_path is required when set_sha256 is not NONE")
        if set_path_raw:
            set_path = resolve(set_path_raw)
            require(errors, set_path.exists(), f"SET file not found: {set_path}")
            if set_path.exists() and HEX64.fullmatch(set_hash):
                actual = sha256_file(set_path)
                require(errors, actual.lower() == set_hash.lower(), f"SET SHA-256 mismatch: expected {set_hash}, actual {actual}")

    compile_log_raw = str(build.get("compile_log_path", "")).strip()
    require(errors, bool(compile_log_raw), "compile_log_path is required")
    if compile_log_raw:
        compile_log = resolve(compile_log_raw)
        require(errors, compile_log.exists(), f"compile log not found: {compile_log}")

    ci = data.get("ci_static")
    ci_bundle_digest = ""
    if not isinstance(ci, dict):
        errors.append("ci_static must be an object")
    else:
        ci_errors, ci_bundle_digest = validate_ci_release_record(ci, git_sha)
        errors.extend(ci_errors)

    deployment = data.get("deployment", {})
    for key in ["broker_company", "trade_server", "account_currency", "margin_mode", "account_leverage"]:
        require(errors, bool(str(deployment.get(key, "")).strip()), f"deployment.{key} is required")
    require(errors, isinstance(deployment.get("symbols"), list) and len(deployment.get("symbols", [])) > 0,
            "deployment.symbols must contain at least one validated symbol")

    api_errors, api_digest = validate_api_transport(data)
    errors.extend(api_errors)

    schema = json.loads(SOAK_SCHEMA.read_text(encoding="utf-8"))
    soak = data.get("demo_soak")
    if not isinstance(soak, dict):
        errors.append("demo_soak must be an object")
        soak_digest = ""
    else:
        soak_errors, soak_digest = validate_soak(soak, schema)
        errors.extend(soak_errors)
        record_path_raw = str(soak.get("acceptance_record_path", "")).strip()
        if record_path_raw:
            record_path = resolve(record_path_raw)
            if record_path.exists():
                try:
                    record = json.loads(record_path.read_text(encoding="utf-8"))
                    record_errors, record_digest = validate_record(record, require_digest=True)
                    errors.extend(f"five-day record: {e}" for e in record_errors)
                    candidate = record.get("candidate", {})
                    for rk, bk in (("git_sha", "git_sha"), ("ex5_sha256", "ex5_sha256"), ("set_sha256", "set_sha256")):
                        require(errors, str(candidate.get(rk, "")).lower() == str(build.get(bk, "")).lower(),
                                f"five-day record candidate.{rk} must match build.{bk}")
                    require(errors, record_digest.lower() == str(soak.get("acceptance_record_digest", "")).lower(),
                            "five-day record digest must match demo_soak.acceptance_record_digest")
                    require(errors, str(record.get("record_id", "")) == str(soak.get("acceptance_record_id", "")),
                            "five-day record ID must match demo_soak.acceptance_record_id")
                except Exception as exc:
                    errors.append(f"could not cross-check five-day acceptance record: {exc}")
            else:
                errors.append(f"five-day acceptance record not found: {record_path}")
        else:
            errors.append("demo_soak.acceptance_record_path is required")

    gates = data.get("gates", {})
    required_gates = [
        "metaeditor_compile", "artifact_identity", "ci_static", "strategy_tester", "intelligence_matrix",
        "adaptive_portfolio", "execution_learning", "champion_challenger", "lifecycle_integrity",
        "broker_matrix", "deployment_profile", "recovery", "stop_matrix", "broker_stop_policy",
        "partial_protection", "stop_observability", "live_news_intermarket", "web_failure_injection",
        "api_transport", "demo_soak", "operator_review",
    ]
    for key in required_gates:
        require(errors, gates.get(key) is True, f"gates.{key} must be true")

    final_review = data.get("final_review", {})
    require(errors, final_review.get("schema_version") == "final_release_review_v1",
            "final_review.schema_version must be final_release_review_v1")
    require(errors, len(str(final_review.get("review_evidence_id", "")).strip()) >= 4,
            "final_review.review_evidence_id is required")
    require(errors, bool(HEX64.fullmatch(str(final_review.get("review_digest", "")))),
            "final_review.review_digest must be 64 hexadecimal characters")
    require(errors, final_review.get("decision") == "GO", "final_review.decision must be GO")
    require(errors, len(str(final_review.get("reviewer", "")).strip()) >= 2, "final_review.reviewer is required")
    require(errors, len(str(final_review.get("review_timestamp", "")).strip()) >= 8, "final_review.review_timestamp is required")

    canonical = json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()

    out = ROOT / "release-evidence-validation.txt"
    if errors:
        text = "RELEASE EVIDENCE VALIDATION: FAILED\n" + "\n".join(f"ERROR: {e}" for e in errors)
        if ci_bundle_digest:
            text += f"\nCI_BUNDLE_SHA256: {ci_bundle_digest}"
        if api_digest:
            text += f"\nAPI_TRANSPORT_SHA256: {api_digest}"
        if soak_digest:
            text += f"\nSOAK_EVIDENCE_SHA256: {soak_digest}"
        text += f"\nEVIDENCE_JSON_SHA256: {digest}\n"
        out.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = (
        f"RELEASE EVIDENCE VALIDATION: PASS\nRELEASE_ID: {required_id}\n"
        f"CI_EVIDENCE_SHA256: {ci['evidence_digest']}\nCI_BUNDLE_SHA256: {ci_bundle_digest}\n"
        f"API_TRANSPORT_SHA256: {api_digest}\nSOAK_EVIDENCE_SHA256: {soak_digest}\n"
        f"EVIDENCE_JSON_SHA256: {digest}\n"
    )
    out.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
