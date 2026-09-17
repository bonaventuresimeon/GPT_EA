# GPT_EA R5 Adaptive Execution Release Test Matrix

This matrix is release-blocking for the R5 adaptive stack. A source-level implementation is not a PASS. Evidence must come from MetaEditor, Strategy Tester where applicable, and demo/terminal testing where live calendar, broker execution or WebRequest behavior is required.

## A. Portfolio correlation and macro concentration

### AR-001 same-direction correlated positions
- Open or simulate one index position, then evaluate a strongly positively correlated same-direction index candidate.
- Verify rolling M15 directional correlation increases weighted portfolio risk.
- Verify the candidate blocks when `InpMaxCorrelationWeightedRiskPercent` is exceeded.

### AR-002 opposite-direction hedge
- Repeat with a materially negatively aligned exposure.
- Verify the engine does not incorrectly count the entire existing position as same-theme risk.

### AR-003 macro factor concentration
- Build multiple USD/risk-on exposures across supported symbol classes.
- Verify the USD/risk-on factor cap can block a candidate even when the ordinary portfolio cap has not yet been reached.

### AR-004 missing correlation history
- Use a newly loaded symbol with insufficient M15 history.
- Verify missing correlation does not fabricate a strong positive correlation.
- Existing hard portfolio caps must still apply.

## B. Per-strategy risk budgets

### AR-010 daily budget isolation
- Exhaust one strategy's daily budget with realized loss/open risk.
- Verify only that strategy is blocked by its strategy budget.
- Verify unrelated strategy classes remain eligible subject to all other gates.

### AR-011 weekly budget
- Verify losses/open risk across multiple days consume the weekly budget until the trading-week reset.

### AR-012 risk normalization
- Verify actual normalized broker lot risk, not only the pre-rounding target, is used in authorization evidence.

## C. Confidence calibration

### AR-020 developing sample
- With fewer than `InpConfidenceCalibrationMinSamples`, raw confidence remains unchanged and is labelled developing evidence.

### AR-021 overconfident bucket
- Seed/obtain a confidence bucket whose observed win rate is materially below its raw forecast.
- Verify calibrated confidence falls after the minimum sample.
- Verify a selected setup below `InpMinCalibratedConfidence` is downgraded from high-confidence authorization.

### AR-022 underconfident bucket
- Verify positive calibration never bypasses strategy, risk, news, release or broker gates.

### AR-023 single-pass rule
- Verify the selected candidate is calibrated once per scan rather than repeatedly shrinking the same confidence value.

## D. Execution-quality learning

### AR-030 fill capture
For a successful order verify `GPT_EA_ExecutionLearning.csv` records:
- expected entry;
- request price;
- actual fill;
- spread at request/fill;
- slippage;
- latency;
- lots/risk;
- strategy/session/event context.

### AR-031 failed request
- Force a broker rejection.
- Verify symbol execution attempt/failure counts update without fabricating a fill.

### AR-032 restart durability
- Restart after fills and verify learning GVs remain available for forecasts.

### AR-033 commission finalization
- Close an adaptive trade and verify actual deal commissions are aggregated into the post-trade record.

## E. Market-condition kill switch

### AR-040 spread expansion
- Force/observe spread-to-ATR beyond the configured kill threshold.
- Verify one abnormal component increments the score without necessarily blocking unless the total score reaches the configured limit.

### AR-041 compound abnormal state
- Combine at least the configured number of conditions: spread expansion, violent M1 range, extreme ATR/opening range, stale quotes or yield shock.
- Verify new exposure is blocked.
- Verify existing positions continue management.

### AR-042 normalization recovery
- When abnormal conditions clear, verify the supervisor can permit new candidates again without clearing unrelated manual/operator safety pauses.

## F. Dynamic sizing

### AR-050 base ceiling
- Verify adaptive sizing never intentionally exceeds `InpRiskPercent` base risk.

### AR-051 reduced-risk strategy
- Put a strategy into `REDUCED_RISK` and verify final risk decreases.

### AR-052 event/drawdown/broker reductions
- Independently trigger event proximity, drawdown reduction and weaker broker health.
- Verify each can reduce the multiplier.

### AR-053 regime transition multiplier
- Trigger a market-state transition.
- Verify `REGIME_RISK_MULT` reduces the final normalized lot during the caution window and returns to 1.0 only after the configured period.

## G. Strategy degradation

