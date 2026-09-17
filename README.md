# GPT_EA

Standalone MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe analysis, advanced confluence, OpenAI secondary review, broker-aware execution, portfolio risk controls, restart recovery, setup analytics, timed **APPROVE / DENY** authorization, release-blocking safety gates, and advanced protective-stop management.

Repository: https://github.com/bonaventuresimeon/GPT_EA.git

## Clone

```bash
git clone https://github.com/bonaventuresimeon/GPT_EA.git
cd GPT_EA
```

## Main EA

Compile `GPT_EA.mq5` in MetaEditor. The entry file includes only local files from this repository:

- `GPT_EA_Part01.mqh` — inputs, OpenAI client and core types
- `GPT_EA_Part02.mqh` — indicators, multi-timeframe scoring and London/New York scheduling
- `GPT_EA_Part03.mqh` — ATR/opening-range adaptation, calendar, Treasury-yield and spread filters
- `GPT_EA_Part04.mqh` — pullback/breakout-retest construction and equity/balance lot sizing
- `GPT_EA_Part08_Advanced.mqh` — advanced confluence, dashboard and trade-level map
- `GPT_EA_Part09_RiskRecoveryAnalytics.mqh` — portfolio risk, setup analytics, DOM, regime logic, journaling and optional ONNX
- `GPT_EA_Part10_BrokerUniversalRecovery.mqh` — broker/symbol abstraction, contract/margin discovery and disk-backed restart recovery
- `GPT_EA_Part11_PreflightRecoveryGuard.mqh` — MT5 `OrderCheck()` preflight, completed checkpoint backups and netting-reversal safety
- `GPT_EA_Part12_SafetyStopManagement.mqh` — release-blocking gates, executable recovery invariants and advanced SL/BE/trailing helpers
- `GPT_EA_Part05.mqh` — signal-card formatting and final broker/release-gated execution
- `GPT_EA_Part06.mqh` — legacy management helpers and approval UI
- `GPT_EA_Part13_AdvancedPositionManager.mqh` — idempotent TP1/TP2 partials, BE, profit locks, trailing and stale-trade management
- `GPT_EA_Part07.mqh` — approval workflow, scanner lifecycle and MT5 event hooks

Release/test documents:

- `COMPILE_TEST_CHECKLIST.md` — MetaEditor, broker, recovery, demo-soak and live release checklist
- `BROKER_MATRIX_TESTS.md` — cross-broker/account/symbol/execution/recovery test matrix
- `RECOVERY_INVARIANTS.md` — formal state invariants that must hold before new authorization
- `RELEASE_SAFETY_GATES.md` — hard release blockers and enforcement points
- `ANALYTICS_SCHEMA.md` — versioned execution, setup-statistics, recovery and broker-profile data contract

## Broker-agnostic symbol support

GPT_EA adapts to the connected MT5 broker instead of assuming one naming convention, spread, leverage or contract specification.

At startup it resolves configured logical names against symbols actually offered by the terminal. Common aliases are recognized for FX, metals, major indices, energy and crypto, including names such as `XAUUSD/GOLD`, `US100/NAS100/USTEC`, `GER40/DE40/DAX40`, `WTI/USOIL` and `BRENT/UKOIL`. Prefixes and suffixes such as `.cash`, `.a`, `m`, `#` and broker-specific variants can be matched where the underlying instrument can be identified.

For proprietary instruments not covered by an alias, use the broker's actual MT5 symbol name directly. The EA relies primarily on the symbol properties exposed by the connected terminal rather than a fixed broker list.

`InpSymbols` can contain normal requested instruments. `AUTO`/`ALL` can resolve the configurable major-instrument universe, and `InpUseMarketWatchUniverse=true` can add selected Market Watch instruments up to the configured cap.

## Runtime broker and contract discovery

For each resolved instrument GPT_EA can inspect and report:

- broker company and trade server
- account currency, account leverage and margin mode
- symbol trade mode, execution mode and filling-policy flags
- symbol description/path and normalized asset class
- base, profit and margin currencies
- digits, point and tick size
- profit/loss tick values
- contract size
- minimum, maximum, step and directional-limit volume
- fixed/floating spread and live Bid/Ask spread
- minimum stop level and freeze level
- symbol calculation mode
- buy/sell one-lot margin estimate
- initial/maintenance margin rates where supplied by the broker

Account leverage is environment information only. GPT_EA does not assume one universal `notional ÷ leverage` formula; risk uses `OrderCalcProfit()` and authorization uses MT5/broker margin calculations.

## Broker and server execution gates

Before APPROVE can become ready, and again immediately before order send, GPT_EA checks:

- account, terminal and EA trading permission
- disabled / close-only / long-only / short-only symbol states
- market-order and protective-SL capability
- minimum/maximum/step/directional volume rules
- current stop/freeze distance
- tick-size-normalized SL/TP
- free margin and configured free-margin usage cap
- supported filling policy
- `OrderCalcMargin()` result
- complete MT5 `OrderCheck()` result
- projected free margin and configurable post-trade margin-level floor

