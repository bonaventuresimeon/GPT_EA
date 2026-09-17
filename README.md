# GPT_EA

Standalone MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe market analysis, advanced confluence scoring, OpenAI secondary validation, risk-based lot sizing, economic-event/yield filters, timed APPROVE/DENY trade authorization, and execution-time revalidation.

Repository: https://github.com/bonaventuresimeon/GPT_EA.git

## Clone

```bash
git clone https://github.com/bonaventuresimeon/GPT_EA.git
cd GPT_EA
```

## Main EA

Compile `GPT_EA.mq5` in MetaEditor. It includes the local project source files:

- `GPT_EA_Part01.mqh` — inputs, OpenAI client, core types
- `GPT_EA_Part02.mqh` — indicators, multi-timeframe scoring, London/New York DST scheduling
- `GPT_EA_Part03.mqh` — ATR/opening-range adaptation, economic calendar, Treasury-yield and spread/slippage filters
- `GPT_EA_Part04.mqh` — pullback/breakout-retest construction and equity/balance lot sizing
- `GPT_EA_Part05.mqh` — signal-card formatting and broker execution
- `GPT_EA_Part06.mqh` — TP1 partials, BE movement, time invalidation, post-TP1 stall management and approval controls
- `GPT_EA_Part08_Advanced.mqh` — advanced confluence engine, event horizon, chart dashboard and trade-level map
- `GPT_EA_Part07.mqh` — approval workflow, advanced scanner and MT5 event hooks

## What the EA analyzes

Every scan evaluates D1, H4, H1, M30, M15 and M5. The base scanner combines EMA20/EMA50 structure, RSI and ATR. The advanced layer then adds:

- higher-timeframe directional voting
- M15/M5 swing structure
- ADX and +DI/-DI strength
- RSI momentum agreement
- EMA impulse/slope
- liquidity-sweep confirmation
- recent fair-value-gap alignment
- M5 tick-volume impulse
- rolling intraday VWAP-side confirmation
- M5 rejection-candle confirmation
- distance from the preferred entry in ATR units
- opening-range volatility regime
- spread and modeled slippage cost

The advanced confluence score is 0–100 and is blended with the original setup confidence. A single indicator cannot authorize execution.

## Pullback vs breakout-retest

The EA builds both setup types and compares them on confidence, confluence and effective R:R.

**Pullback entry:** anchored around the M15 fast EMA and nearby swing structure. Typical failure is acceptance through the support/resistance zone followed by opposite structure expansion.

**Breakout-retest entry:** requires a completed M15 break of a prior swing level and then a retest. Typical failure is a false breakout/breakdown that closes back inside the old range.

Both setups use spread + configured slippage when estimating effective R:R, so a tighter setup can be rejected even when its nominal target structure looks attractive.

## Scheduled re-checks

The EA scans:

- just before the 09:00 London open (default 08:55 London)
- at 09:00 London and every hour through the configured London session window
- just before the U.S. cash open (default 09:25 New York)
- at the U.S. cash open (09:30 New York)

The U.S. open is anchored to **New York local time**, not permanently hard-coded to 14:30 London, so UK/U.S. daylight-saving transition differences are handled correctly.

There is also a **SCAN NOW** button on the dashboard for an immediate manual re-check.

## Economic events and market-open invalidation

Before authorization, the EA checks MetaTrader's native economic calendar for mapped USD/EUR/FX events, displays upcoming high/moderate events within the configured horizon, and blocks entries around configured high-impact windows.

It can also invalidate a setup when:

- the opening range becomes abnormally large versus M15 ATR
- price moves too far from the preferred level before entry
- spread widens beyond the configured M5-ATR fraction
- modeled spread/slippage degrades effective R:R below the minimum
- the configured U.S. Treasury-yield symbol produces a shock move
- the advanced confluence score falls below threshold

## Candle-count invalidation

Pullback and breakout-retest setups have separate M15 candle budgets. The budget adapts to ATR and opening-range conditions:

- unusually fast/high-volatility regime → fewer candles allowed
- unusually slow/low-volatility regime → more candles allowed

If TP1 is not reached inside the adaptive budget, the position is closed.

## TP1 and remaining-position management

At TP1 the EA can take a configurable partial profit and move the stop to breakeven plus a small ATR cost buffer.

After TP1, if price stalls near the next M15 barrier and H1/M15 momentum deteriorates or an M5 reversal appears, the EA can close the remainder instead of waiting indefinitely for TP2/TP3.

## Lot sizing

Lot size is calculated from either account equity or account balance using the configured risk percentage and `OrderCalcProfit()` between the preferred entry and stop. This is suitable for broker-specific CFDs where pip-value assumptions are unreliable.

## Trade approval flow

Analysis card → advanced confluence → OpenAI secondary review → executable-entry trigger → timed APPROVE / DENY prompt → fresh validation → execution.

- **APPROVE:** authorization only. The EA re-checks price-in-zone, M5 trigger, advanced confluence, effective R:R, session displacement, spread, economic events, yield shock, position limit and lot size before sending the order.
- **DENY:** deletes the pending trade setup immediately.
- **No response before timeout:** automatically deletes the pending setup.
- **Expired/stale setup:** cannot be forced through by pressing APPROVE.
- **Optional AI veto:** an OpenAI WAIT/INVALID review can block authorization; AI unavailability can be configured to block or not block.

## Signal-card format

The EA uses the project's signal-card structure:

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

The card also appends the advanced confluence breakdown, upcoming macro-event summary, AI review and current approval readiness.

## Advanced chart UI

The EA can polish the attached MT5 chart into a dark institutional-style layout and display:

- advanced confluence dashboard
- current symbol/bias/setup
- confidence and 0–100 confluence score
- entry zone and preferred price
- SL / TP1 / TP2 / TP3
- ADX, volume ratio and opening-range ratio
- filter status
- entry-trigger readiness
- SCAN NOW button
- timed APPROVE and DENY buttons when a setup becomes executable
- entry-zone rectangle and Entry/SL/TP horizontal levels on the attached symbol

## OpenAI configuration

The OpenAI API key is entered locally in MT5 inputs and must never be committed to GitHub.

In MetaTrader 5, add this URL under **Tools → Options → Expert Advisors → Allow WebRequest for listed URL**:

```text
https://api.openai.com
```

The project currently uses the OpenAI Responses API endpoint and defaults to `gpt-5.6-luna` for frequent secondary reviews.

## Important testing note

`WebRequest()` is unavailable inside the MT5 Strategy Tester, and MetaTrader's native economic-calendar integration is intended for terminal/live-server use. Test the deterministic strategy logic in Strategy Tester, then validate OpenAI/calendar behavior on a demo terminal before enabling approved execution on a live account.

## Project separation

`GPT_EA` is an independent project. It has no runtime dependency on CelestialNexus or any other repository.
