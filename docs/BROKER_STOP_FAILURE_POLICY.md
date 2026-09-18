<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `BROKER_STOP_FAILURE_POLICY.md`

---

# GPT_EA Broker-Specific Stop Failure Policy

This document is the release contract for how GPT_EA reacts when a broker or terminal refuses, delays or cannot process a protective-stop update.

The governing invariant is:

> A failed stop update must never intentionally weaken, remove or move an existing protective stop farther from safety.

Existing positions remain managed even when new entries are blocked.

## Runtime implementation

Broker-specific handling is implemented primarily in:

- `GPT_EA_Part12_SafetyStopManagement.mqh`
- `GPT_EA_Part14_StopFailurePolicy.mqh`
- `GPT_EA_Part18_StopBrokerObservability.mqh`
- `GPT_EA_Part13_AdvancedPositionManager.mqh`

Stop-failure state is keyed by durable `POSITION_IDENTIFIER` rather than the current ticket.

## Failure classes and required behavior

| Class | Typical broker/terminal condition | Default action | Retry policy | New entries |
|---|---|---|---|---|
| `INVALID_STOPS` | server rejects requested SL geometry | retain current SL; recalculate from fresh price | wait for valid distance, default 10s | allowed until escalation unless critical |
| `STOP_LEVEL_DISTANCE` | candidate lies inside `SYMBOL_TRADE_STOPS_LEVEL` | do not send/retain current SL | wait for price-distance clearance | allowed until escalation unless partial-protection hazard |
| `FROZEN` | candidate/current position lies inside freeze zone | retain current SL | wait for freeze clearance | allowed until escalation unless partial-protection hazard |
| `MARKET_CLOSED` | trading session closed | retain current SL; do not replay stale request | default 60s / next tradable session | existing positions managed; new entries normally blocked by release/session gates |
| `REQUOTE_PRICE_CHANGED` | requested price became stale | discard stale candidate | fresh-price retry, default 3s | allowed unless escalation threshold reached |
| `INVALID_PRICE` | broker rejects stale/invalid price | discard stale candidate | fresh-price retry, default 3s | allowed unless escalation threshold reached |
| `NO_QUOTES` | no current executable price | do not calculate/send a new stop from stale quotes | wait for fresh quote, default 30s | release gate blocks stale-price entries |
| `CONNECTION` | terminal/server disconnected | retain existing server-side SL | wait for connection, default 30s | blocked by release gate |
| `RATE_LIMIT` | too many requests | retain current SL | progressive backoff, capped by configuration | allowed initially; repeated failures can pause |
| `TRADE_CONTEXT_LOCKED` | trade context/server request lock | retain current SL | progressive backoff | allowed initially; repeated failures can pause |
| `TRADING_DISABLED` | symbol/account/EA/server trading disabled | retain current SL | operator/broker condition change required | blocked |
| `INVALID_FILL` | account/symbol execution configuration incompatible | do not guess alternative unsafe behavior | operator/broker configuration review | blocked |
| `INVALID_VOLUME` | broker volume state incompatible with requested operation | no repeated blind request | operator/broker configuration review | blocked |
| `NO_CHANGES` | requested protection already equals broker state | no-op | no retry required | allowed |
| `POSITION_CLOSED` | lifecycle already ended | stop managing that position | none | unaffected |
| `PROTECTION_MISSING` | open GPT_EA position has `SL=0` | reconstruct/restore original structural SL; otherwise critical emergency path | retry protection; emergency close after configured timeout | blocked immediately |
| `PARTIAL_PROTECTION` | TP1 partial completed but required BE protection remains incomplete | continue BE repair; never repeat partial | adaptive stop retry; hazard after configured seconds | blocked when hazard threshold reached |
| `OTHER_TRANSIENT_OR_BROKER_REJECTION` | unclassified broker response | retain existing SL; recalculate next attempt | default stop retry interval | escalation policy applies |

## Stable class and action codes

The runtime no longer relies on `StringLen(class)` or free-text hashes as the authoritative failure identity. `GPT_EA_Part18_StopBrokerObservability.mqh` persists stable numeric class and action codes.

This prevents collisions between differently named broker failure classes and makes exported analytics stable across releases.

## Retry action contract

- `RETRY_FRESH_PRICE` — abandon the stale requested level and recalculate from current market data.
- `WAIT_DISTANCE_CLEAR` — do not spam the server while stop/freeze geometry is invalid.
- `WAIT_MARKET_OPEN` — retain protection and retry only after session conditions permit.
- `WAIT_CONNECTION_OR_QUOTE` — wait for connected, fresh market data.
- `BACKOFF` — progressively reduce request frequency after rate-limit/trade-context pressure.
- `OPERATOR_OR_BROKER_CHANGE` — automatic retries alone are not considered sufficient; new entries remain blocked.
- `CRITICAL_PROTECT_OR_CLOSE` — protect the position immediately if possible; otherwise use the configured emergency-close policy.
- `NOOP` — no failure escalation is required.
- `STOP_POSITION_MANAGEMENT` — lifecycle has ended.

## Rate-limit and trade-context backoff

For `RATE_LIMIT` and `TRADE_CONTEXT_LOCKED`, retry delay increases with the per-position failure count and is capped by `InpStopRateLimitMaxBackoffSeconds`.

The EA must not issue the same stop-modification request on every timer tick while the broker is throttling or locking requests.

## Stop/freeze distance handling

Before an automated stop modification, the EA checks current broker stop/freeze distance.

If the candidate is not broker-valid:

1. existing SL is preserved;
2. no weaker fallback stop is substituted;
3. requested protection remains pending;
4. the next attempt is recalculated from a fresh price;
5. TP1/TP2 partial state is not repeated.

## Partial protection

`TP1PARTIAL=1` and `TP1DONE=0` is an intentional transitional state only when the configured TP1 partial has executed and required BE protection has not yet been accepted.

The lifecycle is observable as:

1. `PARTIAL_PROTECTION_STARTED`
2. broker-specific retries while BE is pending
3. either `PARTIAL_PROTECTION_COMPLETED`
4. or `PARTIAL_PROTECTION_HAZARD` after `InpPartialProtectionMaxSeconds`
5. followed by `PARTIAL_PROTECTION_RECOVERED` if protection later completes after hazard escalation.

A partial-protection hazard blocks new entries when `InpBlockNewEntriesOnPartialProtection=true`.

## Critical unprotected position

An open position with `POSITION_SL <= 0` is critical.

Required behavior:

1. attempt reconstruction of original structural SL from durable state/history;
2. validate it against current broker geometry;
3. attempt restoration;
4. immediately pause new entries if restoration is not successful;
5. retry according to stop policy;
6. after `InpUnprotectedEmergencySeconds`, attempt an emergency market close if enabled;
7. if market close is rejected, remain paused and continue later protective/close attempts.

The EA must not open another trade while a critical unprotected GPT_EA position remains unresolved.

## Operator-required states

`TRADING_DISABLED`, `INVALID_FILL` and `INVALID_VOLUME` are treated as conditions that may require broker/account/input/operator correction rather than blind repeated requests.

When `InpBlockOnOperatorStopState=true`, any open position carrying an operator-required stop state independently blocks new approvals even if the global pause flag were manually changed.

## Portfolio stop-health gate

Before new authorization, `StopObservabilityAllowsNewEntries()` independently scans every open GPT_EA position for:

- `SL=0`;
- critical failure state;
- operator-required broker state;
- failure count at/above pause threshold;
- unresolved partial-protection hazard.

This is intentionally separate from the global pause variable.

## Broker migration rule

A stop policy validated on one broker/account type is not assumed valid on another. Re-run the release matrix using the target broker's:

- account margin mode;
- execution mode;
- filling policy;
- tick size;
- volume rules;
- stop level;
- freeze level;
- trading sessions;
- symbol aliases/suffixes;
- normal and stressed spreads.

## Release requirement

A broker/account combination is not approved for live release until the applicable cases in:

- `STOP_MANAGEMENT_TEST_MATRIX.md`
- `PARTIAL_PROTECTION_RELEASE_TEST.md`
- `BROKER_MATRIX_TESTS.md`

have passed and evidence has been archived.
