# GPT_EA Release Evidence Manifest

Complete one copy of this manifest for every candidate production build. A Git commit, input checkbox or profitable demo result alone is not evidence that a release gate passed.

## Build identity

- Git commit SHA:
- Release validation ID:
- Release tag/version:
- MetaTrader build:
- MetaEditor build:
- Windows build/architecture used for compilation:
- `.ex5` path:
- `.ex5` SHA-256:
- EA `.set` preset path:
- EA `.set` SHA-256:
- Compile errors: **0 required**
- Compile warnings: **0 preferred/required for production certification**
- Compile log evidence location:
- Compile timestamp:
- Validation date range:

## Broker/account identity

- Broker company:
- Trade server:
- Account type: demo / real
- Margin mode: hedging / netting / exchange
- Account currency:
- Account leverage:
- Symbols validated:
- Broker symbol-profile evidence location:
- Deployment-drift test evidence location:
- Expected deployment identity inputs, if used:

## Required release contracts

Attach PASS/FAIL evidence for each applicable document:

- [ ] `METAEDITOR_COMPILE_GATE.md`
- [ ] `COMPILE_TEST_CHECKLIST.md`
- [ ] `ADVANCED_INTELLIGENCE_CONTRACT.md`
- [ ] `FULL_INTELLIGENCE_COVERAGE.md`
- [ ] `INTELLIGENCE_TEST_MATRIX.md`
- [ ] `INTELLIGENCE_HARDENING_TESTS.md`
- [ ] `ADAPTIVE_EXECUTION_ARCHITECTURE.md`
- [ ] `ADAPTIVE_EXECUTION_TEST_MATRIX.md`
- [ ] `BROKER_MATRIX_TESTS.md`
- [ ] `DEPLOYMENT_DRIFT_TESTS.md`
- [ ] `RECOVERY_INVARIANTS.md`
- [ ] `RELEASE_SAFETY_GATES.md`
- [ ] `STOP_UPDATE_FAILURE_POLICY.md`
- [ ] `BROKER_STOP_FAILURE_POLICY.md`
- [ ] `STOP_MANAGEMENT_TEST_MATRIX.md`
- [ ] `PARTIAL_PROTECTION_RELEASE_TEST.md`
- [ ] `STOP_FAILURE_OBSERVABILITY_CONTRACT.md`
- [ ] `STOP_OBSERVABILITY_TEST_MATRIX.md`
- [ ] `ANALYTICS_SCHEMA.md`
- [ ] `DEMO_SOAK_ACCEPTANCE.md`
- [ ] `RELEASE_GO_NO_GO.md`

## Artifact identity evidence

- [ ] Exact source Git SHA matches the compiled candidate.
- [ ] EX5 SHA-256 archived.
- [ ] SET SHA-256 archived when a preset is used.
- [ ] No executable source changed after the certified compile without a new compile/hash.
- [ ] Demo soak used the same EX5/SET candidate being proposed for release.
- [ ] `InpReleaseArtifactIdentityArchived=true` will be set only after this section is complete.

## R5 adaptive execution evidence

Complete `ADAPTIVE_EXECUTION_TEST_MATRIX.md` and archive evidence for all applicable cases.

### Portfolio/risk supervisor

- [ ] rolling-correlation same-theme risk tested;
- [ ] opposite-direction/hedge behavior tested;
- [ ] USD/risk-on macro concentration tested;
- [ ] per-strategy daily and weekly budgets tested;
- [ ] base-risk ceiling never exceeded by adaptive sizing;
- [ ] market-condition kill switch tested;
- [ ] broker-health blocking tested;
- [ ] drawdown-acceleration block tested;
- [ ] independent supervisor shown to outrank GPT approval;
- [ ] `InpReleaseAdaptivePortfolioPassed=true` will be set only after this section is complete.

### Execution learning / adaptation

