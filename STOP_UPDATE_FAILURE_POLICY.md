# GPT_EA Stop-Update Failure Policy

This document defines the mandatory runtime behavior when GPT_EA cannot create, restore, move, lock or trail a protective stop.

The governing principle is:

> **A failed stop update must never make the existing protection worse.**

A failure to improve protection is not permission to loosen the current SL, remove the current SL, duplicate a partial close, or open additional risk.

## 1. Failure classes

### A. No-op / not an error

Examples:
- proposed BUY SL is not higher than the current BUY SL;
- proposed SELL SL is not lower than the current SELL SL;
- trailing movement is smaller than the configured minimum step;
- the market has not yet reached the configured R trigger.

Behavior:
- keep the existing SL unchanged;
- do not increment stop-failure counters;
- do not pause trading;
- wait for the next valid market state.

### B. Deferred broker-distance update

Examples:
- proposed SL falls inside the current broker stop level;
- proposed SL falls inside the broker freeze level;
- price is temporarily too close to the requested BE/profit-lock level.

Behavior:
- keep the existing SL unchanged;
- never move the SL backward to make the request pass;
- retry after the configured retry interval;
- if the expected protection stage repeatedly remains unmet, count it as a stop-update failure;
- existing position continues to be managed.

### C. Transient stop-modification failure

Examples:
- `PositionModify()` fails;
- temporary server rejection;
- trade context/server state temporarily prevents modification;
- price changes between calculation and modification.

Behavior:
- keep the current SL unchanged;
- increment `STOP_FAIL_COUNT` only when a protection stage was expected but remains unmet;
- store first and last failure timestamps;
- retry no faster than `InpStopUpdateRetrySeconds`;
- journal escalation points as `STOP_UPDATE_FAIL`;
- alert at `InpStopFailureWarnAfter`;
- pause **new entries** at `InpStopFailurePauseAfter` when configured;
- continue managing the existing position.

### D. Missing protective SL — critical

Condition:
- an open GPT_EA position has `POSITION_SL == 0`.

Behavior:
1. immediately attempt to reconstruct the original SL from durable state/history;
2. attempt to restore that SL only if it is broker-valid;
3. if restoration fails, classify the condition as critical;
4. immediately pause new entries when `InpPauseNewEntriesOnStopFailure=true`;
5. record `STOP_FAIL_CRITICAL`;
6. alert the operator;
7. retry repair on subsequent management cycles;
8. if the position remains unprotected beyond `InpUnprotectedEmergencySeconds` and `InpEmergencyCloseUnprotected=true`, attempt to close the position;
9. if emergency close fails, keep the EA paused and retry protection/closure on later cycles.

The EA must never silently leave an unprotected position while continuing to authorize new trades.

## 2. Retry policy

Default:

- retry interval: `InpStopUpdateRetrySeconds = 10` seconds;
- warning threshold: `InpStopFailureWarnAfter = 3`;
- new-entry pause threshold: `InpStopFailurePauseAfter = 8`;
- unprotected emergency timeout: `InpUnprotectedEmergencySeconds = 30` seconds.

The timer frequency may be slower than the configured retry interval. In that case the next timer cycle is the effective retry point.

A retry must always use fresh:
- Bid/Ask;
- symbol tick size;
- stop level;
- freeze level;
- current position ticket resolved from `POSITION_IDENTIFIER`;
- current SL;
- current R multiple.

A stored modification request must never be blindly replayed after market conditions change.

## 3. Escalation behavior

### First failed expected update

- current SL remains unchanged;
- failure count becomes 1;
- failure timestamp stored;
- diagnostic journal event may be written;
- no forced close if the position still has a valid SL.

### Warning threshold

At `InpStopFailureWarnAfter`:

- terminal alert is generated when enabled;
- push notification is generated when enabled;
- existing position remains managed;
- no SL regression is allowed.

### Pause threshold

At `InpStopFailurePauseAfter`:

- `GPT_EA` pause state is set;
- no new setups may be authorized/executed;
- open positions remain under active management;
- the operator must deliberately resume trading after reviewing the issue.

A later successful stop update clears the per-position failure counters, but it does **not** automatically override a safety pause that has already been triggered.

## 4. Success/recovery behavior

When the expected protection stage is eventually achieved:

- clear `STOP_FAIL_COUNT`;
- clear first/last failure timestamps;
- clear critical failure marker;
- journal `STOP_UPDATE_RECOVERED`;
- retain the improved SL;
- never restore an earlier/weaker SL;
- keep any global/manual pause in place until explicitly resumed if the pause threshold was previously reached.

## 5. Protection stages

Fixed protection stages are evaluated using actual broker position SL, not merely stored intended state.

### Stage 0 — INITIAL

Original structural SL remains active.

### Stage 1 — BREAKEVEN

Expected after `InpBETriggerR`.

The BE level includes a cost buffer based on the larger of:
- configured ATR cost allowance; or
- current spread + modeled dynamic slippage.

Failure behavior:
- retain original SL;
- retry;
- TP1 partial must not be repeated simply because BE failed.

### Stage 2 — PROFIT_LOCK

Expected after `InpProfitLockTriggerR`.

Default concept:
- around 1.5R open profit → lock approximately +0.5R.

Failure behavior:
- retain the existing BE/stronger SL;
- retry according to policy;
- never move back below the current SL.

### Stage 3 — STRONG_LOCK

Expected after `InpStrongLockTriggerR`.

Default concept:
- around 2R open profit → lock approximately +1R.

Failure behavior:
- retain the existing stronger SL;
- retry;
- repeated failure can pause new entries.

### Stage 4 — TRAIL

ATR + M5 structure trailing is opportunistic rather than mandatory every timer cycle.

A trailing calculation that produces no meaningful improvement is a **no-op**, not a failure.

A trailing modification that is actually attempted but rejected must never cause the SL to regress. The next valid trailing opportunity is recalculated from fresh market data.

## 6. TP1 interaction

TP1 state is split deliberately:

- `TP1PARTIAL` — partial profit action completed;
- `TP1DONE` — TP1 management, including required BE protection, completed.

If TP1 partial succeeds but BE fails:

- `TP1PARTIAL` remains true;
- the partial is not repeated;
- `TP1DONE` remains false;
- BE is retried;
- pre-TP1 expiry logic must not create duplicate scale-outs;
- failure policy handles repeated stop-update failure.

## 7. TP2 interaction

TP2 partial is separately idempotent through `TP2PARTIAL`.

A stop update failure does not permit repeated TP2 scale-outs.

TP2 scale-out and stop-management state must survive ticket changes and restarts using `POSITION_IDENTIFIER`-scoped durable state.

## 8. Restart behavior

After restart:

- current broker position is source of truth for actual SL;
- original SL is recovered from durable state/history;
- stop stage is reconstructed from the actual current SL and original R;
- failure counters/timestamps remain associated with `POSITION_IDENTIFIER`;
- a recovered stronger SL must never be replaced with a weaker reconstructed level;
- if actual SL is zero, critical missing-SL behavior begins immediately;
- recovered pending approvals never bypass release gates.

## 9. Broker/session edge cases

### Market closed

- do not assume modification succeeded;
- keep current SL;
- retry when broker accepts modification;
- an unprotected position remains critical even if the market is closed.

### Stale/no quote

- do not calculate a new stop from stale prices;
- retain current SL;
- retry when a fresh quote is available.

### Spread expansion

- cost-aware BE may move farther into profit;
- it must never move backward from a stronger existing SL;
- no new entry is authorized if wider costs violate other risk gates.

### Gap through intended stop-update level

- do not place a logically reversed/invalid stop;
- recalculate from current market state;
- if a missing original SL cannot be safely restored, invoke critical unprotected-position policy.

### Symbol suffix/ticket change

- re-resolve the current ticket by durable `POSITION_IDENTIFIER`;
- apply management to the currently open broker position only.

## 10. Analytics and audit fields

Per-position stop-failure state uses:

- `STOP_FAIL_COUNT`
- `STOP_FAIL_FIRST`
- `STOP_FAIL_LAST`
- `STOP_FAIL_CRITICAL`

Journal events include:

- `STOP_BREAKEVEN`
- `STOP_PROFIT_LOCK`
- `STOP_STRONG_LOCK`
- `STOP_TRAIL`
- `STOP_UPDATE_FAIL`
- `STOP_FAIL_CRITICAL`
- `STOP_UPDATE_RECOVERED`
- `EMERGENCY_CLOSE_UNPROTECTED`

## 11. Release requirement

A build must not be promoted to live execution until the applicable cases in `STOP_MANAGEMENT_TEST_MATRIX.md` pass on the intended broker/account type.

The failure policy is designed to be asymmetric:

- inability to **improve** an already protected trade → retain protection, retry, escalate gradually;
- inability to **protect** an unprotected trade → immediate safety pause and emergency action if unresolved.
