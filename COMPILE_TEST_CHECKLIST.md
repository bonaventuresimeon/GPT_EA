# GPT_EA Compile & Test Checklist

This checklist is the release gate for `GPT_EA.mq5`. A build should not be promoted from development → demo → live until the applicable sections pass.

## 1. MetaEditor compile gate

Open `GPT_EA.mq5` in the same MT5 installation that will run the EA.

- [ ] Compile `GPT_EA.mq5` with **0 errors**.
- [ ] Review every warning; target **0 warnings** for release builds.
- [ ] Confirm all local includes resolve:
  - `GPT_EA_Part01.mqh`
  - `GPT_EA_Part02.mqh`
  - `GPT_EA_Part03.mqh`
  - `GPT_EA_Part04.mqh`
  - `GPT_EA_Part08_Advanced.mqh`
  - `GPT_EA_Part09_RiskRecoveryAnalytics.mqh`
  - `GPT_EA_Part10_BrokerUniversalRecovery.mqh`
  - `GPT_EA_Part05.mqh`
  - `GPT_EA_Part06.mqh`
  - `GPT_EA_Part07.mqh`
- [ ] Confirm exactly one `OnInit`, `OnDeinit`, `OnTimer`, `OnTick`, `OnChartEvent`, and `OnTradeTransaction` implementation is compiled.
- [ ] Confirm no real OpenAI key is present in source control.
- [ ] Confirm terminal Algo Trading is enabled before demo execution tests.

## 2. Broker/account preflight

Record the test environment before execution tests.

- [ ] Broker company and trade server printed correctly.
- [ ] Account currency detected correctly.
- [ ] Account leverage detected correctly.
- [ ] Account margin mode detected correctly: netting / exchange / retail hedging.
- [ ] `ACCOUNT_TRADE_ALLOWED` is true.
- [ ] `ACCOUNT_TRADE_EXPERT` is true.
- [ ] Margin Call and Stop Out settings are understood for the account.
- [ ] Test on both demo and intended live account type when their contract specifications differ.

## 3. Symbol-resolution matrix

Test configured logical symbols against the broker's actual names. Examples should include suffixes/prefixes where offered.

- [ ] Exact names resolve, e.g. `EURUSD` → `EURUSD`.
- [ ] Suffix names resolve, e.g. `EURUSD` → `EURUSDm`, `EURUSD.a`, `EURUSD#`.
- [ ] Gold aliases resolve, e.g. `XAUUSD` / `GOLD`.
- [ ] NASDAQ aliases resolve, e.g. `US100`, `NAS100`, `USTEC`, `NASDAQ100`.
- [ ] DAX aliases resolve, e.g. `GER40`, `DE40`, `DAX40`.
- [ ] Oil aliases resolve, e.g. `WTI`, `USOIL`, `BRENT`, `UKOIL`.
- [ ] Crypto symbols resolve where the broker offers them.
- [ ] An arbitrary broker-specific stock/ETF/future symbol can be used by entering its actual broker name.
- [ ] Unknown/unavailable symbols fail safely and do not create orders.
- [ ] `AUTO` resolves only available instruments.
- [ ] Optional Market Watch universe respects `InpMaxMarketWatchSymbols`.

For every resolved symbol verify the printed runtime profile:

- [ ] digits / point
- [ ] tick size
- [ ] profit/loss tick value
- [ ] contract size
- [ ] min/max/step volume
- [ ] directional volume limit
- [ ] fixed/floating spread flag
- [ ] current spread in points
- [ ] stops level
- [ ] freeze level
- [ ] trade mode
- [ ] filling mode
- [ ] margin currency
- [ ] buy/sell 1-lot margin estimate

## 4. Cross-asset sizing tests

Use a fixed risk percentage and manually compare the loss at SL with the intended account-currency risk.

- [ ] FX major
- [ ] JPY pair
- [ ] gold/metal
- [ ] US equity index CFD
- [ ] European equity index CFD
- [ ] oil/energy CFD
- [ ] crypto CFD where supported
- [ ] stock/ETF/future where supported

Pass criterion: `OrderCalcProfit()`-based stop loss for the calculated volume is acceptably close to configured risk after broker volume-step rounding.

## 5. Broker execution-rule tests

