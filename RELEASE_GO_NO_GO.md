<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚀 Release Engineering & Evidence

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚀 **Document:** `RELEASE_GO_NO_GO.md`

---

# GPT_EA Final GO / NO-GO Release Contract — R6 Base + Current API Transport Guard

This is the final production decision contract. A candidate is **GO** only when every mandatory release gate is PASS, the exact artifact/deployment identity is archived, executed GitHub Actions evidence is bound to the candidate, the five-day machine/operator soak acceptance is complete, the selected API/WebRequest transport passes its release matrix, and the machine-validated final review returns GO.

## GO requires all of the following

- MetaEditor compile gate PASS with 0 errors and 0 production warnings.
- Machine-readable compile-evidence record validates for the exact source/EX5/SET candidate.
- R10 privacy sign-off validates for the exact customer jurisdiction with zero unresolved critical findings.
- Exact Git SHA recorded.
- Exact EX5 SHA-256 archived.
- Exact SET SHA-256 archived, or explicit `NONE`.
- `RELEASE_EVIDENCE_TEMPLATE.json` completed for the exact candidate.
- Validated `runner_recovery_evidence_v1` proving recovery from the known pre-runner failure.
- Validated `runner_recovery_acceptance_v1` with RA-001 through RA-022 PASS.
- Executed GitHub Actions static job on a real allocated runner.
- CI run/attempt/job IDs > 0, `runner_id > 0`, non-empty runner name and at least 7 executed static-job steps.
- CI static job conclusion is literal `success` and its head SHA equals the certified build Git SHA.
- `ci-evidence.json` validates against completed `ci-job-metadata.json`.
- GitHub attestation for `ci-evidence.json` is created and independently verified.
- `ci-bundle-manifest.json` validates under `ci_evidence_bundle_v1` and all archived file hashes match.
- `ci_static.bundle_validated=true` only from that passing bundle.
- Validated `mt5_validation_evidence_v2` for the exact candidate, including hashed compile/tester/runtime artifacts and literal PASS for M5-001 through M5-053.
- Strategy Tester and every applicable intelligence/adaptive/broker/recovery/stop/news matrix PASS.
- Validated `resilience_hardening_evidence_v1` for the exact Git SHA and certified configuration fingerprint, with RH-001 through RH-048 PASS.
- Atomic intent and exactly-once execution tests PASS with zero unresolved intent and zero duplicate order.
- Broker-versus-EA reconciliation, manual-intervention detection and learning quarantine PASS.
- News provenance URL annotations and strict `as_of_utc` freshness tests PASS.
- Macro stress tests PASS for USD strengthening, +20 bp yields, equity risk-off, gold ±2%, oil ±4%, volatility spike and correlated-gap scenarios.
- Gap-risk, stressed-margin, decision-half-life and model-degradation tests PASS.
- Chaos/fault-injection matrix PASS on DEMO/TEST and REAL-account chaos refusal PASS.
- Critical storage failure and certified configuration drift both fail closed.
- Rollback readiness validates as `VALIDATED_PACKAGE` or the explicitly reviewed `FIRST_CERTIFIED_RELEASE` case.
- Deployment profile/drift validation PASS.
- `API_TRANSPORT_TEST_MATRIX.md` HIGH-priority cases applicable to the selected mode PASS.
- `api_transport` evidence records the tested DIRECT_OPENAI or SECURE_PROXY mode, WebRequest allow-list verification, deep-review path, web-search path, failure/recovery behavior, request tracing and zero secret leaks.
- `tools/validate_api_transport_evidence.py` returns PASS.
- `InpReleaseAPITransportPassed=true` is set only from matching archived evidence.
- `FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json` uses `five_day_soak_acceptance_v2` and is completed for exactly five accepted trading days on the same candidate.
- Every accepted day references a completed `SOAK_DAY_RECONCILIATION_CHECKLIST.md` copy with literal `ACCEPT DAY`, reviewer and timestamp.
- `operator_record_path` points to a completed `FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md` copy.
- `report_path` points to the completed demo-soak report.
- `tools/validate_five_day_soak_record.py ... --finalize` and the subsequent validation return PASS.
- `SOAK_EVIDENCE_SCHEMA.json` validation PASS and the accepted five-day record ID/digest is bound to `demo_soak`.
- All soak/five-day zero-tolerance counters equal 0.
- All required soak evidence logs/checkpoints observed.
- All five lifecycle assertions are true.
- `FINAL_RELEASE_REVIEW_TEMPLATE.json` completed for the exact candidate and stable evidence basis.
- `tools/validate_final_release_review.py` returns PASS.
- final decision is literal `GO`.
- `tools/validate_release_evidence.py` returns PASS.
- `tools/validate_release_evidence_r7.py` returns PASS for the current API transport wrapper.
- `tools/validate_release_evidence_r10.py` returns PASS for compile/privacy evidence.
- `tools/validate_final_release_review_r10.py` returns PASS.
- all release-validation outputs and final evidence hashes are archived.
- candidate release-truth dashboard is regenerated from the same final evidence JSON and `--require-pass` succeeds.

