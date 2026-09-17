# GPT_EA Compile & Release Test Checklist

This is the master release gate for `GPT_EA.mq5`. Do not promote a build development → demo → live until every applicable HIGH/release-blocking item passes.

## 1. MetaEditor compile gate

- [ ] Compile `GPT_EA.mq5` with **0 errors**.
- [ ] Review every warning; target **0 warnings** for release builds.
- [ ] Confirm all includes referenced by `GPT_EA.mq5` resolve, including the intelligence, safety, stop-policy and observability modules.
- [ ] Confirm exactly one `OnInit`, `OnDeinit`, `OnTimer`, `OnTick`, `OnChartEvent`, and `OnTradeTransaction` implementation is compiled.
- [ ] No committed API key or armed real-account secret/value exists in source.
- [ ] Record MetaTrader/MetaEditor build number.

Current entry-file module families include:

- core: Parts 01–04;
- advanced confluence/risk/recovery: Parts 08–12;
- forward declarations: Part 00;
- stop policy/observability/advanced management: Parts 14, 18, 13;
- strategy intelligence/framework/context/targets/research/session hardening: Parts 15, 15B, 15C, 15D, 21, 24;
- realistic cost/continuous intelligence: Parts 20, 19;
- news/intermarket/freshness/response parsing: Parts 16, 16A, 22A, 22P, 22;
- thesis/deep GPT/observability hardening: Parts 17, 25, 26, 23;
- execution/UI/event lifecycle: Parts 05–07.

## 2. Broker/account preflight

- [ ] Broker company/server correct.
- [ ] Account currency correct.
- [ ] Account leverage correct.
- [ ] Margin mode correct: hedging/netting/exchange.
- [ ] `ACCOUNT_TRADE_ALLOWED` true.
- [ ] `ACCOUNT_TRADE_EXPERT` true.
- [ ] `TERMINAL_TRADE_ALLOWED` true for execution tests.
- [ ] `MQL_TRADE_ALLOWED` true for execution tests.
- [ ] Margin Call / Stop Out policy recorded.
- [ ] Broker symbol profile archived for every live symbol.

## 3. Release-blocking safety gates

Follow `RELEASE_SAFETY_GATES.md` and `RECOVERY_INVARIANTS.md`.

- [ ] Disconnected terminal blocks new entries.
- [ ] Terminal/account/EA permission failure blocks new entries.
- [ ] Unsynchronized D1/H4/H1/M30/M15/M5 blocks new entries.
- [ ] Required timeframe with insufficient bars blocks.
- [ ] Stale quote blocks.
- [ ] Missing market-order capability blocks.
- [ ] Missing SL capability blocks.
- [ ] Recovery invariant failure blocks.
- [ ] Existing positions remain managed while new-entry gate is blocked.
- [ ] Real account with blank/incorrect arm phrase blocks.
- [ ] Real account with approval disabled blocks when approval is required.
- [ ] Correct arm phrase does not bypass any other safety gate.

## 4. Recovery invariants

- [ ] Every open GPT_EA position has nonzero `POSITION_IDENTIFIER`.
- [ ] Entry/volume valid.
- [ ] Current SL exists unless the critical recovery path is actively handling SL=0.
- [ ] Original SL recoverable.
- [ ] Original BUY SL below entry; SELL SL above entry.
- [ ] Open position not analytics `FINAL=1`.
- [ ] TP geometry directional and ordered.
- [ ] No duplicate active pending approval per symbol.
- [ ] Pending approval timestamps/geometry valid.
- [ ] Day-risk/high-water state valid.
- [ ] Netting reversal mismatch pauses/requires review when configured.
- [ ] Completed checkpoint/backup recovery passes restart tests.

## 5. Broker/symbol/contract matrix

Run `BROKER_MATRIX_TESTS.md` on every intended broker/account combination.

Minimum coverage:

- [ ] exact FX symbol;
- [ ] prefix/suffix FX;
- [ ] XAUUSD/GOLD;
- [ ] US100/NAS100/USTEC;
- [ ] GER40/DE40/DAX40;
- [ ] WTI/USOIL and BRENT/UKOIL;
- [ ] crypto where supported;
- [ ] proprietary stock/ETF/future using actual broker name;
- [ ] unknown symbol fails safely;
- [ ] AUTO/Market Watch cap respected.