The same request must still pass after the user clicks APPROVE; approval is authorization, not a bypass.

## Release-blocking safety gates

`GPT_EA_Part12_SafetyStopManagement.mqh` adds a higher-level release gate on top of normal trading filters. A release blocker prevents **new positions** while existing GPT_EA positions continue to be managed.

Default blockers include:

- disconnected terminal
- terminal/EA/account trading permission failure
- required D1/H4/H1/M30/M15/M5 history not synchronized
- insufficient required bars
- stale quote beyond `InpMaxQuoteAgeSeconds`
- broker does not support market orders or protective SL
- recovery invariant failure
- real account not explicitly armed
- real account with approval disabled when approval is required

On real accounts, with `InpBlockRealUnlessExplicitlyArmed=true`, execution remains blocked until the user deliberately enters the local arm phrase:

`GPT_EA_LIVE_ARMED`

The phrase is deliberately not committed as an armed default. It does not bypass any other gate.

See `RELEASE_SAFETY_GATES.md`.

## Recovery invariants

Before new authorization, recovered state is checked for conditions such as:

- every open GPT_EA position has a valid identifier, entry, volume and protective SL
- original SL is recoverable and remains on the correct original risk side of entry
- open position is not already marked analytics FINAL
- BUY/SELL TP geometry is directional and ordered
- no duplicate active pending approval exists per symbol
- pending approval timestamps/geometry remain valid
- risk-session equity state is valid
- current broker state and durable persistence do not conflict materially

A missing current SL is actively restored from trustworthy durable state/history when possible. If protection cannot be reconstructed, the recovery safety policy can pause new trading.

See `RECOVERY_INVARIANTS.md`.

## Analysis engine

Every scan evaluates **D1 / H4 / H1 / M30 / M15 / M5**. The engine combines EMA20/EMA50 structure, RSI, ATR, higher-timeframe voting, M15/M5 swing structure, ADX/+DI/-DI, volume, rolling VWAP, fair-value gaps, rejection candles, opening-range state, liquidity sweeps, level quality, regime classification and spread/slippage-adjusted R:R.

Breakout-retest can require the stricter **sweep → displacement → retest** sequence. Optional broker DOM and local ONNX remain secondary confirmation layers and cannot override hard risk/release gates.

## Scheduled chart re-checks

Default schedule:

- **08:55 London** — pre-London scan
- **09:00 London** — London-open scan
- hourly through the configured London window
- **09:25 New York** — pre-U.S.-cash-open scan
- **09:30 New York** — U.S. cash open

The U.S. open is anchored to New York local time so UK/U.S. DST transition differences are handled correctly. **SCAN NOW** performs an immediate re-check.

## Economic-event, spread and Treasury-yield invalidation

Before authorization the EA can block for mapped high-impact news, configured moderate events, Treasury-yield shock, opening-range expansion, stale price displacement, spread widening, dynamic R:R deterioration, session invalidation, portfolio risk, cooldown, recovery/release safety, broker execution failure or `OrderCheck()` failure.

## Portfolio and daily risk controls

Configurable protections include:

- maximum total GPT_EA open risk %
- maximum proposed symbol risk %
- maximum correlated directional risk %
- correlated equity-index grouping such as US100/GER40
- block when an existing GPT_EA position has no protective SL
- daily equity-loss kill switch
- equity high-water drawdown kill switch
- consecutive-loss kill switch
- manual **PAUSE TRADING / RESUME TRADING**

Existing positions continue to be managed when new entries are blocked.

## Advanced SL, breakeven and profit-trailing logic

The advanced manager is now the timer-driven position manager. The protection sequence is monotonic: it may tighten risk, never intentionally loosen it.

### Before TP1

- original protective SL remains active;
- if SL disappears after a restart/broker-state issue, the EA attempts to restore the durable original SL when broker-valid;
- if TP1 is not reached inside the adaptive M15 budget, the stale trade can be closed.

### TP1 / breakeven

At TP1:

1. the configured TP1 partial is attempted once;
2. successful partial state is persisted separately as `TP1PARTIAL`;
3. the BE stop uses the larger of the ATR cost buffer or current spread + dynamic-slippage cost;
4. if the broker stop/freeze distance temporarily prevents BE modification, the partial is **not repeated** — BE is retried later;
5. `TP1DONE` is set only when the required partial state and protection state are complete.

### Profit locks

Defaults are configurable:

- at `InpProfitLockTriggerR` (default 1.5R), lock `InpProfitLockR` (default +0.5R);
- at `InpStrongLockTriggerR` (default 2R), lock `InpStrongLockR` (default +1R).

Every stop change is normalized to broker tick size and checked against the current stop/freeze distance.

### TP2 scale-out

At TP2 / 2R, the EA can close `InpPartialAtTP2Percent` of the **remaining** volume. `TP2PARTIAL` makes the operation restart-safe and prevents duplicate reductions.

### ATR + structure trailing

From `InpTrailStartR` (default 2R):