## Automatic NO-GO conditions

R10/compile automatic NO-GO also includes:

- compile-evidence validator failure or digest mismatch;
- compile evidence bound to a different Git/EX5/SET candidate;
- privacy sign-off missing, stale, unvalidated or digest-mismatched;
- privacy jurisdiction mismatch;
- unapproved telemetry state;
- any unresolved critical privacy finding;
- missing privacy data-inventory/retention/customer-notice/secret-handling/cross-border/deletion/incident approval;

The release is **NO-GO** for any of the following:

- compile error or unresolved production warning;
- compiled EX5 cannot be tied to the recorded source commit;
- EX5/SET hash mismatch;
- stale release validation/evidence contract;
- runner-recovery evidence missing/invalid or recovery regresses to the pre-runner signature;
- runner-recovery acceptance matrix incomplete, HOLD, digest-mismatched or not joined to the accepted CI bundle;
- MT5 validation evidence missing/invalid, wrong candidate/build/broker identity, or any required M5 row not PASS;
- MT5 validation schema is not `mt5_validation_evidence_v2` or any M5-035 through M5-053 resilience row is incomplete;
- resilience hardening evidence missing/invalid, any RH-001 through RH-048 row not PASS, or certified configuration fingerprint mismatch;
- unresolved PREPARED/SENT/UNCERTAIN intent, exactly-once duplicate submission, or unreconciled broker position/order/deal;
- provenance/freshness hard failure is bypassed by fallback;
- macro stress, gap-risk or stressed-margin limit is exceeded;
- critical storage failure or configuration drift does not block new exposure;
- chaos/fault injection can run on REAL;
- rollback readiness is absent or invalid;
- CI job completed without a real runner identity;
- `runner_id=0`, empty runner name or empty/unexecuted step list used as release evidence;
- CI head SHA differs from `build.git_sha`;
- static check does not end in `RESULT=PASS`;
- CI evidence/job-metadata identity mismatch;
- CI evidence digest or bundle file hash mismatch;
- required GitHub attestation is absent or verification fails;
- CI bundle validator FAIL;
- API transport release matrix FAIL;
- `gates.api_transport` is not true;
- WebRequest allow-list not verified for the selected endpoint;
- DIRECT mode attempts to send the OpenAI bearer key to a non-`api.openai.com` endpoint;
- PROXY mode exposes or forwards the OpenAI bearer key from MT5;
- proxy credential reuses the OpenAI API key;
- API/proxy secret appears in source or health/release logs;
- required GPT/web intelligence failure can authorize a trade instead of following WAIT/NO-TRADE policy;
- uncontrolled synchronous API retry loop;
- API transport evidence validator FAIL;
- five-day acceptance machine record FAIL;
- five-day operator record is absent/incomplete;
- five-day record candidate Git/EX5/SET differs from build identity;
- five-day acceptance digest mismatch;
- soak schema validation FAIL or soak digest mismatch;
- fewer than 5 accepted trading days;
- insufficient London/New York/session-event coverage;
- missing scheduled, continuous or manual-scan evidence;
- missing primary/backup checkpoint evidence;
- any lifecycle assertion false;
- any zero-tolerance soak/reconciliation counter above zero;
- any unresolved critical state;
- duplicate order or duplicate partial;
- stop regression;
- unprotected-position new authorization;
- release-gate bypass;
- duplicate analytics finalization;
- stop-observability join failure;
- dashboard/gate mismatch;
- runtime critical-error loop;
- deployment identity mismatch or structural drift not reviewed/revalidated;
- recovery inconsistency or non-idempotent lifecycle;
- final review decision other than `GO`;
- final review candidate/evidence basis mismatch;
- final review validator FAIL;
- base or current supplemental release evidence validator FAIL;
- executable source changed after validation;
- required evidence artifact missing;
- any unexplained critical Journal/Experts error.

## HOLD conditions

Use **HOLD** when the candidate may still become releasable but evidence is incomplete, a noncritical issue requires investigation, a reviewer is unavailable, a deployment/API endpoint change requires targeted revalidation, or GitHub/MetaEditor external release infrastructure is unavailable.

In particular, the current GitHub hosted-runner provisioning condition is HOLD while jobs remain queued/pre-runner or finish with `runner_id=0` and no executed steps. This is not a source PASS and should not be converted into manual CI attestation.

HOLD must never arm real trading.