### AR-060 ACTIVE
- Positive/stable recent sample remains ACTIVE.

### AR-061 REDUCED_RISK
- Recent average R/PF below reduced-risk thresholds changes only that strategy to REDUCED_RISK.

### AR-062 SHADOW
- Worse deterioration moves strategy to SHADOW and prohibits live exposure while research/shadow tracking remains active.

### AR-063 DISABLED
- Severe deterioration moves strategy to DISABLED and blocks live exposure.

### AR-064 insufficient sample
- Below minimum sample, do not infer deterioration solely from one or two trades.

## H. MAE/MFE research

### AR-070 open excursion
- Verify MFE increases only when new favorable R extremes occur.
- Verify MAE records adverse R magnitude and does not become negative.

### AR-071 close aggregation
- Close a trade and verify strategy MAE/MFE aggregate N/sums update once.
- Restart and verify `ADAPT_FINAL` prevents duplicate finalization.

## I. Event-specific behavior

### AR-080 classification
On demo terminal verify representative calendar names classify correctly for:
- CPI/inflation;
- PPI;
- NFP/employment;
- FOMC/Fed;
- ECB;
- BoE;
- GDP;
- PMI;
- retail sales;
- central-bank speech;
- other high impact.

### AR-081 negative event/strategy evidence
- With sufficient negative sample, verify the matching strategy/event context blocks when configured.

### AR-082 Strategy Tester limitation
- Confirm native event model does not fabricate calendar events when the tester cannot supply them.

## J. Spread/slippage forecast

### AR-090 learned forecast
- Accumulate execution samples where actual slippage exceeds the current dynamic estimate.
- Verify forecast uses the worse learned symbol/strategy/session estimate.

### AR-091 R:R degradation
- Verify a setup whose current theoretical R:R passes but learned execution forecast drops below floor is rejected.

### AR-092 deviation ceiling
- Verify learned slippage influences order deviation but remains bounded by `InpMaxDynamicSlippagePoints`.

## K. Broker-health score

### AR-100 healthy broker
- Fresh quotes, stable spread, low failure/slippage and no active stop problems should remain above health threshold.

### AR-101 degraded broker
- Introduce stale quotes/rejections/high slippage/stop failures.
- Verify score falls and blocks new exposure below threshold.
- Verify existing positions remain managed.

## L. Lifecycle state machine

### AR-110 normal path
Verify observable sequence:
`CANDIDATE -> WAIT_CONFIRMATION -> APPROVED -> SENT -> FILLED -> TP1_PARTIAL -> PROTECTED -> RUNNER -> CLOSED` as applicable.

### AR-111 invalid transition
- Attempt an illegal transition in a controlled harness.
- Verify it is rejected and journaled/printed rather than silently accepted.

### AR-112 denial/timeout
- Denied/expired approval must move to an invalidated/rejected terminal state and start cooldown where configured.

### AR-113 restart reconstruction
- Restart with a FILLED, TP1-partial, protected and runner position in separate cases.
- Verify state reconstructs from broker/durable flags without repeating partial actions.

## M. Replayable decision snapshots

### AR-120 schema
Verify `GPT_EA_DecisionSnapshots.csv` records:
- strategy/state/decision/direction;
- entry zone, entry, SL, targets;
- confidence/strategy score;
- ATR/opening-range/ADX/RSI/overextension/volume;
- realistic R:R;
- adaptive multiplier;
- broker health/strategy mode/regime transition;
- GPT checksum/excerpt where review occurred.

### AR-121 replay consistency
- Select a saved snapshot and compare values to archived card/log/chart evidence from the same server time.

## N. Counterfactual analytics

### AR-130 rejected setup
- Generate WAIT/filtered setup.
- Verify no broker order occurs but rejected counterfactual shadow can progress to stop/target/expiry outcome.

### AR-131 PB vs BRT
- When both geometries exist, verify the alternative Pullback and Breakout-Retest simulations use independent shadow state and statistics.

### AR-132 same-bar ambiguity
- Create a bar that touches both SL and TP2.
- Verify conservative stop outcome rather than optimistic target outcome.

## O. Learned expiry

### AR-140 developing sample
- Below `InpLearnedExpiryMinSamples`, existing strategy/ATR/opening-range expiry remains in force.

### AR-141 percentile
- After sufficient time-to-TP1 samples, verify selected percentile yields the expected M15 candle budget within the configured max.

