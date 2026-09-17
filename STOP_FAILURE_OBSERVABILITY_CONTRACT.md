# GPT_EA Stop-Failure Observability Contract

This document defines the machine-readable contract for protective-stop health, broker failures, partial-protection transitions and emergency stop-recovery actions.

Runtime file:

`GPT_EA_StopFailures.csv`

Location: MT5 Common Files area.

Schema version:

`stop_failure_observability_v2`

## Purpose

The observability stream exists to answer four release-critical questions:

1. Did a broker reject or delay a required protective-stop improvement?
2. Did the EA preserve the existing SL and choose the correct retry/escalation action?
3. Did a TP1 scale-out create a temporary partial-protection state, and was that state completed within policy?
4. Did a critical unprotected position trigger repair, pause and emergency behavior correctly?

## Event types

Expected event values include:

- `STOP_UPDATE_FAILURE`
- `CRITICAL_FAILURE`
- `STOP_PROTECTION_RECOVERED`
- `PARTIAL_PROTECTION_STARTED`
- `PARTIAL_PROTECTION_COMPLETED`
- `PARTIAL_PROTECTION_HAZARD`
- `PARTIAL_PROTECTION_RECOVERED`
- `EMERGENCY_CLOSE_ATTEMPT`
- `EMERGENCY_CLOSE_FAILED`

Successful stop-stage changes remain additionally auditable in `GPT_EA_Execution.csv` as:

- `STOP_BREAKEVEN`
- `STOP_PROFIT_LOCK`
- `STOP_STRONG_LOCK`
- `STOP_TRAIL`

A successful emergency close is recorded in the execution journal as `EMERGENCY_CLOSE_UNPROTECTED`.

## CSV columns

The stop-observability CSV uses the following contract:

| Field | Type / unit | Meaning |
|---|---|---|
| `schema_version` | text | currently `stop_failure_observability_v2` |
| `time` | trade-server datetime | observation time |
| `event` | enum-like text | lifecycle/failure event |
| `broker` | text | `ACCOUNT_COMPANY` |
| `server` | text | `ACCOUNT_SERVER` |
| `login` | integer string | account login for environment isolation |
| `account_mode` | MT5 enum integer | hedging/netting/exchange account mode |
| `leverage` | integer | account leverage denominator |
| `symbol` | broker symbol | actual resolved MT5 symbol |
| `canonical` | text | normalized instrument key |
| `position_id` | uint64 string | durable `POSITION_IDENTIFIER` |
| `ticket` | uint64 string | current position ticket |
| `side` | `BUY` / `SELL` | live position direction |
| `context` | text | management stage/context |
| `class_code` | integer | stable stop-failure class code |
| `class` | text | class name |
| `action_code` | integer | stable required-action code |
| `action` | text | retry/escalation action |
| `retcode` | integer | last MT5 trade retcode available at observation |
| `retcode_text` | text | broker/terminal description |
| `failure_count` | integer | per-position failure count |
| `critical` | 0/1 | critical protection state flag |
| `current_sl` | price | broker position SL at observation |
| `requested_or_reference_sl` | price | intended/reference stop when available |
| `entry` | price | position entry |
| `r_now` | R multiple | current movement in units of original risk when available |
| `spread_pts` | points | current Bid/Ask spread |
| `quote_age_sec` | seconds | age of latest broker quote |
| `stops_level_pts` | points | current broker stop-level requirement |
| `freeze_level_pts` | points | current broker freeze-level requirement |
| `trade_mode` | MT5 enum | current symbol trade mode |
| `execution_mode` | MT5 enum | current symbol execution mode |
| `terminal_connected` | 0/1 | terminal/server connection state |
| `tp1_partial` | 0/1 | TP1 reduction completed |
| `tp1_done` | 0/1 | TP1 reduction + required protection complete |
| `tp2_partial` | 0/1 | TP2 reduction completed |
| `protection_stage` | integer | actual protection stage |
| `retry_seconds` | seconds | class-specific retry delay |
| `next_retry_time` | trade-server datetime | earliest next controlled retry |
| `reason` | text | detailed reason/context |

## Stable class codes

The authoritative runtime class is numeric. Text is descriptive.