## Required release identity

Record and reconcile:

- Git SHA and release validation ID;
- MetaTrader/MetaEditor builds and compile evidence ID;
- EX5 SHA-256 and SET SHA-256/`NONE`;
- CI run ID/attempt/job ID/runner ID/steps/head SHA;
- CI evidence digest and final CI bundle digest/artifact name;
- attestation verification output;
- runner-recovery acceptance ID/digest;
- MT5 validation v2 evidence ID/digest and retained intent/reconciliation/provenance/model-health/runtime-report hashes;
- resilience-hardening evidence ID/digest and certified configuration fingerprint;
- rollback readiness mode/package digest and validation output;
- selected API transport mode and endpoint host/origin;
- API transport evidence digest/output;
- soak schema/evidence ID/digest;
- five-day acceptance record ID/digest/path;
- five-day operator record and demo-soak report paths;
- final review evidence ID/digest/reviewer/timestamp;
- broker company/server and account profile;
- resolved symbols and test/soak date range.

## Runtime evidence mapping

Part28B must receive values only from accepted runner, CI, MT5 and five-day evidence:

- `InpReleaseRunnerRecoveryPassed=true`
- `InpReleaseRunnerRecoverySchemaVersion=runner_recovery_evidence_v1`
- `InpReleaseRunnerRecoveryEvidenceId`
- `InpReleaseRunnerRecoveryDigest`
- `InpReleaseRunnerRecoveryAcceptancePassed=true`
- `InpReleaseRunnerRecoveryAcceptanceSchemaVersion=runner_recovery_acceptance_v1`
- `InpReleaseRunnerRecoveryAcceptanceId`
- `InpReleaseRunnerRecoveryAcceptanceDigest`

- `InpReleaseCIStaticEvidencePassed=true`
- `InpReleaseCISchemaVersion=github_actions_static_evidence_v1`
- `InpReleaseCIRunId`, `InpReleaseCIRunAttempt`, `InpReleaseCIJobId`, `InpReleaseCIRunnerId`
- `InpReleaseCIStepsExecuted`
- `InpReleaseCIHeadSha`
- `InpReleaseCIEvidenceDigest`
- `InpReleaseCIConclusion=success`
- accepted artifact/archive/attestation fields
- `InpReleaseCIBundleSchemaVersion=ci_evidence_bundle_v1`
- `InpReleaseCIBundleDigest`
- `InpReleaseCIBundleValidated=true`
- `InpReleaseMT5ValidationPassed=true`
- `InpReleaseMT5ValidationSchemaVersion=mt5_validation_evidence_v2`
- `InpReleaseMT5ValidationEvidenceId`
- `InpReleaseMT5ValidationDigest`
- `InpReleaseResilienceHardeningPassed=true`
- `InpReleaseResilienceSchemaVersion=resilience_hardening_evidence_v1`
- `InpReleaseResilienceEvidenceId`
- `InpReleaseResilienceDigest`
- `InpReleaseCertifiedConfigFingerprint`
- `InpReleaseSoakAcceptanceRecordId`
- `InpReleaseSoakAcceptanceRecordDigest`.

Do not enter PASS placeholders before the corresponding validators and archived evidence exist.

## Final human review

Follow `FINAL_GO_NO_GO_REVIEW.md`. Review the exact compile artifact, runner-recovery acceptance, executed CI bundle, MT5 validation evidence, five-day operator/machine acceptance, deployment profile, adaptive/broker/stop matrices, and API transport evidence.

For DIRECT mode, confirm the user's OpenAI key is local-only and the endpoint is `api.openai.com`. For PROXY mode, confirm the OpenAI key is server-side only, the MT5 request contains no OpenAI bearer header, and the proxy token is separately scoped/revocable.

Only then may the operator-review and API transport release flags be entered from matching evidence.

## Final machine validation

After final review has been incorporated into `release_evidence.json`, run:

```text
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_api_transport_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

All results must be PASS.

## Deployment rule

A GO applies only to the exact candidate artifact, selected API transport, endpoint and validated environment. Material source, preset/risk, release contract, API transport/endpoint, broker/server/account or structural symbol-contract changes invalidate GO and require appropriate revalidation.

## Decision record

Release reviewer:

Candidate Git SHA:

Release validation ID:

Runner-recovery acceptance ID/digest:

CI bundle digest/artifact:

MT5 validation evidence ID/digest:

API transport mode/evidence:

Five-day acceptance record ID/digest:

Soak evidence SHA-256:

Final review SHA-256:

Final release-evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:

Passing this contract does not guarantee profitability. It means the exact candidate has met the defined engineering, protection, recovery, broker-compatibility, CI-provenance, API-transport, evidence-integrity and operational release requirements.
