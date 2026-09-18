# GPT_EA Floating Market Intelligence HUD

The chart dashboard is an observability layer. It reads the same market, setup, approval, risk and lifecycle state used by GPT_EA, but the HUD renderer itself does not place, modify or close trades.

## R12 floating layout

Runtime identity:
- source version: `1.24`
- runtime build: `R12-FLOATING-HUD-20260918`
- EX5 marker: `FLOAT124`
- default overlay size: `1120 x 276`
- default anchor: `18,18`
- chart-space reservation: `false`

R12 replaces the old full-height reserved rail with a compact horizontal floating HUD. The live candlestick chart stays visible and usable. The HUD sizes from the actual chart width, targets about 90% of the chart pane on desktop, clamps to safe design bounds, and switches to compact typography on narrow charts.

The HUD can be moved with the dedicated `Drag to move` handle. Position is persisted per account, magic number and chart ID with terminal global variables, so one chart cannot overwrite another chart's HUD position.

## Header

The header shows:
- GPT EA - MARKET INTELLIGENCE
- attached symbol and terminal connectivity
- current session
- chart timeframe
- live spread
- drag handle

A state-accent rail changes with setup/lifecycle state.
## Five intelligence cards

### Market State
Shows trend, regime, structure, volatility, liquidity target and news risk.

### Multi-Timeframe
Shows D1, H4, H1, M30, M15 and M5 direction/state using live scan data.

### GPT Trade Intelligence
In scan/setup mode it shows setup name and direction, confidence with a 10-segment bar, operational status, Entry, SL, calculated cost-aware B.E., TP1/TP2/TP3 and R:R.

In live-position mode it shows strategy/direction, confidence, management status, Entry, current broker SL, B.E., TP1/TP2/TP3 and current R:R.

### Confirmations
Shows pass/pending/fail state for major execution gates, including higher-timeframe structure, M15 momentum, entry-zone interaction, M5 rejection and breakout-volume confirmation. During a live trade it switches to lifecycle confirmations such as TP1, break-even and trailing-profit status.

### Invalidation
Shows the active setup invalidation and time-based reassessment rule. During a live position it reminds the operator that broker stop/freeze geometry, risk and lifecycle rules remain active until close.

## Footer and approval controls

The footer always shows EA status and risk percentage. When no validated approval is pending it also shows `NO POSITION`; APPROVE / DENY remain disabled and fail-closed.

When a chart-local pending setup exists:
- APPROVE and DENY become active;
- buttons bind only to that symbol's pending index;
- clicking or dragging the HUD shell can never approve a trade;
- approval still calls the existing approval pipeline rather than executing directly from the renderer.
## State machine

Market HUD states:
`SCANNING -> SETUP FOUND -> WAITING CONFIRMATION -> ENTRY ARMED`

A recently finalized managed trade can hold `CLOSED`.

Live HUD states:
`TRADE ACTIVE -> TP1 -> BREAK EVEN -> TRAILING`

The router gives an existing managed chart position priority. Otherwise the floating market HUD is rendered.

## Trade map and profit protection

When a valid setup exists, the chart can draw the setup map using the actual candidate Entry / SL / B.E. / TP levels. For an open managed position the live map follows the real broker-visible position and stop lifecycle. Trailing movement is drawn only after the broker SL actually changes.

## Responsiveness and safety

R12 handles `CHARTEVENT_CHART_CHANGE`, recalculates from actual chart dimensions and does not reserve or replace the chart pane. It keeps the HUD inside chart bounds, uses compact typography on smaller charts, keeps approval controls in the footer, and removes legacy full-chart dashboard objects while premium floating mode is active.

`RenderFloatingMarketHUD`, `RenderFloatingLiveHUD`, `HUDRenderFrame`, `HUDRenderControls` and `HandleFloatingHUDDrag` must remain read-only with respect to trade execution.

`tools/check_chart_dashboard_static.py` rejects direct order send, buy/sell, position modification and position-close calls inside those visual functions. `tools/check_dashboard_state_machine.py` validates the R12 market/live state mappings and router priority.

## Current validation

The current R12 source has been validated with:
- MetaEditor compile: `0 errors, 0 warnings`
- installed MT5 compile: `0 errors, 0 warnings`
- floating-HUD static contract: PASS
- dashboard state-machine truth table: PASS
- live MT5 visual check on `GER40.cash,M15`: HUD title, Market State, Multi-Timeframe, GPT Trade Intelligence, online status, confidence, footer status and `NO POSITION` were visible over the live chart.

Real-account release gating remains independent of the dashboard and stays fail-closed unless the release configuration explicitly authorizes execution.
