# GPT_EA R6 Soak-Day Reconciliation Checklist

Use one completed copy for **each accepted trading day** in the five-day demo soak. Copy this file to `artifacts/soak-day-YYYY-MM-DD.md` and reference that path from the matching day object in `five-day-soak-acceptance.json`.

A day does not count toward the five-day acceptance record until this checklist is reconciled and its machine day object has `day_reconciled=true`. This checklist does not require a trade to occur; WAIT/REANALYZE and NO-TRADE are valid observations.

## Day identity

- Date:
- Soak record ID:
- Evidence ID:
- Git SHA:
- EX5 SHA-256:
- SET SHA-256 or `NONE`:
- Broker company:
- Trade server:
- Account mode: DEMO / CONTEST
- MT5 build:
- MetaEditor build:
- API transport mode:
- Reconciled by:
- Reconciled timestamp UTC:

Candidate identity must match the frozen five-day candidate. Any material executable, EX5, SET/risk-profile, broker/server or release-contract change makes this day **HOLD** until the run is restarted or the change is formally revalidated.

## A. Terminal and market-data health

- [ ] Terminal remained connected except for any explicitly tested disconnect/reconnect event.
- [ ] Quotes were fresh for observed symbols.
- [ ] No unexplained quote freeze/gap remained unresolved.
- [ ] Spread/ATR/session conditions were captured where material.
- [ ] Any abnormal market-condition kill-switch event is referenced below.

Evidence/reference:

## B. Scanner and decision reconciliation

Record counts from Part36/runtime evidence and reconcile them with Experts/Journal:

- Scheduled scans:
- Continuous/new-M5 scans:
- Manual SCAN NOW scans:
- HIGH-CONFIDENCE decisions:
- WAIT/REANALYZE decisions:
- NO-TRADE decisions:

- [ ] Counts agree with retained runtime evidence.
- [ ] No decision bypassed deterministic risk/news/release gates.
- [ ] No trade was forced merely to satisfy soak coverage.

Evidence/reference:

## C. Session/event observations

Mark only what actually occurred that day:

- [ ] London observed.
- [ ] New York/U.S.-cash observed.
- [ ] London/New York overlap observed.
- [ ] Relevant high-impact news observed.
- [ ] Rollover spread expansion observed.

For any checked event, retain timestamp and evidence. Unchecked items may be satisfied on another soak day.

Evidence/reference:

## D. Order/deal/execution reconciliation

Compare authorization/lifecycle records against broker order and deal history:

- [ ] Every broker order has a corresponding EA authorization/lifecycle path.
- [ ] No duplicate order from one authorization.
- [ ] No duplicate TP1/TP2 partial.
- [ ] Requested vs actual fills/slippage/commission were captured where fills occurred.
- [ ] Failed/rejected orders are represented in execution learning/Journal evidence.
- [ ] Shadow/counterfactual candidates created no broker orders merely because they were shadow candidates.

Evidence/reference:

## E. Protection and stop-management reconciliation

- [ ] Every open EA-managed position ended the day with valid broker-side protection, or an explicitly documented emergency/market-closed state.
- [ ] No EA-driven SL regression occurred.
- [ ] Stop modification failures have class/action evidence and are joined to the correct `POSITION_IDENTIFIER`.
- [ ] TP1/protection state agrees with broker history.
- [ ] No unresolved partial-protection hazard remained at day end.

Evidence/reference:

## F. Lifecycle and approval-state reconciliation

- [ ] No stale human-approval `WAIT_CONFIRMATION` remained after its approval disappeared without fill.
- [ ] Genuine market-confirmation waits were not incorrectly invalidated.
- [ ] Any approval denial/timeout reached a valid terminal state.
- [ ] No illegal lifecycle transition was accepted.
- [ ] Lifecycle CSV/snapshot state agrees with actual broker position/order state.

Evidence/reference:

## G. Recovery/checkpoint reconciliation

- Primary checkpoint updates:
- Validated backup checkpoint updates:
- Restart/reinitialization events:
- Disconnect/reconnect cycles:

- [ ] Current checkpoint can be read and passes its header/integrity checks.
- [ ] Backup checkpoint evidence is retained when exercised.
- [ ] Any restart/reconnect reconstructed state without duplicate execution or duplicate partials.
- [ ] Existing positions continued to be managed during any release/risk block.

Evidence/reference:

## H. GPT/API/news integrity

- [ ] Required GPT/web intelligence calls used the configured transport.
- [ ] Required API/news failures followed WAIT/NO-TRADE/fail-closed policy.
- [ ] No model response overrode deterministic direction/risk protection.
- [ ] No stale/malformed/internally inconsistent GPT output authorized execution.
- [ ] No OpenAI/proxy secret appeared in source, CSVs, Experts/Journal or archived evidence.

Evidence/reference:

## I. Risk/dashboard consistency

- [ ] Portfolio/correlation/risk-budget decision agrees with logged authorization result.
- [ ] Strategy health state agrees with dashboard and execution behavior.
- [ ] Broker-health/market-kill supervisor state agrees with any block/reduction.
- [ ] No release-gate/dashboard mismatch was observed.

Evidence/reference:

## J. Required day-end artifacts

- [ ] `GPT_EA_Execution.csv`
- [ ] `GPT_EA_StopFailures.csv`
- [ ] `GPT_EA_ReleaseEvidence.csv`
- [ ] relevant lifecycle/decision/execution-learning/shadow/strategy-health CSVs
- [ ] Experts log
- [ ] Journal log
- [ ] broker order/deal-history reference
- [ ] Part36 day/snapshot evidence
- [ ] checkpoint/backup reference when applicable

## K. Zero-tolerance day-end result

Record actual day counts:

- Duplicate orders:
- Duplicate partial exits:
- SL regressions:
- Unprotected new authorizations:
- Release-gate bypasses:
- Duplicate analytics finalizations:
- Stop-failure join failures:
- Dashboard/release-gate mismatches:
- Runtime critical errors:
- Secret exposures:
- Unresolved critical states at day end:

Every value above must be **0** for the day to be accepted.

## Day decision

Decision: **HOLD DAY / ACCEPT DAY**

Reconciled by:

Timestamp UTC:

Notes:

`ACCEPT DAY` means the day's evidence has been reconciled against broker history, terminal logs and runtime records. It does not mean the overall five-day soak or release is accepted.
