<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧠 System Intelligence & Architecture

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧠 **Document:** `FULL_INTELLIGENCE_COVERAGE.md`

---

# GPT_EA Full Intelligence Coverage Map

This file is the implementation traceability contract for the advanced chart, multi-timeframe, strategy and news specification. A capability is considered complete only when it is wired into the scanner/revalidation path, not merely present as an unused helper.

## Market-state vocabulary

Implemented as first-class market states in `GPT_EA_Part15_StrategyIntelligence.mqh`:

- Trend continuation
- Healthy retracement
- Deep retracement
- Correction
- Counter-trend movement
- Trend failure
- Reversal
- Breakout
- Breakout-retest context
- False breakout
- Liquidity sweep
- Range expansion
- Range reversal
- Mean reversion
- Momentum continuation
- Exhaustion
- Possible accumulation
- Possible distribution
- Consolidation

`GPT_EA_Part21_ResearchValidation.mqh` adds corrective-versus-impulsive counter-move analysis, likely retracement destination, chase risk, counter-trend opportunity thresholding and explicit structural conditions that would turn a retracement into a reversal thesis.

## Executable strategy classifications

The dynamic selector exposes:

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

`GPT_EA_Part15B_StrategyFrameworks.mqh` maps these classes to named frameworks such as HH/HL or LH/LL continuation, moving-average/value retracement, Fibonacci retracement, liquidity-sweep retracement/reversal, previous-day high/low breakout, Asian-range/London breakout, U.S. cash opening-range breakout/retest, failed breakout, double top/bottom, divergence + structure, session sweep/reversal, range boundary and VWAP/equilibrium mean reversion.

## Dynamic regime selection

`GPT_EA_Part15_StrategyIntelligence.mqh`, `Part21` and `Part24` jointly enforce:

- regime first, strategy second;
- no forced trade when strategy/regime disagree;
- chase filter for overextended continuation/breakout conditions;
- stronger threshold and trigger for counter-trend trades;
- extreme/out-of-distribution ATR/opening-range block;
- accurate London/New York overlap;
- late-session liquidity downgrade;
- strategy-specific candle expiry before ATR/opening-range adaptation.

## Multi-timeframe evidence

The scanner uses D1, H4, H1, M30, M15 and M5. Higher timeframes establish directional context; M15/M5 supply execution structure and trigger evidence. Existing modules evaluate EMA, RSI, ATR, ADX/+DI/-DI, swings, BOS/CHOCH proxies, liquidity sweep, FVG, rejection, volume, VWAP, opening range, session/previous-day levels, spread and optional DOM/ONNX evidence.

## Retracement intelligence

`GPT_EA_Part21_ResearchValidation.mqh` explicitly answers:

- corrective versus impulsive;
- whether HTF structure is still intact;
- likely retracement destination from EMA20/EMA50, VWAP, swing structure, previous-day/Asian levels and Fibonacci value;
- whether immediate entry is chasing;
- whether waiting for value can improve structural R:R;
- whether a strict counter-trend opportunity exists;
- what structural failure would support a real reversal instead of a retracement label.

## Counter-trend rules

Counter-trend scoring includes exhaustion, liquidity sweep, divergence, double top/bottom, lower-timeframe BOS/CHOCH, major levels, ADX/trend-strength penalty and expansion penalty. Execution requires price in zone plus sweep, M5 BOS/CHOCH and rejection. Counter-trend candidates use conservative targets and shorter strategy-aware expiry.

## Live news and fundamental intelligence

`GPT_EA_Part16_NewsIntermarket.mqh` and `GPT_EA_Part22_IntelligenceFreshness.mqh` combine:

- MT5 native economic calendar;
- central-bank decisions/communications;
- CPI/PPI/inflation;
- NFP/employment/unemployment;
- GDP, PMI and retail sales;
- Treasury-yield/bond volatility;
- USD strength;
- geopolitical and unexpected political/economic headlines;
- company/sector developments where relevant;
- commodity/OPEC/inventory/supply-demand developments;
- instrument-specific breaking events;
- OpenAI web search when enabled.

The hardened web layer uses a structured JSON-schema contract with `CLEAR/WATCH/BLOCK`, a 0-100 risk score, events, breaking news, invalidation channel, intermarket explanation, source attribution and UTC as-of text. Missing/malformed data is explicitly downgraded or blocked according to fail-closed policy. Repeated failures open a visible circuit-breaker condition. High-confidence candidates can be configured to fail closed when live web intelligence is unavailable.

## Intermarket intelligence

The broker-local layer checks fresh M15 data for relevant combinations of DXY, US10Y, VIX, XAUUSD, oil, US100 and US500 depending on target asset class. Stale bars are excluded. A severe contradiction can block authorization; unavailable/stale references do not fabricate confirmation.