For representative assets verify digits, point, tick size/value, contract size, min/max/step volume, directional limit, spread type/current spread, stop/freeze level, trade/execution/filling modes, margin currency and calculation mode.

## 6. Risk sizing, margin and `OrderCheck()`

- [ ] `OrderCalcProfit()` risk sizing matches intended monetary risk after volume-step rounding.
- [ ] FX, JPY, metal, U.S. index, European index, energy, crypto and stock/future cases tested where supported.
- [ ] invalid min/max/step volume rejected.
- [ ] directional volume limit enforced.
- [ ] disabled/close-only/long-only/short-only modes enforced.
- [ ] SL/TP normalized to tick size.
- [ ] too-close stop rejected.
- [ ] insufficient margin rejected.
- [ ] new-trade free-margin cap enforced.
- [ ] supported filling policy selected.
- [ ] valid `OrderCheck()` passes.
- [ ] rejected `OrderCheck()` suppresses approval readiness.
- [ ] `OrderCheck()` runs again immediately before send.
- [ ] projected margin-level floor enforced.

## 7. Full intelligence / strategy gate

Follow `ADVANCED_INTELLIGENCE_CONTRACT.md` and `FULL_INTELLIGENCE_COVERAGE.md`.

- [ ] D1/H4/H1/M30/M15/M5 synchronized and included in analysis.
- [ ] market state distinguishes continuation/retracement/correction/trend failure/reversal/breakout/false breakout/liquidity sweep/range/mean reversion/exhaustion/consolidation states.
- [ ] strategy classification displayed before entry recommendation.
- [ ] counter-trend classes require stricter threshold/confirmation.
- [ ] strategy framework named and regime-appropriate.
- [ ] structure/liquidity-aware targets used with measured-R fallback.
- [ ] realistic R:R includes spread, modeled slippage, commission estimate and configured partial exits.
- [ ] continuous intelligence scan triggers on configured interval/new M5 bar.
- [ ] 25-point thesis rendered for candidate setup.
- [ ] explicit counterargument/disproof section present.
- [ ] historical/context evidence does not use future outcome leakage.
- [ ] weak/contradictory candidate returns WAIT/NO TRADE rather than forced entry.

## 8. News/intermarket/session gate

- [ ] native economic-calendar event block works.
- [ ] upcoming event summary does not falsely block outside configured window.
- [ ] live web/news layer follows availability policy.
- [ ] unexpected headline/news risk cannot silently pass a stale approval.
- [ ] Treasury-yield filter behaves according to configured symbol/availability policy.
- [ ] DXY/yield/equity/gold/oil/volatility/correlated-market evidence is handled when available and relevant.
- [ ] London 08:55/09:00 and New York 09:25/09:30 schedules correct.
- [ ] UK/U.S. DST transition weeks correct.
- [ ] strategy-specific session hardening behaves as documented.

## 9. APPROVE / DENY / pre-entry revalidation

- [ ] no APPROVE-ready state unless strategy + intelligence + release + risk + broker + `OrderCheck()` + trigger gates pass.
- [ ] approval expires correctly.
- [ ] DENY deletes candidate and starts cooldown.
- [ ] duplicate click cannot duplicate order.
- [ ] manual PAUSE clears pending approvals.
- [ ] price leaving zone after prompt cancels execution.
- [ ] strategy classification change cancels/recalculates setup.
- [ ] spread/news/intermarket/risk/stop-health change after prompt cancels execution.
- [ ] final `ApprovedPlaceTrade()` rechecks stop observability before order send.

## 10. TP1 / breakeven / partial protection — RELEASE BLOCKING

Run `PARTIAL_PROTECTION_RELEASE_TEST.md` in addition to the general stop matrix.

- [ ] TP1 partial executes exactly once.
- [ ] `TP1PARTIAL=1` persists independently of BE.
- [ ] `PARTIAL_PROTECTION_STARTED` emitted if BE is not already complete.
- [ ] BE uses current cost-aware buffer.
- [ ] stop/freeze rejection preserves prior SL.
- [ ] BE retries use fresh broker geometry.
- [ ] `TP1DONE=0` while required protection remains incomplete.
- [ ] after timeout, `PARTIAL_PROTECTION_HAZARD` emitted once.
- [ ] hazard independently blocks new approvals/execution.
- [ ] existing trade continues to be managed.
- [ ] BE recovery never repeats TP1 partial.
- [ ] `PARTIAL_PROTECTION_COMPLETED` emitted when protection completes before hazard.
- [ ] `PARTIAL_PROTECTION_RECOVERED` emitted when a prior hazard later clears.
- [ ] restart in `TP1PARTIAL=1` / `TP1DONE=0` state does not duplicate partial or lose lifecycle.
- [ ] BUY and SELL variants pass.
- [ ] hedging/netting variants pass where supported.

## 11. Advanced profit lock / trailing

- [ ] configured profit lock applies only after its trigger.
- [ ] strong lock applies only after its trigger.
- [ ] trailing starts only at/after trail trigger.
- [ ] ATR + M5 structure logic used.
- [ ] minimum improvement step enforced.
- [ ] BUY SL never decreases.
- [ ] SELL SL never increases.
- [ ] tick size / stop / freeze rules respected.
- [ ] runner mode removes fixed TP only when actual trailing begins if configured.
- [ ] fixed-TP mode retains TP3 while trailing.
- [ ] stop-stage events match broker position history.

## 12. Broker-specific stop-failure handling — RELEASE BLOCKING

Follow `BROKER_STOP_FAILURE_POLICY.md` and `STOP_UPDATE_FAILURE_POLICY.md`.

- [ ] `INVALID_STOPS` / stop-level failure → current SL preserved; distance-clear retry.
- [ ] `FROZEN` → current SL preserved; freeze-clear retry.
- [ ] `MARKET_CLOSED` → slower wait-market-open policy.
- [ ] `REQUOTE_PRICE_CHANGED` / `INVALID_PRICE` → fresh-price retry.
- [ ] `NO_QUOTES` / `CONNECTION` → wait fresh quote/connection.
- [ ] `RATE_LIMIT` / `TRADE_CONTEXT_LOCKED` → backoff, not timer spam.
- [ ] `TRADING_DISABLED` / `INVALID_FILL` / `INVALID_VOLUME` → operator/broker-change policy and new-entry block.
- [ ] `NO_CHANGES` remains a no-op condition.
- [ ] `POSITION_CLOSED` stops lifecycle management.
- [ ] `PROTECTION_MISSING` enters critical protect-or-close path.
- [ ] class/action/retry state keyed by `POSITION_IDENTIFIER`.
- [ ] repeated failures pause at configured threshold.
- [ ] later successful protection clears position failure state but does not silently clear an escalated manual/global pause.

## 13. Stop-management matrix — RELEASE BLOCKING

Run all applicable HIGH-priority cases in `STOP_MANAGEMENT_TEST_MATRIX.md`.

Required minimum sequences:

- [ ] full BUY TP1 → BE → profit lock → strong lock → trail → TP2/runner lifecycle;
- [ ] full SELL lifecycle;
- [ ] broker distance/freeze failure and recovery;
- [ ] missing-SL restoration;
- [ ] missing-SL emergency close path;
- [ ] restart during failed BE;
- [ ] restart after BE/profit lock/strong lock/trailing/TP2;
- [ ] manual stronger SL preserved;
- [ ] stale quote / spread shock / reconnect cases;
- [ ] netting reversal protection.

## 14. Stop-failure observability — RELEASE BLOCKING

Follow:

- `STOP_FAILURE_OBSERVABILITY_CONTRACT.md`
- `STOP_OBSERVABILITY_TEST_MATRIX.md`

- [ ] `GPT_EA_StopFailures.csv` created with `stop_failure_observability_v2` schema when enabled.
- [ ] stable numeric `class_code` and `action_code` are present.
- [ ] failure rows include broker/server/account/symbol/position context.
- [ ] retry seconds and next retry timestamp reflect class policy.
- [ ] failure count increments only on controlled retry cycles.
- [ ] recovery event emitted before failure class/action state clears.
- [ ] critical SL=0 state observable.
- [ ] emergency-close attempt observable.
- [ ] emergency-close failure observable when rejected.
- [ ] partial-protection start/completion/hazard/recovery observable.
- [ ] stop CSV joins to execution journal and broker history by `POSITION_IDENTIFIER`.
- [ ] ticket changes do not break lifecycle joins.
- [ ] recorded current SL matches broker state within symbol precision.

## 15. Portfolio/daily protection

