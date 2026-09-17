# GPT_EA Live Release Certification

`GPT_EA_Part28_ReleaseCertification.mqh` and `GPT_EA_Part29_DeploymentDriftGuard.mqh` form the final real-account release-evidence and deployment-stability gates. They do not prove that testing occurred; they force the operator to explicitly attest the required evidence and keep the validated deployment environment stable before real-account execution can be armed.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R5_20260917`

R5 materially changes trade authorization, risk sizing, execution-cost learning, strategy health and shadow validation. Any R4 certification is therefore stale and cannot authorize R5.

## Default behavior

All release-attestation inputs default to `false` and the validation ID defaults to blank. Therefore a real account remains blocked even if the normal live-arm phrase is entered.

Strategy Tester bypasses the evidence-attestation requirement so testing is possible. Demo/contest accounts treat the evidence flags as informational so broker tests, adaptive-learning tests, failure injection and demo soak remain possible.

## Required evidence before real arming

All of these inputs must be deliberately set only after the corresponding evidence has been completed and archived:

- `InpReleaseMetaEditorCompilePassed=true` — `METAEDITOR_COMPILE_GATE.md` passed with the exact candidate source/build.
- `InpReleaseArtifactIdentityArchived=true` — exact Git SHA, EX5 SHA-256 and SET SHA-256 (when a preset is used) are archived together.
- `InpReleaseStrategyTesterPassed=true` — applicable Strategy Tester scenarios passed.
- `InpReleaseIntelligenceMatrixPassed=true` — full intelligence and hardening matrices passed.
- `InpReleaseAdaptivePortfolioPassed=true` — correlation aggregation, macro concentration, per-strategy budgets, dynamic sizing, market kill switch, broker health and independent supervisor passed `ADAPTIVE_EXECUTION_TEST_MATRIX.md`.
- `InpReleaseExecutionLearningPassed=true` — execution capture/forecast, confidence calibration, event behavior, MAE/MFE, learned expiry, degradation and regime-transition tests passed.
- `InpReleaseChampionChallengerPassed=true` — shadow/counterfactual lifecycle and champion/challenger eligibility/promotion safeguards passed.
- `InpReleaseLifecycleIntegrityPassed=true` — lifecycle transition, restart reconstruction, GPT disagreement, model-output integrity and decision replay tests passed.
- `InpReleaseBrokerMatrixPassed=true` — intended broker/account/symbol matrix passed.
- `InpReleaseDeploymentProfilePassed=true` — `DEPLOYMENT_DRIFT_TESTS.md` and intended deployment profile passed.
- `InpReleaseRecoveryTestsPassed=true` — restart/recovery invariants passed.
- `InpReleaseStopMatrixPassed=true` — HIGH-priority stop-management matrix passed.
- `InpReleaseBrokerStopPolicyPassed=true` — broker-specific stop-failure classes/actions/retry behavior validated.
- `InpReleasePartialProtectionPassed=true` — `PARTIAL_PROTECTION_RELEASE_TEST.md` passed.
- `InpReleaseStopObservabilityPassed=true` — stop-failure observability schema/events/recovery evidence validated.
- `InpReleaseLiveNewsIntermarketPassed=true` — live-news, source, freshness and intermarket paths validated on terminal/demo.
- `InpReleaseWebFailureInjectionPassed=true` — OpenAI/WebRequest unavailable, malformed, timeout and recovery paths tested.
- `InpReleaseDemoSoakPassed=true` — `DEMO_SOAK_ACCEPTANCE.md` passed using the exact release artifacts.
- `InpReleaseOperatorReviewPassed=true` — `RELEASE_GO_NO_GO.md` final human release decision is GO.
- `InpReleaseValidationId=GPT_EA_FULL_INTELLIGENCE_R5_20260917`.

The existing `InpLiveArmPhrase=GPT_EA_LIVE_ARMED` remains separately required when configured. Neither gate bypasses the other. Stop-health, adaptive risk, broker, news, deployment-drift and execution gates remain independently enforceable.

## R5 adaptive runtime stack

The executable adaptive layer is documented in `ADAPTIVE_EXECUTION_ARCHITECTURE.md` and tested by `ADAPTIVE_EXECUTION_TEST_MATRIX.md`.

R5 includes:

- portfolio correlation and USD/risk-on concentration;
- per-strategy daily/weekly risk budgets;
- confidence calibration;
- execution-quality learning and slippage forecasts;
- market-condition kill switch;
- dynamic quality/regime position sizing;
- strategy degradation modes;
- MAE/MFE research;
- event-specific strategy evidence;
- broker-health scoring;
- lifecycle state machine;
- replayable decision snapshots;
- counterfactual analytics;
- learned candle expiry;
- regime-transition risk reduction;
- independent deterministic risk supervisor;
- GPT disagreement/model-integrity gates;
- champion/challenger shadow validation;
- strategy health dashboard.

The independent risk supervisor can only block/reduce exposure. GPT cannot override it.

## Deployment drift guard

`GPT_EA_Part29_DeploymentDriftGuard.mqh` captures structural properties for resolved symbols at startup and checks them during the running deployment.

Structural drift includes unexpected changes to:

- digits;
- point size;
- tick size;
- contract size;
- volume step;
- calculation mode;
- execution mode;
- filling mode;
- symbol availability.

These changes block new entries while existing positions continue protective management. Dynamic spread, stop-level and freeze-level changes are not structural drift because they can legitimately vary intraday and are already handled by live gates.

Optional expected deployment identity checks can also validate broker company, server, account currency, margin mode and leverage.

## Runtime synchronization

The R5 release state is refreshed during safety initialization and timer cycles. Startup stop-observability initialization also returns control to the R5 gate, so an older intermediate certification state cannot overwrite the final release state.

Existing positions continue to be managed when certification, adaptive supervision or deployment drift blocks new entries.

## Runtime audit

When enabled, `GPT_EA_ReleaseEvidence.csv` is written to the MT5 Common Files area at initialization. It records required/entered release IDs, account/broker/server, every R5 evidence flag, combined PASS/BLOCK result and blocking reason.

Additional R5 runtime evidence includes:

- `GPT_EA_ExecutionLearning.csv`
- `GPT_EA_ShadowValidation.csv`
- `GPT_EA_Lifecycle.csv`
- `GPT_EA_DecisionSnapshots.csv`
- `GPT_EA_StrategyHealth.csv`

These files are audit/research sources; they do not substitute for the underlying broker/test evidence.

## Release sequence

1. Compile the exact R5 candidate in MetaEditor and pass `METAEDITOR_COMPILE_GATE.md`.
2. Record Git SHA, EX5 SHA-256 and SET SHA-256.
3. Run Strategy Tester plus intelligence/hardening matrices.
4. Run all applicable cases in `ADAPTIVE_EXECUTION_TEST_MATRIX.md`.
5. Run broker/account/symbol matrix tests.
6. Run `DEPLOYMENT_DRIFT_TESTS.md` on the intended environment.
7. Run restart and recovery tests.
8. Run HIGH-priority stop-management and broker-stop-failure tests.
9. Run partial-protection and stop-observability tests.
10. Validate live-news/intermarket freshness, blocking and source behavior.
11. Run OpenAI/WebRequest failure injection and recovery.
12. Run `DEMO_SOAK_ACCEPTANCE.md` using the same candidate artifacts.
13. Review intelligence, execution-learning, shadow, lifecycle, decision-snapshot, strategy-health, stop-failure and release-evidence journals for unresolved blockers.
14. Complete `RELEASE_EVIDENCE_MANIFEST.md`.
15. Complete `RELEASE_GO_NO_GO.md`; decision must be GO.
16. Only then set every R5 release-attestation input plus the live-arm phrase locally on the intended terminal.

## Invalidation of certification

Certification must be repeated when a change can materially affect execution, protection, market classification, risk, learning, OpenAI/news behavior, broker compatibility, recovery or release logic. Examples include executable source changes, risk budget/sizing changes, learning/calibration changes, champion/challenger promotion changes, order/SL/partial logic changes, broker failure policy changes, strategy/pre-entry changes, live-news/intermarket changes, persistence/recovery changes, release/deployment changes, or deployment to a materially different broker/account/symbol environment.

A source change after certification is a new candidate build unless the release owner explicitly records that it is documentation-only and non-executable.

## Live rule

A real-account R5 build is not release-certified until all of the following pass simultaneously:

1. ordinary release safety requirements, including explicit live arming;
2. stop-health/protection requirements;
3. complete R5 evidence requirements, including the adaptive stack;
4. deployment identity/structural-drift requirements;
5. all current runtime risk/news/broker/execution authorization gates.

Passing release certification never guarantees a profitable trade. It verifies only that the exact candidate artifact has passed the defined engineering, protection, recovery, adaptive-risk, broker-compatibility and operational release process.