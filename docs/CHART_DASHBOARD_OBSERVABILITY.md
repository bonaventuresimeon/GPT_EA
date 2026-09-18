<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### ✨ Elegant Chart Dashboard & Trade Map

**Calligraphic Intelligence • Live Risk • Entry • SL • B.E. • TPs • Trailing Profit**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🚀 Release](RELEASE_CERTIFICATION.md) · [🧪 MT5 Validation](MT5_VALIDATION_EVIDENCE.md)

</div>

> ✨ **Document:** `CHART_DASHBOARD_OBSERVABILITY.md`

---

# Elegant Chart Dashboard and Trade Map

The chart dashboard is an observability layer. It reads the same candidate, lifecycle, broker, risk, stop-management and model-health state used by the EA, but it does not submit, modify or close trades.

## Scan / analysis mode

For the symbol attached to the chart, the dashboard shows:

- strategy and directional bias;
- D1 / H4 / H1 / M30 / M15 / M5 analysis context;
- current market price, entry zone and preferred entry;
- distance to entry in ATR;
- initial SL and TP1 / TP2 / TP3;
- effective R:R;
- confidence and confluence score;
- ADX, volume impulse and opening-range state;
- structure, liquidity sweep, fair-value-gap and rejection status;
- portfolio risk, daily loss and drawdown;
- broker-health and model-trust state;
- release gate and filter state;
- pending approval / final-check state;
- plain-language explanation of what the EA is currently waiting for.

Only the attached chart symbol owns the visible dashboard; multi-symbol scanning cannot replace it with the last symbol scanned.

## Live position-management mode

When GPT_EA has an open managed position on the chart symbol, the dashboard automatically switches to live management and shows:

- position ticket, direction, strategy and lifecycle state;
- volume and opening time;
- entry price and current executable market price;
- current R multiple and floating P/L;
- initial SL;
- current broker SL;
- calculated cost-aware break-even level;
- stop stage: `INITIAL`, `BREAKEVEN`, `PROFIT_LOCK`, `STRONG_LOCK` or `TRAIL`;
- TP1 / TP2 / TP3 state;
- initial risk money;
- portfolio risk, daily loss and account drawdown;
- broker health;
- model-health state;
- release status;
- current management action in plain language.

## Chart levels

The live trade map draws:

- Entry;
- Initial SL;
- B.E.;
- Current protected SL;
- TP1;
- TP2;
- TP3 / runner;
- risk and reward regions.

Every price level has a right-side text label.

## Trailing-profit movement

When the broker SL advances, the dashboard records a bounded history of the last stop movements using chart trend segments.

The visual path includes break-even, profit-lock, strong-lock and ATR/structure-trailing advances. It never invents a stop movement: a segment is drawn only after the actual `POSITION_SL` changes.

The active trailing line therefore represents the broker-visible protection, not a hypothetical trail.

## Performance

Tick handling remains execution-free. `OnTick()` only refreshes visual observability and is throttled by `InpDashboardRefreshMs`.

All scanning, risk authorization, approvals and position management remain on their existing execution paths.

## Boxed elegant HUD layout

Premium mode renders every dashboard element inside one enclosed HUD that matches the MT5 live-chart palette. The outer enclosure uses the same `C'11,15,22'` background as `ApplyChartPolish()`, with an inset frame, header rail, state accent and footer/control rail. Titles, status, intelligence cards, risk/safety content, lifecycle text and buttons all remain inside this box.

`InpDashboardTransparent=true` now means **glass inner cards only**. The outer HUD enclosure never becomes transparent, so dashboard text cannot fall directly onto candles. The renderer still reserves a right-side chart gutter with `CHART_SHIFT_SIZE`, shifting price action left rather than hiding candles beneath the HUD. Candidate entry zones plus live risk/reward regions remain outline-only.

The renderer responds to `CHARTEVENT_CHART_CHANGE`, recalculates width and height from the actual chart pane, and now honors `InpDashboardHeight`. Narrow/short charts switch to compact typography and tighter cards. The default HUD is 540×560 px with responsive 400–600 px width bounds, 12 px chart offsets and a 16 px chart gap.

The legacy left-side Risk & Performance block, giant strategy-health label and raw `Comment(card)` diagnostic dump are suppressed while the premium dashboard is active. Their underlying analytics remain available to the trading engine, journals and fallback non-premium view.