### AR-142 no TP1
- Trades that never reach TP1 must not fabricate a time-to-TP1 observation.

## P. Regime transitions

### AR-150 transition record
- Trigger/identify a state change and verify FROM/TO/time are durable.

### AR-151 mature regime
- After caution bars elapse without another transition, verify transition sizing returns to normal subject to all other risk factors.

## Q. Independent risk supervisor

### AR-160 precedence
- Provide an otherwise high-confidence/GPT-approved setup while a supervisor block is active.
- Verify GPT cannot override the supervisor.

### AR-161 drawdown acceleration
- Increase drawdown by the configured percentage-point threshold inside the window.
- Verify new exposure blocks.

### AR-162 independent recovery
- Clearing one supervisor condition must not bypass another active stop/release/manual pause.

## R. GPT disagreement architecture

### AR-170 agreement
- Deterministic LONG + GPT validation without veto/opposite direction can pass this gate.

### AR-171 strong disagreement
- Deterministic LONG + GPT explicit SHORT/NO TRADE/BLOCK response reaches configured disagreement threshold.
- Verify result is WAIT/blocked; deterministic geometry is not reversed into a short.

### AR-172 unavailable GPT
- Verify behavior follows existing `InpBlockIfAIUnavailable`/review policy and the stored integrity state cannot become a fabricated positive review.

## S. Model-output integrity

### AR-180 malformed/too short
- Inject a too-short/malformed response and verify integrity blocks when GPT review was requested.

### AR-181 parser fallback
- Inject parser fallback text and verify block.

### AR-182 credential-like response
- Inject `Authorization: Bearer`/API-key-like text and verify block/log behavior without persisting a real secret.

### AR-183 stale stored review
- Let the stored AI review exceed `InpStoredAIReviewMaxAgeSeconds` before execution.
- Verify reanalysis is required.

### AR-184 contradictory setup geometry
- Corrupt a bullish candidate so SL is above entry or targets descend.
- Verify deterministic integrity blocks before order placement.

## T. Champion / challenger

### AR-190 shadow only default
- With `InpAutoPromoteChallenger=false`, a challenger may become statistically eligible but must not replace the live selector.

### AR-191 minimum sample
- Verify promotion eligibility cannot occur before both champion and challenger reach `InpChampionChallengerMinSamples`.

### AR-192 multi-metric promotion
- Higher win rate alone must not promote a challenger.
- Verify avg-R, PF, DD and stability conditions all apply.

### AR-193 explicit promotion
- Only after separate validation, enable auto-promotion and verify the eligible PB/BRT candidate can replace selected execution geometry while all downstream gates still apply.

### AR-194 stability deterioration
- A challenger with attractive mean performance but excessive configured instability must remain ineligible.

## U. Strategy Health Dashboard

### AR-200 dashboard state
- Verify every executable strategy displays status, N, avg R, PF, DD, recent metrics, realized R ratio, learned slippage, current regime evidence and risk multiplier.

### AR-201 CSV
- Verify `GPT_EA_StrategyHealth.csv` periodically records the same strategy-health state without duplicate per-timer flooding.

### AR-202 status/action agreement
- A strategy shown as SHADOW/DISABLED must not receive live exposure.

## V. Integration / regression

### AR-210 no bypass
- Verify existing release, stop, partial-protection, calendar/web, intermarket, portfolio, cooldown, broker and OrderCheck gates still execute.

### AR-211 no double partial / no stop regression
- Rerun HIGH stop/partial-protection regression cases after R5 adaptive integration.

### AR-212 live release fail closed
- On REAL with any R5 adaptive release-attestation flag false, verify new entries remain blocked even with the live-arm phrase set.

### AR-213 demo/test availability
- Demo and Strategy Tester remain usable for evidence generation without requiring completed live release attestations.

### AR-214 restart / persistence
- Restart during active shadow simulation, live trade, pending approval and strategy degradation states. Verify no duplicate orders/partials/history finalization.

## R5 pass rule

R5 must not be armed live unless all applicable HIGH cases pass and evidence is archived for:

- adaptive portfolio/correlation/strategy budgets;
- execution learning/calibration/event/MAE-MFE/expiry/regime transition;
- champion/challenger and counterfactuals;
- lifecycle/integrity/replay;
- all pre-existing intelligence, broker, recovery, stop, partial-protection, WebRequest and demo-soak release gates.

The R5 release attestation flags must remain false until that evidence exists.