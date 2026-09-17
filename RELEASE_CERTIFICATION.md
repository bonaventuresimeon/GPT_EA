# GPT_EA Live Release Certification — R6 Base + Current Supplemental Guards

The base release validation identity remains:

`GPT_EA_FULL_INTELLIGENCE_R6_20260917`

The active runtime safety chain is layered:

`Part28 base R6 certification → Part29 deployment drift → Part28B executed-CI/five-day evidence → Part37 API transport guard`.

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

## 2. Executed GitHub Actions evidence

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

## 3. Adaptive/intelligence/broker validation

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

## 4. API/WebRequest transport certification

The active source routes GPT/news traffic through Part37. Complete `API_TRANSPORT_TEST_MATRIX.md` for the exact selected mode and endpoint.

Required evidence includes HTTPS/allow-list configuration, deep-review path, live web-search path, failure/recovery, request tracing, and zero secret leaks.

Run:

```text
python tools/validate_api_transport_evidence.py release_evidence.json
```

REAL arming remains blocked until `InpReleaseAPITransportPassed=true` is backed by matching evidence.

## 5. Five-day soak and operator acceptance

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

## 6. Deployment drift guard

Part29 captures structural symbol/deployment properties and blocks new entries if the live environment materially differs from the validated profile. Dynamic spread/stops/freeze changes remain execution conditions rather than structural identity fields.

Existing positions continue management when new entries are blocked.

## 7. Final GO/NO-GO review

Complete `FINAL_RELEASE_REVIEW_TEMPLATE.json` against the stable evidence basis containing the exact build, CI bundle, deployment, API transport and demo-soak/five-day identities.

Only literal `GO` can pass:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

Then copy the matching review identity/digest/reviewer/timestamp into `release_evidence.json` and Part28 inputs.

## 8. Final aggregate validation

Run:

```text
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

The aggregate validation verifies candidate hashes, compile evidence, executed CI bundle/provenance, deployment, API transport, five-day operator/machine acceptance, soak digest, all mandatory gates and final GO review.

## 9. Runtime audit artifacts

Runtime evidence includes:

- `GPT_EA_ReleaseEvidence.csv` from Part28;
- `GPT_EA_R6SupplementalEvidence.csv` from Part28B;
- `GPT_EA_APIHealth.csv` from Part37;
- Part36 soak artifacts and the normal execution/lifecycle/stop/intelligence journals.

These make the running terminal auditable but do not replace archived release files.

## Current release sequence

1. Freeze candidate source/preset identity.
2. Compile exact candidate; archive EX5/SET hashes and compile log.
3. Obtain a green executed GitHub Actions CI evidence bundle for the exact candidate.
4. Run Strategy Tester and all intelligence/adaptive/broker/recovery/stop matrices.
5. Validate selected API transport/WebRequest mode on demo.
6. Run the exact candidate through the five-day demo soak.
7. Complete the machine five-day record, operator worksheet and soak report.
8. Finalize the five-day record digest and validate soak evidence.
9. Complete `release_evidence.json` and all non-review gates.
10. Complete and validate final GO/NO-GO review.
11. Run both aggregate release validators; all must PASS.
12. Complete `RELEASE_EVIDENCE_MANIFEST.md` and `RELEASE_GO_NO_GO.md`.
13. Enter the exact validated Part28/Part28B/Part37 inputs locally.
14. Only then enter the live-arm phrase.

## Certification invalidation

Executable-source changes, different EX5/SET or material risk preset, release-contract changes, selected API transport/endpoint changes, or material broker/server/account/symbol-deployment changes invalidate the affected evidence. A new candidate must not inherit stale CI, soak or release digests.

## Live rule

REAL trading is eligible only when ordinary safety, stop health, base R6 certification, deployment stability, executed CI/five-day supplemental evidence, API transport certification, final GO review and all live broker/risk/news/execution gates pass simultaneously.

This certification is an engineering/release assurance process; it does not guarantee profitability.