- [ ] symbol risk cap.
- [ ] total portfolio risk cap.
- [ ] correlated directional risk cap.
- [ ] any unprotected open GPT_EA position blocks new risk.
- [ ] critical/operator-required stop-health state blocks new risk independently of global pause flag.
- [ ] daily loss kill switch.
- [ ] high-water drawdown kill switch.
- [ ] consecutive-loss kill switch.
- [ ] blocked new-entry state does not stop protective management of existing positions.

## 16. Restart/crash durability

- [ ] no-position/no-pending restart.
- [ ] pending approval valid/expired offline cases.
- [ ] restart immediately before/after order send.
- [ ] restart before TP1.
- [ ] restart after TP1 partial before BE.
- [ ] restart after BE/profit lock/strong lock/trailing/TP2.
- [ ] restart with stop failure count/class/action/next-retry active.
- [ ] ticket change, same identifier.
- [ ] deliberate netting reversal.
- [ ] account/server/magic mismatch rejected.
- [ ] truncated primary checkpoint uses completed backup.
- [ ] invalid primary + invalid backup fails safely.
- [ ] finalized analytics not duplicated.

## 17. Analytics / observability consistency

Follow `ANALYTICS_SCHEMA.md` plus the stop observability contract.

- [ ] one logical ENTRY per lifecycle.
- [ ] partial/final EXIT events correct.
- [ ] CLOSED once per identifier.
- [ ] final R uses original planned risk.
- [ ] MAE/MFE valid.
- [ ] strategy/context analytics join correctly.
- [ ] stop-stage events use durable position ID.
- [ ] stop-failure/recovery events use durable position ID.
- [ ] no future-outcome leakage into candidate feature records.

## 18. OpenAI / web intelligence / DOM / ONNX

OpenAI/web:
- [ ] blank/invalid API key fails according to configured availability policy.
- [ ] timeout/network failure cannot bypass deterministic gates.
- [ ] parser does not treat malformed response as confirmed setup.
- [ ] no API secret appears in source/logs.

DOM:
- [ ] subscription works where broker supports it.
- [ ] unavailable DOM follows optional/required policy.

ONNX:
- [ ] model shape contract validated.
- [ ] missing/invalid model cannot bypass risk/release gates.

## 19. Strategy Tester / static gate

- [ ] no array-out-of-range.
- [ ] no divide-by-zero.
- [ ] no indicator-handle leak.
- [ ] no duplicate position beyond configured limit.
- [ ] no runaway release/stop/news scan logging.
- [ ] historical risk plausible.
- [ ] drawdown reviewed.
- [ ] strategy classes reviewed separately where sample exists.

## 20. Demo soak

- [ ] multiple London/U.S. sessions.
- [ ] at least one high-impact news day.
- [ ] weekend/terminal restart.
- [ ] spread expansion/rollover period.
- [ ] checkpoint + backup + execution CSV + stop observability CSV persist.
- [ ] complete BUY and SELL stop-management lifecycle observed.
- [ ] controlled broker stop failure/recovery observed.
- [ ] controlled partial-protection hazard/recovery observed.
- [ ] controlled missing-SL emergency path observed.
- [ ] intended broker matrix completed.
- [ ] intelligence contract coverage reviewed.

## 21. Live release gate

Before setting the local live arm phrase:

- [ ] MetaEditor compile passed.
- [ ] release/recovery invariants passed.
- [ ] full-intelligence tests passed.
- [ ] intended live broker matrix passed.
- [ ] `BROKER_STOP_FAILURE_POLICY.md` applicable classes tested.
- [ ] all applicable HIGH `STOP_MANAGEMENT_TEST_MATRIX.md` cases passed.
- [ ] `PARTIAL_PROTECTION_RELEASE_TEST.md` passed.
- [ ] `STOP_OBSERVABILITY_TEST_MATRIX.md` passed.
- [ ] demo soak passed.
- [ ] `InpRequireApproval=true` for initial live deployment.
- [ ] conservative risk used initially.
- [ ] ONNX/DOM kept optional unless separately validated live.
- [ ] archive `.ex5`, `.set`, Git commit SHA, MT5 build, analytics schema, stop observability schema, broker profile and all release evidence.

A source push alone is **not** a release. The build is releasable only after the above gates are evidenced on the intended MT5 broker/account environment.
