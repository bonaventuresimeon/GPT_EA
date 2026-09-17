# GPT_EA Five-Day Soak Operator Record

Record ID:

Evidence ID:

Release validation ID: `GPT_EA_FULL_INTELLIGENCE_R6_20260917`

Operator/reviewer:

## Frozen candidate

- Git commit SHA:
- EX5 SHA-256:
- SET SHA-256 or `NONE`:
- Broker company:
- Trade server:
- Account mode: DEMO / CONTEST
- Account currency:
- Margin mode:
- MT5 build:
- MetaEditor build:
- API transport mode: DIRECT_OPENAI / SECURE_PROXY / DISABLED
- Candidate freeze timestamp:

Any material candidate change after this point invalidates this record.

## Daily reconciliation

| Evidence | Day 1 | Day 2 | Day 3 | Day 4 | Day 5 |
|---|---|---|---|---|---|
| Date | | | | | |
| Gap justification, if any | | | | | |
| Fresh quotes | | | | | |
| London observed | | | | | |
| New York/U.S. cash observed | | | | | |
| London/NY overlap observed | | | | | |
| Relevant high-impact news observed | | | | | |
| Rollover spread expansion observed | | | | | |
| Scheduled scans | | | | | |
| Continuous/new-M5 scans | | | | | |
| Manual SCAN NOW scans | | | | | |
| Primary checkpoint updates | | | | | |
| Validated backup checkpoint updates | | | | | |
| Restarts/reinitializations | | | | | |
| Disconnect/reconnect cycles | | | | | |
| HIGH-CONFIDENCE decisions | | | | | |
| WAIT/REANALYZE decisions | | | | | |
| NO-TRADE decisions | | | | | |
| Daily zero-tolerance failures | 0 | 0 | 0 | 0 | 0 |
| Unresolved critical states at day end | 0 | 0 | 0 | 0 | 0 |
| `GPT_EA_Execution.csv` present | | | | | |
| `GPT_EA_StopFailures.csv` present | | | | | |
| `GPT_EA_ReleaseEvidence.csv` present | | | | | |
| Experts/Journal reference | | | | | |
| Part36 snapshot/evidence reference | | | | | |
| Broker order/deal history reference | | | | | |
| Checkpoint/backup reference | | | | | |
| Operator notes | | | | | |

## Lifecycle acceptance

Each item must be evidenced and marked PASS.

- [ ] PASS — stale human-approval WAIT closed when approval disappeared without a fill.
  Evidence/reference:
- [ ] PASS — genuine market-confirmation WAIT remained preserved.
  Evidence/reference:
- [ ] PASS — approval denial/timeout reached a terminal lifecycle state.
  Evidence/reference:
- [ ] PASS — restart lifecycle reconstruction completed without duplicate execution/partial actions.
  Evidence/reference:
- [ ] PASS — no illegal lifecycle transition was accepted.
  Evidence/reference:

## Zero-tolerance reconciliation

All final counts must be zero after review against broker history, Experts/Journal and CSVs.

- Duplicate orders: 0
- Duplicate partial exits: 0
- SL regressions: 0
- Unprotected new authorizations: 0
- Release-gate bypasses: 0
- Duplicate analytics finalizations: 0
- Stop-failure join failures: 0
- Dashboard/release-gate mismatches: 0
- Runtime critical errors: 0
- Secret exposures: 0

Reconciliation notes/evidence:

## Required aggregate coverage

- [ ] Five accepted consecutive trading days.
- [ ] London observed on at least three days.
- [ ] New York/U.S. cash observed on at least three days.
- [ ] London/NY overlap observed at least once.
- [ ] Relevant high-impact news observed at least once.
- [ ] Rollover spread expansion observed at least once.
- [ ] Restart/reinitialization observed at least once.
- [ ] Disconnect/reconnect observed at least once.
- [ ] Scheduled scan observed.
- [ ] Continuous/new-M5 scan observed.
- [ ] Manual SCAN NOW observed.
- [ ] Primary checkpoint update observed.
- [ ] Validated backup checkpoint update observed.

## Required archived artifacts

- [ ] `GPT_EA_DemoSoakEvidence.csv`
- [ ] `GPT_EA_DemoSoakSnapshot.json`
- [ ] `GPT_EA_Execution.csv`
- [ ] `GPT_EA_StopFailures.csv`
- [ ] `GPT_EA_ReleaseEvidence.csv`
- [ ] lifecycle/decision/execution-learning/shadow/strategy-health CSVs where generated
- [ ] Experts log
- [ ] Journal log
- [ ] broker history export
- [ ] recovery checkpoint and `.bak` samples
- [ ] completed demo-soak report
- [ ] finalized `five-day-soak-acceptance.json`
- [ ] `five-day-soak-record-validation.txt`

## Machine-record binding

Machine acceptance record path:

Machine record SHA-256 / `record_digest`:

Demo-soak evidence digest:

`validate_five_day_soak_record.py`: PASS / FAIL

`validate_soak_evidence.py`: PASS / FAIL

`validate_release_evidence.py`: PASS / FAIL

## Operator decision

Decision: HOLD / ACCEPT

Reviewer:

Timestamp:

Notes:

`ACCEPT` confirms that the five-day engineering soak evidence is complete and reconciled. It does **not** authorize REAL trading by itself; every other release gate, including executed CI, compile, API transport and final GO/NO-GO review, must also pass.
