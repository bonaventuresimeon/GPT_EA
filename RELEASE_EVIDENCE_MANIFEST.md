# GPT_EA Release Evidence Manifest — R6

Complete one copy for every production candidate. A Git commit, checkbox or profitable demo result alone is not evidence that a release gate passed.

## Build identity

- Git commit SHA:
- Release validation ID:
- Release tag/version:
- MetaTrader build:
- MetaEditor build:
- Windows build/architecture:
- `.ex5` path:
- `.ex5` SHA-256:
- `.set` path:
- `.set` SHA-256 or `NONE`:
- Compile evidence ID:
- Compile errors: **0 required**
- Compile warnings: **0 required for production certification**
- Compile log path:
- Compile timestamp:

## Machine-readable release evidence

Start from `RELEASE_EVIDENCE_TEMPLATE.json`.

Working file:

- `release_evidence.json` path:

Required validators/artifacts:

- [ ] `python tools/validate_soak_evidence.py release_evidence.json` → PASS
- [ ] `soak-evidence-validation.txt` archived
- [ ] soak evidence SHA-256 archived
- [ ] `python tools/validate_final_release_review.py release_evidence.json final_release_review.json` → PASS
- [ ] `final-release-review-validation.txt` archived
- [ ] final review SHA-256 archived
- [ ] `python tools/validate_release_evidence.py release_evidence.json` → PASS after final review is incorporated
- [ ] `release-evidence-validation.txt` archived
- [ ] final evidence JSON SHA-256 archived

## Broker/account identity

- Broker company:
- Trade server:
- Account type: demo / real
- Margin mode: hedging / netting / exchange
- Account currency:
- Account leverage:
- Resolved symbols:
- Broker symbol-profile evidence:
- Deployment-drift evidence:

## Required release contracts

Attach PASS/FAIL evidence for applicable contracts:

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
- [ ] `SOAK_EVIDENCE_SCHEMA.json`
- [ ] `RELEASE_EVIDENCE_VALIDATION.md`
- [ ] `FINAL_GO_NO_GO_REVIEW.md`
- [ ] `RELEASE_GO_NO_GO.md`

## Artifact identity evidence

- [ ] Source Git SHA matches compiled candidate.
- [ ] EX5 SHA-256 archived.
- [ ] SET SHA-256 archived or `NONE` explicitly recorded.
- [ ] MetaEditor/MT5 builds recorded.
- [ ] Compile evidence ID recorded.
- [ ] No executable source changed after certified compile without new compile/hash.
- [ ] Demo soak used the exact candidate EX5/SET.
- [ ] Artifact hashes recomputed/verified by validator.

Concrete MT5 inputs:

- `InpReleaseSourceCommitSha=`
- `InpReleaseEx5Sha256=`
- `InpReleaseSetSha256=`
- `InpReleaseCompileEvidenceId=`
- `InpReleaseMetaEditorBuild=`
- `InpReleaseMT5Build=`

## R5 adaptive trading-stack evidence carried into R6 release certification

R6 retains the R5 adaptive runtime stack. Complete `ADAPTIVE_EXECUTION_TEST_MATRIX.md` and archive evidence for:

### Portfolio/risk supervisor

- [ ] rolling-correlation same-theme risk;
- [ ] opposite-direction/hedge behavior;
- [ ] USD/risk-on concentration;
- [ ] per-strategy daily/weekly budgets;
- [ ] base-risk ceiling;
- [ ] market-condition kill switch;
- [ ] broker-health blocking;
- [ ] drawdown-acceleration block;
- [ ] deterministic supervisor outranks GPT approval.

### Execution learning

- [ ] request/fill capture;
- [ ] spread/slippage/latency/commission capture;
- [ ] confidence calibration;
- [ ] ACTIVE/REDUCED_RISK/SHADOW/DISABLED degradation;
- [ ] MAE/MFE;
- [ ] event-specific evidence;
- [ ] learned slippage/R:R rejection;
- [ ] learned TP1 expiry;
- [ ] regime-transition sizing reduction.

### Champion/challenger

- [ ] champion and challenger shadow paths;
- [ ] WAIT/rejected counterfactuals without broker orders;
- [ ] conservative same-bar ambiguity;
- [ ] minimum sample and promotion rules;
- [ ] auto-promotion disabled unless explicitly certified;
- [ ] promoted candidate still passes all downstream gates.

### Lifecycle/GPT integrity/replay

- [ ] normal lifecycle transitions;
- [ ] invalid transition rejection;
- [ ] denial/timeout/restart reconstruction;
- [ ] GPT disagreement cannot reverse deterministic direction;
- [ ] malformed/model-integrity cases;
- [ ] stale GPT reanalysis;
- [ ] contradictory geometry block;
- [ ] decision snapshot replay.

## Deployment profile/drift evidence

- [ ] broker/server/currency/leverage/margin mode recorded;
- [ ] resolved symbol names recorded;
- [ ] digits/point/tick/contract/volume step recorded;
- [ ] calculation/execution/filling modes recorded;
- [ ] stable environment does not drift-block;
- [ ] controlled structural drift blocks new entries;
- [ ] spread/stops/freeze changes do not cause false structural drift;
- [ ] existing positions remain managed during drift block.

## Stop-management evidence

