# GPT_EA Live Release Certification

`GPT_EA_Part28_ReleaseCertification.mqh` and `GPT_EA_Part29_DeploymentDriftGuard.mqh` form the final real-account release-evidence and deployment-stability gates. They do not prove that testing occurred; they require the operator to attest completed evidence **and identify the exact artifact/test campaign** before real-account execution can be armed.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R5_20260917`

R5 materially changes trade authorization, risk sizing, execution-cost learning, strategy health and shadow validation. Any older certification is stale and cannot authorize R5.

## Default behavior

All release-attestation inputs default to `false`, concrete identity fields default blank, and the validation ID defaults blank. Therefore a real account remains blocked even if the normal live-arm phrase is entered.

Strategy Tester bypasses the evidence-attestation requirement so testing is possible. Demo/contest accounts treat release evidence as informational so broker tests, adaptive-learning tests, failure injection and demo soak remain possible.

## Concrete artifact identity required on REAL accounts

In addition to `InpReleaseMetaEditorCompilePassed=true` and `InpReleaseArtifactIdentityArchived=true`, the real-account gate now requires:

- `InpReleaseSourceCommitSha` — exact 40-character hexadecimal candidate Git SHA;
- `InpReleaseEx5Sha256` — exact 64-character EX5 SHA-256;
- `InpReleaseSetSha256` — exact 64-character preset SHA-256, or literal `NONE` when no `.set` is used;
- `InpReleaseCompileEvidenceId` — reference to the archived compile evidence;
- `InpReleaseMetaEditorBuild` — build used for compilation;
- `InpReleaseMT5Build` — terminal build used for validation.

Malformed or missing identity fields keep the real-account gate BLOCKED even when the boolean compile/artifact flags are true.

## Concrete demo-soak evidence required on REAL accounts

`InpReleaseDemoSoakPassed=true` is not sufficient by itself. The gate also requires:

- non-empty `InpReleaseSoakEvidenceId`;
- `InpReleaseSoakTradingDays >= 5`;
- `InpReleaseSoakLondonSessions >= 3`;
- `InpReleaseSoakNYSessions >= 3`;
- overlap observed;
- relevant high-impact news day observed;
- rollover/spread-expansion window observed;
- restart observed;
- disconnect/reconnect observed;
- `InpReleaseSoakZeroToleranceFailures == 0`;
- `InpReleaseSoakUnresolvedCriticalStates == 0`.

These fields enforce the minimum coverage defined by `DEMO_SOAK_ACCEPTANCE.md` at runtime. They do not replace the full soak report.

## Machine-readable release evidence

Use `RELEASE_EVIDENCE_TEMPLATE.json` to prepare the candidate evidence bundle and run:

```text
python tools/validate_release_evidence.py path/to/release_evidence.json
```

The validator checks the current release ID, Git/hash formats, compile counts/build identifiers, referenced artifact hashes when files are available, deployment identity, soak coverage/zero-tolerance thresholds and all mandatory R5 gate flags. It writes `release-evidence-validation.txt` and an evidence JSON SHA-256 digest.

Archive the completed JSON, validation output and digest with the candidate artifacts. See `RELEASE_EVIDENCE_VALIDATION.md`.

## Required evidence before real arming

All of these inputs must be deliberately set only after matching evidence has been completed and archived:

- `InpReleaseMetaEditorCompilePassed=true` — `METAEDITOR_COMPILE_GATE.md` passed with the exact candidate source/build.
- `InpReleaseArtifactIdentityArchived=true` — exact Git SHA, EX5 SHA-256 and SET SHA-256/`NONE` archived together.
- `InpReleaseStrategyTesterPassed=true` — applicable Strategy Tester scenarios passed.
- `InpReleaseIntelligenceMatrixPassed=true` — full intelligence and hardening matrices passed.
- `InpReleaseAdaptivePortfolioPassed=true` — correlation aggregation, macro concentration, strategy budgets, sizing, kill switch, broker health and deterministic supervisor passed.
- `InpReleaseExecutionLearningPassed=true` — execution capture/forecast, confidence calibration, event behavior, MAE/MFE, learned expiry, degradation and regime-transition tests passed.
- `InpReleaseChampionChallengerPassed=true` — shadow/counterfactual lifecycle and champion/challenger safeguards passed.
- `InpReleaseLifecycleIntegrityPassed=true` — lifecycle transition, restart reconstruction, GPT disagreement, model-output integrity and decision replay tests passed.
- `InpReleaseBrokerMatrixPassed=true` — intended broker/account/symbol matrix passed.
- `InpReleaseDeploymentProfilePassed=true` — intended deployment profile and `DEPLOYMENT_DRIFT_TESTS.md` passed.
- `InpReleaseRecoveryTestsPassed=true` — restart/recovery invariants passed.
- `InpReleaseStopMatrixPassed=true` — HIGH-priority stop-management matrix passed.
- `InpReleaseBrokerStopPolicyPassed=true` — broker-specific stop-failure behavior validated.
- `InpReleasePartialProtectionPassed=true` — partial-protection test passed.
- `InpReleaseStopObservabilityPassed=true` — stop-failure observability contract/matrix passed.
- `InpReleaseLiveNewsIntermarketPassed=true` — live-news/intermarket paths validated.
- `InpReleaseWebFailureInjectionPassed=true` — OpenAI/WebRequest failure-injection paths validated.
- `InpReleaseDemoSoakPassed=true` — full demo-soak contract passed using exact release artifacts.
- `InpReleaseOperatorReviewPassed=true` — final `RELEASE_GO_NO_GO.md` decision is GO.
- `InpReleaseValidationId=GPT_EA_FULL_INTELLIGENCE_R5_20260917`.

The existing `InpLiveArmPhrase=GPT_EA_LIVE_ARMED` remains separately required when configured. No evidence input bypasses stop-health, adaptive risk, broker, news, deployment-drift or execution gates.

## R5 adaptive runtime stack

The executable adaptive layer is documented in `ADAPTIVE_EXECUTION_ARCHITECTURE.md` and tested by `ADAPTIVE_EXECUTION_TEST_MATRIX.md`. It includes portfolio/correlation concentration, per-strategy budgets, confidence calibration, execution learning, market-condition kill switches, adaptive sizing, degradation modes, MAE/MFE research, event evidence, broker-health scoring, lifecycle/replay, counterfactual analytics, learned expiry, regime-transition reduction, deterministic supervision, GPT disagreement/model-integrity gates, champion/challenger shadow validation and strategy-health reporting.

The independent risk supervisor can only block/reduce exposure. GPT cannot override it.

## Deployment drift guard

`GPT_EA_Part29_DeploymentDriftGuard.mqh` captures structural symbol properties at startup and checks them during deployment. Unexpected changes to digits, point/tick size, contract size, volume step, calculation mode, execution mode, filling mode or symbol availability block new entries while existing positions continue protective management.

Dynamic spread, stop-level and freeze-level changes are not structural drift; they are handled by live gates. Optional expected deployment identity checks can validate broker company, server, account currency, margin mode and leverage.

## Runtime audit

`GPT_EA_ReleaseEvidence.csv` now records not only PASS/BLOCK flags but also source commit, EX5/SET hashes, compile evidence/build identity and measurable demo-soak evidence fields. This makes a runtime snapshot auditable against the archived release bundle.

Additional R5 evidence files include execution-learning, shadow-validation, lifecycle, decision-snapshot, strategy-health, execution, intelligence and stop-failure journals.

## Release sequence

1. Compile exact candidate and pass `METAEDITOR_COMPILE_GATE.md`.
2. Record exact Git SHA, EX5 SHA-256 and SET SHA-256/`NONE` plus MetaEditor/MT5 builds.
3. Complete required Strategy Tester/intelligence/adaptive/broker/recovery/stop/news matrices.
4. Run `DEMO_SOAK_ACCEPTANCE.md` using the same exact candidate artifacts.
5. Complete `RELEASE_EVIDENCE_TEMPLATE.json`.
6. Run `tools/validate_release_evidence.py`; result must PASS.
7. Archive the evidence JSON, validation output and evidence JSON SHA-256.
8. Complete `RELEASE_EVIDENCE_MANIFEST.md`.
9. Complete `RELEASE_GO_NO_GO.md`; decision must be GO.
10. Enter the same concrete artifact/soak identity values and PASS attestations in the intended terminal.
11. Enter the live-arm phrase only after the final release review.

## Invalidation of certification

Any executable change after compile or soak evidence creates a new candidate artifact identity. Material changes to strategy, sizing, execution, protection, recovery, news/OpenAI, broker policy, release logic or deployment environment require the affected gates to be rerun. Documentation-only changes may reuse evidence only when explicitly recorded as non-executable.

## Live rule

A real-account R5 build is not release-certified until ordinary safety/live arming, stop health, full R5 evidence, concrete artifact identity, quantitative demo-soak evidence, deployment stability and all current runtime risk/news/broker/execution gates pass simultaneously.

Passing release certification never guarantees profitability. It verifies only that the exact candidate artifact has passed the defined engineering, protection, recovery, adaptive-risk, broker-compatibility, evidence-integrity and operational release process.
