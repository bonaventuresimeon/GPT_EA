# GPT_EA Demo-Soak Acceptance Contract

This contract is **release blocking**. A demo soak is not considered passed merely because the EA stayed attached without crashing.

## 1. Minimum coverage

The candidate build must run on the intended broker/account type using the exact release `.ex5` and `.set` preset for at least:

- **5 consecutive trading days**;
- coverage of London session and New York/U.S. cash session on at least 3 of those days;
- at least one London/New York overlap;
- at least one broker rollover/spread-expansion window;
- at least one high-impact scheduled-news day relevant to a configured symbol;
- at least one terminal/VPS restart;
- at least one disconnect/reconnect event, naturally occurring or controlled;
- at least one forced manual SCAN NOW cycle and normal scheduled/continuous scans.

If the intended deployment trades weekend-enabled instruments, include at least one weekend session for those instruments.

## 2. Instrument/account coverage

Use the intended broker naming/specification and validate the configured portfolio, normally including the selected release symbols such as XAUUSD, US100 and GER40 where offered.

Record:

- broker company/server;
- demo account margin mode;
- account currency/leverage;
- actual resolved symbol names;
- tick size, contract size, volume step, stops/freeze levels and execution mode;
- spread observations in normal and stressed conditions.

## 3. Mandatory operational observations

The soak must demonstrate all applicable behaviors without forcing artificial trades solely to increase sample count:

- scans continue across all configured symbols;
- HIGH-CONFIDENCE, WAIT/REANALYZE and NO-TRADE states can all occur without forcing execution;
- pending approvals expire safely;
- approval revalidation blocks stale/changed setups;
- news/intermarket failures follow configured fail-open/fail-closed policy;
- release/risk gates never become bypassed because of a timer, restart or reconnect;
- existing positions continue to be protected when new entries are blocked;
- checkpoint and `.bak` recovery files continue to update;
- execution, intelligence, stop-failure and release-evidence logs remain writable and internally consistent.

## 4. Position-management evidence

Across the full release test campaign, including controlled matrix tests plus soak, archive evidence for at least one complete BUY and one complete SELL lifecycle where market conditions permit:

`initial SL → TP1 partial → BE → profit lock → strong lock → trailing/TP3 or managed exit`.

The soak itself must not manufacture unsafe market orders just to satisfy this requirement. If natural setups do not produce every stage during the 5-day soak, use the already required controlled demo stop-management tests and reference those artifacts in the soak report.

## 5. Zero-tolerance failures

The soak immediately FAILS for any of the following:

- duplicate market order caused by one authorization;
- duplicate TP1 or TP2 partial exit;
- BUY SL moves backward or SELL SL moves backward because of EA logic;
- valid broker-held SL is unintentionally removed;
- an unprotected GPT_EA position coexists with newly authorized risk;
- a real-account order is possible without full release certification;
- recovery creates a position that does not actually exist at the broker;
- stale pending approval executes after restart without fresh validation;
- netting reversal receives stale pre-reversal management state;
- analytics finalizes the same position lifecycle twice;
- stop/recovery critical error is silently auto-cleared without policy authorization;
- release/dashboard reports PASS while the certified gate is BLOCKED;
- uncaught initialization/runtime loop prevents normal position protection;
- unexplained array/divide/indicator-handle runtime errors;
- API key or other secret appears in logs/source artifacts.

## 6. End-of-soak unresolved-state rule

At the end of the soak there must be **zero unexplained critical release blockers**.

The following must be either clear or explicitly reconciled and archived:

- no `SL=0` GPT_EA position;
- no unresolved `STOP_FAIL_CRITICAL` state;
- no unresolved operator-required stop-failure class;
- no stale partial-protection hazard;
- no duplicate pending approval;
- no corrupt/unreadable recovery checkpoint without a valid fallback;
- no unexplained `OrderCheck`/broker execution rejection loop;
- no repeated WebRequest/OpenAI failure loop that violates configured policy;
- no release-evidence mismatch on the candidate environment.

A deliberately induced safety pause may remain paused, but its cause, recovery and operator decision must be documented before release.

## 7. Stability/quality thresholds

The candidate should meet all of the following during the soak:

- no EA crash or uncontrolled reinitialization loop;
- no runaway duplicate log/alert storm;
- no more than one expected scan action per configured scheduling trigger/new-M5-bar event;
- broker-specific stop retry obeys its configured backoff;
- no repeated emergency close request faster than policy permits;
- no unexplained orphaned pending state after reconnect/restart;
- no unexplained discrepancy between broker history and `GPT_EA_Execution.csv` lifecycle identity;
- every observed material stop failure is joinable to `GPT_EA_StopFailures.csv` by `POSITION_IDENTIFIER`;
- every release-evidence snapshot clearly reports PASS/BLOCK and reason.

## 8. Performance is observed, not guaranteed

The soak should record win rate, realized R, MAE/MFE, slippage, spread, strategy class and session, but **profitability is not itself the release acceptance criterion** for a 5-day engineering soak.

A build does not fail solely because demo P/L is negative over a small sample, and it does not pass solely because P/L is positive. Strategy-edge decisions require the separate historical/walk-forward/forward-performance evidence defined by the strategy analytics contracts.

## 9. Required archived evidence

Archive together:

- exact Git commit SHA;
- `.ex5` SHA-256;
- `.set` SHA-256;
- MetaTrader/MetaEditor builds;
- broker/server/account profile;
- soak start/end timestamps;
- terminal uptime/restart notes;
- Experts and Journal logs;
- `GPT_EA_Execution.csv`;
- `GPT_EA_StopFailures.csv`;
- intelligence/news observations;
- `GPT_EA_ReleaseEvidence.csv`;
- checkpoint and `.bak` samples;
- screenshots or trade-history exports for material lifecycle/failure events;
- list of all unresolved warnings/issues, which must be empty for critical blockers.

## 10. PASS decision

`InpReleaseDemoSoakPassed=true` may be set only when:

1. minimum session/time/event coverage is complete;
2. all zero-tolerance rules pass;
3. no unexplained critical state remains;
4. required observability/recovery files are internally consistent;
5. exact release artifacts are identified and archived;
6. a human operator reviews and signs the soak report.

Any executable source change after the soak invalidates the soak certification for that build and requires a new candidate artifact plus revalidation appropriate to the change.