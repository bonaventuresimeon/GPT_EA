# GPT_EA

Standalone MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe market analysis, advanced confluence scoring, OpenAI secondary validation, portfolio-level risk controls, restart recovery, execution analytics, timed APPROVE/DENY authorization, and execution-time revalidation.

Repository: https://github.com/bonaventuresimeon/GPT_EA.git

## Clone

```bash
git clone https://github.com/bonaventuresimeon/GPT_EA.git
cd GPT_EA
```

## Main EA

Compile `GPT_EA.mq5` in MetaEditor. The entry file includes these local modules:

- `GPT_EA_Part01.mqh` — inputs, OpenAI client and core types
- `GPT_EA_Part02.mqh` — indicators, multi-timeframe scoring and London/New York scheduling
- `GPT_EA_Part03.mqh` — ATR/opening-range adaptation, calendar, Treasury-yield and spread filters
- `GPT_EA_Part04.mqh` — pullback/breakout-retest construction and equity/balance lot sizing
- `GPT_EA_Part08_Advanced.mqh` — advanced confluence, dashboard and trade-level map
- `GPT_EA_Part09_RiskRecoveryAnalytics.mqh` — portfolio risk, restart recovery, setup analytics, DOM, regime logic, dynamic slippage, journaling and optional ONNX
- `GPT_EA_Part05.mqh` — signal-card formatting and final broker execution
- `GPT_EA_Part06.mqh` — TP1 partials, breakeven movement, time invalidation and post-TP1 management
- `GPT_EA_Part07.mqh` — approval workflow, scanner lifecycle and MT5 event hooks

## Analysis engine

Every scan evaluates D1, H4, H1, M30, M15 and M5. The base engine combines EMA20/EMA50 structure, RSI and ATR. The advanced engine then adds higher-timeframe voting, M15/M5 swing structure, ADX/+DI/-DI, RSI agreement, EMA impulse, liquidity sweeps, fair-value gaps, M5 tick-volume impulse, rolling VWAP, rejection candles, entry-distance/ATR, opening-range regime, spread quality and effective R:R.

The EA builds both **pullback** and **breakout-retest** candidates, scores both, and selects the better valid setup. A single indicator cannot authorize execution.

## Additional institutional filters

The risk/recovery module adds several independent checks:

- **level-quality score** based on touches and aligned rejections
- **sweep → displacement → retest** sequence detection
- **market-regime classification**: TRENDING, HIGH_VOL_EXPANSION, RANGING or COMPRESSION
- setup-specific regime weighting
- optional **Depth of Market** bid/ask imbalance confirmation where the broker exposes DOM
- optional **ONNX** local-ML confirmation using a 12-feature input contract
- dynamic spread/slippage-adjusted R:R immediately before order placement

The default breakout logic can require the sweep-displacement-retest sequence. DOM and ONNX remain optional because many CFD brokers do not expose useful DOM and an ONNX model file is not bundled with the repository.

## Portfolio risk controls

Before a setup can be authorized, GPT_EA can enforce:

- maximum total GPT_EA open risk as a percentage of equity
- maximum proposed single-symbol risk
- maximum correlated directional risk
- correlation grouping for equity indices such as US100 and GER40
- rejection of additional risk when an existing GPT_EA position has no protective stop

The default portfolio controls are configurable from EA inputs.

## Daily loss / drawdown kill switch

New entries can be automatically blocked when any configured protection is reached:

- daily equity-loss percentage
- maximum equity drawdown from the persistent high-water mark
- maximum consecutive losing trades
- manual **PAUSE TRADING** state

The chart dashboard shows current portfolio risk, daily loss, drawdown, consecutive losses and whether trading is ACTIVE or BLOCKED.

## Duplicate-signal cooldown

After a user denial, approval timeout or completed trade, the symbol enters a configurable M15-candle cooldown. This prevents the EA from repeatedly offering essentially the same stale level immediately after rejection or completion.

## Dynamic slippage and execution quality

Instead of relying only on one fixed slippage allowance, GPT_EA can calculate a dynamic ceiling from:

- current spread
- M5 ATR
- configured minimum and maximum slippage points

The order is rejected if the resulting execution-cost assumptions reduce effective R:R below the minimum.

## Execution journal

The EA records execution data through MT5 trade-transaction events and can write a CSV journal in the MetaTrader Common Files area:

`GPT_EA_Execution.csv`

The journal records items such as:

- requested/reference execution price
- actual fill price
- slippage in points
- setup type
- position identifier
- realized R
- MAE in R
- MFE in R
- partial and final exits

## Setup performance analytics

Performance is stored persistently and separated for:

- **PULLBACK**
- **BREAKOUT-RETEST**

The statistics panel tracks:

- completed trades
- win rate
- average R / expectancy
- profit factor in R terms
- average slippage
- average MAE
- average MFE

This allows future decisions to be based on the actual behavior of each setup type rather than assumptions.

## Restart / VPS recovery

GPT_EA persists important state with terminal Global Variables and rebuilds state after MetaTrader or VPS restart.

Recovery includes:

