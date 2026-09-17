# GPT_EA R5 Adaptive Execution Architecture

This document maps the advanced adaptive-execution roadmap to executable modules. These features do not replace the existing strategy/news/stop/release architecture. They sit around it and may only reduce, delay, shadow or block exposure unless a separately validated champion/challenger promotion is explicitly enabled.

## Governing principles

1. Deterministic risk controls outrank GPT output.
2. Adaptation may reduce risk automatically; it must not exceed the configured base/account/portfolio ceilings.
3. Insufficient samples are labelled developing evidence rather than treated as proof.
4. Strategy degradation isolates the affected strategy instead of automatically disabling unrelated strategies.
5. Shadow/counterfactual outcomes never place broker orders.
6. A challenger cannot become live merely because its win rate is higher.
7. Existing open positions continue protective management when new-entry adaptive gates block.
8. R5 requires a new release evidence pack; R4 evidence does not arm R5.

## 1. Champion / challenger shadow mode

`GPT_EA_Part32_ChampionChallenger.mqh`

The selected strategy is shadowed as the champion benchmark while Pullback and Breakout-Retest alternatives can be simulated in parallel. Promotion evidence includes minimum sample, average-R advantage, profit-factor advantage, maximum drawdown and EWMA stability. Same-bar SL/TP ambiguity is conservatively scored as a stop outcome. `InpAutoPromoteChallenger=false` by default, so eligibility is informational unless the operator deliberately validates and enables promotion.

## 2. Per-strategy risk budgets

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh`

Trend, Retracement, Counter-Trend Scalp, Counter-Trend Swing, Potential Reversal, Breakout, Breakout-Retest, Range and Mean-Reversion have separate daily and weekly loss/open-risk budgets. A depleted strategy budget blocks that strategy without automatically stopping unrelated strategy classes.

## 3. Confidence calibration

`GPT_EA_Part31_ExecutionLearning.mqh`

Raw confidence is grouped into 5-point buckets. After a minimum sample, observed wins are combined with a configurable Bayesian prior based on the raw forecast. The selected setup is calibrated once before high-confidence authorization. A calibrated result below `InpMinCalibratedConfidence` downgrades the setup.

## 4. Execution-quality learning

`GPT_EA_Part31_ExecutionLearning.mqh`

The EA records expected entry, request price, actual fill, spread at request/fill, slippage points, request-to-fill latency, lots, risk money, strategy/session/event context, commission and realized R. Symbol/strategy/session EWMAs feed future execution-cost forecasts.

Runtime file: `GPT_EA_ExecutionLearning.csv`.

## 5. Market-condition kill switch

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh`

The abnormal-market score combines spread/ATR expansion, violent M1 range relative to M15 ATR, extreme ATR regime, extreme opening range, stale quotes and Treasury-yield shock evidence. Reaching the configured score blocks new exposure while open-position management continues.

## 6. Portfolio correlation and macro-factor aggregation

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh`

Open-position risk is weighted by rolling M15 return correlation and directional alignment. A separate approximate macro-factor layer aggregates USD and risk-on/risk-off exposure across indices, metals, major FX, crypto and oil. Both sit below the existing hard portfolio-risk ceiling.

## 7. Dynamic position sizing

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh` + `GPT_EA_Part31A_RegimeSizing.mqh`

Risk starts from `InpRiskPercent` as a ceiling and is multiplied down using setup confidence, strategy health, broker health, drawdown, historical strategy evidence, event proximity and regime-transition caution. Final lot size is normalized to broker volume rules and can never intentionally exceed the base-risk ceiling.

## 8. Strategy degradation detector

`GPT_EA_Part31_ExecutionLearning.mqh`

Recent average R and profit factor move each strategy among:

- `ACTIVE`
- `REDUCED_RISK`
- `SHADOW`
- `DISABLED`

`SHADOW` and `DISABLED` prohibit live exposure through the independent supervisor. `REDUCED_RISK` applies a lower risk multiplier.

## 9. MAE/MFE stop/target research

`GPT_EA_Part31_ExecutionLearning.mqh`

Every adaptive trade tracks maximum adverse excursion and maximum favorable excursion in R while open. Closed-trade aggregates are retained by strategy for research and dashboard review. These statistics are evidence for future stop/target tuning; they do not automatically loosen existing protective stops.

## 10. Event-specific behavior models

`GPT_EA_Part31_ExecutionLearning.mqh`

Native MT5 calendar events are classified into CPI/inflation, PPI, NFP/employment, FOMC/Fed, ECB, BoE, GDP, PMI, retail sales, central-bank speech and other high-impact classes. Strategy/event buckets accumulate R statistics. With sufficient negative evidence, a matching event/strategy context can block entry.