## Risk-to-reward and execution costs

`GPT_EA_Part20_RealisticCostModel.mqh` models:

- live spread;
- dynamic slippage allowance;
- historical/fallback commission;
- 1-lot stop risk through `OrderCalcProfit()`;
- TP1/TP2 partials;
- remaining runner reward.

`GPT_EA_Part25_ThesisHardening.mqh` displays separate realistic weighted R:R for the pullback, breakout-retest and selected setup. A theoretical pattern with poor executable R:R is not authorized.

## Price and time invalidation

Price invalidation is structural and remains attached to the setup/SL thesis. Time invalidation is strategy-specific through `StrategyAdaptiveExpiry()` and then adjusted by ATR/opening-range speed through `AdaptiveExpiry()`. Breakout and counter-trend scalp setups require faster follow-through than swing/retracement setups.

## Counterargument / disproof

Every card contains deterministic opposing evidence plus the optional adversarial GPT validation prompt. `GPT_EA_Part25_ThesisHardening.mqh` adds a deterministic disproof checklist covering trend failure, false breakout, exhaustion, chase risk, counter-trend strictness, SL invalidation and strategy score.

## Historical, forward and walk-forward evidence

The EA records strategy results in R and computes win rate, average R/expectancy, profit factor, max drawdown and maximum consecutive losses. Context buckets track:

- strategy;
- market state;
- long versus short;
- high/normal/low volatility;
- session;
- M15 setup / M5 execution timeframe;
- proximity to high-impact news.

`GPT_EA_Part21_ResearchValidation.mqh` adds chronological train-versus-recent walk-forward evidence and drift detection. Negative recent out-of-sample evidence can block the strategy. Developing samples are explicitly described as neutral evidence, not proof of reliability.

## Mandatory 25-point thesis

`GPT_EA_Part17_ThesisEngine.mqh` implements all 25 requested sections:

1. Multi-Timeframe Alignment
2. Market Regime
3. Market Structure
4. Strategy Selection
5. Trend vs Retracement Assessment
6. Entry Logic
7. Confirmation Logic
8. Stop-Loss Logic
9. Take-Profit Logic
10. Risk-to-Reward Analysis
11. Pullback vs Breakout-Retest Analysis
12. Counter-Trend Assessment
13. Liquidity & Fakeout Assessment
14. Volatility Analysis
15. News Risk Assessment
16. Treasury-Yield & Intermarket Analysis
17. Session Analysis
18. Time-Based Invalidation
19. Price-Based Invalidation
20. Counterargument Analysis
21. Setup Quality Filtering
22. Confidence Validation
23. Historical Strategy Validation
24. Pre-Entry Revalidation
25. Detailed Trade Thesis

`Part25` appends the realistic-cost, research-validation and freshness details that would otherwise be too compressed inside those sections.

## Pre-entry revalidation

Immediately before execution the strict path rechecks:

- stored strategy identity;
- fresh strategy/state/direction;
- price zone and M5 strategy trigger;
- confluence and institutional/regime filters;
- research/context/walk-forward gate through the final selector;
- spread and realistic R:R;
- economic calendar;
- yield shock;
- structured live web intelligence;
- fresh intermarket conflict;
- session conditions;
- release safety;
- stop/partial-protection observability;
- portfolio/correlation risk;
- broker execution constraints;
- MT5 `OrderCheck()`.

Changed conditions cancel execution and require reanalysis.

## Decision states

The engine is allowed to produce only the operational outcome justified by evidence:

- `HIGH-CONFIDENCE TRADE SETUP`
- `WAIT FOR CONFIRMATION / REANALYZE`
- `NO TRADE`

A scan request never forces an entry.

## Observability and release controls

`GPT_EA_Part23_IntelligenceObservability.mqh` writes `GPT_EA_Intelligence.csv` with the signal card and key decision fields. Stop failures use the separate durable stop observability contract. `.github/workflows/static-quality.yml` checks architecture/wiring/secrets/basic source balance on every push/PR.

The following remain hard external release gates because this repository environment does not provide a MetaEditor/MT5 terminal:

- MetaEditor compilation with 0 errors and reviewed warnings;
- Strategy Tester;
- broker matrix;
- recovery tests;
- stop-management HIGH-priority matrix;
- structured WebRequest failure injection in terminal;
- demo soak;
- explicit live arming.

See `INTELLIGENCE_TEST_MATRIX.md`, `INTELLIGENCE_HARDENING_TESTS.md`, `COMPILE_TEST_CHECKLIST.md`, `BROKER_MATRIX_TESTS.md`, `STOP_MANAGEMENT_TEST_MATRIX.md` and `RELEASE_SAFETY_GATES.md`.
