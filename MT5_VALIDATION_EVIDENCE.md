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

Machine schema: `mt5_validation_evidence_v1`.

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

## Required artifacts

At minimum the record references and hashes:

- compile log;
- Strategy Tester report;
- Experts log;
- Journal log;
- broker history export or reconciliation file;
- completed `MT5_VALIDATION_ACCEPTANCE_MATRIX.md` working copy documenting the MT5 runtime tests.

Copy the matrix to `artifacts/mt5-validation-matrix.md`. The validator does not trust the matrix hash alone: it parses M5-001 through M5-034, requires exactly one row for each ID, requires literal `PASS`, and requires a non-empty evidence/reference for every row.

Use `tools/build_mt5_validation_evidence.py` to calculate file hashes—including the completed matrix—into a draft. Complete the JSON PASS booleans only from the same actual observations referenced by the M5 rows, then finalize with:

```text
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json --finalize
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json
```

The resulting evidence ID/digest and PASS status are required by the R6 supplemental gate. This record is engineering evidence; it does not guarantee trading profitability.
