<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚀 Release Engineering & Evidence

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚀 **Document:** `RELEASE_CERTIFICATION.md`

---

# GPT_EA Live Release Certification — R6 Base + Current Supplemental Guards

The base release validation identity remains:

`GPT_EA_FULL_INTELLIGENCE_R6_20260917`

The active runtime safety chain is layered:

`Part28 base R6 certification → Part29 deployment drift → Part28B runner/CI/MT5/five-day evidence → Part37 API transport guard`.

The later wrappers do not weaken or replace R6. Every layer must pass simultaneously before REAL-account arming.

## Default fail-closed behavior

All production-release attestations default to `false` and evidence identities/digests default blank. A REAL account remains blocked even when the ordinary live-arm phrase is present until the complete matching evidence is supplied.

Strategy Tester remains usable without real-account certification. Demo/contest accounts remain available for evidence generation.

## 1. Compile and artifact identity

Required:

- exact 40-hex Git SHA;
- exact 64-hex EX5 SHA-256;
- exact SET SHA-256 or `NONE`;
- 0 compile errors and 0 production warnings;
- compile evidence ID;
- MetaEditor and MT5 build identity;
- artifact identity archived.

Follow `METAEDITOR_COMPILE_GATE.md`.

## 2. Runner recovery and production acceptance

Part28B requires both `runner_recovery_evidence_v1` and `runner_recovery_acceptance_v1`. The recovery record proves the original pre-runner failure was followed by real runner execution; the acceptance record requires RA-001 through RA-022, joins the exact candidate and CI-bundle digest, and records operator acceptance.

Validate both records before CI is treated as production evidence.

## 3. Executed GitHub Actions evidence

Part28B requires executed CI provenance; a created/failed pre-runner workflow is not evidence.

Follow `CI_EVIDENCE_CONTRACT.md`. A valid CI record requires:

- run ID/attempt/job ID > 0;
- `runner_id > 0` and runner name present;
- at least 7 executed static-job steps;
- static job conclusion `success`;
- exact source SHA match;
- repository aggregate static result PASS;
- validated `ci-evidence.json`;
- verified GitHub provenance attestation;
- archived/validated `ci_evidence_bundle_v1` bundle.

Part28B additionally requires `InpReleaseCIBundleValidated=true` and the matching bundle SHA-256.

`runner_id=0`, blank runner name or `steps=[]` is HOLD and cannot be converted manually into PASS.

## 4. MT5/MetaEditor validation evidence

The exact release candidate must produce a finalized `mt5_validation_evidence_v1` record following `MT5_VALIDATION_EVIDENCE.md` and `MT5_VALIDATION_ACCEPTANCE_MATRIX.md`. It binds compile/load smoke, Strategy Tester, broker geometry, recovery, stop/protection behavior, live-demo WebRequest/news paths, and hashed MT5 artifacts.

Run `tools/validate_mt5_validation_evidence.py` and archive its PASS output before setting the Part28B MT5 evidence inputs.

## 5. Adaptive/intelligence/broker validation

Before real arming archive PASS evidence for all applicable:

- Strategy Tester;
- intelligence/hardening matrices;
- adaptive portfolio/risk supervisor;
- execution learning/calibration/MAE-MFE/event behavior;
- champion/challenger/counterfactual validation;
- lifecycle/GPT-integrity/replay;
- broker/account/symbol matrix;
- deployment profile/drift;
- recovery/restart tests;
- HIGH stop-management matrix;
- broker-specific stop failure policy;
- partial-protection tests;
- stop observability;
- live news/intermarket validation;
- WebRequest/OpenAI failure injection.

## 6. API/WebRequest transport certification

The active source routes GPT/news traffic through Part37. Complete `API_TRANSPORT_TEST_MATRIX.md` for the exact selected mode and endpoint.

Required evidence includes HTTPS/allow-list configuration, deep-review path, live web-search path, failure/recovery, request tracing, and zero secret leaks.

Run:

```text
python tools/validate_api_transport_evidence.py release_evidence.json
```

REAL arming remains blocked until `InpReleaseAPITransportPassed=true` is backed by matching evidence.

## 7. Five-day soak and operator acceptance

Part36 produces `demo_soak_evidence_v1` machine observations. R6 additionally requires the detailed five-day acceptance record and human/operator reconciliation.

Use:

- `FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json`;
- `FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md`;
- `DEMO_SOAK_REPORT_TEMPLATE.md`.