## 11. Spread/slippage forecast before entry

`GPT_EA_Part31_ExecutionLearning.mqh` + `GPT_EA_Part35_AdaptiveIntegration.mqh`

The forecast takes the worse of dynamic current-market slippage and learned symbol/strategy/session EWMAs. An execution-forecast R:R test must remain above the strategy floor. The learned forecast also informs the order deviation ceiling, bounded by the existing maximum-slippage configuration.

## 12. Broker-health scoring

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh`

Broker health scores quote age, spread stability, order failure rate, learned slippage and active stop failures. Low health blocks new orders but does not stop management of existing positions.

## 13. Trade lifecycle state machine

`GPT_EA_Part33_LifecycleIntegrityReplay.mqh`

Durable lifecycle states are:

`CANDIDATE -> WAIT_CONFIRMATION -> APPROVED -> SENT -> FILLED -> TP1_PARTIAL -> PROTECTED -> RUNNER -> CLOSED`

with terminal rejection/invalidation states. Invalid transitions are rejected. Restart logic reconstructs open-position lifecycle state from broker/durable TP1/TP2 protection state.

Runtime file: `GPT_EA_Lifecycle.csv`.

## 14. Replayable decision snapshots

`GPT_EA_Part33_LifecycleIntegrityReplay.mqh`

Each scan can persist strategy/state, direction, full geometry, confidence, score, ATR/opening-range/ADX/RSI/overextension/volume context, realistic R:R, adaptive risk multiplier, broker health, strategy health, regime transition, filters and GPT checksum/excerpt.

Runtime file: `GPT_EA_DecisionSnapshots.csv`.

## 15. Counterfactual analytics

`GPT_EA_Part32_ChampionChallenger.mqh`

Rejected/WAIT candidates can be tracked without orders. Pullback and Breakout-Retest alternatives are also shadowed so the EA can measure whether a filter or selected entry style improved outcomes rather than merely reducing trade count.

## 16. Learned adaptive candle expiry

`GPT_EA_Part31_ExecutionLearning.mqh`

Time-to-TP1 is stored as an M15 histogram by strategy. Once the configured sample exists, the selected percentile becomes the strategy's learned expiry, subject to a hard maximum. Developing samples use the existing strategy/ATR/opening-range expiry.

## 17. Regime-transition detection

`GPT_EA_Part31_ExecutionLearning.mqh` + `GPT_EA_Part31A_RegimeSizing.mqh`

State transitions are persisted by symbol. During the configured caution window after a transition, final position size is reduced. This distinguishes a newly changing regime from a mature regime even when both receive the same current-state label.

## 18. Independent risk supervisor

`GPT_EA_Part30_AdaptiveRiskPortfolio.mqh`

This deterministic supervisor can block entries for account kill-switch conditions, degraded strategy state, abnormal market conditions, poor broker health and accelerating drawdown. GPT cannot override it.

## 19. GPT disagreement architecture

`GPT_EA_Part33_LifecycleIntegrityReplay.mqh` + `GPT_EA_Part35_AdaptiveIntegration.mqh`

The deterministic engine creates the setup first. GPT then challenges it. Strong opposite-direction, veto, no-trade or invalidation language raises a disagreement score. Strong disagreement withholds high-confidence execution; GPT does not replace the deterministic direction or geometry.

## 20. Model-output integrity checks

`GPT_EA_Part33_LifecycleIntegrityReplay.mqh`

Before GPT can participate in authorization the EA checks deterministic price geometry/freshness, response availability policy, minimum response length, parser fallback text and credential-like leakage. The review decision is timestamped/checksummed and must remain fresh at execution.

## Strategy Health Dashboard

`GPT_EA_Part34_StrategyHealthDashboard.mqh`

The dashboard and `GPT_EA_StrategyHealth.csv` expose strategy status, sample size, win rate, average R, profit factor, max drawdown, recent performance, realized win/loss R ratio, learned slippage, current-regime evidence, champion/challenger status and current risk multiplier.

## Integration layer

`GPT_EA_Part35_AdaptiveIntegration.mqh` inserts the adaptive system into the existing selector, pre-authorization risk check, GPT review, notification/decision snapshot, init/timer and UI cleanup boundaries. `GPT_EA.mq5` applies final adaptive sizing and learned slippage to the actual Part05 order path.

## Release rule

R5 is not live-certified until `ADAPTIVE_EXECUTION_TEST_MATRIX.md` and all pre-existing release matrices pass on the exact candidate artifacts and intended broker/account/symbol environment.