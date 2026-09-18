# GPT_EA v1.22 — HUD / Input / EX5 Validation Run

## Candidate identity

- Source version: **1.22**
- Runtime build: **R8-ELEGANT-HUD-INPUTS-20260918**
- EX5 marker: **HUD122**
- Required Journal line:
  `GPT_EA runtime build R8-ELEGANT-HUD-INPUTS-20260918 • source version 1.22 • EX5 marker HUD122`

## Pre-compile checks

1. Pull the latest `main`.
2. Open `GPT_EA.mq5` in MetaEditor.
3. Confirm the first inputs are `InpSymbols="ALL"`, then OpenAI Use / Key / Model / Endpoint.
4. Confirm the API key source value is blank in source control.
5. Compile with **0 errors**. Treat warnings as defects until reviewed.

## MT5 attach / stale-EX5 check

1. Remove the previous GPT_EA from the chart.
2. Delete or replace the old compiled EX5 if MetaEditor did not overwrite it.
3. Attach the newly compiled GPT_EA.
4. Confirm the Journal contains the exact runtime line above.
5. Confirm the HUD subtitle visibly contains `v1.22 • R8 HUD`.
6. If either marker is absent, stop the run: an older EX5 is loaded.

## Visual acceptance

The full dashboard must be contained inside one elegant dark HUD box within the live-chart pane.

Required:
- outer HUD background matches the MT5 chart background;
- thin framed border and top state-accent rail;
- header, status, cards and footer controls remain inside the enclosure;
- no raw `Comment()` dump;
- no legacy left-side Risk & Performance overlay;
- no text overlaps candles;
- no button is clipped;
- D1/H4/H1/M30/M15/M5 matrix is readable;
- Entry / SL / B.E. / TP1 / TP2 / TP3 / trailing values stay inside the trade card;
- SCAN NOW / PAUSE or APPROVE / DENY stay inside the HUD footer;
- resizing the chart rerenders without leaving orphaned objects.

## Input acceptance

Defaults to verify:
- `InpSymbols = "ALL"`
- `InpOpenAIAPIKey = ""`
- `InpOpenAIModel = "gpt-5.6-sol"`
- `InpOpenAIEndpoint = "https://api.openai.com/v1/responses"`
- `InpDashboardX/Y = 12 / 12`
- `InpDashboardWidth/Height = 540 / 560`
- `InpDashboardRefreshMs = 500`
- `InpDashboardMinWidth/MaxWidth = 400 / 600`
- `InpDashboardChartGap = 16`

Invalid user-facing values must fail initialization with `GPT_EA INPUT CONFIGURATION BLOCK:` rather than silently producing a broken EA.

## Runtime data / scanner acceptance

- insufficient D1/H4/H1/M30/M15/M5 history => `DATA LOADING / INSUFFICIENT HISTORY`;
- no zero-price Entry/SL/TP setup proceeds;
- unavailable Asian/session values render as `N/A`, never ±1e100;
- broker-universe scan remains bounded;
- attached chart retains dashboard priority;
- no abnormal termination during repeated full-universe batches.

## Decision-state acceptance

A strategy candidate may show `QUALIFIED CANDIDATE — FINAL GATES PENDING`.

`ENTRY ARMED` / final `HIGH-CONFIDENCE TRADE SETUP` is permitted only after the full authorization path passes: structure/confluence, trigger, spread, realistic R:R, news/intermarket, GPT policy where enabled, risk, release, broker-execution and final fresh-validation gates.

## Run evidence to capture

Save:
- MetaEditor compile output;
- Experts + Journal log from startup through several scanner batches;
- one screenshot each for SCANNING, candidate/waiting, and live/approval state when available;
- terminal chart size used;
- broker/server name;
- exact source commit SHA.

Keep real-account execution blocked until compile, visual acceptance and runtime stability are all confirmed.
