# GPT_EA

Standalone MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe analysis, advanced confluence, OpenAI secondary review, broker-aware execution, portfolio risk controls, restart recovery, setup analytics, and timed **APPROVE / DENY** authorization.

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
- `GPT_EA_Part11_PreflightRecoveryGuard.mqh` — MT5 `OrderCheck()` preflight and netting-reversal recovery safety
- `GPT_EA_Part05.mqh` — signal-card formatting and final broker execution
- `GPT_EA_Part06.mqh` — TP1 partials, breakeven movement, time invalidation and post-TP1 management
- `GPT_EA_Part07.mqh` — approval workflow, scanner lifecycle and MT5 event hooks

Release/test documents:

- `COMPILE_TEST_CHECKLIST.md` — MetaEditor, broker, recovery, demo-soak and live release checklist
- `ANALYTICS_SCHEMA.md` — versioned execution, setup-statistics, recovery and broker-profile data contract

## Broker-agnostic symbol support

GPT_EA is designed to adapt to the connected MT5 broker instead of assuming one naming convention, spread, leverage or contract specification.

At startup it resolves configured logical names against symbols actually offered by the terminal. Common aliases are recognized for FX, metals, major indices, energy and crypto, including names such as `XAUUSD/GOLD`, `US100/NAS100/USTEC`, `GER40/DE40/DAX40`, `WTI/USOIL` and `BRENT/UKOIL`. Prefixes and suffixes such as `.cash`, `.a`, `m`, `#` and broker-specific variants can be matched where the underlying instrument can be identified.

For proprietary instruments not covered by an alias, use the broker's actual MT5 symbol name directly. No EA can truthfully guarantee every proprietary naming scheme in advance, so GPT_EA relies primarily on the symbol properties exposed by the connected terminal rather than a fixed broker list.

`InpSymbols` can contain normal requested instruments. `AUTO`/`ALL` can resolve the configurable major-instrument universe, and `InpUseMarketWatchUniverse=true` can add currently selected Market Watch instruments up to the configured cap.

## Runtime broker and contract discovery

For each resolved instrument GPT_EA can inspect and report the live broker specification, including:

- broker company and trade server
- account currency and account leverage
- account margin mode: netting / exchange / retail hedging
- symbol trade mode and execution mode
- filling-policy flags
- symbol description/path and normalized asset class
- base, profit and margin currencies
- digits and point size
- tick size
- profit/loss tick values
- contract size
- minimum, maximum and step volume
- directional volume limit
- fixed/floating spread flag and current Bid/Ask spread
- minimum stop level and freeze level
- symbol calculation mode
- buy/sell one-lot margin estimate
- initial/maintenance margin rates where supplied by the broker

Account leverage is recorded as environment information, but GPT_EA does **not** assume that a simple `notional ÷ leverage` formula is valid for every CFD/future/stock/crypto contract. It uses MT5/broker calculations for the actual instrument.

## Broker execution gate

Before a signal can activate APPROVE, and again immediately before order send, GPT_EA checks broker-specific rules:

- account trading permission
- Expert Advisor trading permission
- disabled / close-only / long-only / short-only symbol states
- minimum/maximum/step volume
- broker directional volume limit
- current minimum stop distance
- tick-size normalization of SL and targets
- current free margin
- `OrderCalcMargin()` requirement in account currency
- configurable maximum percentage of free margin consumed by the proposed trade
- supported order filling policy
- MT5 `OrderCheck()` result for the complete proposed market request
- projected post-trade free margin and configurable projected margin-level floor

An APPROVE prompt is therefore not shown merely because the chart setup is attractive; the request must also be executable under the connected account's current broker rules.

## Analysis engine

Every scan evaluates **D1 / H4 / H1 / M30 / M15 / M5**. The base engine combines EMA20/EMA50 structure, RSI and ATR. The advanced layer adds:

- higher-timeframe directional voting
- M15/M5 swing structure
- ADX and +DI/-DI
- RSI agreement
- EMA impulse/slope
- liquidity sweeps
- fair-value gaps
- strict sweep → displacement → retest logic
- M5 tick-volume impulse
- rolling VWAP-side confirmation
- M5 rejection candles
- entry-distance/ATR
- level touch/rejection quality
- opening-range regime
- live spread and slippage-adjusted effective R:R
- optional broker DOM imbalance
- optional local ONNX confirmation

