# GPT_EA R6 Five-Day Soak Acceptance Record

The five-day record is the release-blocking human/machine reconciliation layer between `GPT_EA_DemoSoakSnapshot.json` and final R6 release evidence. It is not a profitability scorecard and it cannot be completed before the observations actually occur.

## Candidate freeze

Before Day 1, copy `FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json` to `artifacts/five-day-soak-acceptance.json`. Record the exact Git commit, EX5 SHA-256, SET SHA-256 or `NONE`, broker/server, demo or contest account mode, account currency, margin mode, MetaEditor build and MT5 build. The candidate identity must remain unchanged for all five accepted trading days. Any material executable, EX5, SET/risk-profile or release-contract change invalidates the run and requires a new record/evidence ID.

## Daily acceptance row

Exactly five accepted trading-day objects are required. For each day record the date, fresh-quote observation, London/New York/overlap coverage, relevant high-impact news, rollover spread expansion, scheduled/continuous/manual scan counts, checkpoint and backup-checkpoint counts, restart/reconnect counts, HIGH-CONFIDENCE/WAIT/NO-TRADE observations, zero-tolerance failures, unresolved critical states at day end and presence of execution/stop/release logs.

Dates must be unique and increasing. The validator treats the next weekday as the normal next trading day, including Friday to Monday. A holiday or exceptional market closure gap is allowed only when the later day contains a non-empty `gap_justification`; the operator must retain supporting terminal/broker evidence.

## Five-day aggregate minimum

Acceptance requires all five daily rows, fresh quotes and all three required logs on every accepted day; at least three London observations and three New York/U.S.-cash observations; at least one London/New York overlap, relevant high-impact-news observation and rollover spread-expansion observation; at least one restart and reconnect; at least one scheduled, continuous and manual scan; and at least one primary and validated backup checkpoint update.

No trade is forced merely to satisfy coverage. HIGH-CONFIDENCE, WAIT/REANALYZE and NO-TRADE counts are observational. Safety filters remain authoritative.

## Zero-tolerance reconciliation

The final `reconciliation` object must be checked against broker order/deal history, Experts/Journal and runtime CSVs. Every one of these fields must be zero: duplicate orders, duplicate partials, SL regressions, unprotected new authorizations, release-gate bypasses, analytics duplicate finalizations, stop-failure join failures, dashboard/gate mismatches, runtime critical errors and secret exposure. A machine-produced zero is not accepted without operator reconciliation.

Each accepted day must also end with `zero_tolerance_failures=0` and `unresolved_critical_states_end=0`.

## Lifecycle acceptance

The record cannot pass until all lifecycle checks are explicitly true: stale human-approval WAIT closes when its pending approval disappears without a fill; legitimate market-confirmation WAIT remains preserved; denial/timeout reaches a terminal state; restart reconstruction passes; and no illegal lifecycle transition is accepted.

## Report and operator review

`report_path` must point to the completed `DEMO_SOAK_REPORT_TEMPLATE.md` copy. The operator decision remains `HOLD` while the run is incomplete or any discrepancy is unresolved. Only after reconciliation may it become `ACCEPT`, with reviewer identity and timestamp.

## Finalize and validate

After all observations are complete, run:

```text
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json --finalize
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json
python tools/import_soak_snapshot.py --snapshot GPT_EA_DemoSoakSnapshot.json --acceptance-record artifacts/five-day-soak-acceptance.json --release-evidence release_evidence.json
python tools/validate_soak_evidence.py release_evidence.json
python tools/validate_release_evidence.py release_evidence.json
```

`--finalize` writes the canonical SHA-256 `record_digest` only when all other acceptance checks pass. Any later edit changes the canonical digest and makes validation fail until the record is reviewed and finalized again.

The release evidence must bind the acceptance record ID and digest to the same build Git/EX5/SET identity. Part28B also requires the acceptance record ID/digest before REAL-account arming.

## GitHub Actions evidence dependency

Five-day soak acceptance does not substitute for executed GitHub Actions evidence. R6 release validation separately requires an Actions run with a real runner (`runner_id > 0`), executed steps, successful conclusion, matching source commit, archived CI evidence artifact and verified provenance attestation. A pre-runner failure with `runner_id=0` and `steps=[]` remains a release HOLD even if the five-day soak passes.
