# GPT_EA Stop-Management Test Matrix

This matrix is a release-blocking test suite for the advanced stop-management engine.

A live release should not be armed until all applicable HIGH-priority tests pass on the intended broker/account type.

## Test conventions

- Run on demo first.
- Test both BUY and SELL wherever direction matters.
- Repeat on at least one hedging account and one netting account if both are intended deployment targets.
- Record broker, server, account type, symbol, contract specification, spread, stop level, freeze level, MT5 build, EA commit SHA and input preset.
- Verify actual broker position SL after every expected stop transition; stored state alone is not sufficient evidence.

## Matrix

| ID | Priority | Scenario | Setup | Expected behavior | Pass criteria |
|---|---|---|---|---|---|
| SM-001 | HIGH | Initial BUY SL | Open BUY with valid structural SL | Original SL attached | Broker position shows intended normalized SL |
| SM-002 | HIGH | Initial SELL SL | Open SELL with valid structural SL | Original SL attached | Broker position shows intended normalized SL |
| SM-003 | HIGH | BUY BE at TP1 | Price reaches TP1 / BE trigger | TP1 partial once, then cost-aware BE | No duplicate partial; SL >= entry and broker-valid |
| SM-004 | HIGH | SELL BE at TP1 | Price reaches TP1 / BE trigger | TP1 partial once, then cost-aware BE | No duplicate partial; SL <= entry and broker-valid |
| SM-005 | HIGH | TP1 partial succeeds, BE fails | Force stop/freeze-distance rejection | Partial remains completed; BE retries | `TP1PARTIAL=1`, `TP1DONE=0` until protection succeeds |
| SM-006 | HIGH | BE retry succeeds | Remove temporary broker-distance condition | BE applied on later cycle | Failure counter clears; no second TP1 partial |
| SM-007 | HIGH | BUY profit lock | Reach `InpProfitLockTriggerR` | Lock configured positive R | SL advances, never regresses |
| SM-008 | HIGH | SELL profit lock | Reach `InpProfitLockTriggerR` | Lock configured positive R | SL advances, never regresses |
| SM-009 | HIGH | BUY strong lock | Reach `InpStrongLockTriggerR` | Stronger R lock applied | Actual SL >= required lock level |
| SM-010 | HIGH | SELL strong lock | Reach `InpStrongLockTriggerR` | Stronger R lock applied | Actual SL <= required lock level |
| SM-011 | HIGH | ATR/structure trail BUY | Reach trail start with valid M5 structure | Trail advances only upward | Each accepted SL >= previous SL |
| SM-012 | HIGH | ATR/structure trail SELL | Reach trail start with valid M5 structure | Trail advances only downward | Each accepted SL <= previous SL |
| SM-013 | HIGH | Tiny trail improvement | Candidate smaller than minimum step | No modification | No failure count; current SL unchanged |
| SM-014 | HIGH | Trail candidate worse than current BUY SL | Force lower candidate | Reject no-op | BUY SL never decreases |
| SM-015 | HIGH | Trail candidate worse than current SELL SL | Force higher candidate | Reject no-op | SELL SL never increases |
| SM-016 | HIGH | Broker stop-level block | Set/observe large stop distance | Keep current SL, retry later | No regression or invalid modification |
| SM-017 | HIGH | Broker freeze-level block | Trigger modification inside freeze zone | Keep current SL, retry later | No duplicate partial; retry resumes after freeze clears |
| SM-018 | HIGH | PositionModify transient failure | Simulate/reproduce server rejection | Failure counted, current SL retained | `STOP_FAIL_COUNT` increments; existing SL unchanged |
| SM-019 | HIGH | Warning escalation | Cause repeated failures to warning threshold | Alert/log once at threshold | Warning generated and trade remains managed |
| SM-020 | HIGH | Pause escalation | Cause repeated failures to pause threshold | New entries paused | Existing trade still managed; new approvals blocked |
| SM-021 | HIGH | Recovery after failures | Allow next stop update to succeed | Failure state clears | `STOP_FAIL_COUNT=0`, recovery event logged |
| SM-022 | HIGH | Missing SL after restart | Remove/produce SL=0 and restart | Restore original SL from durable state/history | Protection restored without weakening geometry |
| SM-023 | HIGH | Missing SL cannot be restored | SL=0, broker rejects restoration | Immediate critical state and pause | No new trades; critical event recorded |
| SM-024 | HIGH | Emergency close unprotected | Leave SL=0 beyond emergency timeout | Attempt market close | Close sent after configured timeout |
| SM-025 | HIGH | Emergency close fails | Market closed/server rejects close | Remain paused; retry later | EA never resumes new entries automatically |
| SM-026 | HIGH | Restart after BE | Restart with BE already set | Reconstruct stage >= BE | Stronger SL preserved; no move back to initial SL |
| SM-027 | HIGH | Restart after profit lock | Restart with +R lock | Reconstruct correct stage | No SL regression after restart |
| SM-028 | HIGH | Restart during failed BE retries | Failure state active then restart | Resume retry policy | Partial not duplicated; timestamps/counters persist where available |
| SM-029 | HIGH | Ticket changes after partial | Netting/position lifecycle changes ticket | Re-resolve by position identifier | Management continues on current broker ticket |
| SM-030 | HIGH | TP2 partial idempotency | Reach TP2 multiple timer cycles | Scale out once only | `TP2PARTIAL=1`; no duplicate scale-out |
| SM-031 | HIGH | Runner mode | `InpKeepTP3WhileTrailing=false` | Remove TP only after trail stage begins | TP remains through BE/locks; removed at actual trail |
| SM-032 | HIGH | Fixed TP3 mode | `InpKeepTP3WhileTrailing=true` | Keep TP3 during trailing | Position retains TP3 while SL trails |
| SM-033 | HIGH | Gap beyond BE/profit-lock level | Create fast/gap movement | Recalculate with current price | No invalid/stale stop replay |
| SM-034 | HIGH | Gap makes original missing SL invalid | SL missing and original SL now wrong side/inside limits | Critical policy | No forced invalid SL; pause/emergency handling active |
| SM-035 | HIGH | Stale quote | Prevent/freeze fresh ticks | Do not calculate new stop from stale data | No unsafe modification; retry after quote refresh |
| SM-036 | HIGH | Spread explosion at BE | Widen spread sharply | Cost-aware BE adapts or defers | Never moves existing stronger SL backward |
| SM-037 | HIGH | Market closed | Stop update expected outside trading session | Update fails safely | Existing SL retained; failure/retry policy active |
| SM-038 | HIGH | Hedging partial close | Hedging account TP1 | Use partial-close path | Correct residual volume and one partial only |
| SM-039 | HIGH | Netting partial reduction | Netting account TP1 | Opposite deal reduces volume | Position identifier recovery remains coherent |
| SM-040 | HIGH | Netting reversal inconsistency | Reverse test position manually | Recovery safety catches reversal | EA pauses rather than applying stale stop state |
| SM-041 | MED | Zero TP1 partial | `InpPartialAtTP1Percent=0` | No scale-out; BE logic still valid | No volume change; stop stages function |
| SM-042 | MED | 100% TP1 exit | TP1 partial configured 100% | Position closes fully | No later BE/trail attempts on closed position |
| SM-043 | MED | Zero TP2 partial | `InpPartialAtTP2Percent=0` | No TP2 scale-out | Stop management continues |
| SM-044 | MED | 100% TP2 exit | TP2 partial configured 100% | Close remainder | No subsequent trail on closed position |
| SM-045 | MED | Invalid stop configuration | Misorder R triggers/locks | Release gate blocks new trades | Clear configuration reason displayed |
| SM-046 | MED | Very small tick-size symbol | Fine pricing increment | Normalize to tick size | No invalid-price retcodes |
| SM-047 | MED | Coarse tick-size CFD | Large tick increment | Normalize correctly | Stop accepted or safely deferred |
| SM-048 | MED | High stop/freeze index CFD | Large broker distance | Retry/defer policy | No stop regression |
| SM-049 | MED | Crypto weekend symbol | Weekend trading enabled | Normal stop lifecycle | No FX-session assumptions break protection |
| SM-050 | MED | Symbol suffix migration | Same instrument with different broker suffix | Resolve current broker symbol | Recovery/management follows actual symbol |
| SM-051 | MED | Multiple positions | Multiple GPT_EA symbols active | Independent stop state per position ID | No cross-position state contamination |
| SM-052 | MED | Same symbol hedging positions | If allowed/configured | Correct ticket/identifier isolation | One position's SL does not alter another |
| SM-053 | MED | Manual stronger SL | Operator tightens SL manually | EA must preserve stronger protection | No later automated weakening |
| SM-054 | MED | Manual TP removal | Operator removes TP while trailing | Respect configured runner/TP policy on next valid update | No SL regression |
| SM-055 | MED | Reconnect after outage | Disconnect during stop trigger, reconnect later | Fresh recalculation and retry | No stale request replay |
| SM-056 | MED | Requote/price changed | Broker price changes during modify | Retry later from fresh market data | Current SL retained |
| SM-057 | MED | Failure counter isolation | One symbol repeatedly fails | Other positions unaffected | Failure state keyed by `POSITION_IDENTIFIER` |
| SM-058 | MED | Pause persists after recovery | Stop later succeeds after pause threshold | Per-position failures clear, global pause remains | Manual resume required |
| SM-059 | MED | Alert throttling | Repeated failures | Alert at defined escalation points | No alert storm every timer tick |
| SM-060 | MED | Analytics audit | Complete full lifecycle | Events recorded in order | Stop and failure events match broker history |

