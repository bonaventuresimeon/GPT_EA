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
- `InpDashboardTitleFont`;
- `InpDashboardBodyFont`.

The default title font is `Segoe Script` for a calligraphic heading while the analytical body uses a more readable UI font.

## Safety invariant

The visual functions must remain read-only. `tools/check_chart_dashboard_static.py` rejects dashboard functions containing trade execution, position modification, close or order-send calls.

This dashboard does not alter the release gate, exactly-once execution, stop policy or risk supervisor.
