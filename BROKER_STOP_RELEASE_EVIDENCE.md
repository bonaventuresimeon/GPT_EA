# GPT_EA Broker Stop Release Evidence

This file is the release-evidence template for broker-specific protective-stop behavior. It complements `STOP_UPDATE_FAILURE_POLICY.md`, `STOP_FAILURE_OBSERVABILITY.md`, `STOP_MANAGEMENT_TEST_MATRIX.md`, and `PARTIAL_PROTECTION_RELEASE_TEST.md`.

A broker/account/symbol combination is **not certified** merely because another broker passed.

## Evidence identity

Record for every certification run:

- GPT_EA release validation ID;
- Git commit SHA;
- MT5 terminal build;
- broker company and trade server;
- account mode: demo/real test environment, hedging/netting/exchange;
- symbol as offered by broker, including prefix/suffix;
- symbol canonical mapping;
- execution mode and supported filling modes;
- digits, point, tick size, contract size;
- minimum/maximum/step volume;
- stop level and freeze level;
- representative normal and stressed spread;
- test date/time and operator.

## Required broker stop-failure classes

Where the broker/test harness can reproduce the condition, capture the normalized class, action and retry behavior from `GPT_EA_StopFailures.csv`.

| Condition | Expected normalized class | Expected action |
|---|---|---|
| requested stop inside minimum distance | `INVALID_STOPS` or `STOP_LEVEL_DISTANCE` | `WAIT_DISTANCE_CLEAR` |
| stop inside freeze zone | `FROZEN` | `WAIT_DISTANCE_CLEAR` |
| session closed | `MARKET_CLOSED` | `WAIT_MARKET_OPEN` |
| requote / price changed | `REQUOTE_PRICE_CHANGED` | `RETRY_FRESH_PRICE` |
| missing/stale quotes | `NO_QUOTES` | `WAIT_CONNECTION_OR_QUOTE` |
| disconnected terminal/server | `CONNECTION` | `WAIT_CONNECTION_OR_QUOTE` |
| too-frequent requests / throttling | `RATE_LIMIT` | `BACKOFF` |
| trade context locked | `TRADE_CONTEXT_LOCKED` | `BACKOFF` |
| broker/account trading disabled | `TRADING_DISABLED` | `OPERATOR_OR_BROKER_CHANGE` |
| invalid filling mode | `INVALID_FILL` | `OPERATOR_OR_BROKER_CHANGE` |
| invalid volume during reduction | `INVALID_VOLUME` | `OPERATOR_OR_BROKER_CHANGE` |
| actual open position has SL=0 | `PROTECTION_MISSING` | `CRITICAL_PROTECT_OR_CLOSE` |
| TP1 partial succeeded but required protection remains incomplete | `PARTIAL_PROTECTION` | `CRITICAL_PROTECT_OR_CLOSE` after hazard threshold |
| requested stop already equals broker state | `NO_CHANGES` | `NOOP` |
| position no longer exists | `POSITION_CLOSED` | `STOP_POSITION_MANAGEMENT` |

## Mandatory behavioral invariants

For every applicable failure class verify:

1. Existing server-side SL never becomes weaker because an update failed.
2. BUY SL never moves downward; SELL SL never moves upward.
3. A retry uses a fresh quote and current stop/freeze/tick geometry.
4. A stale requested stop is not blindly replayed.
5. Retry cadence matches the normalized broker-failure class.
6. Rate-limit / trade-context failures back off rather than hammering the server.
7. Operator/broker-change failures block new exposure when configured.
8. Existing positions continue to be managed while new entries are blocked.
9. Missing-SL state pauses new entries immediately and enters repair/emergency-close handling.
10. Recovery is observable and does not silently clear an operator-required safety pause.

## Per-broker certification table

Create one row per tested broker/account/symbol combination.

| Broker/server | Account mode | Symbol | Build/SHA | Stop/freeze tested | Requote | Disconnect | Market close | Rate limit/context | Missing SL | Partial protection | Restart | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | |

## Required archived evidence

For each PASS retain:

- `.set` input file;
- MetaEditor compile output;
- Experts and Journal excerpts;
- `GPT_EA_StopFailures.csv`;
- matching `GPT_EA_Execution.csv`;
- broker deal/order history;
- before/failure/recovery screenshots;
- symbol specification screenshot/export;
- test result sheet with PASS/FAIL and notes.

## Certification rule

`InpReleaseBrokerMatrixPassed=true` and `InpReleaseStopMatrixPassed=true` must be set on a real account only after the intended deployment broker/account/symbol set has evidence archived for all applicable HIGH-priority cases.

A broker change, account-mode change, material execution-policy change, MT5 build change that affects trade behavior, or relevant GPT_EA stop-management code change requires revalidation before a new release ID is certified.
