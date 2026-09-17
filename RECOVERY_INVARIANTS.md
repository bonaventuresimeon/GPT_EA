<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `RECOVERY_INVARIANTS.md`

---

# GPT_EA Recovery Invariants

These invariants define conditions that must remain true before GPT_EA may authorize a new trade after startup, reconnection, VPS migration or state restoration. Existing positions remain managed even when a release/recovery gate blocks new entries.

## A. Broker position is the source of truth

1. A checkpoint may restore management state only for a GPT_EA position that actually exists on the connected account.
2. No disk/global-variable record may create a replacement position by itself.
3. `POSITION_IDENTIFIER` is the durable lifecycle key; current ticket is only the live management handle.
4. If an open position's ticket changes, ticket-scoped management state must be rebuilt for the current ticket.
5. An open GPT_EA position may not already have analytics `FINAL=1`.

**Violation:** block new entries. Continue managing/reconciling existing positions where safe.

## B. Every open GPT_EA position must be protected

For every open GPT_EA position:

- `POSITION_IDENTIFIER > 0`;
- entry price > 0;
- volume > 0;
- current SL > 0;
- original/initial SL must be recoverable from persistent state or position history;
- original BUY SL must be below original entry;
- original SELL SL must be above original entry;
- initial risk distance must be greater than one symbol point.

If current SL is missing but original SL is recoverable and broker rules permit modification, the advanced manager attempts to restore protection. If no trustworthy original SL exists, the recovery-safety policy can PAUSE new trading.

## C. Target geometry must remain directional

For BUY positions/setups:

`initial SL < entry < TP1 < TP2 < TP3`

For SELL positions/setups:

`initial SL > entry > TP1 > TP2 > TP3`

A recovered setup with inverted or collapsed target geometry is invalid and cannot be authorized.

## D. Stops are monotonic after protection advances

A protective SL may become safer; it may never intentionally become less protective.

BUY:

`new SL > old SL`

SELL:

`new SL < old SL`

Trailing logic is additionally subject to a minimum R-step so the EA does not spam microscopic broker modifications.

Stages:

1. `INITIAL`
2. `BREAKEVEN`
3. `PROFIT_LOCK`
4. `STRONG_LOCK`
5. `TRAIL`

The current broker SL itself remains authoritative if terminal state is lost; the stage can be reconstructed from its relationship to entry and original R.

## E. TP1 state is idempotent

TP1 partial-close state and BE state are tracked separately.

- A successful TP1 partial is persisted as `TP1PARTIAL=1`.
- BE/protective-stop completion is independently verified.
- `TP1DONE=1` is set only when the configured partial state is complete and required BE protection is in place.
- If the broker temporarily rejects/freeze-blocks the BE change, the EA retries protection without taking another TP1 partial.
- Restart recovery may infer TP1 completion from exit-deal history and current protected SL.

This prevents duplicate partial exits after restart or transient stop-modification failure.

## F. TP2 state is idempotent

- `TP2PARTIAL=1` is written only after the TP2 reduction succeeds.
- A failed TP2 reduction remains retryable.
- The percentage is applied to the then-current remaining volume.
- If the position becomes fully closed, no further management state is applied.

## G. Pending approvals are unique and finite

For each symbol:

- at most one active pending approval;
- `expires_at > created_at`;
- setup is marked valid;
- symbol is available/resolvable;
- directional SL/TP geometry is valid;
- expired approvals cannot be restored as executable approvals;
- restored approvals must pass a fresh scan and all current release/risk/broker gates.

Persistence is never authorization.

## H. Account/server/magic isolation

A recovery snapshot is valid only when its metadata is compatible with the current runtime policy:

- account login matches;
- EA magic number matches;
- broker server matches when server-mismatch rejection is enabled;
- schema version is supported;
- checkpoint contains a completed `END` marker.

The validated `.bak` file is eligible only under the same rules.

## I. Recovery-source precedence

Reconciliation order is conceptually:

1. **Current broker positions and position/deal history** — what actually happened.
2. **Terminal Global Variables** — fast persistent EA state.
3. **Completed primary checkpoint** — durable supplemental state.
4. **Completed backup checkpoint** — fallback if primary is incomplete/invalid.

Lower-priority persistence must not contradict an observable broker position/deal history fact.

## J. Netting reversal is a safety fault

On a non-hedging account, a reversal can preserve the same position identifier while changing direction. Recovery compares the first historical lifecycle direction to the currently open direction.

If they differ, GPT_EA must not reuse the former trade's TP/SL/risk analytics as though it were the same directional setup. With `InpPauseOnNettingReversal=true`, new trading is PAUSED and manual review is required.

## K. Risk-session state must be valid

Before new authorization:

- day-start equity > 0;
- equity high-water mark > 0;
- daily-loss state is refreshed for the current server date;
- manual/recovery pause state is honored;
- consecutive-loss state is preserved.

Existing positions remain managed when the entry gate is blocked.

## L. Release data must be live enough to authorize

When enabled, every required D1/H4/H1/M30/M15/M5 series must be synchronized and contain at least the configured minimum bars. The latest broker tick must also be younger than the configured quote-age ceiling.

A disconnected terminal, stale quote or unsynchronized required timeframe is a **new-entry block**, not an instruction to abandon existing position management.

## M. Real-account execution requires explicit release arming

When `InpBlockRealUnlessExplicitlyArmed=true`, a real-money account cannot authorize execution unless the locally entered arm phrase is exactly:

`GPT_EA_LIVE_ARMED`

The source repository does not contain an armed value. The user must set it locally after compilation and broker/demo validation.

When `InpRequireApprovalOnRealAccount=true`, disabling approval also blocks new real-account trades.

## N. Recovery completion criteria

Recovery is considered safe for new entries only when:

- broker positions reconcile;
- all open GPT_EA positions pass protection/geometry invariants;
- no netting reversal safety fault exists;
- pending approvals are unique/valid;
- risk-session state is valid;
- terminal/account permissions are valid;
- required market data is synchronized/fresh;
- broker supports required market-order and SL capabilities;
- real-account release policy is satisfied.

Any failing invariant is surfaced as a release-block reason and prevents the APPROVE-ready state.
