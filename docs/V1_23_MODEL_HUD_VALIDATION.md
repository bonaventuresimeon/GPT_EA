# GPT_EA v1.24 - R12 Floating HUD Validation

> Legacy filename retained for repository compatibility. This document describes the current v1.24 R12 HUD.

## Exact build identity

- Source version: **1.24**
- Runtime build: **R12-FLOATING-HUD-20260918**
- EX5 marker: **FLOAT124**
- Requested OpenAI model: **gpt-5.6-sol**

Expected Journal identity:
`GPT_EA runtime build R12-FLOATING-HUD-20260918 | source version 1.24 | EX5 marker FLOAT124`

If that marker is absent after compile/re-attach, MT5 may still be running an older EX5.

## Source and installed compile acceptance

Both the repository source and the installed MT5 copy must compile with:
`0 errors, 0 warnings`

The installed source used for validation is under the active terminal data folder:
`MQL5\Experts\Advisors\GPT_EA\GPT_EA.mq5`

## Static HUD acceptance

Run:
`python tools/check_chart_dashboard_static.py`

Expected:
`FLOATING HUD STATIC CHECK: PASS`
The static check verifies:
- R12 build identity
- responsive floating-width logic
- five-card market HUD
- live HUD
- chart-local approval binding
- APPROVE / DENY fail-closed behavior
- drag/hover event wiring
- per-chart persisted HUD position
- no legacy full-chart renderer in the active router
- no trade execution or position mutation from visual rendering functions

## Dashboard state-machine acceptance

Run:
`python tools/check_dashboard_state_machine.py`

Expected:
`DASHBOARD STATE MACHINE CHECK: PASS`

Validated market states:
`CLOSED / SCANNING / SETUP FOUND / WAITING CONFIRMATION / ENTRY ARMED`

Validated live states:
`TRADE ACTIVE / TP1 / BREAK EVEN / TRAILING`

Router priority:
`managed live position -> floating live HUD; otherwise -> floating market HUD`
## Live MT5 visual acceptance

On an attached chart verify that the candlestick chart remains visible and the HUD floats above it rather than replacing it.

Required header content:
- GPT EA - MARKET INTELLIGENCE
- symbol and ONLINE / OFFLINE
- session
- chart timeframe
- spread
- drag handle

Required cards:
1. Market State
2. Multi-Timeframe
3. GPT Trade Intelligence
4. Confirmations
5. Invalidation

Required footer behavior:
- EA status is visible
- risk percentage is visible
- `NO POSITION` appears when appropriate
- APPROVE / DENY are disabled without a validated pending setup
- controls become active only for the chart-local pending setup

## Live evidence captured

The active `GER40.cash,M15` chart rendered the R12 HUD over the live chart. Visual/OCR verification confirmed:
- `GPT EA - MARKET INTELLIGENCE`
- `MARKET STATE`
- `MULTI-TIMEFRAME`
- `GPT TRADE INTELLIGENCE`
- `GER40.cash ONLINE`
- `Confidence: 0/100`
- `Status: SCANNING`
- `EA STATUS`
- `NO POSITION`
- `RISK 1.00%`
## OpenAI model-resolution validation

With direct OpenAI transport and a valid locally supplied API key:
1. start with `InpOpenAIModel = gpt-5.6-sol`;
2. allow model-catalog discovery when `InpOpenAIModelAutoResolve = true`;
3. use the requested model when available;
4. otherwise select an eligible configured fallback;
5. keep the requested model `UNVERIFIED` when authentication/network/model-list access fails rather than misclassifying it as unavailable.

Secrets remain local and must never be committed.

## Release safety

HUD validation does not bypass the production release gate. Keep real-account execution blocked until all configured release, broker, risk, reconciliation and live-arm requirements pass.
