<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `STOP_OBSERVABILITY_TEST_MATRIX.md`

---

# GPT_EA Stop Observability Test Matrix

This matrix validates `STOP_FAILURE_OBSERVABILITY_CONTRACT.md` and is release-blocking for intended live broker/account combinations.

## Matrix

| ID | Priority | Scenario | Expected observation | Pass criteria |
|---|---|---|---|---|
| SO-001 | HIGH | First BE modification failure | `STOP_UPDATE_FAILURE` | correct `position_id`, class/action, requested/reference SL, failure count 1 |
| SO-002 | HIGH | Stop/freeze distance block | class `INVALID_STOPS`, `FROZEN` or `STOP_LEVEL_DISTANCE` | action `WAIT_DISTANCE_CLEAR`; retry timestamp in future |
| SO-003 | HIGH | Requote/price changed | class `REQUOTE_PRICE_CHANGED` | action `RETRY_FRESH_PRICE`; short retry interval |
| SO-004 | HIGH | No quote | class `NO_QUOTES` | action `WAIT_CONNECTION_OR_QUOTE`; quote age/context captured |
| SO-005 | HIGH | Connection loss | class `CONNECTION` | terminal connection state 0; current SL unchanged |
| SO-006 | HIGH | Market closed | class `MARKET_CLOSED` | action `WAIT_MARKET_OPEN`; slower retry |
| SO-007 | HIGH | Rate limit | class `RATE_LIMIT` | action `BACKOFF`; retry increases under repeated failures |
| SO-008 | HIGH | Trade-context lock | class `TRADE_CONTEXT_LOCKED` | action `BACKOFF`; no timer-spam retries |
| SO-009 | HIGH | Trading disabled | class `TRADING_DISABLED` | action `OPERATOR_OR_BROKER_CHANGE`; new entries blocked |
| SO-010 | HIGH | Invalid fill/configuration | class `INVALID_FILL` | operator/broker-change action and release block |
| SO-011 | HIGH | Critical SL=0 | `CRITICAL_FAILURE` / class `PROTECTION_MISSING` | `critical=1`; new entries blocked |
| SO-012 | HIGH | Emergency close timer reached | `EMERGENCY_CLOSE_ATTEMPT` | same `position_id`; critical context preserved |
| SO-013 | HIGH | Emergency close rejected | `EMERGENCY_CLOSE_FAILED` | broker retcode/text captured; pause remains active |
| SO-014 | HIGH | Stop repair succeeds after failure | `STOP_PROTECTION_RECOVERED` | emitted before class/action state clears |
| SO-015 | HIGH | TP1 partial begins protection gap | `PARTIAL_PROTECTION_STARTED` | `tp1_partial=1`, `tp1_done=0` |
| SO-016 | HIGH | Partial gap exceeds threshold | `PARTIAL_PROTECTION_HAZARD` | one hazard event; new approvals blocked |
| SO-017 | HIGH | Partial protection completes before threshold | `PARTIAL_PROTECTION_COMPLETED` | no hazard event; no duplicate partial |
| SO-018 | HIGH | Hazard later repaired | `PARTIAL_PROTECTION_RECOVERED` | hazard flag clears only after protection completes |
| SO-019 | HIGH | Restart while failure active | subsequent rows use same `position_id` | count/class/action/retry state remains coherent |
| SO-020 | HIGH | Ticket changes | same lifecycle with new ticket | `position_id` remains stable join key |
| SO-021 | MED | Non-improving trail | no failure row | no false `STOP_UPDATE_FAILURE` |
| SO-022 | MED | Successful BE | execution journal `STOP_BREAKEVEN` | stop CSV is not used to fabricate a failure |
| SO-023 | MED | Successful profit lock | execution journal `STOP_PROFIT_LOCK` | accepted stop and current R are auditable |
| SO-024 | MED | Successful strong lock | execution journal `STOP_STRONG_LOCK` | accepted stop is monotonic |
| SO-025 | MED | Successful trail | execution journal `STOP_TRAIL` | current stop and broker history agree |
| SO-026 | MED | BUY/SELL symmetry | equivalent class/action handling | side field and stop geometry correct |
| SO-027 | MED | Hedging/netting | same schema on both account types | account mode captured; lifecycle joins work |
| SO-028 | MED | High spread | failure row records spread | spread value matches broker tick within tolerance |
| SO-029 | MED | High stop/freeze symbol | levels captured | recorded levels match symbol properties |
| SO-030 | MED | Observability disabled | no stop CSV writes | trading behavior remains safe; release evidence notes observability disabled |

## Schema validation

For every HIGH-priority failure row verify these fields are non-empty or valid where applicable:

- `schema_version`
- `time`
- `event`
- `broker`
- `server`
- `login`
- `symbol`
- `position_id`
- `ticket`
- `side`
- `context`
- `class_code`
- `class`
- `action_code`
- `action`
- `failure_count`
- `critical`
- `current_sl`
- `entry`
- `spread_pts`
- `quote_age_sec`
- `stops_level_pts`
- `freeze_level_pts`
- `trade_mode`
- `execution_mode`
- `terminal_connected`
- `tp1_partial`
- `tp1_done`
- `tp2_partial`
- `protection_stage`
- `retry_seconds`
- `next_retry_time` when retry is applicable
- `reason`

## Cross-file reconciliation

For each tested lifecycle:

1. Join stop CSV rows by `position_id`.
2. Join matching `GPT_EA_Execution.csv` lifecycle/stop-stage events.
3. Compare with broker order/deal/position history.
4. Confirm accepted SL changes exist in broker history/current position.
5. Confirm failed attempts did not weaken current protection.
6. Confirm partial reductions occurred exactly once.

## Release failure conditions

The observability gate fails if:

- two materially different failure classes share the same persisted class code;
- a critical position cannot be identified by `position_id`;
- retry action/time cannot be determined from the record;
- a partial-protection hazard is not distinguishable from an ordinary stop retry;
- failure recovery clears state without an auditable recovery event;
- repeated timer cycles create duplicate partial exits;
- operator-required broker states do not block new authorization;
- recorded current SL materially disagrees with the broker position state at observation time.