- [ ] expected/request/fill price capture verified;
- [ ] spread/slippage/latency/commission capture verified;
- [ ] confidence calibration developing and mature samples tested;
- [ ] strategy degradation states ACTIVE/REDUCED_RISK/SHADOW/DISABLED tested;
- [ ] MAE/MFE capture/finalization tested;
- [ ] CPI/PPI/NFP/FOMC/ECB/BoE/GDP/PMI/retail/speech event classes tested where available;
- [ ] negative event/strategy evidence block tested;
- [ ] learned slippage forecast and R:R rejection tested;
- [ ] learned time-to-TP1 expiry tested;
- [ ] regime-transition final sizing reduction tested;
- [ ] `InpReleaseExecutionLearningPassed=true` will be set only after this section is complete.

### Champion/challenger / counterfactuals

- [ ] champion, pullback challenger and breakout-retest challenger shadow paths tested;
- [ ] rejected/WAIT counterfactuals tracked without broker orders;
- [ ] same-bar SL/target ambiguity uses conservative outcome;
- [ ] minimum sample requirement enforced;
- [ ] average-R, PF, DD and stability promotion requirements enforced;
- [ ] `InpAutoPromoteChallenger=false` cannot silently promote;
- [ ] explicit promotion still passes every downstream risk/news/release/broker gate;
- [ ] `InpReleaseChampionChallengerPassed=true` will be set only after this section is complete.

### Lifecycle / GPT integrity / replay

- [ ] normal lifecycle transitions tested;
- [ ] invalid transition rejection tested;
- [ ] denial/timeout/restart reconstruction tested;
- [ ] GPT strong disagreement downgrades/blocks rather than reverses deterministic direction;
- [ ] malformed/short/parser-fallback/credential-like model output tested;
- [ ] stale GPT review requires reanalysis;
- [ ] contradictory price geometry blocks before order;
- [ ] `GPT_EA_DecisionSnapshots.csv` matches archived decisions;
- [ ] `InpReleaseLifecycleIntegrityPassed=true` will be set only after this section is complete.

## Deployment profile / drift evidence

- [ ] Intended broker company recorded.
- [ ] Intended server recorded.
- [ ] Account currency/leverage/margin mode recorded.
- [ ] Resolved broker symbol names recorded.
- [ ] digits/point/tick size/contract size/volume step recorded.
- [ ] calculation/execution/filling modes recorded.
- [ ] stable session causes no drift block.
- [ ] controlled structural-drift cases block new entries.
- [ ] spread/stops/freeze changes remain handled by live gates rather than false structural-drift classification.
- [ ] existing positions remain managed during a deployment-drift block.
- [ ] `InpReleaseDeploymentProfilePassed=true` will be set only after this section is complete.

## Stop-management evidence

- [ ] Normal BUY TP1 → BE → profit lock → strong lock → trail lifecycle.
- [ ] Normal SELL lifecycle.
- [ ] TP1 partial/BE failure without duplicate partial.
- [ ] Partial-protection start/completion observed.
- [ ] Partial-protection hazard blocks new entries.
- [ ] Partial-protection recovery observed.
- [ ] Stop/freeze-distance failure observed.
- [ ] Requote/fresh-price retry observed.
- [ ] Disconnect/reconnect behavior observed.
- [ ] Market-closed behavior observed where applicable.
- [ ] Rate-limit/trade-context backoff observed or equivalent controlled test documented.
- [ ] Operator-required stop state blocks new entries.
- [ ] Missing-SL restore path tested.
- [ ] Emergency unprotected-position path tested.
- [ ] Restart with active stop failure tested.
- [ ] Ticket-change/position-identifier reconciliation tested.

## Observability artifacts

Archive:

- `GPT_EA_Execution.csv`
- `GPT_EA_StopFailures.csv`
- `GPT_EA_Intelligence.csv`
- `GPT_EA_ExecutionLearning.csv`
- `GPT_EA_ShadowValidation.csv`
- `GPT_EA_Lifecycle.csv`
- `GPT_EA_DecisionSnapshots.csv`
- `GPT_EA_StrategyHealth.csv`
- `GPT_EA_ReleaseEvidence.csv`
- Experts log
- Journal log
- broker order/deal history
- screenshots for HIGH-priority stop/adaptive cases
- recovery checkpoint and `.bak` where relevant
- intelligence/news observations where relevant