## Dashboard lifecycle state machine

The visible state is deterministic and follows:

`SCANNING → SETUP FOUND → WAITING CONFIRMATION → ENTRY ARMED → TRADE ACTIVE → TP1 → BREAK EVEN → TRAILING → CLOSED`

The candidate dashboard also renders a clear `NO TRADE — score/100` condition. In that state no executable level ladder is presented as authorized; the dashboard instead displays the strategy rationale, current confirmation requirement, pullback-versus-breakout-retest scores, news/spread context and invalidation information.

After a managed position closes, `CLOSED` is held briefly using `InpDashboardClosedHoldSeconds`, then the interface returns automatically to `SCANNING`.

Approval controls are integrated into the same reserved dashboard rail in premium mode. This prevents the separate approval hero from covering candles while preserving APPROVE / DENY functionality, including pending setups discovered on other scanned symbols.

## Inputs

The visual controls include:

- `InpElegantChartDashboard`;
- `InpDrawDashboard`;
- `InpDrawTradeLevels`;
- `InpDrawLiveManagementLevels`;
- `InpDrawTrailingMovement`;
- `InpTrailMovementSegments`;
- `InpDashboardRefreshMs`;
- `InpDashboardWidth` / `InpDashboardHeight`;
- `InpDashboardTransparent`;
- `InpDashboardReserveChartSpace`;
- `InpDashboardMinWidth` / `InpDashboardMaxWidth`;
- `InpDashboardChartGap`;
- `InpDashboardClosedHoldSeconds`;
- `InpDashboardTitleFont`;
- `InpDashboardBodyFont`.

The default title font is `Segoe Script` for a calligraphic heading while the analytical body uses a more readable UI font. The HUD header also shows `v1.23 • R10 HUD` so the running visual build can be checked at a glance.

## Safety invariant

The visual functions must remain read-only. `tools/check_chart_dashboard_static.py` rejects dashboard functions containing trade execution, position modification, close or order-send calls.

This dashboard does not alter the release gate, exactly-once execution, stop policy or risk supervisor.


## Exact stop-movement rules card

The dashboard displays the same protection rules enforced by the live manager:

- **B.E. trigger:** at `InpBETriggerR` (default 1.00R). The stop moves beyond entry by the larger of `InpBELockMinR × R` or the live cost allowance. The live cost allowance is `max(InpBECostATRFrac × M5 ATR, spread + learned slippage)`.
- **Profit lock:** at `InpProfitLockTriggerR` (default 1.50R), the stop target becomes `InpProfitLockR` (default +0.50R).
- **Strong lock:** at `InpStrongLockTriggerR` (default 2.00R), the stop target becomes `InpStrongLockR` (default +1.00R).
- **ATR/structure trail:** begins from `InpTrailStartR` (default 2.00R). For a long, the candidate is the stronger of the strong-lock floor and the weaker of the ATR stop and buffered M5 swing-low stop; the short formula is the mirrored equivalent.
- The trail uses `InpTrailATRMultiplier`, `InpTrailStructureBarsM5`, `InpTrailStructureBufferATR`, and requires at least `InpTrailMinStepR` improvement before another ratchet.
- Every stop change still has to pass broker stop/freeze-distance validation. The dashboard does not move the stop itself.

The profit-protection ladder is only advanced after TP1 protection is complete, matching `ManagePositionsAdvanced()` and `HandleTP1State()`.

## Compact trade timeline

For an open position the dashboard shows two compact timestamp lines:

`ANALYZE → APPROVE → SENT → FILL`

and

`TP1 → B.E. → LOCK → STRONG → TP2 → TRAIL`.

The execution timestamps are persisted on the position even when execution-quality learning is disabled. B.E., profit-lock, strong-lock and trail timestamps are written only after the broker accepts the corresponding stop modification. TP1 and TP2 timestamps come from the actual partial/protection lifecycle.

A missing milestone is shown as `--`; the dashboard does not invent completion times.


## Exact stop-movement ladder

The live dashboard exposes the same stop rules used by the manager:

- **B.E. trigger:** at `InpBETriggerR` (default 1.00R), move toward entry plus/minus a cost buffer. The buffer is the larger of `InpBELockMinR × R` and the cost estimate `max(InpBECostATRFrac × M5 ATR, spread + learned slippage)`.
- **Profit lock:** at `InpProfitLockTriggerR` (default 1.50R), protect `InpProfitLockR` (default +0.50R).
- **Strong lock:** at `InpStrongLockTriggerR` (default 2.00R), protect `InpStrongLockR` (default +1.00R).
- **Trail:** from `InpTrailStartR` (default 2.00R), combine the ATR stop and M5 structure stop while respecting the strong-lock floor.
- **Trail inputs:** default 1.25× M5 ATR, 8-bar M5 structure and 0.15 ATR structure buffer.
- **Ratchet:** trailing protection must improve by at least `InpTrailMinStepR` (default 0.15R, subject to at least one symbol point).
- **Broker geometry:** every update must pass stop/freeze-distance validation.
- **Non-regression:** the stop is never deliberately loosened.

For LONG positions the trail uses the stronger broker-valid protective level from the strong-lock floor and the ATR/structure combination; SELL logic mirrors it.

## Compact trade timeline

The live timeline uses persistent event timestamps and renders:

`ANALYZE → APPROVE → SENT → FILL → TP1 → B.E. → +0.5R LOCK → +1R LOCK → TP2 → TRAIL`

Milestones display:

- `✓` when completed, with the actual event time;
- `● ... NEXT` for the current expected milestone;
- `○` for future milestones;
- the most recent trailing-stop ratchet time once trailing is active.

The timeline is reconstructed from durable execution/lifecycle keys such as `EXEC_ANALYSIS_TIME`, `EXEC_APPROVAL_TIME`, `EXEC_SENT_TIME`, `EXEC_FILL_TIME`, `TP1_TIME`, `BE_TIME`, `PROFIT_LOCK_TIME`, `STRONG_LOCK_TIME`, `TP2_TIME`, `TRAIL_TIME` and `TRAIL_LAST_TIME`.


## v1.23 input ordering and model discovery

The first MT5 user input is `InpSymbols="ALL"`. Immediately below it, the user-facing OpenAI controls appear in this order:

`InpUseOpenAI → InpOpenAIAPIKey → InpOpenAIModel → InpOpenAIEndpoint → InpOpenAITimeoutMs`.

The source default for `InpOpenAIAPIKey` remains blank. Secrets are entered locally or loaded from `GPT_EA_OpenAI.key`; they must never be committed to Git.

The v1.23 default requested model is `gpt-5.6-sol` and the direct Responses endpoint remains `https://api.openai.com/v1/responses`.

When a direct OpenAI API key is available and `InpOpenAIModelAutoResolve=true`, the EA queries the OpenAI model catalog at `GET /v1/models`. If the requested model is available and suitable for the EA's text/Responses workload, it is used. If it is unavailable, the EA selects the first accessible model from `InpOpenAIModelFallbacks`; if none of those are returned, it ranks compatible GPT text models discovered for the key and chooses the best eligible fallback. All standard, live-web-intelligence and deep-review request builders then use the resolved runtime model rather than blindly using the requested input value.

The default fallback order is `gpt-5.6-sol → gpt-5.6-terra → gpt-5.6-luna → gpt-5.6 → gpt-5.2 → gpt-5.1 → gpt-5 → gpt-4.1 → gpt-4o`. The model catalog is refreshed every `InpOpenAIModelScanMinutes` (default 60 minutes). Authentication/network failure during discovery does not masquerade as model unavailability: the requested model is retained as `UNVERIFIED` and normal API safety/failure handling remains active.

Secure-proxy mode does not expose the server-side OpenAI key to MT5, so direct model-list discovery is deliberately skipped there and model selection is delegated to the proxy configuration.

## v1.23 runtime identity

A correctly compiled and attached v1.23 EX5 prints:

`GPT_EA runtime build R10-AUTO-MODEL-HUD-20260918 • source version 1.23 • EX5 marker HUD123`

The chart HUD subtitle must also contain `v1.23 • R10 HUD`. The Risk / Safety card shows the active runtime AI model and whether it is VERIFIED, FALLBACK, PROXY or UNVERIFIED. If the EX5/HUD markers are absent, the terminal is still running an older compiled build.