- [ ] Minimum volume rejection works.
- [ ] Maximum volume rejection works.
- [ ] Volume-step rejection works.
- [ ] Directional volume-limit rejection works.
- [ ] Disabled symbol is rejected.
- [ ] Close-only symbol is rejected.
- [ ] Long-only/short-only restrictions are respected.
- [ ] SL/TP inside broker stop level is rejected before order send.
- [ ] SL/TP are normalized to broker tick size.
- [ ] Insufficient free margin is rejected.
- [ ] `InpMaxNewTradeMarginPctFree` cap is enforced.
- [ ] Broker filling mode is selected through `SetTypeFillingBySymbol()`.

## 6. Spread/slippage/R:R tests

Test once in normal conditions and once during a deliberately wider-spread session on demo.

- [ ] Current spread is read from broker Bid/Ask.
- [ ] M5 ATR is available.
- [ ] Dynamic slippage stays between configured min/max points.
- [ ] Effective R:R falls when spread/slippage expands.
- [ ] Setup is rejected if effective R:R drops below `InpMinEffectiveRR`.
- [ ] Actual fill slippage is recorded by trade transaction handling.

## 7. Multi-timeframe and setup logic

For each tested symbol:

- [ ] D1 loaded.
- [ ] H4 loaded.
- [ ] H1 loaded.
- [ ] M30 loaded.
- [ ] M15 loaded.
- [ ] M5 loaded.
- [ ] Pullback setup produces coherent entry/SL/TP geometry.
- [ ] Breakout-retest requires the intended breakout/retest conditions.
- [ ] Sweep → displacement → retest filter behaves as configured.
- [ ] Level-touch score changes as a level is repeatedly tested.
- [ ] Market regime classification is plausible.
- [ ] Advanced confluence cannot exceed 100 or become negative.

## 8. Calendar, session and yield tests

Run in a terminal that provides the native economic calendar.

- [ ] Relevant USD events map to XAUUSD/US indices.
- [ ] Relevant EUR events map to GER40/EUR instruments.
- [ ] High-impact pre/post event window blocks authorization.
- [ ] Upcoming-event summary displays without creating a false block outside the configured window.
- [ ] London pre-open scan fires at configured London local time.
- [ ] London hourly scans fire once per scheduled minute.
- [ ] U.S. scan is anchored to 09:30 New York local time.
- [ ] UK/U.S. DST transition weeks do not shift the New York open incorrectly.
- [ ] Treasury-yield filter fails safely if broker does not offer the configured yield symbol.
- [ ] Treasury-yield shock blocks authorization when threshold is exceeded.

## 9. APPROVE / DENY tests

- [ ] No APPROVE prompt appears unless hard filters pass and entry trigger is ready.
- [ ] APPROVE executes only after fresh validation.
- [ ] Price leaving entry zone after prompt causes approval to fail safely.
- [ ] Spread widening after prompt causes approval to fail safely.
- [ ] News/yield/risk change after prompt causes approval to fail safely.
- [ ] DENY removes setup.
- [ ] Timeout removes setup.
- [ ] DENY/timeout starts cooldown.
- [ ] Duplicate click cannot send a second order.
- [ ] PAUSE clears pending approvals and blocks new authorization.
- [ ] RESUME restores scanning without auto-executing stale approvals.

## 10. Portfolio-risk tests

Create multiple demo positions to verify aggregate controls.

- [ ] Single-symbol risk cap blocks excess proposed risk.
- [ ] Total portfolio-risk cap blocks excess aggregate risk.
- [ ] Same-direction US100/GER40 exposure is treated as correlated index risk.
- [ ] An existing GPT_EA position without SL blocks additional risk.
- [ ] Daily loss kill switch blocks new entries.
- [ ] Equity high-water drawdown kill switch blocks new entries.
- [ ] Consecutive-loss kill switch blocks new entries.
- [ ] Existing trades continue to be managed while new entries are blocked.

## 11. TP1 / trade-management tests

- [ ] TP1 partial closes configured percentage.
- [ ] Netting account reduction behaves correctly.
- [ ] Hedging account partial close behaves correctly.
- [ ] BE stop moves in correct direction with cost buffer.
- [ ] TP1 flag persists after partial close.
- [ ] Pre-TP1 candle expiry closes stale trade.
- [ ] Fast ATR/opening-range regime shortens expiry.
- [ ] Slow regime lengthens expiry within configured bounds.
- [ ] Post-TP1 stall logic closes remainder only when barrier + momentum/reversal conditions are met.

## 12. Restart/crash recovery matrix

Repeat these tests by removing/re-attaching EA and by restarting MT5 on demo.

- [ ] Restart with no open trade/no pending approval.
- [ ] Restart with a pending approval still inside timeout.
- [ ] Restart after pending approval expired while terminal was offline.
- [ ] Restart immediately after order fill.
- [ ] Restart before TP1.
- [ ] Restart immediately after TP1 partial close.
- [ ] Restart after BE movement.
- [ ] Restart with multiple GPT_EA positions.
- [ ] Restart when position ticket changed but `POSITION_IDENTIFIER` is unchanged.
- [ ] Restart after a symbol suffix/prefix changed on a migrated demo server.
- [ ] Recovery file from a different account login is ignored.
- [ ] Recovery file from a different server is ignored when mismatch rejection is enabled.
- [ ] Missing terminal Global Variables are rebuilt from disk/history where possible.
- [ ] Missing disk checkpoint falls back to terminal globals/history.
- [ ] Recovered pending setup is re-scanned and cannot bypass fresh validation.
- [ ] Recovered position with moved SL does not reconstruct original risk from BE if historical initial SL is available.
- [ ] Partial exit history is recognized so TP1 is not taken twice.
- [ ] Finalized trade analytics are not duplicated after restart.

Note: terminal Global Variables are not permanent storage; the EA therefore uses both terminal globals and an account/magic-specific common-files checkpoint.

## 13. Analytics validation

Follow `ANALYTICS_SCHEMA.md`.

- [ ] ENTRY event generated once per new position identifier.
- [ ] EXIT_PART generated for each partial/final exit deal.
- [ ] CLOSED generated once per completed position identifier.
- [ ] requested and actual prices use symbol digits.
- [ ] slippage uses symbol points.
- [ ] realized R uses original planned monetary risk.
- [ ] MAE_R never negative.
- [ ] MFE_R never negative.
- [ ] Pullback and breakout-retest statistics remain separate.
- [ ] Profit factor uses positive-R / absolute-negative-R totals.
- [ ] Consecutive-loss count resets on a profitable completed trade.

## 14. OpenAI integration test

Do this on demo/live terminal, not Strategy Tester.

- [ ] `https://api.openai.com` is added to MT5 WebRequest allow-list.
- [ ] Blank key fails safely.
- [ ] Invalid key fails safely.
- [ ] Network timeout fails safely.
- [ ] AI unavailable does not bypass deterministic controls.
- [ ] WAIT/INVALID veto works if enabled.
- [ ] No API secret appears in Experts/Journal logs.

## 15. DOM / ONNX optional tests

DOM:
- [ ] `MarketBookAdd()` succeeds for a symbol that supports DOM.
- [ ] No DOM fails open or closed according to `InpRequireDOMConfirmation`.
- [ ] Bid/ask imbalance direction is correct.

ONNX:
- [ ] Model exists in expected MT5 file area.
- [ ] Input shape `[1,12]` accepted.
- [ ] Output shape `[1,1]` accepted.
- [ ] Inference probability is bounded 0..1.
- [ ] Missing/invalid model cannot bypass deterministic controls.

## 16. Strategy Tester gate

Because WebRequest and some terminal services differ in Strategy Tester, validate deterministic logic separately.

- [ ] No array-out-of-range errors.
- [ ] No zero-divide errors.
- [ ] No invalid indicator handles left unreleased.
- [ ] No runaway log spam.
- [ ] No duplicate position for same symbol beyond configured maximum.
- [ ] Risk per trade matches intended range across history.
- [ ] Maximum drawdown is reviewed.
- [ ] Pullback and breakout-retest statistics are reviewed separately.
- [ ] Spread assumptions match the tester configuration.

## 17. Demo soak test

Minimum release recommendation before live funds:

- [ ] Run continuously across multiple London and U.S. sessions.
- [ ] Include at least one high-impact news day.
- [ ] Include a weekend terminal restart.
- [ ] Include at least one broker spread expansion/rollover period.
- [ ] Verify recovery checkpoint and execution CSV continue writing.
- [ ] Review every rejected order and every broker retcode.
- [ ] Confirm no unexplained duplicate orders.

## 18. Live release gate

- [ ] Compile gate passed.
- [ ] Broker/symbol matrix passed on intended live account.
- [ ] Demo soak passed.
- [ ] Start with approved execution and conservative risk.
- [ ] Keep `InpRequireApproval=true` for initial live validation.
- [ ] Keep ONNX/DOM optional unless separately validated on the live broker.
- [ ] Archive the `.ex5`, input preset, commit SHA, analytics schema version and broker profile used for the release.