The EA builds both **pullback** and **breakout-retest** candidates, scores both, and selects the better valid setup. No single indicator, AI answer or ML probability can bypass the deterministic execution/risk gates.

## Market-regime logic

The EA classifies current conditions as:

- `TRENDING`
- `HIGH_VOL_EXPANSION`
- `RANGING`
- `COMPRESSION`

Pullback and breakout-retest setups receive different regime adjustments. Breakout-retest can require the stricter sweep → displacement → retest sequence.

## Scheduled chart re-checks

Default schedule:

- **08:55 London** — pre-London scan
- **09:00 London** — London-open scan
- every configured hour thereafter through the London window
- **09:25 New York** — pre-U.S.-cash-open scan
- **09:30 New York** — U.S. cash open

The U.S. open is anchored to New York local time rather than permanently hard-coded to 14:30 London, so UK/U.S. daylight-saving transition differences are handled correctly.

A **SCAN NOW** button performs an immediate manual re-check.

## Economic-event, spread and Treasury-yield invalidation

Before authorization the EA can block a setup for:

- mapped high-impact economic events
- configured moderate events when enabled
- abnormal opening-range expansion
- excessive price displacement from the planned level
- spread widening relative to M5 ATR
- dynamic effective R:R deterioration
- configured U.S. Treasury-yield shock
- loss/drawdown/consecutive-loss kill switches
- duplicate-signal cooldown
- portfolio/correlated exposure limits
- broker execution-rule failure
- `OrderCheck()` failure
- falling confluence or stale M5 trigger

Upcoming mapped macro events can also be displayed without necessarily blocking the trade outside the configured event window.

## Pullback vs breakout-retest

The EA calculates both setup types independently.

**Pullback:** normally seeks a better entry around M15 trend/structure. Typical failure is acceptance through the intended support/resistance zone followed by opposite structure expansion.

**Breakout-retest:** requires a completed breakout and retest. Typical failure is a false break followed by a close back inside the prior range. The advanced engine can require sweep → displacement → retest before the breakout candidate is considered valid.

Both setups use spread/slippage-adjusted effective R:R, separate time-expiry budgets and separate long-term performance statistics.

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

Existing positions continue to be managed even when the EA blocks new authorizations.

## Dynamic slippage and R:R

The execution ceiling can adapt to live spread and M5 ATR while remaining inside configured min/max point limits. Effective R:R is recalculated immediately before authorization and immediately before order send.

If execution costs reduce effective R:R below the configured minimum, the trade is rejected.

## Lot sizing and leverage

Lot size is calculated from the selected equity/balance risk percentage using `OrderCalcProfit()` between preferred entry and SL, then normalized to the broker's volume step.

The proposed trade is subsequently checked against portfolio limits, broker volume rules, `OrderCalcMargin()`, free margin and `OrderCheck()`. This lets the same risk engine operate across different broker leverage, contract-size and margin models without hard-coding a universal pip-value formula.

## Trade approval flow

Signal scan → pullback/breakout comparison → advanced confluence → institutional/regime filters → economic/yield/session filters → optional AI review → portfolio/kill-switch gate → broker contract/margin gate → MT5 `OrderCheck()` → executable M5 entry trigger → timed **APPROVE / DENY** prompt → complete fresh validation → order send.

**APPROVE** is authorization only. If price, spread, R:R, margin, news, yield, confluence, portfolio risk or broker rules change before the click is processed, no order is opened.

**DENY** deletes the pending setup and starts cooldown. **No reply** before the timeout also deletes the setup. Manual **PAUSE** clears pending approvals and blocks new ones.

## Restart / VPS recovery

Recovery uses three sources rather than relying on one volatile state store:

1. current broker positions and trade history;
2. MT5 terminal Global Variables;
3. an account/magic-specific Common Files checkpoint:
   `GPT_EA_RecoveryState_<account_login>_<magic>.csv`.

The checkpoint stores version/account/server/magic metadata, risk state, active pending approvals and open-position management/analytics state. State is periodically checkpointed and also written around critical approval/order transitions.

Recovery handles:

- pending approval levels/direction/type/confidence/expiry
- offline approval expiration
- current position ticket changes
- stable `POSITION_IDENTIFIER` reconciliation
- original SL recovery from position history where available
- TP1/TP2/TP3 reconstruction
- adaptive candle expiry
- TP1 completion after a partial exit/BE movement
- initial monetary risk for analytics
- MAE/MFE and finalization guards
- day-start equity / high-water mark / consecutive losses / pause state
- account/server/magic mismatch rejection
- symbol re-resolution after broker suffix/prefix changes

Recovered pending setups are **never blindly executed**; startup performs a fresh scan and all normal authorization gates still apply.

### Netting reversal safety

In MT5 netting mode, a one-deal reversal can preserve `POSITION_IDENTIFIER` while changing position direction. GPT_EA compares the first position direction in history with the current direction during recovery. If a reversal/inconsistent state is detected, the EA can automatically **PAUSE** rather than applying stale TP/SL analytics to the opposite position.

## Time-based trade management

Pullback and breakout-retest setups have separate M15 candle budgets. The budget adapts to ATR/opening-range regime:

- unusually fast/high-volatility tape → fewer candles
- unusually slow/low-volatility tape → more candles

If TP1 is not reached inside the adaptive budget, the position can be closed.

At TP1 the EA can take a configurable partial profit and move SL to breakeven plus a cost buffer. After TP1, a stall near the next M15 barrier combined with momentum deterioration/M5 reversal can close the remainder rather than waiting indefinitely for TP2/TP3.

## Execution journal and analytics

Trade transactions feed `GPT_EA_Execution.csv` in the MT5 Common Files area. The current schema records:

- server timestamp
- event (`ENTRY`, `EXIT_PART`, `CLOSED`)
- broker symbol
- setup type
- deal ticket
- stable position identifier
- requested/reference price
- actual fill
- slippage points
- final R
- MAE_R
- MFE_R
- note/context

Persistent performance statistics remain separate for **PULLBACK** and **BREAKOUT-RETEST**, including trade count, win rate, average R/expectancy, profit factor, average slippage, average MAE and average MFE.

See `ANALYTICS_SCHEMA.md` for the versioned data contract and recovery-state schema.

## Chart interface

The chart can display:

- advanced confluence dashboard
- current symbol, direction and setup
- entry zone and preferred entry
- SL / TP1 / TP2 / TP3
- ADX / volume / opening-range state
- filter/readiness state
- **SCAN NOW**
- **APPROVE TRADE**
- **DENY / DELETE**
- **PAUSE TRADING / RESUME TRADING**
- portfolio risk and daily protection state
- separate pullback/breakout analytics

## Optional Depth of Market

DOM confirmation is disabled by default because availability/quality differs by broker and CFD instrument. When enabled, GPT_EA subscribes to the broker's market book and can use directional bid/ask imbalance as an additional confirmation. It cannot override hard risk filters.

## Optional ONNX model

Native ONNX confirmation is disabled by default. If enabled, the EA expects the configured model file with:

- float input shape `[1,12]`
- float output shape `[1,1]`
- output interpreted as setup-validity probability

ONNX is a secondary gate only. It cannot override portfolio limits, news/yield blocks, broker rules, R:R protection, cooldowns or approval requirements.

## OpenAI configuration

Enter the API key locally in MT5 inputs and never commit it to GitHub. Add the API endpoint under **Tools → Options → Expert Advisors → Allow WebRequest for listed URL**:

```text
https://api.openai.com
```

OpenAI is a secondary review/veto layer. Broker prices, indicators, spread, positions, calendar and risk calculations come from MT5 rather than being invented by the language model.

## Compilation and release testing

Use `COMPILE_TEST_CHECKLIST.md` as the release gate. The intended process is:

**MetaEditor compile → Strategy Tester deterministic checks → broker-specific demo tests → restart/crash recovery matrix → multi-session demo soak → conservative live release.**

The project should not be treated as production-ready merely because the source was pushed to GitHub. It still needs a clean MetaEditor compile and broker-specific demo validation on the terminal/account where it will run.

## Project separation

`GPT_EA` is an independent project with no runtime dependency on CelestialNexus or any other repository.
