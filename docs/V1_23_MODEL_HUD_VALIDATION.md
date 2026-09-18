# GPT_EA v1.23 — Automatic Model Resolution + Boxed HUD Validation

## Exact build identity

- Source: **1.23**
- Runtime build: **R10-AUTO-MODEL-HUD-20260918**
- EX5 marker: **HUD123**
- HUD marker: **v1.23 • R10 HUD**

The Journal must print exactly:

`GPT_EA runtime build R10-AUTO-MODEL-HUD-20260918 • source version 1.23 • EX5 marker HUD123`

If that line or the HUD marker is absent after compile/re-attach, stop: MT5 is running an older EX5.

## OpenAI model-resolution validation

With `InpAPITransportMode = GPT_API_DIRECT_OPENAI`, `InpUseOpenAI = true`, and a valid local/input API key:

1. Start with `InpOpenAIModel = gpt-5.6-sol`.
2. The EA queries `GET https://api.openai.com/v1/models` using the local bearer key.
3. If the requested model appears in the key's model catalog and is an eligible GPT Responses/text model, Journal status must show `REQUESTED MODEL VERIFIED`.
4. If the requested model is not returned, the EA must select an accessible fallback from `InpOpenAIModelFallbacks`.
5. If no configured fallback is returned, the EA may choose the highest-ranked compatible GPT text model discovered for that key.
6. Every standard OpenAI, live web-intelligence and deep-review request must use the resolved runtime model.
7. The Risk / Safety HUD must show the active model with `VERIFIED`, `FALLBACK`, `PROXY`, `UNVERIFIED` or `NO MODEL`.
8. Model availability is refreshed periodically using `InpOpenAIModelScanMinutes`.

Test an intentionally invalid requested model (for example a made-up ID) on a demo terminal. Expected result: the EA remains initialized, selects an available eligible fallback returned by the API catalog, prints the requested→active transition, and subsequent AI calls use the active fallback.

Do not treat 401/403 authentication failure, WebRequest allow-list failure or network failure as proof that a model is unavailable. In those cases the requested model is kept as `UNVERIFIED`; fix the API/key/network configuration first.

In secure-proxy mode the server-side OpenAI key is not exposed to MT5, so direct catalog discovery is skipped and model selection remains proxy-managed.

## Boxed HUD state validation

Validate each visual state separately:

- **SCANNING:** Market Scan HUD, scanner/data status, risk/API/active-model status, EA action, SCAN NOW / PAUSE all remain inside the enclosure.
- **SETUP / WAITING / ENTRY ARMED:** Intelligence HUD, D1/H4/H1/M30/M15/M5 matrix, Entry/SL/B.E./TP ladder, confirmation/invalidation, risk/news/model state and approval controls all remain inside the box.
- **LIVE TRADE:** Live Trade HUD, current R, Entry/initial SL/live SL/B.E./TP1/TP2/TP3/trailing, stop rules/timeline, risk/model state and management action all stay inside the box.
- **CLOSED:** Lifecycle HUD and final result remain inside the box until the configured hold expires.

For every state verify:
- dark outer enclosure matches the live chart background;
- inset border, header and dynamic top state rail are visible;
- footer controls are not clipped;
- no raw Comment dump or legacy Risk & Performance overlay appears;
- no HUD text overlaps candles;
- resizing the terminal rerenders cleanly;
- trade-map price objects may extend over the chart, but informational dashboard text/cards/buttons do not escape the HUD.

## Input defaults to verify

- `InpSymbols = "ALL"`
- `InpOpenAIAPIKey = ""` in source
- `InpOpenAIModel = "gpt-5.6-sol"`
- `InpOpenAIEndpoint = "https://api.openai.com/v1/responses"`
- `InpOpenAIModelAutoResolve = true`
- `InpOpenAIModelScanMinutes = 60`
- `InpDashboardX/Y = 12 / 12`
- `InpDashboardWidth/Height = 540 / 560`
- `InpDashboardRefreshMs = 500`
- `InpDashboardMinWidth/MaxWidth = 400 / 600`

## Evidence to send back after MetaEditor compile

Capture:
1. MetaEditor compile output showing **0 errors**.
2. Journal lines containing the exact HUD123 build marker and `OpenAI model resolution:`.
3. A screenshot of the boxed HUD after attachment.
4. If testing fallback, Journal lines showing requested and active model IDs.
5. Experts/Journal logs through several broker-universe batches to confirm there is no abnormal termination.

Keep real-account execution blocked until the new EX5 has passed compile, boxed-HUD visual acceptance, model-resolution validation and repeated scanner stability on demo.