- [ ] BUY initial SL → TP1 → BE → profit lock → strong lock → trail lifecycle;
- [ ] SELL lifecycle;
- [ ] TP1 partial/BE failure without duplicate partial;
- [ ] partial-protection start/completion/hazard/recovery;
- [ ] stop/freeze rejection;
- [ ] requote/fresh-price retry;
- [ ] disconnect/reconnect;
- [ ] market-closed behavior where applicable;
- [ ] backoff/rate-limit behavior;
- [ ] operator-required state blocks entries;
- [ ] missing-SL restore;
- [ ] emergency unprotected-position path;
- [ ] restart with active stop failure;
- [ ] ticket-change/position-identifier reconciliation.

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
- recovery checkpoint + `.bak`
- material screenshots/exports

Verify:

- [ ] stop schema = `stop_failure_observability_v2`;
- [ ] stable class/action codes present;
- [ ] stop lifecycle joins by `POSITION_IDENTIFIER`;
- [ ] execution-learning rows reconcile fills/closed results;
- [ ] no illegal lifecycle transitions;
- [ ] shadow candidates do not create orders merely for being shadow candidates;
- [ ] current SL agrees with broker state;
- [ ] no duplicate TP1/TP2 partials;
- [ ] no accepted stop regression;
- [ ] recovery preserves failure class/action.

## Intelligence evidence

- [ ] market-state taxonomy exercised;
- [ ] strategy classifications exercised where feasible;
- [ ] WAIT and NO TRADE examples archived;
- [ ] counter-trend stricter gate demonstrated;
- [ ] live-news/intermarket stale-approval cancellation;
- [ ] WebRequest/OpenAI failure behavior;
- [ ] realistic R:R costs;
- [ ] continuous + scheduled scanning;
- [ ] 25-point thesis/adversarial validation;
- [ ] GPT cannot override deterministic risk/direction.

## Recovery evidence

- [ ] clean restart;
- [ ] pending approval restart;
- [ ] TP1 partial-before-BE restart;
- [ ] profit-lock/trailing restart;
- [ ] stop-failure restart;
- [ ] lifecycle reconstruction;
- [ ] shadow/counterfactual restart;
- [ ] completed backup fallback;
- [ ] netting reversal safety where applicable.

## Versioned demo-soak evidence

Follow `DEMO_SOAK_ACCEPTANCE.md` and `SOAK_EVIDENCE_SCHEMA.json`.

Record:

- schema version: `demo_soak_evidence_v1`
- soak evidence ID:
- soak evidence SHA-256:
- soak start/end:
- trading days: **>=5**
- London sessions: **>=3**
- New York sessions: **>=3**
- overlap observed: **yes**
- high-impact news day: **yes**
- rollover/spread expansion: **yes**
- restart: **yes**
- reconnect: **yes**
- scheduled scans: **>=1**
- continuous scans: **>=1**
- checkpoint updates: **>=1**
- backup checkpoint updates: **>=1**
- zero-tolerance failures: **0**
- unresolved critical states: **0**
- duplicate orders: **0**
- duplicate partials: **0**
- SL regressions: **0**
- unprotected new authorizations: **0**
- release-gate bypasses: **0**
- duplicate analytics finalizations: **0**
- stop-join failures: **0**
- dashboard/gate mismatches: **0**
- runtime critical errors: **0**
- secrets exposed: **0**
- execution log present: **yes**
- stop log present: **yes**
- release evidence log present: **yes**
- demo-soak report path:

Concrete MT5 soak inputs must exactly match this validated evidence.

## Final GO/NO-GO review

Follow `FINAL_GO_NO_GO_REVIEW.md` and start from `FINAL_RELEASE_REVIEW_TEMPLATE.json`.

Record/archive:

- final review evidence ID:
- reviewer:
- review timestamp:
- stable release-evidence basis SHA-256:
- final review SHA-256:
- decision: **GO / HOLD / NO-GO**
- known limitations:
- open noncritical issues:

Requirements:

- [ ] final review validator PASS;
- [ ] candidate Git/EX5/SET identities match release evidence;
- [ ] deployment identity matches;
- [ ] all mandatory non-review gates PASS;
- [ ] all zero-tolerance counts are zero;
- [ ] no unresolved critical state;
- [ ] initial live risk is conservative;
- [ ] approval remains required for initial live deployment;
- [ ] decision is literal `GO` before real arming.

Concrete MT5 final-review inputs:

- `InpReleaseFinalReviewEvidenceId=`
- `InpReleaseFinalReviewDigest=`
- `InpReleaseFinalDecision=GO`
- `InpReleaseFinalReviewer=`
- `InpReleaseFinalReviewTimestamp=`
- `InpReleaseOperatorReviewPassed=true`

## Final R6 release decision

- [ ] soak schema validator PASS;
- [ ] final GO/NO-GO validator PASS;
- [ ] final release evidence validator PASS;
- [ ] exact artifact identity archived;
- [ ] deployment profile validated;
- [ ] all R6 release flags/evidence fields match archived evidence;
- [ ] live arm phrase will be entered locally only after GO;
- [ ] optional DOM/ONNX enabled only when separately validated.

Release reviewer:

Soak SHA-256:

Final review SHA-256:

Final evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:
