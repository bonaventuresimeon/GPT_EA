# GPT_EA Partial-Protection Release Test

This is a **release-blocking** test. It validates the state where TP1 partial profit is already taken but breakeven/profit protection has not yet been secured.

## Required scenario

1. Open a demo trade with a valid initial SL.
2. Drive/replay price to TP1.
3. Confirm the TP1 partial close succeeds.
4. Force the subsequent BE modification to fail temporarily using a broker freeze/stops condition, market closure, stale quote/requote, or a controlled test harness.
5. Verify `TP1PARTIAL=1` while `TP1DONE=0`.
6. Verify the original/current protective SL remains on the broker position and is never loosened.
7. Keep the BE failure unresolved beyond `InpPartialProtectionMaxSeconds`.
8. Verify `PartialProtectionHazardActive()` becomes true.
9. Verify **new approvals/executions are blocked** when `InpBlockNewEntriesOnPartialProtection=true`.
10. Verify the existing position continues to be managed and BE repair keeps retrying under the broker-specific retry policy.
11. Remove the temporary broker restriction.
12. Verify BE succeeds without taking the TP1 partial a second time.
13. Verify `TP1DONE=1`, the stop-failure state clears, and the position can advance to profit-lock/trailing stages.
14. Verify the global safety pause is not silently removed if it was escalated to a manual/operator-required pause.

## Pass criteria

- exactly one TP1 partial;
- no stop regression;
- no duplicate order/partial after restart or retry;
- pending/new entries blocked after the configured hazard timeout;
- live position still managed;
- BE repair uses fresh price, stop/freeze level and tick size;
- recovery works after terminal restart in the middle of the partial-protection state;
- observability CSV identifies the position, broker, failure class and partial-protection flags;
- once protection succeeds, `TP1DONE` becomes durable and restart-safe.

## Mandatory variants

Run this test for:

- BUY and SELL;
- hedging and netting accounts where applicable;
- normal spread and stressed spread;
- broker stop-level rejection;
- freeze-level rejection;
- requote/price-changed failure;
- disconnect/reconnect;
- terminal restart while `TP1PARTIAL=1` and `TP1DONE=0`.

A live release fails this gate if any applicable variant can duplicate the partial, loosen/remove the existing SL, authorize new exposure while the hazard remains unresolved, or lose the state across restart.