| Code | Class |
|---:|---|
| 0 | `NONE` |
| 1 | `INVALID_STOPS` |
| 2 | `FROZEN` |
| 3 | `MARKET_CLOSED` |
| 4 | `REQUOTE_PRICE_CHANGED` |
| 5 | `NO_QUOTES` |
| 6 | `CONNECTION` |
| 7 | `RATE_LIMIT` |
| 8 | `TRADING_DISABLED` |
| 9 | `INVALID_VOLUME` |
| 10 | `INVALID_PRICE` |
| 11 | `INVALID_FILL` |
| 12 | `STOP_LEVEL_DISTANCE` |
| 13 | `NO_CHANGES` |
| 14 | `POSITION_CLOSED` |
| 15 | `PROTECTION_MISSING` |
| 16 | `PARTIAL_PROTECTION` |
| 17 | `TRADE_CONTEXT_LOCKED` |
| 99 | `OTHER_TRANSIENT_OR_BROKER_REJECTION` |

## Stable action codes

| Code | Action |
|---:|---|
| 0 | `NONE` |
| 1 | `RETRY_FRESH_PRICE` |
| 2 | `WAIT_DISTANCE_CLEAR` |
| 3 | `WAIT_MARKET_OPEN` |
| 4 | `WAIT_CONNECTION_OR_QUOTE` |
| 5 | `BACKOFF` |
| 6 | `OPERATOR_OR_BROKER_CHANGE` |
| 7 | `CRITICAL_PROTECT_OR_CLOSE` |
| 8 | `NOOP` |
| 9 | `STOP_POSITION_MANAGEMENT` |

## State fields

Durable per-position stop-health state uses the `POSITION_IDENTIFIER` namespace and includes:

- `STOP_FAIL_COUNT`
- `STOP_FAIL_FIRST`
- `STOP_FAIL_LAST`
- `STOP_FAIL_CRITICAL`
- `STOP_FAIL_CLASS_CODE`
- `STOP_FAIL_ACTION_CODE`
- `STOP_FAIL_RETRY_SEC`
- `STOP_FAIL_NEXT_RETRY`
- `PARTIAL_PROTECT_STARTED_LOGGED`
- `PARTIAL_PROTECT_HAZARD_LOGGED`

The old `STOP_FAIL_CLASS_HASH` field is legacy-only and is cleared on recovery; it is not authoritative.

## Partial-protection lifecycle contract

A normal TP1 partial-protection sequence should produce:

1. TP1 reduction succeeds.
2. `TP1PARTIAL=1`.
3. If BE is not already satisfied, `PARTIAL_PROTECTION_STARTED` is emitted.
4. BE is recalculated/retried without repeating the partial.
5. If BE succeeds before timeout, `TP1DONE=1` and `PARTIAL_PROTECTION_COMPLETED` is emitted.
6. If BE remains incomplete beyond `InpPartialProtectionMaxSeconds`, `PARTIAL_PROTECTION_HAZARD` is emitted once and new entries are blocked.
7. If protection later succeeds after hazard, the hazard clears and `PARTIAL_PROTECTION_RECOVERED` is emitted.

## Failure/recovery contract

For a real stop-update failure:

1. failure count increments once per controlled retry cycle;
2. class/action are persisted;
3. next retry time is persisted;
4. observation row is written;
5. current valid SL remains unchanged;
6. warning/pause escalation occurs at configured thresholds;
7. a later successful protection state emits `STOP_PROTECTION_RECOVERED` before failure state is cleared.

## Critical unprotected-position contract

When `POSITION_SL=0`:

- class/action must reflect critical protection handling;
- new entries must remain blocked;
- recovery attempts must be observable;
- `EMERGENCY_CLOSE_ATTEMPT` must be observable after the configured timeout when emergency close is enabled;
- failed close attempts produce `EMERGENCY_CLOSE_FAILED`;
- successful close is corroborated by broker history and `EMERGENCY_CLOSE_UNPROTECTED` in the execution journal.

## Data-quality rules

- Never fabricate a retcode, broker property or quote.
- Do not treat free-text reason as the durable primary key.
- `position_id` is the lifecycle key; ticket is contextual metadata.
- If a broker ticket changes, events for the same lifecycle remain joinable by `position_id`.
- `current_sl` must reflect broker position state at observation time.
- Retry time must come from the class policy, not from a hard-coded universal retry.
- Repeated timer cycles must not create duplicate partial exits.

## Release evidence

For HIGH-priority stop-management tests, archive:

- relevant `GPT_EA_StopFailures.csv` rows;
- matching `GPT_EA_Execution.csv` rows;
- Experts/Journal logs;
- broker position/order/deal history;
- screenshots before/after the protection event;
- EA `.set` preset;
- Git commit SHA;
- MetaTrader build;
- broker symbol profile.

A live release fails if the stop CSV cannot distinguish the failure class/action that occurred, if lifecycle events cannot be joined by `POSITION_IDENTIFIER`, or if a partial-protection hazard is not observable and release-blocking as specified.
