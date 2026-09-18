<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Chaos & Fault-Injection Validation

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

</div>

# R6 Chaos / Fault-Injection Test Matrix

Use only on Strategy Tester, DEMO or CONTEST. The EA must refuse fault injection on a REAL account.

Copy this file into the release evidence folder and replace HOLD with PASS only after retaining the stated evidence.

| ID | Scenario | Required procedure | Mandatory result | Status | Evidence/reference |
|---|---|---|---|---|---|
| CF-001 | REAL refusal | Attach with chaos enabled on a non-trading REAL validation environment without submitting orders | ChaosEnvironmentAllows() refuses injection; no fault is armed and no new order is caused | HOLD | |
| CF-002 | API timeout | CHAOS_API_TIMEOUT during required intelligence | synthetic timeout is recorded; model failure counter increases; required intelligence cannot authorize entry | HOLD | |
| CF-003 | Stale quote | CHAOS_STALE_QUOTE before authorization | entry is rejected before intent/order submission | HOLD | |
| CF-004 | Storage failure | CHAOS_STORAGE_WRITE_FAIL at storage heartbeat/intent persistence | critical storage health becomes failed and new exposure is blocked | HOLD | |
| CF-005 | Pre-send ambiguity | CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS after durable SENT | intent becomes UNCERTAIN; no blind retry; reconciliation resolves before any future nonce | HOLD | |
| CF-006 | Post-fill/pre-bind | CHAOS_POST_FILL_PRE_BIND after broker success | restart/timer reconciliation finds nonce in broker evidence and reconstructs intent/lifecycle without duplicate | HOLD | |
| CF-007 | Dropped callback | CHAOS_DROP_TRADE_TRANSACTION | missing callback does not lose broker truth; periodic reconciliation reconstructs state | HOLD | |
| CF-008 | Duplicate callback | CHAOS_DUPLICATE_TRADE_TRANSACTION | duplicate signature is detected; no second lifecycle/order/learning transition is applied | HOLD | |
| CF-009 | Stop modify failure | CHAOS_STOP_MODIFY_FAIL during protection | stop failure/retry/observability policy activates; no false protection success is recorded | HOLD | |
| CF-010 | Corrupt checkpoint | CHAOS_CORRUPT_CHECKPOINT on restart | disk checkpoint restore is refused; broker/GV reconciliation remains authoritative; no duplicate trade | HOLD | |
| CF-011 | Connection loss | CHAOS_CONNECTION_LOSS before entry | new entry is blocked; existing-position management resumes safely after reconnect | HOLD | |
| CF-012 | Restart after SENT | restart terminal with durable SENT/UNCERTAIN intent | same nonce is not submitted again; broker orders/deals/positions are queried first | HOLD | |
| CF-013 | Restart after fill | terminate after broker fill before normal metadata bind | open position is joined to intent/lifecycle and protective state is reconstructed | HOLD | |
| CF-014 | Disk unavailable during active trade | make Common Files unwritable while a managed position exists | existing protection continues where possible; new exposure is blocked; sample is quarantined | HOLD | |
| CF-015 | Manual/mobile intervention | alter EA position SL/TP or close from client/mobile/web | intervention is recorded as external, reconciliation journal updates and learning sample is quarantined | HOLD | |
| CF-016 | Repeated fault isolation | run every scenario independently after reset | one-shot state from one scenario cannot contaminate the next scenario's evidence | HOLD | |

## Zero-tolerance acceptance

The completed matrix is PASS only when every CF-001 through CF-016 row is PASS; duplicate order count is 0; unresolved intent count is 0; unreconciled EA position count is 0; fault-injection samples do not enter learning; and no test bypasses release, stop, storage, configuration, provenance or risk gates.

Chaos evidence is test evidence only. It cannot be used to enable chaos on a REAL account.
