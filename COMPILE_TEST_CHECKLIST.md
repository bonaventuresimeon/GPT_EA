# GPT_EA Compile & Test Checklist

This is the release gate for `GPT_EA.mq5`. Do not promote a build development → demo → live until the applicable checks pass.

## 1. MetaEditor compile gate

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
  - `GPT_EA_Part11_PreflightRecoveryGuard.mqh`
  - `GPT_EA_Part12_SafetyStopManagement.mqh`
  - `GPT_EA_Part05.mqh`
  - `GPT_EA_Part06.mqh`
  - `GPT_EA_Part13_AdvancedPositionManager.mqh`
  - `GPT_EA_Part07.mqh`
- [ ] Exactly one `OnInit`, `OnDeinit`, `OnTimer`, `OnTick`, `OnChartEvent`, and `OnTradeTransaction` is compiled.
- [ ] No committed API key or real-account live-arm value exists in source.

## 2. Broker/account preflight

- [ ] Broker company/server correct.
- [ ] Account currency correct.
- [ ] Account leverage correct.
- [ ] Account margin mode correct: hedging/netting/exchange.
- [ ] `ACCOUNT_TRADE_ALLOWED` true.
- [ ] `ACCOUNT_TRADE_EXPERT` true.
- [ ] `TERMINAL_TRADE_ALLOWED` true for execution tests.
- [ ] `MQL_TRADE_ALLOWED` true for execution tests.
- [ ] Margin Call / Stop Out policy recorded.

## 3. Release-blocking safety gates

Follow `RELEASE_SAFETY_GATES.md`.

- [ ] Disconnected terminal blocks new entries.
- [ ] Terminal/account/EA permission failure blocks new entries.
- [ ] Unsynchronized D1/H4/H1/M30/M15/M5 blocks new entries.
- [ ] Required timeframe with fewer than `InpMinBarsPerRequiredTF` blocks.
- [ ] Stale quote older than `InpMaxQuoteAgeSeconds` blocks.
- [ ] Missing market-order capability blocks.
- [ ] Missing SL capability blocks.
- [ ] Recovery invariant failure blocks.
- [ ] Existing positions continue to be managed while release gate is blocked.
- [ ] Real account with blank/incorrect arm phrase blocks.
- [ ] Real account with approval disabled blocks when `InpRequireApprovalOnRealAccount=true`.
- [ ] Correct local arm phrase does not bypass other gates.

## 4. Recovery invariants

Follow `RECOVERY_INVARIANTS.md`.

- [ ] Every open GPT_EA position has nonzero `POSITION_IDENTIFIER`.
- [ ] Entry and volume are valid.
- [ ] Current SL exists.
- [ ] Original SL is recoverable.
- [ ] Original BUY SL is below entry; original SELL SL is above entry.
- [ ] Open position is not analytics `FINAL=1`.
- [ ] TP1/TP2/TP3 geometry is directional and ordered.
- [ ] No duplicate active pending approval for one symbol.
- [ ] Pending approval timestamps are valid.
- [ ] Risk-session equity/high-water state is valid.
- [ ] Netting reversal mismatch pauses/requires review when configured.

## 5. Symbol-resolution matrix

Run `BROKER_MATRIX_TESTS.md` for every intended broker/account combination.

Minimum cases:

- [ ] exact FX symbol
- [ ] FX suffix/prefix
- [ ] XAUUSD/GOLD alias
- [ ] US100/NAS100/USTEC alias
- [ ] GER40/DE40/DAX40 alias
- [ ] WTI/USOIL and BRENT/UKOIL
- [ ] crypto where available
- [ ] proprietary stock/ETF/future using actual broker symbol
- [ ] unknown symbol fails safely
- [ ] `AUTO` / Market Watch universe respects caps

## 6. Contract/tick/volume matrix

For each representative asset class verify:

- [ ] digits/point
- [ ] tick size
- [ ] tick value profit/loss
- [ ] contract size
- [ ] min/max/step volume
- [ ] directional volume limit
- [ ] floating/fixed spread flag
- [ ] stop level
- [ ] freeze level
- [ ] trade/execution/filling modes
- [ ] margin currency/calculation mode

Cross-asset sizing:

- [ ] 5-digit FX
- [ ] JPY FX
- [ ] metal
- [ ] U.S. index CFD
- [ ] European index CFD
- [ ] energy CFD
- [ ] crypto CFD where supported
- [ ] stock/ETF/future where supported

Pass: intended monetary loss at initial SL is acceptably close to configured risk after volume-step rounding.

## 7. Broker execution and `OrderCheck()`

- [ ] invalid min/max/step volume rejected
- [ ] directional volume limit enforced
- [ ] disabled/close-only/long-only/short-only modes enforced
- [ ] SL/TP normalized to broker tick size
- [ ] too-close stop rejected
- [ ] nonzero freeze level respected during modifications
- [ ] insufficient free margin rejected
- [ ] `InpMaxNewTradeMarginPctFree` enforced
- [ ] Market Execution uses supported FOK/IOC
- [ ] Request/Instant/Exchange policy validated
- [ ] valid `OrderCheck()` passes
- [ ] rejected `OrderCheck()` suppresses APPROVE readiness
- [ ] `OrderCheck()` runs again before send
- [ ] projected negative free margin rejected
- [ ] projected margin-level floor enforced

## 8. Spread/slippage/R:R

- [ ] spread is live Bid/Ask distance
- [ ] M5 ATR available
- [ ] dynamic slippage remains inside configured min/max
- [ ] wider spread reduces effective R:R
- [ ] effective R:R below minimum blocks entry
- [ ] actual fill slippage logged
- [ ] rollover/news spread expansion cannot pass a stale approval

## 9. Setup and multi-timeframe logic

- [ ] D1/H4/H1/M30/M15/M5 loaded and synchronized
- [ ] pullback geometry coherent
- [ ] breakout/retest geometry coherent
- [ ] sweep → displacement → retest behaves as configured
- [ ] level-touch/rejection score changes appropriately
- [ ] regime classification plausible
- [ ] advanced confluence stays 0..100

## 10. Calendar/session/yield

- [ ] mapped USD events affect XAU/USD-related U.S. assets as intended
- [ ] mapped EUR events affect EUR/GER40-related assets as intended
- [ ] high-impact block before/after works
- [ ] upcoming event outside block window does not falsely block
- [ ] London 08:55/09:00 schedules correct
- [ ] New York 09:25/09:30 schedules correct
- [ ] UK/U.S. DST transition weeks correct
- [ ] missing yield symbol fails safely according to policy
- [ ] yield shock blocks when threshold exceeded

## 11. APPROVE / DENY

- [ ] no APPROVE-ready state unless release + strategy + risk + broker + `OrderCheck()` + M5 trigger all pass
- [ ] APPROVE revalidates everything
- [ ] price leaves zone after prompt → no trade
- [ ] spread/news/yield/risk/release status changes after prompt → no trade
- [ ] DENY deletes setup and starts cooldown
- [ ] timeout deletes setup and starts cooldown
- [ ] duplicate click cannot create duplicate order
- [ ] manual PAUSE clears pending approvals

## 12. Advanced TP1 / breakeven state machine

For BUY and SELL:

- [ ] before TP1 original SL remains intact
- [ ] TP1 partial executes once
- [ ] `TP1PARTIAL` persists independently of BE
- [ ] cost-aware BE buffer includes at least ATR-cost buffer or spread + dynamic-slippage cost
- [ ] broker freeze/stop distance can delay BE without duplicating TP1 partial
- [ ] BE retry eventually succeeds when broker-valid
- [ ] `TP1DONE` is written only after configured partial + required protection are complete
- [ ] restart after TP1 partial but before BE does not duplicate partial

## 13. Advanced profit locks and trailing

- [ ] at `InpProfitLockTriggerR`, lock `InpProfitLockR`
- [ ] at `InpStrongLockTriggerR`, lock `InpStrongLockR`
- [ ] trailing starts only at/after `InpTrailStartR`
- [ ] ATR trail uses M5 ATR
- [ ] structure trail uses recent M5 structure
- [ ] wider ATR/structure stop is chosen before applying strong-lock floor
- [ ] trail changes require `InpTrailMinStepR` improvement
- [ ] BUY stop never decreases
- [ ] SELL stop never increases
- [ ] every stop respects current broker stop/freeze level
- [ ] stop normalized to tick size
- [ ] TP3 remains attached by default
- [ ] optional runner mode removes fixed TP after trailing begins when configured
- [ ] journal records `STOP_BREAKEVEN`, `STOP_PROFIT_LOCK`, `STOP_STRONG_LOCK`, `STOP_TRAIL`