Verify:

- [ ] stop CSV schema = `stop_failure_observability_v2`.
- [ ] stable class/action codes are present.
- [ ] stop lifecycles join by `POSITION_IDENTIFIER`.
- [ ] adaptive execution-learning rows join fills/closed results correctly.
- [ ] lifecycle rows do not contain illegal accepted transitions.
- [ ] shadow rows never correspond to broker orders merely because they are shadow candidates.
- [ ] current SL in evidence agrees with broker state.
- [ ] no duplicate TP1/TP2 partials.
- [ ] no accepted stop regression.
- [ ] recovery events preserve the failure class/action being recovered.

## Intelligence evidence

- [ ] market-state taxonomy exercised.
- [ ] strategy classifications exercised where feasible.
- [ ] WAIT and NO TRADE examples archived.
- [ ] counter-trend stricter gate demonstrated.
- [ ] live news/intermarket stale-approval cancellation demonstrated.
- [ ] OpenAI/WebRequest failure-injection behavior demonstrated.
- [ ] realistic R:R cost model verified.
- [ ] continuous/scheduled scanning verified.
- [ ] 25-point thesis/adversarial validation reviewed.
- [ ] GPT disagreement cannot override deterministic risk or reverse the underlying setup.

## Recovery evidence

- [ ] clean restart.
- [ ] pending approval restart.
- [ ] TP1 partial before BE restart.
- [ ] profit-lock/trailing restart.
- [ ] stop-failure restart.
- [ ] lifecycle reconstruction restart.
- [ ] active shadow/counterfactual restart.
- [ ] completed backup fallback.
- [ ] netting reversal safety where applicable.

## Demo-soak acceptance

Follow `DEMO_SOAK_ACCEPTANCE.md`.

- Soak start:
- Soak end:
- Consecutive trading days completed:
- London sessions observed:
- U.S. sessions observed:
- London/New York overlap observed:
- High-impact news day observed:
- Rollover/spread expansion observed:
- Restart observed:
- Disconnect/reconnect observed:
- Weekend session observed if applicable:
- Unexpected EA errors:
- Unexplained broker retcodes:
- Duplicate orders/partials: **must be none**
- Unresolved critical stop/recovery states at end: **must be none**
- Release/dashboard mismatch observed: **must be none**
- Adaptive strategy status/execution mismatch observed: **must be none**
- Secrets exposed in logs: **must be none**
- Demo-soak report evidence location:

## Live certification inputs

The live inputs in `GPT_EA_Part28_ReleaseCertification.mqh` may be set to PASS only after the matching evidence above exists and has been reviewed.

Current required validation ID is defined in source by `GPT_EA_REQUIRED_RELEASE_VALIDATION_ID`; do not guess or reuse an old release ID after the contract changes.

Required R5 evidence includes compile, artifact identity, Strategy Tester, intelligence matrix, adaptive portfolio, execution learning, champion/challenger, lifecycle/integrity/replay, broker matrix, deployment profile/drift, recovery, stop matrix, broker stop policy, partial protection, stop observability, live-news/intermarket, WebRequest failure injection, demo soak and final operator review.

## Final release decision

Complete `RELEASE_GO_NO_GO.md`.

- [ ] All applicable HIGH/release-blocking tests passed.
- [ ] Exact artifact identity archived.
- [ ] Deployment profile validated.
- [ ] All four R5 adaptive attestation groups passed.
- [ ] Human approval remains enabled for initial live deployment.
- [ ] Conservative initial risk selected.
- [ ] Live arm phrase will be entered locally only after final review.
- [ ] Optional DOM/ONNX components are enabled only if separately validated on this broker.

Release reviewer:

Decision: GO / NO-GO / HOLD

Notes: