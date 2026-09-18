<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚀 Release Engineering & Evidence

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚀 **Document:** `MT5_VALIDATION_EVIDENCE.md`

---

# GPT_EA R6 MT5 Validation Evidence Contract

This is the release-blocking evidence definition for validation performed inside the intended MetaTrader 5 / MetaEditor environment. Source checks and GitHub CI cannot substitute for this record because they do not prove MQL compilation, Strategy Tester behavior, broker symbol geometry, terminal lifecycle, WebRequest behavior or runtime protection on the target MT5 build.

Machine schema: `mt5_validation_evidence_v2`.

## Required identity

The MT5 record must bind the exact:

- R6 release validation ID;
- Git commit SHA;
- EX5 SHA-256;
- SET SHA-256 or literal `NONE`;
- MetaEditor build;
- MT5 terminal build;
- broker company and trade server;
- DEMO/CONTEST account mode used for validation;
- account currency and margin mode.

Any executable, EX5, SET/material risk preset, MT5 build, broker/server or release-contract change invalidates the affected evidence.

## Compile and load evidence

Production acceptance requires:

- exact `GPT_EA.mq5` compile;
- 0 compile errors;
- 0 production warnings;
- complete compile log archived and SHA-256 bound;
- generated EX5 hash matching the release candidate;
- demo load smoke PASS;
- no `INIT_FAILED` / `INIT_PARAMETERS_INCORRECT`;
- configured symbols resolve or fail explicitly/safely;
- timer/dashboard initialize where enabled;
- release remains blocked before attestations;
- attaching the EA alone sends no order.

## Strategy Tester evidence

The record must include a retained tester report and hash. At minimum:

- at least one completed representative run;
- tester model/mode and date range recorded;
- tested symbols recorded;
- no runtime-critical error;
- no duplicate order/partial;
- no SL regression;
- no unprotected-position authorization;
- deterministic release/risk safety remains active where applicable.

Strategy Tester cannot prove live WebRequest/news behavior and therefore does not satisfy the live API section.

## Broker/runtime validation

Validate and archive:

- broker/account/symbol matrix;
- stops level, freeze level, tick size/value and volume geometry;
- filling/order modes used by configured symbols;
- margin calculation / lot normalization;
- restart and reconnect reconstruction;
- primary and backup recovery checkpoints;
- stop-management HIGH matrix;
- broker-specific stop failure handling;
- partial protection;
- stop observability;
- at least one controlled BUY and SELL management lifecycle across matrix/soak evidence where feasible without manufacturing unsafe live exposure.

## Live demo API/news validation

On DEMO/CONTEST outside Strategy Tester:

- MT5 WebRequest allow-list verified for selected transport;
- deep-review request path PASS;
- live web-search/news path PASS;
- timeout/malformed/auth/rate-limit/unavailable failure policy tested;
- recovery after failure PASS;
- request tracing observed;
- zero API/proxy secret leaks;
- required intelligence failure cannot authorize a trade.

## R6 resilience runtime validation

Use a working copy of `MT5_RESILIENCE_RUNTIME_REPORT_TEMPLATE.md` for the exact candidate and complete `CHAOS_FAULT_INJECTION_TEST_MATRIX.md` for CF-001 through CF-016. Both are retained release artifacts; neither may be pre-filled as PASS.

MT5 v2 additionally proves the new execution/reliability controls in the terminal rather than from source inspection alone:

- direct breakout and breakout-retest execution types remain distinct end-to-end;
- the atomic intent ledger records PREPARED then SENT before the broker submission boundary;
- restart, duplicate timer/callback and ambiguous broker responses cannot submit an unresolved nonce twice;
- broker positions/orders/deals reconcile back to EA intent/lifecycle state;
- manual/mobile/web interventions are identified and quarantined from learning;
- critical storage failure and certified configuration drift fail closed;
- material broker-server/GMT clock drift blocks time/news-sensitive entries;
- chaos/fault-injection is categorically refused on REAL and the controlled demo/test matrix exercises API timeout, stale quote, storage failure, pre-send ambiguity, post-fill/pre-bind recovery, dropped/duplicate transaction callbacks, stop-modification failure, corrupt checkpoint and connection loss;
- portfolio authorization is tested against USD +1%, yields +20 bp, equity-index risk-off, gold ±2%, oil ±4%, volatility spike and correlated gap scenarios;
- gap-risk, stressed-margin, decision-half-life and learned-latency gates are exercised;
- model trust transitions NORMAL → REDUCED_TRUST → DETERMINISTIC_ONLY are verified;
- Responses URL provenance and `as_of_utc` freshness fail closed when required;
- quarantined observations do not update adaptive learning/evidence;
- challenger promotion significance, probation rollback and requalification cooldown are verified.

The retained resilience runtime report must contain these literal summary markers:

```text
MT5 RESILIENCE RUNTIME: PASS
DUPLICATE_ORDER_COUNT=0
UNRESOLVED_INTENT_COUNT=0
UNRECONCILED_POSITION_COUNT=0
CHAOS_REAL_ACCOUNT_REFUSAL=PASS
MACRO_STRESS_MATRIX=PASS
PROVENANCE_FRESHNESS=PASS
STORAGE_FAILURE_FAIL_CLOSED=PASS
CONFIG_DRIFT_FAIL_CLOSED=PASS
```

## Required artifacts

At minimum the record references and hashes:

- compile log;
- Strategy Tester report;
- Experts log;
- Journal log;
- broker history export or reconciliation file;
- `GPT_EA_TradeIntentLedger.csv`;
- `GPT_EA_BrokerReconciliation.csv`;
- `GPT_EA_WebIntelProvenance.csv`;
- `GPT_EA_ModelHealth.csv`;
- completed MT5 resilience runtime report with the required literal markers;
- completed `MT5_VALIDATION_ACCEPTANCE_MATRIX.md` working copy documenting M5-001 through M5-053.

Copy the matrix to `artifacts/mt5-validation-matrix.md`. The validator does not trust the matrix hash alone: it parses M5-001 through M5-053, requires exactly one row for each ID, requires literal `PASS`, and requires a non-empty evidence/reference for every row.

Use `tools/build_mt5_validation_evidence.py` to calculate file hashes—including the completed matrix—into a draft. Complete the JSON PASS booleans only from the same actual observations referenced by the M5 rows, then finalize with:

```text
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json --finalize
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json
```

The resulting evidence ID/digest and PASS status are required by the R6 supplemental gate. This record is engineering evidence; it does not guarantee trading profitability.


## Minimum proof view

For operator execution, `MT5_MINIMUM_PROOF_SET.md` groups M5-001 through M5-053 into eight proof bundles (MP-01 through MP-08). This is a compact execution plan, not a reduced acceptance standard.

After the authoritative `mt5_validation_evidence_v2` record passes, `tools/build_mt5_minimum_proof_summary.py` may derive the compact summary. It cannot create PASS from incomplete MT5 evidence and Part28B continues to trust the MT5 v2 evidence digest, not the summary.
