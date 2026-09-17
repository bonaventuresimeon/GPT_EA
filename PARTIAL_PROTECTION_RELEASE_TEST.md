# GPT_EA Partial-Protection Release Test

This is a **release-blocking** test. It validates the transitional state where TP1 partial profit has executed but required breakeven protection has not yet been secured.

The test must be run on demo before live arming.

## State contract under test

The intended transitional state is:

- `TP1PARTIAL=1`
- `TP1DONE=0`
- existing broker SL still present and not weaker than before the TP1 event
- `PARTIAL_PROTECT_STARTED_LOGGED=1`
- BE/protection retries controlled by broker-specific retry policy

This state must never cause a second TP1 partial.

## Required event sequence

A normal controlled test should demonstrate:

1. `PARTIAL_PROTECTION_STARTED`
2. one or more controlled broker stop-failure observations if BE cannot be applied
3. either `PARTIAL_PROTECTION_COMPLETED` before the hazard timeout
4. or `PARTIAL_PROTECTION_HAZARD` after `InpPartialProtectionMaxSeconds`
5. if hazard occurred and protection later succeeds, `PARTIAL_PROTECTION_RECOVERED`

The successful BE modification must also be corroborated by `STOP_BREAKEVEN` in `GPT_EA_Execution.csv` when a new BE stop was actually accepted by the broker.

## Core test PP-001 — TP1 partial then temporary BE failure

1. Open a demo trade with a valid structural initial SL.
2. Record position ticket and `POSITION_IDENTIFIER`.
3. Drive/replay price to TP1.
4. Confirm the configured TP1 partial close succeeds exactly once.
5. Force the subsequent BE modification to fail temporarily using a broker freeze/stops condition or controlled harness.
6. Verify broker position still has its prior protective SL.
7. Verify `TP1PARTIAL=1` and `TP1DONE=0`.
8. Verify `PARTIAL_PROTECTION_STARTED` exists in `GPT_EA_StopFailures.csv` for the same `POSITION_IDENTIFIER`.
9. Verify the broker-specific failure row contains class/action/retry information.
10. Keep BE unresolved beyond `InpPartialProtectionMaxSeconds`.
11. Verify `PARTIAL_PROTECTION_HAZARD` is emitted once.
12. Verify `StopObservabilityAllowsNewEntries()` blocks new approvals/execution while hazard remains active.
13. Verify the existing position continues to be managed.
14. Remove the temporary broker restriction.
15. Verify BE succeeds using freshly recalculated broker-valid geometry.
16. Verify no second TP1 partial occurs.
17. Verify `TP1DONE=1` becomes durable.
18. Verify hazard/recovery state clears according to policy.
19. Verify global/manual safety pause is **not** silently auto-cleared if the failure previously escalated to a pause requiring operator review.

## PP-002 — protection succeeds before hazard timeout

1. Repeat the TP1 partial sequence.
2. Temporarily block BE for less than `InpPartialProtectionMaxSeconds`.
3. Restore broker-valid conditions.
4. Verify `PARTIAL_PROTECTION_STARTED` then `PARTIAL_PROTECTION_COMPLETED`.
5. Verify no `PARTIAL_PROTECTION_HAZARD` is emitted.
6. Verify exactly one TP1 partial.
7. Verify new-entry release gate never needs to enter hazard state.

## PP-003 — restart during partial protection

1. Reach `TP1PARTIAL=1`, `TP1DONE=0`.
2. Confirm `PARTIAL_PROTECTION_STARTED` has been observed.
3. Restart MT5 or remove/re-attach the EA.
4. Verify recovery uses the same `POSITION_IDENTIFIER`.
5. Verify TP1 partial is not repeated.
6. Verify BE repair resumes using current price/broker rules.
7. Verify timeout/hazard timing remains reasonable from durable TP1 state rather than starting an entirely new trade lifecycle.
8. Verify eventual `TP1DONE=1` after BE recovery.

## PP-004 — partial protection plus connection/no-quote failure

1. Reach TP1 partial.
2. Interrupt terminal/server connectivity or quote flow in a controlled demo environment.
3. Verify current broker-held SL remains intact.
4. Verify class/action becomes connection/no-quote handling rather than stale-price replay.
5. Verify new entries are blocked if the partial-protection hazard threshold is reached.
6. Reconnect.
7. Verify fresh quote is used before BE retry.
8. Verify no duplicate partial.

## PP-005 — partial protection plus market closed

1. Reproduce TP1 partial close near a session boundary on an instrument that closes.
2. Cause required BE modification to become unavailable because the market/session is closed.
3. Verify `MARKET_CLOSED` / `WAIT_MARKET_OPEN` policy.
4. Verify prior SL remains intact.
5. Verify no aggressive timer-loop retries.
6. Verify protection is recalculated after market reopens.

## PP-006 — BUY/SELL symmetry

Run PP-001 for both directions.

BUY pass condition:
- final BE/protective SL is at or above the required BE threshold and never below the previous accepted SL.

SELL pass condition:
- final BE/protective SL is at or below the required BE threshold and never above the previous accepted SL.

## PP-007 — hedging/netting behavior

Where both account modes are deployment targets:

- repeat partial-protection test on a hedging account;
- repeat on a netting account;
- verify reduction mechanism is correct for each account model;
- verify `POSITION_IDENTIFIER` remains the durable lifecycle key;
- verify ticket changes do not duplicate TP1 partial or erase failure state.

## PP-008 — stressed spread

1. Repeat TP1 transition during deliberately wider spread conditions on demo.
2. Verify cost-aware BE buffer adapts or defers.
3. Verify existing stronger SL is never moved backward merely to satisfy the new cost estimate.
4. Verify eventual protection uses current spread/slippage inputs.

## Release pass criteria

All applicable HIGH-priority partial-protection variants must satisfy every item below:

- exactly one TP1 partial;
- no stop regression;
- no duplicate order or reduction after timer retries;
- no duplicate partial after restart;
- existing SL remains broker-visible throughout non-critical BE delay;
- `PARTIAL_PROTECTION_STARTED` is observable;
- broker failure class/action is observable when BE fails;
- hazard is emitted once after configured threshold;
- new approvals/executions are blocked while hazard remains unresolved;
- existing live position continues to be managed;
- retry timing respects broker-specific policy;
- recovery uses fresh price, current stop/freeze distance and tick size;
- `TP1DONE=1` only after configured TP1 action and protection state are complete;
- all events join to the same `POSITION_IDENTIFIER`;
- manual/operator-required pause is never silently cleared.

## Mandatory variants

At minimum run:

- BUY;
- SELL;
- hedging account if supported;
- netting account if supported;
- normal spread;
- stressed spread;
- stop-level rejection;
- freeze-level rejection;
- requote/price-changed condition;
- disconnect/reconnect;
- market-close/reopen where applicable;
- terminal restart while `TP1PARTIAL=1` and `TP1DONE=0`.

## Evidence to archive

For each run retain:

- pre-TP1 screenshot;
- post-partial/pre-BE screenshot;
- final protected-position screenshot;
- broker order/deal history;
- Experts/Journal log excerpts;
- `GPT_EA_StopFailures.csv` rows;
- matching `GPT_EA_Execution.csv` rows;
- input `.set` file;
- broker symbol profile;
- Git commit SHA;
- MT5 build;
- PASS/FAIL result and notes.

## Live release rule

A live release fails this gate if any applicable variant can:

- duplicate the TP1 partial;
- loosen/remove the existing SL;
- lose partial-protection state across restart;
- authorize new exposure after the configured partial-protection hazard is active;
- retry using stale market geometry;
- fail to emit auditable partial-protection and broker-failure events.