## Required release sequences

### Sequence A — normal BUY lifecycle

1. Open BUY with structural SL.
2. Reach TP1.
3. Verify one TP1 partial.
4. Verify BE + cost buffer.
5. Reach profit-lock threshold.
6. Verify +R lock.
7. Reach strong-lock threshold.
8. Verify stronger +R lock.
9. Enter trailing phase.
10. Verify monotonic BUY trailing.
11. Reach TP2 and verify one TP2 partial.
12. Finish at TP3/trailing exit/stall exit.
13. Verify journal and final analytics.

### Sequence B — normal SELL lifecycle

Repeat Sequence A with inverse price geometry.

### Sequence C — broker-distance failure

1. Reach TP1.
2. Force BE inside freeze/stop distance.
3. Verify TP1 partial occurs once.
4. Verify BE remains pending.
5. Verify failure/retry state.
6. Clear distance restriction.
7. Verify BE succeeds without duplicate partial.
8. Verify failure counters clear.

### Sequence D — critical missing-SL recovery

1. Start with open GPT_EA position.
2. Produce/reproduce SL=0 in controlled demo test.
3. Verify immediate restoration attempt.
4. If restoration is deliberately prevented, verify safety pause.
5. Wait beyond emergency timeout.
6. Verify emergency close attempt.
7. If close is rejected, verify pause persists and retries continue.

