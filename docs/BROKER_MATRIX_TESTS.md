<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `BROKER_MATRIX_TESTS.md`

---

# GPT_EA Broker Matrix Test Cases

This matrix is designed to validate broker-agnostic behavior. It does not assume that any broker uses one fixed symbol name, leverage level or execution policy.

For each intended broker/account type, record the actual terminal values and mark PASS/FAIL.

## Test record header

Record for every test run:

- Git commit SHA
- MT5 terminal build
- broker company
- trade server
- account type: demo/contest/real
- account currency
- account leverage
- account margin mode
- hedging allowed
- FIFO-close flag
- timestamp/server timezone

## Matrix A — Symbol naming and resolution

| Case | Requested logical symbol | Example broker presentation | Expected result |
|---|---|---|---|
| A1 | `EURUSD` | `EURUSD` | Exact match |
| A2 | `EURUSD` | `EURUSDm` | Suffix match |
| A3 | `EURUSD` | `EURUSD.a` | Suffix match |
| A4 | `EURUSD` | `EURUSD#` | Suffix match |
| A5 | `XAUUSD` | `GOLD` | Metal alias resolution |
| A6 | `XAUUSD` | `XAUUSDm` | Metal + suffix resolution |
| A7 | `US100` | `NAS100` | Index alias resolution |
| A8 | `US100` | `USTEC` | Index alias resolution |
| A9 | `GER40` | `DE40` | Index alias resolution |
| A10 | `GER40` | `DAX40` | Index alias resolution |
| A11 | `WTI` | `USOIL` | Energy alias resolution |
| A12 | `BRENT` | `UKOIL` | Energy alias resolution |
| A13 | `BTCUSD` | broker crypto suffix | Crypto canonical match where identifiable |
| A14 | proprietary stock CFD | exact broker symbol | Exact broker-name support |
| A15 | nonexistent symbol | no matching instrument | Fail safely; no order |
| A16 | `AUTO` | mixed Market Watch catalogue | Resolve available configured universe only |

Pass criteria:
- no ambiguous symbol silently maps to a materially different instrument;
- resolved symbol is selected and trade properties are readable;
- unavailable instruments do not generate APPROVE-ready setups.

## Matrix B — Account accounting mode

| Case | Margin/accounting mode | Required checks |
|---|---|---|
| B1 | Retail hedging | Partial close uses hedging-compatible close; multiple symbol positions handled correctly |
| B2 | Retail netting | Reduction uses netting-safe opposite deal; single position per symbol behavior respected |
| B3 | Exchange/netting | Position management and margin calculations use broker/exchange properties |
| B4 | Netting reversal | Reversal preserving `POSITION_IDENTIFIER` triggers safety pause/review |

## Matrix C — Execution and filling modes

| Case | Broker execution/filling capability | Expected behavior |
|---|---|---|
| C1 | Market Execution + FOK | FOK-compatible request passes |
| C2 | Market Execution + IOC | IOC-compatible request passes |
| C3 | Market Execution without valid FOK/IOC | New order blocked |
| C4 | Instant Execution | Allowed policy chosen; `OrderCheck()` passes before send |
| C5 | Request Execution | RETURN may be used where permitted |
| C6 | Exchange Execution | Exchange-compatible filling behavior |
| C7 | Invalid/changed filling mode | `OrderCheck()`/broker gate blocks execution |

## Matrix D — Trade-mode restrictions

| Case | Symbol trade mode | Expected behavior |
|---|---|---|
| D1 | FULL | Direction allowed subject to other gates |
| D2 | LONGONLY | SELL setup blocked |
| D3 | SHORTONLY | BUY setup blocked |
| D4 | CLOSEONLY | New entries blocked; existing positions still manageable |
| D5 | DISABLED | New entries blocked |

## Matrix E — Order capability flags

| Case | `SYMBOL_ORDER_MODE` | Expected behavior |
|---|---|---|
| E1 | Market + SL + TP | Normal operation |
| E2 | Market allowed, SL not allowed | Release gate blocks new trade |
| E3 | SL allowed, market not allowed | Release gate blocks market-entry strategy |
| E4 | TP not allowed but SL allowed | Validate policy before enabling this symbol; fixed TP order may fail |

## Matrix F — Spread behavior

Test every main asset class under both normal and stressed spread conditions.

| Case | Spread pattern | Expected behavior |
|---|---|---|
| F1 | Tight floating spread | Normal dynamic slippage/R:R |
| F2 | Wide floating spread | Effective R:R deteriorates; block if below minimum |
| F3 | Fixed spread | Correct point conversion and profile reporting |
| F4 | Rollover expansion | No stale approval execution through spread blowout |
| F5 | News expansion | Calendar/spread gates independently block when applicable |

## Matrix G — Price precision and tick size

| Case | Instrument style | Validate |
|---|---|---|
| G1 | 5-digit FX | point/tick normalization |
| G2 | 3-digit JPY FX | SL/TP/lot risk calculations |
| G3 | Gold with 2/3 digit quote | tick-size normalization |
| G4 | Index with integer/0.1 tick | targets align to tradable tick increments |
| G5 | Futures/stock non-decimal tick | all stop modifications normalize to `SYMBOL_TRADE_TICK_SIZE` |

