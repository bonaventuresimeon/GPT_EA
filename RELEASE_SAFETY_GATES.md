# GPT_EA Release-Blocking Safety Gates

This document separates **release blockers** from ordinary trading filters. A release blocker means GPT_EA must not create a new position even if the market setup itself is valid.

Existing GPT_EA positions continue to be managed unless the broker/account itself prevents trade-management operations.

## Gate 1 — Real-account arm

**Blocks when:** account is `ACCOUNT_TRADE_MODE_REAL`, `InpBlockRealUnlessExplicitlyArmed=true`, and local `InpLiveArmPhrase` is not exactly `GPT_EA_LIVE_ARMED`.

**Purpose:** prevents an uncompiled/unvalidated configuration copied from demo from immediately trading real funds.

**Auto clears:** only after the user deliberately enters the arm phrase locally.

## Gate 2 — Human approval on real accounts

**Blocks when:** real account + `InpRequireApprovalOnRealAccount=true` + `InpRequireApproval=false`.

**Purpose:** initial real deployment cannot silently turn into full autonomous execution just because approval was disabled elsewhere.

## Gate 3 — Terminal/server connectivity

**Blocks when:** terminal is disconnected while `InpRequireTerminalConnected=true`.

**Purpose:** prevents decisions based on stale local state.

This is a transient block and automatically clears after reconnection and fresh validation.

## Gate 4 — Terminal/EA/account trade permission

New execution requires all applicable permissions:

- `TERMINAL_TRADE_ALLOWED`
- `MQL_TRADE_ALLOWED`
- `ACCOUNT_TRADE_ALLOWED`
- `ACCOUNT_TRADE_EXPERT`

Any failure blocks new orders.

## Gate 5 — Recovery invariants

When `InpBlockOnRecoveryInvariantFail=true`, every open GPT_EA position and pending approval must satisfy `RECOVERY_INVARIANTS.md`.

Examples of blocking faults:

- open position with SL=0;
- original SL cannot be reconstructed;
- open position already marked analytics FINAL;
- target geometry inverted;
- duplicate active pending approval for the same symbol;
- invalid risk-session equity state;
- detected netting reversal.

## Gate 6 — Required market-data synchronization

When enabled, D1/H4/H1/M30/M15/M5 must report `SERIES_SYNCHRONIZED` and meet `InpMinBarsPerRequiredTF`.

**Purpose:** prevents high-confidence signals from being generated while a newly added broker symbol still has incomplete local history.

## Gate 7 — Fresh quote

The most recent tick must be no older than `InpMaxQuoteAgeSeconds`.

**Purpose:** catches disconnected/stale/closed-data situations where an old Bid/Ask would otherwise appear valid.

This gate applies to new authorization, not ongoing management of already-open positions.

## Gate 8 — Market-order and SL capability

When `InpRequireMarketAndSLOrderModes=true`, the broker's `SYMBOL_ORDER_MODE` must permit:

- market orders;
- Stop Loss.

A symbol that cannot support a protective SL cannot be opened by the EA.

## Gate 9 — Broker contract/execution gate

Existing Part10 checks remain hard blockers:

- trade mode not disabled/close-only;
- correct long-only/short-only direction;
- volume min/max/step;
- directional volume limit;
- broker stop-distance requirements;
- adequate free margin;
- configured margin/free-margin usage cap.

## Gate 10 — MT5 `OrderCheck()`

The complete proposed market request must pass `OrderCheck()` before the APPROVE-ready state and again before order send.

The EA also checks projected free margin and the configured post-trade margin-level floor.

## Gate 11 — Existing risk kill switches

The following remain blockers for new entries:

- manual PAUSE;
- daily equity-loss limit;
- max equity drawdown;
- consecutive-loss limit;
- total portfolio risk;
- symbol risk;
- correlated directional risk;
- existing unprotected GPT_EA position;
- duplicate-signal cooldown.

## Gate 12 — Trading-condition gates

These are strategy/execution blockers rather than release-environment blockers, but they are still required before approval:

- advanced confluence;
- institutional/regime validation;
- price inside entry zone;
- M5 trigger;
- spread/ATR limit;
- economic-calendar block;
- Treasury-yield shock;
- session/opening-range invalidation;
- effective R:R minimum;
- optional AI veto;
- optional DOM/ONNX confirmation where configured.

## Gate behavior

A failing release gate must:

1. prevent a setup from becoming `APPROVAL READY`;
2. suppress a newly queued approval prompt;
3. reject a stale approval during fresh validation;
4. reject final order execution even if an approval click has already occurred;
5. print/surface a concrete reason;
6. keep managing existing GPT_EA positions.

This creates four independent enforcement points: scan → queue → approval click → final order send.

## Recommended live defaults

For initial live deployment:

- `InpUseReleaseSafetyGate=true`
- `InpBlockRealUnlessExplicitlyArmed=true`
- `InpRequireApprovalOnRealAccount=true`
- `InpRequireApproval=true`
- `InpRequireTerminalConnected=true`
- `InpRequireSeriesSynchronized=true`
- `InpBlockOnRecoveryInvariantFail=true`
- `InpRequireMarketAndSLOrderModes=true`
- `InpUseOrderCheckPreflight=true`
- `InpPauseOnNettingReversal=true`
- `InpPauseOnRecoveryInconsistency=true`

Do not use the live-arm phrase as a substitute for completing `COMPILE_TEST_CHECKLIST.md` and `BROKER_MATRIX_TESTS.md`.
