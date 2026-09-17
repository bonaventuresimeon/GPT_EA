# GPT_EA Release Evidence Manifest

Complete one copy of this manifest for every candidate production build. A Git commit or input checkbox alone is not evidence that a test passed.

## Build identity

- Git commit SHA:
- Release validation ID:
- Release tag/version:
- MetaTrader build:
- MetaEditor build:
- `.ex5` file/hash:
- EA `.set` preset/hash:
- Compile errors: **0 required**
- Compile warnings:
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

## Required release contracts

Attach PASS/FAIL evidence for each applicable document:

- [ ] `COMPILE_TEST_CHECKLIST.md`
- [ ] `ADVANCED_INTELLIGENCE_CONTRACT.md`
- [ ] `FULL_INTELLIGENCE_COVERAGE.md`
- [ ] `INTELLIGENCE_TEST_MATRIX.md`
- [ ] `BROKER_MATRIX_TESTS.md`
- [ ] `RECOVERY_INVARIANTS.md`
- [ ] `RELEASE_SAFETY_GATES.md`
- [ ] `STOP_UPDATE_FAILURE_POLICY.md`
- [ ] `BROKER_STOP_FAILURE_POLICY.md`
- [ ] `STOP_MANAGEMENT_TEST_MATRIX.md`
- [ ] `PARTIAL_PROTECTION_RELEASE_TEST.md`
- [ ] `STOP_FAILURE_OBSERVABILITY_CONTRACT.md`
- [ ] `STOP_OBSERVABILITY_TEST_MATRIX.md`
- [ ] `ANALYTICS_SCHEMA.md`

## Stop-management evidence

- [ ] Normal BUY TP1 → BE → profit lock → strong lock → trail lifecycle
- [ ] Normal SELL lifecycle
- [ ] TP1 partial/BE failure without duplicate partial
- [ ] Partial-protection start/completion observed
- [ ] Partial-protection hazard blocks new entries
- [ ] Partial-protection recovery observed
- [ ] Stop/freeze-distance failure observed
- [ ] Requote/fresh-price retry observed
- [ ] Disconnect/reconnect behavior observed
- [ ] Market-closed behavior observed where applicable
- [ ] Rate-limit/trade-context backoff observed or equivalent controlled test documented
- [ ] Operator-required stop state blocks new entries
- [ ] Missing-SL restore path tested
- [ ] Emergency unprotected-position path tested
- [ ] Restart with active stop failure tested
- [ ] Ticket-change/position-identifier reconciliation tested

## Observability artifacts

Archive:

- `GPT_EA_Execution.csv`
- `GPT_EA_StopFailures.csv`
- `GPT_EA_ReleaseEvidence.csv`
- Experts log
- Journal log
- broker order/deal history
- screenshots for HIGH-priority stop cases
- recovery checkpoint and `.bak` where relevant
- intelligence/news observations where relevant

Verify:

- [ ] stop CSV schema = `stop_failure_observability_v2`
- [ ] stable class/action codes are present
- [ ] stop lifecycles join by `POSITION_IDENTIFIER`
- [ ] current SL in evidence agrees with broker state
- [ ] no duplicate TP1/TP2 partials
- [ ] no accepted stop regression
- [ ] recovery events preserve the failure class/action being recovered

## Intelligence evidence

- [ ] market-state taxonomy exercised
- [ ] strategy classifications exercised where feasible
- [ ] WAIT and NO TRADE examples archived
- [ ] counter-trend stricter gate demonstrated
- [ ] live news/intermarket stale-approval cancellation demonstrated
- [ ] OpenAI/WebRequest failure-injection behavior demonstrated
- [ ] realistic R:R cost model verified
- [ ] continuous/scheduled scanning verified
- [ ] 25-point thesis/adversarial validation reviewed

## Recovery evidence

- [ ] clean restart
- [ ] pending approval restart
- [ ] TP1 partial before BE restart
- [ ] profit-lock/trailing restart
- [ ] stop-failure restart
- [ ] completed backup fallback
- [ ] netting reversal safety where applicable

## Demo soak

- Start:
- End:
- London sessions observed:
- U.S. sessions observed:
- High-impact news day observed:
- Rollover/spread expansion observed:
- Weekend/restart observed:
- Unexpected EA errors:
- Unexplained broker retcodes:
- Duplicate orders/partials: **must be none**

## Live certification inputs

The live inputs in `GPT_EA_Part28_ReleaseCertification.mqh` may be set to PASS only after the corresponding evidence above exists and has been reviewed.

Current required validation ID is defined in source by `GPT_EA_REQUIRED_RELEASE_VALIDATION_ID`; do not guess or reuse an old release ID after the contract changes.

## Final release decision

- [ ] All applicable HIGH/release-blocking tests passed.
- [ ] Human approval remains enabled for initial live deployment.
- [ ] Conservative initial risk selected.
- [ ] Live arm phrase will be entered locally only after final review.
- [ ] Optional DOM/ONNX components are enabled only if separately validated on this broker.

Release reviewer:

Decision: PASS / FAIL / HOLD

Notes:
