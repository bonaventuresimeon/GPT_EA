# GPT_EA Broker-Specific Stop-Failure Policy

This policy supplements `STOP_UPDATE_FAILURE_POLICY.md`. Stop updates are handled from the broker/server condition actually returned by MT5 rather than using one retry interval for every failure.

## Runtime classifications

| Failure class | Typical MT5 condition | Default handling |
|---|---|---|
| `INVALID_STOPS` | broker rejects stop geometry / minimum stop distance | preserve current SL, recalculate from fresh Bid/Ask/tick size/stops level, retry after freeze-distance interval |
| `FROZEN` | requested modification lies within broker freeze zone | preserve current SL, wait for price to leave freeze zone, retry |
| `MARKET_CLOSED` | session closed / symbol not currently accepting modifications | preserve current SL; if SL exists, retry at slower interval; if SL=0, remain critically paused and emergency-close when possible |
| `REQUOTE_PRICE_CHANGED` | requote / price moved between calculation and request | discard old request, obtain fresh tick, recalculate stop, retry quickly |
| `NO_QUOTES` | no executable quote | do not replay stale price; wait for fresh tick; keep new entries blocked if protection is critical |
| `CONNECTION` | terminal/server connection issue | keep current server-held SL, pause new risk if protection is missing, retry after reconnect |
| `RATE_LIMIT` | broker/server request throttling | increase retry delay; never spam modification requests |
| `TRADING_DISABLED` | account/symbol/server has disabled trading | classify as operator/broker-condition dependent and pause new entries |
| `INVALID_VOLUME` | malformed close/partial volume | do not loop rapidly; recalculate volume step/min/max and require operator/broker-condition correction if persistent |
| `INVALID_PRICE` | invalid/stale requested price | refresh tick and tick-size normalization before retry |
| `INVALID_FILL` | unsupported fill policy | pause new entries; execution configuration/broker mode must be corrected |
| `OTHER_TRANSIENT_OR_BROKER_REJECTION` | uncategorized server rejection | retain current protection and use normal controlled retry/escalation |

## Adaptive retry

The runtime module `GPT_EA_Part18_StopBrokerObservability.mqh` writes a per-position retry delay to `STOP_FAIL_RETRY_SEC`. `StopUpdateRetryDue()` reads this value instead of forcing the same timing for all brokers/failure modes.

Configured defaults:

- requote / price changed: 3 seconds;
- broker freeze / invalid-stops: 10 seconds;
- connection / no quote: 30 seconds;
- rate limit: 30 seconds;
- market closed: 60 seconds.

The EA timer may be slower than those values; in that case the next timer cycle is the effective retry.

## Non-negotiable invariants

1. A failed modification never loosens the current stop.
2. A failed modification never removes an existing protective stop.
3. A rejected request is recalculated from fresh market/broker state before retry.
4. No stale requested stop is blindly replayed after a price change, reconnect or restart.
5. Missing SL is a separate critical condition and blocks new risk immediately.
6. Broker-specific failures that require an operator/session/configuration change do not auto-resume trading.
7. Existing protected positions continue to be managed even when new entries are blocked.
8. Every escalated failure is observable by position identifier and broker/server context.

## Broker migration rule

A stop policy validated on one broker/account type is not assumed valid on another. Before deployment, re-run the stop-management matrix using the target broker's:

- account margin mode;
- execution mode;
- filling policy;
- tick size;
- volume rules;
- stops level;
- freeze level;
- trading sessions;
- symbol aliases/suffixes;
- typical and stressed spreads.