## Matrix H — Stop/freeze distances

| Case | Broker property | Expected behavior |
|---|---|---|
| H1 | stop level = 0 | normal protective modification |
| H2 | large stop level | invalid close-to-price SL rejected/retried |
| H3 | nonzero freeze level | BE/trailing waits rather than forcing invalid modification |
| H4 | stop/freeze changes intraday | each modification uses current broker values |

Advanced-stop pass criteria:
- stop never loosens;
- TP1 partial is not duplicated while BE waits for a valid distance;
- trailing retries only after meaningful improvement;
- no modification loop floods broker/journal.

## Matrix I — Volume rules

| Case | Volume specification | Expected behavior |
|---|---|---|
| I1 | 0.01 min / 0.01 step | standard normalization |
| I2 | 0.10 min / 0.10 step | calculated volume rounded down safely |
| I3 | unusual 0.25 step | no invalid volume request |
| I4 | tight max volume | proposal above max blocked |
| I5 | directional volume limit | existing same-direction exposure counted |
| I6 | tiny remaining position after partial | avoid invalid sub-minimum partial-close volume |

## Matrix J — Leverage and margin

Run the same planned risk setup across multiple account leverages where the broker offers them.

| Case | Example leverage | Validate |
|---|---|---|
| J1 | 1:30 | `OrderCalcMargin`, free-margin cap, `OrderCheck()` |
| J2 | 1:50 | same |
| J3 | 1:100 | same |
| J4 | 1:500 | same |
| J5 | symbol-specific CFD margin | do not assume account leverage alone determines requirement |
| J6 | hedged margin | existing opposite exposure handled by broker calculation |

Pass criteria:
- risk sizing still derives from SL loss via `OrderCalcProfit()`;
- margin authorization derives from broker/MT5 calculations;
- projected margin-level floor blocks unsafe entry.

## Matrix K — Account currency

Run where available:

- USD
- EUR
- GBP
- JPY
- NGN or another non-quote account currency

Validate that `OrderCalcProfit()` and `OrderCalcMargin()` results are interpreted in account currency and that analytics labels do not assume USD.

## Matrix L — Market-data readiness

| Case | Market data state | Expected result |
|---|---|---|
| L1 | all six timeframes synchronized | release gate may pass |
| L2 | newly selected symbol with unsynced D1 | new entries blocked |
| L3 | insufficient M5 history | new entries blocked |
| L4 | stale last tick | new entries blocked |
| L5 | reconnect then fresh tick/history | transient block auto-clears |

## Matrix M — Recovery on broker/account changes

| Case | Change | Expected behavior |
|---|---|---|
| M1 | terminal restart, same account/server | state reconciles |
| M2 | VPS restart after TP1 partial | no second TP1 partial |
| M3 | restart while BE modification was freeze-blocked | partial state preserved; BE retried |
| M4 | position ticket changes, same identifier | management migrates to current ticket |
| M5 | broker suffix changes after server migration | symbol re-resolves, stale setup revalidated |
| M6 | different account login | old checkpoint ignored |
| M7 | different server with mismatch rejection | old checkpoint ignored |
| M8 | truncated primary checkpoint | completed `.bak` restored if valid |
| M9 | both primary/backup invalid | broker history/globals used; safety block if invariants cannot be satisfied |

## Matrix N — Advanced SL / BE / trailing

For both BUY and SELL test positions:

1. Before 1R: original SL remains unchanged.
2. At `InpBETriggerR`: TP1 partial occurs once and cost-aware BE is requested.
3. If BE modification is broker-freeze blocked: partial remains recorded; BE retries without another partial.
4. At `InpProfitLockTriggerR`: stop locks `InpProfitLockR` when broker-valid.
5. At `InpStrongLockTriggerR`: stop locks `InpStrongLockR`.
6. At/after `InpTrailStartR`: ATR + M5 structure trailing begins.
7. Trail advances only by at least `InpTrailMinStepR` for trail-stage changes.
8. BUY stop never decreases; SELL stop never increases.
9. TP2 partial executes once using the remaining volume.
10. TP3 remains attached by default while trailing.
11. With `InpKeepTP3WhileTrailing=false`, trail manages the runner without fixed TP3 after the first successful trailing modification.
12. Restart at every stage reconstructs a safe stage from current broker SL and state.

## Matrix O — Real-account release block

Use a real account only after all non-live tests are complete.

- live arm phrase blank → BLOCK;
- incorrect live arm phrase → BLOCK;
- correct local arm phrase + approval disabled while required → BLOCK;
- correct arm + approval enabled + all other gates pass → eligible for approval;
- disconnect/stale quote/recovery fault after arming → BLOCK again.

The arm phrase is not a bypass. Every other gate remains active.

## Required release evidence

For each production broker/account combination archive:

- completed matrix rows relevant to that broker;
- terminal screenshots/log excerpts for broker profile and release gate;
- `.set` input preset;
- compiled `.ex5`;
- source commit SHA;
- MetaTrader build;
- sample execution journal;
- restart test result;
- one TP1→BE→lock→trail demo lifecycle.
