#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from json_bundle import materialize_legacy_json_documents
from release_contract import load_release_contract

materialize_legacy_json_documents()

ROOT = Path(__file__).resolve().parents[1]
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
MARGIN_MODES = {
    "ACCOUNT_MARGIN_MODE_RETAIL_NETTING": 0,
    "ACCOUNT_MARGIN_MODE_EXCHANGE": 1,
    "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING": 2,
    "RETAIL_NETTING": 0,
    "EXCHANGE": 1,
    "RETAIL_HEDGING": 2,
    "NETTING": 0,
    "HEDGING": 2,
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve(value: str) -> Path:
    p = Path(value)
    return p if p.is_absolute() else ROOT / p


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path} must contain a JSON object")
    return value


def run_validator(script: str, *args: Path) -> None:
    proc = subprocess.run(
        [sys.executable, str(ROOT / "tools" / script), *(str(x) for x in args)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"{script} failed:\n{proc.stdout}")


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def safe_string(value: Any, name: str) -> str:
    s = str(value if value is not None else "")
    if "\n" in s or "\r" in s or "||" in s:
        raise RuntimeError(f"{name} contains characters unsafe for a MetaTrader SET value")
    return s


def set_line(name: str, value: Any, kind: str) -> str:
    if kind == "string":
        return f"{name}={safe_string(value, name)}"
    if kind == "bool":
        v = "true" if bool(value) else "false"
        return f"{name}={v}||false||0||true||N"
    if kind in {"int", "long", "enum"}:
        v = int(value)
        return f"{name}={v}||{v}||1||{v}||N"
    raise RuntimeError(f"unsupported SET kind {kind!r} for {name}")


def parse_base_set(path: Path) -> tuple[list[str], dict[str, int]]:
    lines = path.read_text(encoding="utf-8-sig", errors="strict").splitlines()
    index: dict[str, int] = {}
    for i, raw in enumerate(lines):
        s = raw.strip()
        if not s or s.startswith(";") or "=" not in s:
            continue
        name = s.split("=", 1)[0].strip()
        if name:
            index[name] = i
    return lines, index


def write_overlay(base_lines: list[str], index: dict[str, int], params: list[tuple[str, Any, str]]) -> str:
    lines = list(base_lines)
    for name, value, kind in params:
        line = set_line(name, value, kind)
        if name in index:
            lines[index[name]] = line
        else:
            index[name] = len(lines)
            lines.append(line)
    header = [
        "; GPT_EA deterministic release preset",
        "; Generated only after release/privacy/risk/final-review validation PASS.",
        "; Secrets (OpenAI API key and proxy token) are intentionally excluded.",
        "; InpReleaseSetSha256 records the certified baseline SET identity from release evidence.",
        "; The final deployment preset SHA-256 is recorded in the sidecar manifest.",
    ]
    body = "\n".join(header + [""] + lines).rstrip() + "\n"
    return body


def gate(data: dict[str, Any], key: str) -> bool:
    return data.get("gates", {}).get(key) is True


def margin_mode(value: Any) -> int:
    if isinstance(value, int):
        if value in {0, 1, 2}:
            return value
        raise RuntimeError("deployment.margin_mode integer must be 0, 1 or 2")
    text = str(value or "").strip().upper()
    if text.isdigit() and int(text) in {0, 1, 2}:
        return int(text)
    if text in MARGIN_MODES:
        return MARGIN_MODES[text]
    raise RuntimeError(f"unsupported deployment.margin_mode: {value!r}")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Validate finalized GPT_EA release evidence and export a deterministic MetaTrader .set release preset."
    )
    ap.add_argument("release_evidence", help="Finalized release evidence JSON")
    ap.add_argument("--final-review", default="artifacts/final-release-review.json")
    ap.add_argument("--privacy-signoff", default="", help="Defaults to release_evidence.privacy_signoff.evidence_path")
    ap.add_argument("--risk-ack", default="artifacts/customer-risk-acknowledgement.json")
    ap.add_argument("--base-set", default="", help="Certified baseline SET when build.set_sha256 is not NONE")
    ap.add_argument("--license-reference", default="", help="Prefer GPT_EA_LICENSE_REFERENCE env var to avoid shell history")
    ap.add_argument("--proxy-endpoint", default="", help="Required for SECURE_PROXY mode; proxy token is never exported")
    ap.add_argument("--output", default="artifacts/GPT_EA_RELEASE.set")
    ap.add_argument("--manifest", default="", help="Defaults to <output>.manifest.json")
    ap.add_argument("--allow-non-head", action="store_true", help="Permit evidence for a candidate other than the current git HEAD")
    args = ap.parse_args()

    contract = load_release_contract()
    evidence_path = resolve(args.release_evidence)
    if not evidence_path.exists():
        raise SystemExit(f"release evidence not found: {evidence_path}")
    evidence = load_json(evidence_path)

    privacy_ref = args.privacy_signoff or str(evidence.get("privacy_signoff", {}).get("evidence_path", ""))
    if not privacy_ref:
        raise SystemExit("privacy sign-off path is required")
    privacy_path = resolve(privacy_ref)
    risk_path = resolve(args.risk_ack)
    review_path = resolve(args.final_review)
    for p in (privacy_path, risk_path, review_path):
        if not p.exists():
            raise SystemExit(f"required evidence file not found: {p}")

    try:
        run_validator("validate_release_evidence_r10.py", evidence_path)
        run_validator("validate_final_release_review_r10.py", evidence_path, review_path)
        run_validator("validate_privacy_signoff.py", privacy_path)
        run_validator("validate_customer_risk_acknowledgement.py", risk_path)
    except RuntimeError as exc:
        raise SystemExit(str(exc))

    privacy = load_json(privacy_path)
    risk = load_json(risk_path)
    release_id = str(evidence.get("release_validation_id", ""))
    candidate_sha = str(evidence.get("build", {}).get("git_sha", ""))
    if release_id != contract["release_validation_id"]:
        raise SystemExit("release_validation_id does not match GPT_EA_DATA.json release_contract")
    if not HEX40.fullmatch(candidate_sha):
        raise SystemExit("build.git_sha must be a 40-character Git SHA")
    head = git_head()
    if not args.allow_non_head and head and candidate_sha.lower() != head.lower():
        raise SystemExit(f"candidate SHA {candidate_sha} does not match current HEAD {head}")
    if str(privacy.get("release_id", "")) != release_id:
        raise SystemExit("privacy sign-off release_id does not match release evidence")
    if str(privacy.get("git_sha", "")).lower() != candidate_sha.lower():
        raise SystemExit("privacy sign-off git_sha does not match release evidence")

    risk_jur = str(risk.get("jurisdiction", "")).strip()
    privacy_jur = str(privacy.get("jurisdiction", "")).strip()
    if risk_jur != privacy_jur:
        raise SystemExit("risk acknowledgement jurisdiction must match privacy sign-off jurisdiction")
    if risk.get("schema_version") != contract["risk_ack_schema"]:
        raise SystemExit("risk acknowledgement schema does not match release_contract")
    if risk.get("terms_version") != contract["legal_terms_version"]:
        raise SystemExit("risk acknowledgement terms version does not match release_contract")
    if privacy.get("schema_version") != contract["privacy_schema"]:
        raise SystemExit("privacy sign-off schema does not match release_contract")

    privacy_summary = evidence.get("privacy_signoff", {})
    if str(privacy_summary.get("signoff_id", "")) != str(privacy.get("signoff_id", "")):
        raise SystemExit("privacy signoff_id mismatch between release evidence and privacy record")
    if str(privacy_summary.get("evidence_digest", "")).lower() != str(privacy.get("evidence_digest", "")).lower():
        raise SystemExit("privacy digest mismatch between release evidence and privacy record")

    license_reference = args.license_reference or os.environ.get("GPT_EA_LICENSE_REFERENCE", "")
    if len(license_reference.strip()) < 6:
        raise SystemExit("customer license reference is required via --license-reference or GPT_EA_LICENSE_REFERENCE")
    masked = str(risk.get("license_reference_masked", ""))
    suffix = masked[-4:] if len(masked) >= 4 else ""
    if suffix and suffix != "****" and not license_reference.endswith(suffix):
        raise SystemExit("customer license reference does not match masked risk-acknowledgement suffix")

    build = evidence.get("build", {})
    baseline_sha = str(build.get("set_sha256", "NONE"))
    base_lines: list[str] = []
    base_index: dict[str, int] = {}
    base_path: Path | None = None
    if baseline_sha == "NONE" and args.base_set:
        raise SystemExit("--base-set cannot be used when release evidence build.set_sha256 is NONE")
    if baseline_sha != "NONE":
        if not HEX64.fullmatch(baseline_sha) or set(baseline_sha) == {"0"}:
            raise SystemExit("build.set_sha256 must be NONE or a non-zero SHA-256")
        if not args.base_set:
            raise SystemExit("--base-set is required because build.set_sha256 is not NONE")
        base_path = resolve(args.base_set)
        if not base_path.exists():
            raise SystemExit(f"baseline SET not found: {base_path}")
        if sha256_file(base_path).lower() != baseline_sha.lower():
            raise SystemExit("baseline SET SHA-256 does not match release evidence build.set_sha256")
        base_lines, base_index = parse_base_set(base_path)

    demo = evidence.get("demo_soak", {})
    ci = evidence.get("ci_static", {})
    rr = evidence.get("runner_recovery", {})
    ra = evidence.get("runner_recovery_acceptance", {})
    mt5 = evidence.get("mt5_validation", {})
    rh = evidence.get("resilience_hardening", {})
    review = evidence.get("final_review", {})
    deployment = evidence.get("deployment", {})
    api = evidence.get("api_transport", {})
    controls = privacy.get("controls", {})
    ack = risk.get("acknowledgements", {})

    basic_gates = {
        "InpReleaseMetaEditorCompilePassed": "metaeditor_compile",
        "InpReleaseArtifactIdentityArchived": "artifact_identity",
        "InpReleaseStrategyTesterPassed": "strategy_tester",
        "InpReleaseIntelligenceMatrixPassed": "intelligence_matrix",
        "InpReleaseAdaptivePortfolioPassed": "adaptive_portfolio",
        "InpReleaseExecutionLearningPassed": "execution_learning",
        "InpReleaseChampionChallengerPassed": "champion_challenger",
        "InpReleaseLifecycleIntegrityPassed": "lifecycle_integrity",
        "InpReleaseBrokerMatrixPassed": "broker_matrix",
        "InpReleaseDeploymentProfilePassed": "deployment_profile",
        "InpReleaseRecoveryTestsPassed": "recovery",
        "InpReleaseStopMatrixPassed": "stop_matrix",
        "InpReleaseBrokerStopPolicyPassed": "broker_stop_policy",
        "InpReleasePartialProtectionPassed": "partial_protection",
        "InpReleaseStopObservabilityPassed": "stop_observability",
        "InpReleaseLiveNewsIntermarketPassed": "live_news_intermarket",
        "InpReleaseWebFailureInjectionPassed": "web_failure_injection",
        "InpReleaseDemoSoakPassed": "demo_soak",
        "InpReleaseOperatorReviewPassed": "operator_review",
    }

    params: list[tuple[str, Any, str]] = [
        ("InpReleaseValidationId", release_id, "string"),
        ("InpReleaseSourceCommitSha", candidate_sha, "string"),
        ("InpReleaseEx5Sha256", build.get("ex5_sha256", ""), "string"),
        ("InpReleaseSetSha256", baseline_sha, "string"),
        ("InpReleaseCompileEvidenceId", build.get("compile_evidence_id", ""), "string"),
        ("InpReleaseMetaEditorBuild", build.get("metaeditor_build", ""), "string"),
        ("InpReleaseMT5Build", build.get("mt5_build", ""), "string"),
    ]
    params += [(name, gate(evidence, key), "bool") for name, key in basic_gates.items()]
    params += [
        ("InpReleaseSoakSchemaVersion", demo.get("schema_version", ""), "string"),
        ("InpReleaseSoakEvidenceId", demo.get("evidence_id", ""), "string"),
        ("InpReleaseSoakEvidenceDigest", demo.get("evidence_digest", ""), "string"),
        ("InpReleaseSoakTradingDays", demo.get("trading_days", 0), "int"),
        ("InpReleaseSoakLondonSessions", demo.get("london_sessions", 0), "int"),
        ("InpReleaseSoakNYSessions", demo.get("ny_sessions", 0), "int"),
        ("InpReleaseSoakOverlapObserved", demo.get("overlap_observed", False), "bool"),
        ("InpReleaseSoakNewsDayObserved", demo.get("news_day_observed", False), "bool"),
        ("InpReleaseSoakRolloverObserved", demo.get("rollover_observed", False), "bool"),
        ("InpReleaseSoakRestartObserved", demo.get("restart_observed", False), "bool"),
        ("InpReleaseSoakReconnectObserved", demo.get("reconnect_observed", False), "bool"),
        ("InpReleaseSoakScheduledScans", demo.get("scheduled_scans", 0), "int"),
        ("InpReleaseSoakContinuousScans", demo.get("continuous_scans", 0), "int"),
        ("InpReleaseSoakCheckpointUpdates", demo.get("checkpoint_updates", 0), "int"),
        ("InpReleaseSoakBackupCheckpointUpdates", demo.get("backup_checkpoint_updates", 0), "int"),
        ("InpReleaseSoakZeroToleranceFailures", demo.get("zero_tolerance_failures", 0), "int"),
        ("InpReleaseSoakUnresolvedCriticalStates", demo.get("unresolved_critical_states", 0), "int"),
        ("InpReleaseSoakDuplicateOrders", demo.get("duplicate_orders", 0), "int"),
        ("InpReleaseSoakDuplicatePartials", demo.get("duplicate_partials", 0), "int"),
        ("InpReleaseSoakSLRegressions", demo.get("sl_regressions", 0), "int"),
        ("InpReleaseSoakUnprotectedAuthorizations", demo.get("unprotected_new_authorizations", 0), "int"),
        ("InpReleaseSoakReleaseGateBypasses", demo.get("release_gate_bypasses", 0), "int"),
        ("InpReleaseSoakAnalyticsDuplicateFinal", demo.get("analytics_duplicate_finalizations", 0), "int"),
        ("InpReleaseSoakStopJoinFailures", demo.get("stop_failure_join_failures", 0), "int"),
        ("InpReleaseSoakDashboardMismatches", demo.get("dashboard_gate_mismatches", 0), "int"),
        ("InpReleaseSoakRuntimeCriticalErrors", demo.get("runtime_critical_errors", 0), "int"),
        ("InpReleaseSoakSecretsExposed", demo.get("secrets_exposed", 0), "int"),
        ("InpReleaseSoakExecutionLogPresent", demo.get("execution_log_present", False), "bool"),
        ("InpReleaseSoakStopLogPresent", demo.get("stop_log_present", False), "bool"),
        ("InpReleaseSoakReleaseLogPresent", demo.get("release_evidence_log_present", False), "bool"),
        ("InpReleaseFinalReviewEvidenceId", review.get("review_evidence_id", ""), "string"),
        ("InpReleaseFinalReviewDigest", review.get("review_digest", ""), "string"),
        ("InpReleaseFinalDecision", review.get("decision", ""), "string"),
        ("InpReleaseFinalReviewer", review.get("reviewer", ""), "string"),
        ("InpReleaseFinalReviewTimestamp", review.get("review_timestamp", ""), "string"),
        ("InpReleaseRunnerRecoveryPassed", gate(evidence, "runner_recovery"), "bool"),
        ("InpReleaseRunnerRecoverySchemaVersion", rr.get("schema_version", ""), "string"),
        ("InpReleaseRunnerRecoveryEvidenceId", rr.get("evidence_id", ""), "string"),
        ("InpReleaseRunnerRecoveryDigest", rr.get("evidence_digest", ""), "string"),
        ("InpReleaseRunnerRecoveryAcceptancePassed", gate(evidence, "runner_recovery_acceptance"), "bool"),
        ("InpReleaseRunnerRecoveryAcceptanceSchemaVersion", ra.get("schema_version", ""), "string"),
        ("InpReleaseRunnerRecoveryAcceptanceId", ra.get("acceptance_id", ""), "string"),
        ("InpReleaseRunnerRecoveryAcceptanceDigest", ra.get("acceptance_digest", ""), "string"),
        ("InpReleaseCIStaticEvidencePassed", gate(evidence, "ci_static"), "bool"),
        ("InpReleaseCISchemaVersion", ci.get("schema_version", ""), "string"),
        ("InpReleaseCIRunId", ci.get("run_id", 0), "long"),
        ("InpReleaseCIRunAttempt", ci.get("run_attempt", 0), "int"),
        ("InpReleaseCIJobId", ci.get("job_id", 0), "long"),
        ("InpReleaseCIRunnerId", ci.get("runner_id", 0), "long"),
        ("InpReleaseCIStepsExecuted", ci.get("steps_executed", 0), "int"),
        ("InpReleaseCIHeadSha", ci.get("head_sha", ""), "string"),
        ("InpReleaseCIEvidenceDigest", ci.get("evidence_digest", ""), "string"),
        ("InpReleaseCIConclusion", ci.get("conclusion", ""), "string"),
        ("InpReleaseCIArtifactName", ci.get("artifact_name", ""), "string"),
        ("InpReleaseCIArtifactArchived", ci.get("artifact_archived", False), "bool"),
        ("InpReleaseCIAttestationVerified", ci.get("attestation_verified", False), "bool"),
        ("InpReleaseCIBundleSchemaVersion", ci.get("bundle_schema_version", ""), "string"),
        ("InpReleaseCIBundleDigest", ci.get("bundle_digest", ""), "string"),
        ("InpReleaseCIBundleValidated", ci.get("bundle_validated", False), "bool"),
        ("InpReleaseMT5ValidationPassed", gate(evidence, "mt5_validation"), "bool"),
        ("InpReleaseMT5ValidationSchemaVersion", mt5.get("schema_version", ""), "string"),
        ("InpReleaseMT5ValidationEvidenceId", mt5.get("evidence_id", ""), "string"),
        ("InpReleaseMT5ValidationDigest", mt5.get("evidence_digest", ""), "string"),
        ("InpReleaseResilienceHardeningPassed", gate(evidence, "resilience_hardening"), "bool"),
        ("InpReleaseResilienceSchemaVersion", rh.get("schema_version", ""), "string"),
        ("InpReleaseResilienceEvidenceId", rh.get("evidence_id", ""), "string"),
        ("InpReleaseResilienceDigest", rh.get("evidence_digest", ""), "string"),
        ("InpReleaseCertifiedConfigFingerprint", rh.get("config_fingerprint", ""), "string"),
        ("InpReleaseSoakAcceptanceSchemaVersion", demo.get("acceptance_record_schema_version", ""), "string"),
        ("InpReleaseSoakAcceptanceRecordId", demo.get("acceptance_record_id", ""), "string"),
        ("InpReleaseSoakAcceptanceRecordDigest", demo.get("acceptance_record_digest", ""), "string"),
        ("InpReleaseAPITransportPassed", gate(evidence, "api_transport"), "bool"),
        ("InpAPITransportMode", 1 if api.get("mode") == "SECURE_PROXY" else 0, "enum"),
        ("InpAPIRequireHTTPS", api.get("https_required", True), "bool"),
        ("InpAPIRequireProxyOnReal", api.get("mode") == "SECURE_PROXY", "bool"),
        ("InpAcceptGPTCommercialTerms", ack.get("commercial_terms", False), "bool"),
        ("InpAcceptGPTTradingRisk", ack.get("trading_risk", False), "bool"),
        ("InpGPTTermsAcceptancePhrase", contract["legal_acceptance_phrase"], "string"),
        ("InpCustomerLicenseReference", license_reference, "string"),
        ("InpAcknowledgeNoProfitGuarantee", ack.get("no_profit_guarantee", False), "bool"),
        ("InpAcknowledgePossibleTotalLoss", ack.get("possible_total_loss", False), "bool"),
        ("InpAcknowledgeAILimitations", ack.get("ai_limitations", False), "bool"),
        ("InpAcknowledgeBrokerThirdPartyRisk", ack.get("broker_third_party_risk", False), "bool"),
        ("InpAcknowledgePersonalResponsibility", ack.get("personal_responsibility", False), "bool"),
        ("InpAcknowledgeDemoFirst", ack.get("demo_first", False), "bool"),
        ("InpCustomerJurisdiction", risk_jur, "string"),
        ("InpAcceptedGPTTermsVersion", contract["legal_terms_version"], "string"),
        ("InpAcceptedGPTRiskAckVersion", contract["risk_ack_schema"], "string"),
        ("InpReleasePrivacySignoffPassed", gate(evidence, "privacy_signoff"), "bool"),
        ("InpReleasePrivacySignoffSchemaVersion", privacy.get("schema_version", ""), "string"),
        ("InpReleasePrivacySignoffId", privacy.get("signoff_id", ""), "string"),
        ("InpReleasePrivacySignoffDigest", privacy.get("evidence_digest", ""), "string"),
        ("InpReleasePrivacyReviewer", privacy.get("reviewer", ""), "string"),
        ("InpReleasePrivacyReviewerRole", privacy.get("reviewer_role", ""), "string"),
        ("InpReleasePrivacySignedAt", privacy.get("signed_at_utc", ""), "string"),
        ("InpReleasePrivacyJurisdiction", privacy_jur, "string"),
        ("InpReleasePrivacyDataInventoryApproved", controls.get("data_inventory_approved", False), "bool"),
        ("InpReleasePrivacyRetentionApproved", controls.get("retention_schedule_approved", False), "bool"),
        ("InpReleasePrivacyCustomerNoticeApproved", controls.get("customer_notice_approved", False), "bool"),
        ("InpReleasePrivacySecretHandlingApproved", controls.get("secret_handling_approved", False), "bool"),
        ("InpReleasePrivacyCrossBorderApproved", controls.get("cross_border_review_approved", False), "bool"),
        ("InpReleasePrivacyDeletionWorkflowApproved", controls.get("deletion_workflow_approved", False), "bool"),
        ("InpReleasePrivacyIncidentResponseApproved", controls.get("incident_response_approved", False), "bool"),
        ("InpReleasePrivacyTelemetryState", controls.get("telemetry_state", ""), "string"),
        ("InpReleasePrivacyUnresolvedCriticalFindings", controls.get("unresolved_critical_findings", 0), "int"),
    ]

    if gate(evidence, "deployment_profile"):
        params += [
            ("InpRequireExpectedIdentityOnReal", True, "bool"),
            ("InpExpectedBrokerCompany", deployment.get("broker_company", ""), "string"),
            ("InpExpectedTradeServer", deployment.get("trade_server", ""), "string"),
            ("InpExpectedAccountCurrency", deployment.get("account_currency", ""), "string"),
            ("InpExpectedMarginMode", margin_mode(deployment.get("margin_mode")), "int"),
            ("InpExpectedAccountLeverage", int(deployment.get("account_leverage", 0) or 0), "int"),
        ]

    if api.get("mode") == "SECURE_PROXY":
        proxy = args.proxy_endpoint or os.environ.get("GPT_EA_PROXY_ENDPOINT", "")
        if not proxy.startswith("https://"):
            raise SystemExit("SECURE_PROXY release requires HTTPS --proxy-endpoint or GPT_EA_PROXY_ENDPOINT")
        params.append(("InpAPIProxyEndpoint", proxy, "string"))

    output = resolve(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = write_overlay(base_lines, base_index, params)
    output.write_text(payload, encoding="utf-8")
    final_sha = sha256_file(output)

    manifest_path = resolve(args.manifest) if args.manifest else Path(str(output) + ".manifest.json")
    manifest = {
        "schema_version": "gpt_ea_mt5_release_preset_manifest_v1",
        "contract_version": contract["contract_version"],
        "release_validation_id": release_id,
        "candidate_git_sha": candidate_sha,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "release_evidence_path": str(evidence_path),
        "release_evidence_sha256": sha256_file(evidence_path),
        "privacy_signoff_path": str(privacy_path),
        "privacy_signoff_sha256": sha256_file(privacy_path),
        "risk_ack_path": str(risk_path),
        "risk_ack_sha256": sha256_file(risk_path),
        "final_review_path": str(review_path),
        "final_review_sha256": sha256_file(review_path),
        "certified_baseline_set_path": str(base_path) if base_path else "",
        "certified_baseline_set_sha256": baseline_sha,
        "deployment_set_path": str(output),
        "deployment_set_sha256": final_sha,
        "api_secrets_included": False,
        "proxy_token_included": False,
        "openai_api_key_included": False,
        "customer_license_reference_included": True,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print("GPT_EA MT5 RELEASE INPUT EXPORT: PASS")
    print("OUTPUT:", output)
    print("DEPLOYMENT_SET_SHA256:", final_sha)
    print("MANIFEST:", manifest_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