- M5 ATR supplies a volatility trail;
- recent M5 structure supplies a swing-based trail;
- the wider of ATR/structure is used to avoid excessive noise tightening;
- the stop never gives back below the strong-lock floor;
- trail-stage changes require at least `InpTrailMinStepR` improvement;
- BUY SL never moves down; SELL SL never moves up;
- TP3 remains attached by default while trailing; it can be disabled for a pure runner through configuration.

Stop-stage changes are written to the execution journal as `STOP_BREAKEVEN`, `STOP_PROFIT_LOCK`, `STOP_STRONG_LOCK` and `STOP_TRAIL` events.

### Post-TP1 stall exit

The stall timer now starts from TP1 completion rather than original entry. If the remainder stalls near the next M15 barrier and momentum deteriorates / M5 reverses, the remaining position can close early.

## Restart / VPS recovery

Recovery combines:

1. current broker positions and position/deal history;
2. MT5 terminal Global Variables;
3. account/magic-specific Common Files checkpoint;
4. completed validated `.bak` checkpoint.

The checkpoint includes a completed `END` marker. An incomplete/truncated primary snapshot is not promoted to backup. If the primary is invalid and a completed matching backup exists, the backup can be restored before reconciliation.

Recovery handles pending approvals, approval expiry, ticket changes, `POSITION_IDENTIFIER`, original SL, TP state, adaptive expiry, partial-state reconstruction, initial monetary risk, MAE/MFE, analytics finalization guards, day-risk state, pause state, account/server/magic isolation and symbol re-resolution.

### Netting reversal safety

On non-hedging accounts, MT5 can retain the same `POSITION_IDENTIFIER` through a reversal. GPT_EA compares original lifecycle direction with current direction and can PAUSE new trading when they differ instead of applying stale directional management state.

## Trade approval flow

Signal scan → advanced setup comparison → confluence/regime/institutional filters → event/yield/session filters → optional AI review → release-safety gate → portfolio/kill-switch gate → broker contract/margin gate → MT5 `OrderCheck()` → M5 trigger → timed **APPROVE / DENY** → fresh validation → final release/broker/risk validation → order send.

A failing release gate suppresses APPROVE readiness, suppresses queueing, rejects an already-open approval during fresh validation, and rejects final order send.

## Execution journal and analytics

`GPT_EA_Execution.csv` records entry/exit lifecycle data and now also accepts protective-stop stage events. Core fields include server time, event, symbol, setup type, deal, stable position identifier, requested/reference price, actual price, slippage points, R, MAE_R, MFE_R and note.

Persistent performance remains separate for **PULLBACK** and **BREAKOUT-RETEST**.

See `ANALYTICS_SCHEMA.md`.

## Broker matrix validation

`BROKER_MATRIX_TESTS.md` includes explicit cases for:

- exact/prefix/suffix/alias symbol names
- hedging, netting and exchange accounts
- market/request/instant/exchange execution
- FOK/IOC/RETURN filling behavior
- full/long-only/short-only/close-only/disabled trade modes
- market/SL order capability flags
- fixed/floating/widened spreads
- FX/JPY/metals/indices/energy/crypto/stocks/futures tick sizes
- nonzero stop/freeze levels
- unusual volume steps and directional limits
- low/high leverage and symbol-specific margins
- multiple account currencies
- stale/unsynchronized data
- truncated recovery checkpoints
- TP1→BE→profit-lock→trail restart scenarios
- explicit real-account release arming

The matrix must be run on the intended broker/account combination rather than assumed from another broker's demo.

## Optional Depth of Market

DOM confirmation is disabled by default because availability/quality differs by broker and CFD instrument. When enabled, GPT_EA subscribes to the broker market book and can use directional imbalance as an additional confirmation. It cannot override hard gates.

## Optional ONNX model

Native ONNX confirmation is disabled by default. If enabled, the EA expects float input `[1,12]`, float output `[1,1]`, with the output treated as setup-validity probability. ONNX cannot override portfolio limits, broker rules, release safety, R:R, cooldown or approval requirements.

## OpenAI configuration

Enter the API key locally in MT5 inputs and never commit it. Add this endpoint under **Tools → Options → Expert Advisors → Allow WebRequest for listed URL**:

```text
https://api.openai.com
```

OpenAI is a secondary review/veto layer. Broker prices, positions, indicators, spread, calendar and risk calculations come from MT5.

## Compilation and release testing

Use `COMPILE_TEST_CHECKLIST.md`, `BROKER_MATRIX_TESTS.md`, `RECOVERY_INVARIANTS.md` and `RELEASE_SAFETY_GATES.md` together.

Recommended release flow:

**MetaEditor 0-error compile → static/Strategy Tester checks → broker matrix on demo → restart/crash matrix → TP1/BE/lock/trail lifecycle tests → multi-session demo soak → explicit real-account arming → conservative live release with approval required.**

The project should not be treated as production-ready merely because source code is present on GitHub. MetaEditor compilation and broker-specific demo validation are still required.

## Project separation

`GPT_EA` is independent and has no runtime dependency on CelestialNexus or another repository.
