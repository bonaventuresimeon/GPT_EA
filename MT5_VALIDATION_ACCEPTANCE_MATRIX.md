# GPT_EA R6 MT5 Validation Acceptance Matrix

This matrix defines the minimum MT5/MetaEditor evidence needed for `mt5_validation_evidence_v1`.

| ID | Area | Mandatory evidence / PASS condition |
|---|---|---|
| M5-001 | Candidate identity | Git SHA, EX5 SHA-256 and SET SHA-256/`NONE` match release candidate |
| M5-002 | Compile | Exact `GPT_EA.mq5`, 0 errors, 0 production warnings |
| M5-003 | Compile provenance | Complete compile log archived and hash verified |
| M5-004 | Terminal identity | MetaEditor and MT5 build recorded |
| M5-005 | Load smoke | No init error, timer/dashboard starts, symbols safe, release initially blocked |
| M5-006 | Attach safety | No broker order sent merely by attaching EA |
| M5-007 | Tester artifact | Strategy Tester report archived and hash verified |
| M5-008 | Tester coverage | Model/date range/symbols recorded; at least one representative completed run |
| M5-009 | Tester integrity | No critical runtime error, duplicate order/partial, SL regression or unprotected authorization |
| M5-010 | Broker matrix | Intended broker/server/account/symbol matrix PASS |
| M5-011 | Contract geometry | Stops/freeze, tick size/value, volume geometry and filling modes verified |
| M5-012 | Margin sizing | Margin calculation and lot normalization verified |
| M5-013 | Restart | Restart reconstruction PASS without duplicate execution |
| M5-014 | Reconnect | Disconnect/reconnect reconstruction PASS |
| M5-015 | Recovery | Primary and validated backup checkpoint PASS |
| M5-016 | Stop management | HIGH stop matrix PASS |
| M5-017 | Broker stop failures | Broker-specific stop-failure policy PASS |
| M5-018 | Partial protection | Partial protection release test PASS |
| M5-019 | Stop observability | Durable stop observability/join PASS |
| M5-020 | BUY lifecycle | Controlled BUY management lifecycle PASS |
| M5-021 | SELL lifecycle | Controlled SELL management lifecycle PASS |
| M5-022 | End-state protection | Zero unexplained unprotected end states |
| M5-023 | MT5 WebRequest | Allow-list verified on live demo terminal |
| M5-024 | Deep review | GPT deep-review transport path PASS |
| M5-025 | Web search/news | Live web-search/news path PASS |
| M5-026 | Failure injection | Timeout/malformed/auth/rate-limit/unavailable policy PASS |
| M5-027 | API recovery | Recovery from induced API failure PASS |
| M5-028 | Request tracing | MT5/API request trace observed |
| M5-029 | Fail closed | Required intelligence failure cannot authorize execution |
| M5-030 | Secret safety | Secret leak count = 0 |
| M5-031 | Runtime logs | Experts and Journal archived and hashed |
| M5-032 | Broker history | Broker history/reconciliation artifact archived and hashed |
| M5-033 | Matrix bundle | MT5 matrix/report bundle archived and hashed |
| M5-034 | Operator review | Literal `ACCEPT`, reviewer and timestamp |

All rows are mandatory for production R6 acceptance. A row may be satisfied by a controlled demo matrix rather than a naturally occurring soak trade; unsafe market exposure must never be manufactured merely to complete a row.