## 14. TP2 scale-out and runner

- [ ] TP2 partial uses percentage of remaining position
- [ ] `TP2PARTIAL` prevents duplicate scale-out
- [ ] failed TP2 partial remains retryable
- [ ] sub-minimum partial volume is handled safely
- [ ] trailing continues on remaining position
- [ ] post-TP1 stall timer begins at TP1 time, not original entry
- [ ] stall + barrier + momentum/reversal condition can close remainder

## 15. Portfolio/daily protection

- [ ] symbol risk cap
- [ ] total portfolio risk cap
- [ ] correlated directional risk cap
- [ ] unprotected existing position blocks new risk
- [ ] daily loss kill switch
- [ ] equity high-water drawdown kill switch
- [ ] consecutive-loss kill switch
- [ ] blocked state does not stop protective management of existing trades

## 16. Restart/crash recovery matrix

- [ ] no-position/no-pending restart
- [ ] pending approval still valid
- [ ] approval expires while terminal offline
- [ ] restart immediately before/after order send
- [ ] restart before TP1
- [ ] restart after TP1 partial before BE
- [ ] restart after BE
- [ ] restart after +0.5R lock
- [ ] restart after +1R lock
- [ ] restart during trailing
- [ ] restart after TP2 partial
- [ ] position ticket change, same identifier
- [ ] deliberate netting reversal
- [ ] account/server/magic mismatch
- [ ] truncated primary checkpoint restores completed `.bak`
- [ ] invalid primary + invalid backup fails safely
- [ ] missing globals rebuild from broker/history where possible
- [ ] finalized analytics not duplicated

## 17. Analytics

Follow `ANALYTICS_SCHEMA.md`.

- [ ] one logical ENTRY per lifecycle
- [ ] EXIT_PART for partial/final exit deals
- [ ] CLOSED once per completed identifier
- [ ] requested/actual/slippage units correct
- [ ] final R uses original planned monetary risk
- [ ] MAE_R/MFE_R nonnegative
- [ ] pullback/breakout statistics separate
- [ ] profit factor calculation correct
- [ ] `FINAL=1` idempotency works
- [ ] protective-stop stage events contain position ID and current R

## 18. OpenAI / DOM / ONNX

OpenAI:
- [ ] blank/invalid key fails safely
- [ ] timeout/network failure fails safely
- [ ] AI cannot bypass deterministic/release gates
- [ ] no key appears in logs/source

DOM:
- [ ] subscription works where supported
- [ ] unavailable DOM follows optional/required policy

ONNX:
- [ ] `[1,12]` input and `[1,1]` output validated
- [ ] missing/invalid model cannot bypass hard gates

## 19. Strategy Tester / static gate

- [ ] no array-out-of-range
- [ ] no divide-by-zero
- [ ] no invalid indicator-handle leak
- [ ] no duplicate position beyond configured limit
- [ ] no runaway release-gate/trailing log spam
- [ ] historical risk per trade plausible
- [ ] drawdown reviewed
- [ ] pullback and breakout performance reviewed independently

## 20. Demo soak and live release

Demo:
- [ ] multiple London/U.S. sessions
- [ ] at least one high-impact news day
- [ ] weekend/terminal restart
- [ ] spread expansion/rollover period
- [ ] checkpoint + backup + execution CSV persist
- [ ] at least one complete TP1 → BE → lock → trail lifecycle
- [ ] `BROKER_MATRIX_TESTS.md` completed for intended broker

Live:
- [ ] compile gate passed
- [ ] recovery invariants passed
- [ ] release-gate tests passed
- [ ] broker matrix passed on intended live account type
- [ ] demo soak passed
- [ ] `InpRequireApproval=true` for initial live deployment
- [ ] live arm phrase entered locally only after validation
- [ ] conservative risk used initially
- [ ] ONNX/DOM remain optional unless separately live-validated
- [ ] archive `.ex5`, `.set`, commit SHA, MT5 build, analytics schema version and broker profile