The exact candidate must cover five accepted trading days, >=3 London sessions, >=3 New York/U.S.-cash sessions, overlap, relevant high-impact news, rollover spread expansion, restart, reconnect, scheduled/continuous/manual scans, primary/backup checkpoints, required logs and zero hard-failure counters.

All five lifecycle assertions must pass, including stale human-approval WAIT closure and preservation of genuine market-confirmation WAIT.

Finalize/validate:

```text
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json --finalize
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json
python tools/validate_soak_evidence.py release_evidence.json
```

Part28B requires the resulting acceptance record ID and digest.

## 8. Deployment drift guard

Part29 captures structural symbol/deployment properties and blocks new entries if the live environment materially differs from the validated profile. Dynamic spread/stops/freeze changes remain execution conditions rather than structural identity fields.

Existing positions continue management when new entries are blocked.

## 9. Final GO/NO-GO review

Complete `FINAL_RELEASE_REVIEW_TEMPLATE.json` against the stable evidence basis containing the exact build, CI bundle, deployment, API transport and demo-soak/five-day identities.

Only literal `GO` can pass:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

Then copy the matching review identity/digest/reviewer/timestamp into `release_evidence.json` and Part28 inputs.

## 10. Final aggregate validation

Run:

```text
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

The aggregate validation verifies candidate hashes, compile evidence, executed CI bundle/provenance, deployment, API transport, five-day operator/machine acceptance, soak digest, all mandatory gates and final GO review.

## 11. Runtime audit artifacts

Runtime evidence includes:

- `GPT_EA_ReleaseEvidence.csv` from Part28;
- `GPT_EA_R6SupplementalEvidence.csv` from Part28B;
- `GPT_EA_APIHealth.csv` from Part37;
- Part36 soak artifacts and the normal execution/lifecycle/stop/intelligence journals.

These make the running terminal auditable but do not replace archived release files.

## Current release sequence

1. Freeze candidate source/preset identity.
2. Compile exact candidate; archive EX5/SET hashes and compile log.
3. Obtain and validate runner-recovery evidence plus the runner-recovery acceptance matrix.
4. Obtain a green executed GitHub Actions CI evidence bundle for the exact candidate.
5. Compile/load/test the exact candidate in MT5 and finalize `mt5_validation_evidence_v1`.
6. Run remaining intelligence/adaptive/broker/recovery/stop matrices.
7. Validate selected API transport/WebRequest mode on demo.
8. Run the exact candidate through the five-day demo soak.
9. Complete the machine five-day record, daily reconciliation, operator worksheet and soak report.
10. Finalize the five-day record digest and validate soak evidence.
11. Complete `release_evidence.json` and all non-review gates.
12. Complete and validate final GO/NO-GO review.
13. Run both aggregate release validators; all must PASS.
14. Complete `RELEASE_EVIDENCE_MANIFEST.md` and `RELEASE_GO_NO_GO.md`.
15. Enter the exact validated Part28/Part28B/Part37 inputs locally.
16. Only then enter the live-arm phrase.

## Certification invalidation

Executable-source changes, different EX5/SET or material risk preset, release-contract changes, selected API transport/endpoint changes, or material broker/server/account/symbol-deployment changes invalidate the affected evidence. A new candidate must not inherit stale CI, soak or release digests.

## Live rule

REAL trading is eligible only when ordinary safety, stop health, base R6 certification, deployment stability, executed CI/five-day supplemental evidence, API transport certification, final GO review and all live broker/risk/news/execution gates pass simultaneously.

This certification is an engineering/release assurance process; it does not guarantee profitability.


## Supplemental runner-recovery and soak-day reconciliation

For the current R6 candidate, Part28B additionally requires `runner_recovery_evidence_v1` because hosted Actions previously exhibited the pre-runner `runner_id=0 / steps=[]` failure. The accepted recovery record must prove a later successful runner probe and the exact candidate's executed CI bundle.

The five-day acceptance sub-schema is now `five_day_soak_acceptance_v2`. Each of the five accepted days must have its own completed `SOAK_DAY_RECONCILIATION_CHECKLIST.md` artifact, `day_reconciled=true`, reviewer identity and reconciliation timestamp.

These are additive fail-closed requirements; the base release ID remains `GPT_EA_FULL_INTELLIGENCE_R6_20260917` and the active API safety wrapper remains Part37.
