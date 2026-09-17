# GPT_EA Live Release Certification — R6

`GPT_EA_Part28_ReleaseCertification.mqh` and `GPT_EA_Part29_DeploymentDriftGuard.mqh` form the real-account release-evidence and deployment-stability gates.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R6_20260917`

R6 retains the R5 adaptive trading stack but strengthens release evidence with a versioned demo-soak schema, concrete evidence digests and a machine-validated final GO/NO-GO review. Any R5 or earlier release attestation is stale for R6.

## Default behavior

All release-attestation booleans default to `false`, identity/digest fields default blank and the final decision defaults blank. A REAL account remains blocked even if the ordinary live-arm phrase is entered.

Strategy Tester bypasses real-account evidence attestation so testing remains possible. Demo/contest accounts treat release evidence as informational while validation is performed.

## Compile and artifact identity

Real arming requires:

- exact 40-hex source Git SHA;
- exact 64-hex EX5 SHA-256;
- exact 64-hex SET SHA-256 or literal `NONE`;
- compile evidence ID;
- MetaEditor build;
- MT5 build;
- `InpReleaseMetaEditorCompilePassed=true`;
- `InpReleaseArtifactIdentityArchived=true`.

Use `METAEDITOR_COMPILE_GATE.md` and `tools/validate_release_evidence.py`.

## Versioned demo-soak evidence

Required schema:

`demo_soak_evidence_v1`

`SOAK_EVIDENCE_SCHEMA.json` and `DEMO_SOAK_ACCEPTANCE.md` define the contract.

R6 requires:

- soak evidence ID and SHA-256 digest;
- at least 5 consecutive trading days;
- at least 3 London sessions;
- at least 3 New York/U.S.-cash sessions;
- overlap, high-impact-news day, rollover, restart and reconnect coverage;
- scheduled and continuous scans observed;
- primary and backup checkpoint updates observed;
- execution, stop and release evidence logs present;
- zero zero-tolerance failures;
- zero unresolved critical states;
- zero duplicate orders/partials;
- zero stop regressions;
- zero unprotected new authorizations;
- zero release-gate bypasses;
- zero duplicate analytics finalization;
- zero stop-observability join failures;
- zero dashboard/gate mismatch;
- zero runtime critical errors;
- zero secret exposure.

Run:

```text
python tools/validate_soak_evidence.py release_evidence.json
```

Archive `soak-evidence-validation.txt` and its `SOAK_EVIDENCE_SHA256`.

## Full R6 evidence

The following must also pass before real arming:

- Strategy Tester;
- full intelligence matrix;
- adaptive portfolio/risk supervisor;
- execution learning/calibration/event/MAE-MFE;
- champion/challenger and counterfactual validation;
- lifecycle/GPT-integrity/replay;
- broker/account/symbol matrix;
- deployment profile/drift tests;
- restart/recovery tests;
- HIGH-priority stop-management matrix;
- broker-specific stop-failure policy;
- partial-protection release test;
- stop-observability matrix;
- live-news/intermarket validation;
- OpenAI/WebRequest failure injection.

## Release evidence validator

Complete `RELEASE_EVIDENCE_TEMPLATE.json` for the exact candidate and run:

```text
python tools/validate_release_evidence.py release_evidence.json
```

The validator checks release ID, artifact/hash identity, compile evidence, deployment identity, soak schema, quantitative soak thresholds, all mandatory gates and final-review fields. Archive `release-evidence-validation.txt` and its reported evidence digest.

## Final GO/NO-GO review

Use `FINAL_RELEASE_REVIEW_TEMPLATE.json` and follow `FINAL_GO_NO_GO_REVIEW.md`.

The final review must bind to the exact Git SHA, EX5/SET hashes, deployment identity and stable pre-review release-evidence digest.

Only literal decision `GO` is eligible for real arming. `HOLD` and `NO-GO` remain blocked.

Run:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

Archive `final-release-review-validation.txt` and its `FINAL_REVIEW_SHA256`, then enter the matching review evidence ID/digest/decision/reviewer/timestamp into MT5.

## Deployment drift guard

`GPT_EA_Part29_DeploymentDriftGuard.mqh` captures structural symbol properties and blocks new entries when the running environment materially differs from the validated deployment.

Structural checks include symbol availability, digits, point, tick size, contract size, volume step, calculation mode, execution mode and filling mode. Optional expected identity fields can bind the release to broker company, server, account currency, margin mode and leverage.

Dynamic spread/stops/freeze changes remain live execution conditions, not structural-drift failures.

## Runtime audit

`GPT_EA_ReleaseEvidence.csv` records release ID, artifact identity, compile identity, soak schema/digest and quantitative counters, final review identity/digest/decision and the final PASS/BLOCK reason.

The runtime evidence does not replace the archived files; it makes the running terminal auditable against them.

## R6 release sequence

1. Compile the exact candidate and pass `METAEDITOR_COMPILE_GATE.md`.
2. Record Git SHA, EX5 SHA-256 and SET SHA-256/`NONE`.
3. Run Strategy Tester and all required intelligence/adaptive/broker/recovery/stop/news tests.
4. Run the exact candidate through the required demo soak.
5. Complete `release_evidence.json` from `RELEASE_EVIDENCE_TEMPLATE.json`.
6. Run `tools/validate_soak_evidence.py` and archive PASS/digest.
7. Complete all non-review gates in `release_evidence.json`.
8. Run the release evidence validator as part of the review package.
9. Complete `final_release_review.json` from `FINAL_RELEASE_REVIEW_TEMPLATE.json`.
10. Run `tools/validate_final_release_review.py`; result must PASS.
11. Set `gates.operator_review=true` and copy final-review identity/digest into the release evidence bundle.
12. Run `tools/validate_release_evidence.py` again; result must PASS.
13. Complete `RELEASE_EVIDENCE_MANIFEST.md` and `RELEASE_GO_NO_GO.md`.
14. Only then enter the matching R6 inputs and live-arm phrase locally.

## Certification invalidation

A GO becomes stale after executable-source changes, materially changed presets/risk controls, a changed EX5, materially different broker/server/account/symbol contract, or discovery of evidence invalidating a hard-gate assumption.

Documentation-only changes may retain artifact evidence only when explicitly recorded as non-executable.

## Live rule

A REAL-account R6 build is eligible only when ordinary safety, stop health, complete R6 evidence, final GO review, deployment stability and all current risk/news/broker/execution gates pass simultaneously.

This certification never guarantees profitability. It certifies the engineering, protection, evidence and operational release process for the exact candidate.