### Sequence E — restart durability

Perform terminal restart separately at:

- before TP1;
- immediately after TP1 partial but before BE success;
- after BE;
- after profit lock;
- after strong lock;
- during trailing;
- after TP2 partial;
- while a stop-update failure counter is active.

At every point verify:

- no duplicate partial;
- no weaker SL restored;
- current broker position remains the source of truth;
- position lifecycle follows `POSITION_IDENTIFIER`;
- analytics finalization remains idempotent.

## Failure-policy acceptance criteria

A release passes only if all of the following are true:

- failed stop modifications never weaken an existing SL;
- failure to improve protection never causes duplicate partials;
- unprotected positions immediately block new risk;
- repeated non-critical failures escalate without abandoning the live position;
- emergency handling activates only for genuinely unprotected positions after the configured timeout;
- successful recovery clears position-level failure state;
- safety pauses are not silently auto-cleared;
- restarts do not reset protection to an earlier stage;
- BUY and SELL behavior is symmetric;
- broker stop/freeze/tick-size rules are respected.

## Evidence to archive

For each HIGH-priority case retain:

- screenshot before trigger;
- screenshot after expected stop action;
- Experts log excerpt;
- broker position/order/deal history;
- `GPT_EA_Execution.csv` rows;
- input preset;
- broker symbol profile;
- commit SHA;
- MetaTrader build number;
- pass/fail and notes.
