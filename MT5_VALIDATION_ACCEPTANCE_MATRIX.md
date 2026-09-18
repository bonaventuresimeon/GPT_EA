<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Validation & Quality Assurance

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧪 **Document:** `MT5_VALIDATION_ACCEPTANCE_MATRIX.md`

---

# GPT_EA R6 MT5 Validation Acceptance Matrix

This matrix defines the minimum MT5/MetaEditor evidence needed for `mt5_validation_evidence_v2`.

| ID | Area | Mandatory evidence / PASS condition | Status | Evidence/reference |
|---|---|---|---|---|
| M5-001 | Candidate identity | Git SHA, EX5 SHA-256 and SET SHA-256/`NONE` match release candidate | HOLD | |
| M5-002 | Compile | Exact `GPT_EA.mq5`, 0 errors, 0 production warnings | HOLD | |
| M5-003 | Compile provenance | Complete compile log archived and hash verified | HOLD | |
| M5-004 | Terminal identity | MetaEditor and MT5 build recorded | HOLD | |
| M5-005 | Load smoke | No init error, timer/dashboard starts, symbols safe, release initially blocked | HOLD | |
| M5-006 | Attach safety | No broker order sent merely by attaching EA | HOLD | |
| M5-007 | Tester artifact | Strategy Tester report archived and hash verified | HOLD | |
| M5-008 | Tester coverage | Model/date range/symbols recorded; at least one representative completed run | HOLD | |
| M5-009 | Tester integrity | No critical runtime error, duplicate order/partial, SL regression or unprotected authorization | HOLD | |
| M5-010 | Broker matrix | Intended broker/server/account/symbol matrix PASS | HOLD | |
| M5-011 | Contract geometry | Stops/freeze, tick size/value, volume geometry and filling modes verified | HOLD | |
| M5-012 | Margin sizing | Margin calculation and lot normalization verified | HOLD | |
| M5-013 | Restart | Restart reconstruction PASS without duplicate execution | HOLD | |
| M5-014 | Reconnect | Disconnect/reconnect reconstruction PASS | HOLD | |
| M5-015 | Recovery | Primary and validated backup checkpoint PASS | HOLD | |
| M5-016 | Stop management | HIGH stop matrix PASS | HOLD | |
| M5-017 | Broker stop failures | Broker-specific stop-failure policy PASS | HOLD | |
| M5-018 | Partial protection | Partial protection release test PASS | HOLD | |
| M5-019 | Stop observability | Durable stop observability/join PASS | HOLD | |
| M5-020 | BUY lifecycle | Controlled BUY management lifecycle PASS | HOLD | |
| M5-021 | SELL lifecycle | Controlled SELL management lifecycle PASS | HOLD | |
| M5-022 | End-state protection | Zero unexplained unprotected end states | HOLD | |
| M5-023 | MT5 WebRequest | Allow-list verified on live demo terminal | HOLD | |
| M5-024 | Deep review | GPT deep-review transport path PASS | HOLD | |
| M5-025 | Web search/news | Live web-search/news path PASS | HOLD | |
| M5-026 | Failure injection | Timeout/malformed/auth/rate-limit/unavailable policy PASS | HOLD | |
| M5-027 | API recovery | Recovery from induced API failure PASS | HOLD | |
| M5-028 | Request tracing | MT5/API request trace observed | HOLD | |
| M5-029 | Fail closed | Required intelligence failure cannot authorize execution | HOLD | |
| M5-030 | Secret safety | Secret leak count = 0 | HOLD | |
| M5-031 | Runtime logs | Experts and Journal archived and hashed | HOLD | |
| M5-032 | Broker history | Broker history/reconciliation artifact archived and hashed | HOLD | |
| M5-033 | Matrix bundle | MT5 matrix/report bundle archived and hashed | HOLD | |
| M5-034 | Operator review | Literal `ACCEPT`, reviewer and timestamp | HOLD | |
| M5-035 | Direct breakout | Direct breakout executes only as `SETUP_BREAKOUT`; breakout-retest refuses it | HOLD | |
| M5-036 | Atomic intent | PREPARED and SENT intent records are durably written before broker submission | HOLD | |
| M5-037 | Exactly once | Restart/duplicate timer/callback cannot resubmit unresolved SENT/UNCERTAIN nonce | HOLD | |
| M5-038 | Ambiguous submit | Simulated broker ambiguity reconciles against orders/deals/positions without duplicate | HOLD | |
| M5-039 | Broker reconciliation | Orphan/missing-lifecycle/unexpected pending/manual exposure is detected | HOLD | |
| M5-040 | Manual intervention | Client/mobile/web modification is recorded and learning is quarantined | HOLD | |
| M5-041 | Storage failure | Intent/reconciliation/storage heartbeat failure blocks new exposure | HOLD | |
| M5-042 | Config drift | Certified configuration fingerprint mismatch blocks REAL new entries | HOLD | |
| M5-043 | Clock drift | Material server/GMT clock drift blocks time/news-sensitive authorization | HOLD | |
| M5-044 | Chaos safety | Chaos mode refuses REAL accounts and all configured fault scenarios are demo/test-only | HOLD | |
| M5-045 | Checkpoint chaos | Corrupt-checkpoint injection skips disk restore and safely reconciles broker/GV state | HOLD | |
| M5-046 | Macro stress | USD +1%, yields +20 bp, equity risk-off, gold ±2%, oil ±4%, volatility and correlated-gap scenarios PASS | HOLD | |
| M5-047 | Gap risk | Worst proposed gap/scenario loss multiple is bounded by policy | HOLD | |
| M5-048 | Margin stress | Worst-scenario stressed margin level remains above configured floor | HOLD | |
| M5-049 | Decision lifetime | Strategy-specific half-life and learned latency budget invalidate stale execution | HOLD | |
| M5-050 | Model degradation | NORMAL → REDUCED_TRUST → DETERMINISTIC_ONLY and emergency strategy policy PASS | HOLD | |
| M5-051 | Provenance freshness | Raw URL annotations, authoritative-source rule and `as_of_utc` freshness fail closed | HOLD | |
| M5-052 | Learning quarantine | Corrupted/manual/chaos/config-mismatch samples cannot alter adaptive evidence | HOLD | |
| M5-053 | Champion rollback | Statistical promotion significance and probation rollback/requalification PASS | HOLD | |

All rows are mandatory for production R6 acceptance. A row may be satisfied by a controlled demo matrix rather than a naturally occurring soak trade; unsafe market exposure must never be manufactured merely to complete a row.


## Working-copy rule

Copy this matrix to `artifacts/mt5-validation-matrix.md`. Every M5-001 through M5-053 row must be PASS with a concrete artifact, test ID, log reference, broker-history reference, screenshot/export reference, or controlled-test report. The JSON evidence validator verifies the machine-bindable identity and hashes; the completed matrix records how each engineering claim was established.
