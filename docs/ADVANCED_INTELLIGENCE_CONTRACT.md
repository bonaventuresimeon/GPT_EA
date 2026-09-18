<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧠 System Intelligence & Architecture

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧠 **Document:** `ADVANCED_INTELLIGENCE_CONTRACT.md`

---

# GPT_EA Advanced Intelligence Contract

This document maps the full market-analysis contract implemented by the strategy/news intelligence modules.

## Market-state vocabulary

The engine explicitly distinguishes and reports:

- trend continuation;
- healthy retracement;
- deep retracement;
- correction;
- counter-trend movement;
- trend failure;
- reversal;
- breakout;
- breakout-retest;
- false breakout;
- liquidity sweep;
- range expansion;
- range reversal;
- mean reversion;
- momentum continuation;
- exhaustion;
- possible accumulation;
- possible distribution;
- consolidation.

These are market-state classifications, not guaranteed predictions.

## Executable strategy classifications

Before an entry recommendation, the engine must classify the candidate as one of:

1. Trend Continuation
2. Retracement Entry
3. Counter-Trend Scalp
4. Counter-Trend Swing
5. Potential Reversal
6. Breakout
7. Breakout-Retest
8. Range Trade
9. Mean-Reversion Setup
10. No Trade

`WAIT FOR CONFIRMATION` is a separate action state used when a valid market idea exists but execution requirements are incomplete.

## Strategy framework library

The regime selector can identify/use frameworks including:

### Trend following
- higher-high/higher-low continuation;
- lower-high/lower-low continuation;
- multi-timeframe trend alignment;
- EMA/dynamic-support continuation;
- pullback-to-structure;
- momentum/volatility-expansion continuation.

### Breakout
- support/resistance breakout;
- breakout-retest;
- opening-range breakout/retest;
- previous-day high/low breakout;
- Asian-range breakout;
- London open breakout;
- U.S. cash opening-range breakout;
- consolidation / volatility-expansion breakout.

### Retracement
- previous breakout structure retest;
- previous-day structure retracement;
- EMA/dynamic support-resistance retracement;
- Fibonacci 38.2-61.8% value-zone retracement;
- liquidity-sweep retracement.

### Counter-trend / reversal
- liquidity sweep + reversal;
- failed breakout;
- double top/bottom + structural confirmation;
- exhaustion + RSI divergence;
- change of character;
- lower-timeframe break of structure;
- major support/resistance rejection;
- London liquidity-sweep reversal;
- U.S. cash-session sweep/reversal.

### Range / mean reversion
- range support buy;
- range resistance sell;
- failed range breakout;
- session-range reversal;
- mean reversion toward equilibrium/VWAP.

No framework is described as universally profitable.

## Retracement intelligence

For a move against the dominant trend, the engine evaluates:

- HTF D1/H4/H1 vote strength;
- M15/M5 structure;
- price versus EMA20/EMA50;
- ATR-normalized retracement depth;
- prior swing range;
- Fibonacci 38.2-61.8% value zone;
- prior-day structure;
- supply/demand proxy zones;
- liquidity sweeps;
- whether lower-timeframe structure has actually changed.

It distinguishes healthy/deep retracement from trend failure/reversal and avoids treating every counter move as a reversal.

## Counter-trend intelligence

Counter-trend trades are subject to a higher score threshold and require combinations of:

- exhaustion/overextension;
- major range or previous-day level;
- liquidity sweep;
- RSI divergence;
- double top/bottom where present;
- change of character / M5 break of structure;
- rejection confirmation;
- session context;
- reduced target assumptions.

A strong HTF ADX trend penalizes counter-trend scoring.

## Multi-timeframe scope

Every scanner/revalidation cycle uses:

- D1
- H4
- H1
- M30
- M15
- M5

Higher timeframes establish context; lower timeframes establish confirmation and entry timing.

## Technical evidence

The combined engine can use:

- EMA20 / EMA50;
- RSI;
- ATR;
- ADX / +DI / -DI;
- swing HH/HL/LH/LL structure;
- break of structure / change of character;
- liquidity sweeps;
- fair-value gaps;
- displacement/retest sequence;
- tick-volume impulse;
- VWAP;
- rejection candles;
- previous-day highs/lows;
- Asian/session ranges;
- opening-range ratio;
- level touches/rejections;
- DOM where the broker supplies it;
- dynamic spread/slippage-adjusted R:R.

## News intelligence

Before approval/execution, GPT_EA combines:

1. MT5 native economic calendar filtering;
2. Treasury-yield shock filtering;
3. OpenAI Responses API web search when enabled;
4. local broker intermarket data.

The web-search prompt explicitly asks for current:

- interest-rate decisions;
- CPI/inflation;
- PPI;
- employment/NFP/unemployment;
- GDP;
- PMI;
- retail sales;
- FOMC/ECB/BoE and other central-bank communication;
- Treasury/bond-market developments;
- USD strength;
- geopolitical/political/economic breaking headlines;
- company/sector developments where relevant;
- commodity/OPEC/inventory/supply-demand developments;
- volatility/risk events;
- instrument-specific high-impact developments.

The web layer must explain the invalidation channel, not merely say that news exists.

## Intermarket intelligence

Where the relevant broker instruments are available, the engine can compare the proposed direction against:

- DXY / USD index;
- US 10-year yield instrument;
- VIX/volatility index;
- gold;
- WTI/oil;
- US100;
- US500;
- related FX behavior.

No unavailable intermarket data is fabricated. Severe contradiction can block authorization.

## Historical/internal strategy evidence

Strategy results are accumulated by:

- strategy class;
- market state;
- long vs short;
- volatility bucket;
- session;
- setup/execution timeframe context;
- proximity to high-impact news.

Metrics include trade count, win rate, average R/expectancy, profit factor, cumulative R, maximum drawdown in R and maximum consecutive losses.

After the configured minimum sample is reached, negative expectancy/profit-factor evidence can block a strategy. Before that point the sample is explicitly treated as developing evidence rather than proof.

## Mandatory 25-point thesis

Every selected setup builds all 25 analysis sections requested by the product contract:

1. multi-timeframe alignment;
2. market regime;
3. market structure;
4. strategy selection;
5. trend vs retracement assessment;
6. entry logic;
7. confirmation logic;
8. stop-loss logic;
9. take-profit logic;
10. realistic R:R;
11. pullback vs breakout-retest;
12. counter-trend assessment;
13. liquidity/fakeout;
14. volatility;
15. news risk;
16. Treasury/intermarket;
17. session;
18. time invalidation;
19. price invalidation;
20. counterargument/disproof;
21. setup-quality filtering;
22. confidence validation;
23. historical strategy evidence;
24. pre-entry revalidation;
25. detailed trade thesis.

## Adversarial GPT validation

After deterministic strategy selection, the secondary GPT review is instructed to try to disprove the setup, identify opposing evidence, distinguish retracement from reversal, distinguish breakout from sweep/fakeout, evaluate overextension and execution costs, and return VALID / WAIT / INVALID.

GPT cannot override deterministic release, risk, broker, stop-safety or OrderCheck gates.

## Decision invariant

The valid terminal states are:

- `HIGH-CONFIDENCE TRADE SETUP`
- `WAIT FOR CONFIRMATION / REANALYZE`
- `NO TRADE`

The engine is not required to produce a trade merely because a scan was requested.