- pending approval direction/setup/levels/confidence/expiry
- approval timeout state
- open-position initial stop
- TP1 / TP2 / TP3 state
- adaptive candle expiry
- TP1 completion state
- setup type and initial risk for analytics
- daily risk state
- equity high-water mark
- consecutive-loss state
- manual pause state

Recovered pending trades are **not blindly executed**. On startup the EA immediately runs a fresh full scan, so stale authorizations are removed if current conditions no longer qualify.

## Scheduled re-checks

The EA scans:

- just before the 09:00 London open — default 08:55 London
- at 09:00 London and every configured hour thereafter
- just before the U.S. cash open — default 09:25 New York
- at the U.S. cash open — 09:30 New York

The U.S. open is anchored to New York local time so U.S./UK daylight-saving differences are handled correctly.

A **SCAN NOW** chart button performs an immediate re-check.

## Economic events and yield invalidation

Before authorization, the EA checks MetaTrader's native calendar for mapped economic events and can block entries around high-impact releases. It also monitors the configured U.S. Treasury-yield symbol and invalidates levels when a yield shock exceeds the configured threshold.

A setup can also be invalidated by opening-range expansion, excessive displacement from the preferred entry, spread widening, dynamic R:R deterioration, loss/drawdown limits, correlated exposure, cooldown state, or falling confluence.

## Candle-count invalidation

Pullback and breakout-retest setups have separate M15 candle budgets. The budget adapts to ATR and opening-range conditions:

- unusually fast/high-volatility tape → fewer candles
- unusually slow/low-volatility tape → more candles

If TP1 is not reached within the adaptive budget, the position is closed.

## TP1 and remaining-position management

At TP1 the EA can take a configurable partial profit and move the stop to breakeven plus a small ATR cost buffer.

After TP1, if price stalls near the next M15 barrier while H1/M15 momentum deteriorates or an M5 reversal develops, GPT_EA can close the remainder instead of waiting indefinitely for TP2/TP3.

## Lot sizing

Lot size is calculated from either account equity or account balance using the configured risk percentage and `OrderCalcProfit()` between the preferred entry and stop. Portfolio-risk controls are applied after the individual lot calculation and again immediately before execution.

## Trade approval flow

Signal scan → pullback/breakout comparison → advanced confluence → institutional filters → economic/yield/session filters → optional AI review → portfolio/kill-switch checks → executable-entry trigger → timed APPROVE/DENY prompt → fresh full validation → execution.

- **APPROVE:** authorization only. Price, M5 trigger, confluence, institutional filters, R:R, session state, portfolio risk, cooldown, spread, news, yield shock and position limits are checked again.
- **DENY:** deletes the pending setup and starts the configured cooldown.
- **No response before timeout:** deletes the pending setup and starts cooldown.
- **Stale/expired setup:** cannot be forced through by APPROVE.
- **Manual PAUSE:** prevents new authorization and clears pending approvals.

## Signal-card format

```text
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 SYMBOL LONG/SHORT — PRIMARY SETUP
━━━━━━━━━━━━━━━━━━━━
Asset:
TF: D1 / H4 / H1 / M30 / M15 / M5
Bias:
Analysis:
Confirmation:
Entry:
Preferred Entry:
SL:
TP1:
TP2:
TP3:
R:R:
Confidence:
Time invalidation:
Invalidation:
Failure pattern:
Pullback vs Breakout-Retest:
Position management:
Preferred Trade:
Execution rule:
Risk note:
```

The card additionally reports advanced confluence, institutional validation, market regime, level quality, sweep-displacement-retest status, DOM state when available, dynamic R:R/slippage, upcoming macro events, AI review, portfolio-risk gate and approval readiness.

## Chart interface

The chart can display:

- advanced confluence dashboard
- exact entry zone and preferred entry
- SL / TP1 / TP2 / TP3
- ADX, volume and opening-range state
- filter and readiness status
- **SCAN NOW**
- **APPROVE TRADE**
- **DENY / DELETE**
- **PAUSE TRADING / RESUME TRADING**
- portfolio-risk and performance panel
- separate pullback and breakout analytics

## Optional ONNX model

Native ONNX confirmation is disabled by default. If enabled, the EA expects a model file named by `InpONNXModelFile` in the MT5 `MQL5/Files` area, with:

- float input shape: `[1,12]`
- float output shape: `[1,1]`
- output interpreted as setup-validity probability

ONNX is a secondary confirmation only. It cannot override portfolio limits, news/yield blocks, stop requirements, spread/R:R protection, cooldowns or approval rules.

## OpenAI configuration

Enter the API key locally in MT5 inputs and never commit it to GitHub. Add this URL under **Tools → Options → Expert Advisors → Allow WebRequest for listed URL**:

```text
https://api.openai.com
```

## Testing note

`WebRequest()` is unavailable inside MT5 Strategy Tester, and broker DOM/calendar availability differs by terminal and symbol. Test deterministic logic in Strategy Tester and validate OpenAI, calendar, DOM, restart recovery and execution behavior on a demo account before enabling approved execution on live funds.

## Project separation

`GPT_EA` is an independent project with no runtime dependency on CelestialNexus or any other repository.
