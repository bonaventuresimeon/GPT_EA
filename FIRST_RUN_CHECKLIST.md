# GPT_EA First-Run Setup Checklist

Use this checklist the first time GPT_EA is installed on a new MT5 terminal, VPS, broker account, or newly compiled release.

Do not use a real-money account for first-run validation.

## A. Before opening GPT_EA

- [ ] MetaTrader 5 desktop is installed and updated.
- [ ] You are logged in to the intended **demo** account.
- [ ] The terminal shows a live broker connection.
- [ ] Market Watch is receiving live ticks.
- [ ] The chart is updating normally.
- [ ] Windows/VPS internet access is stable.
- [ ] GPT_EA release files are in the correct `MQL5/Experts/GPT_EA` folder.
- [ ] If source was supplied, `GPT_EA.mq5` compiled with 0 errors and no unresolved production warnings.
- [ ] The installed EX5/source version matches the release package you intend to test.

## B. OpenAI account and API

- [ ] You are using **your own** OpenAI API platform account.
- [ ] API billing/credits are active.
- [ ] You created your own secret API key.
- [ ] The key has **not** been shared with the seller, broker, Telegram/Discord group, or support.
- [ ] You understand that ChatGPT subscriptions and API billing are separate.

Recommended API model choices:

- `gpt-5.6-luna` — economical/high-volume default.
- `gpt-5.6-terra` — stronger intelligence/cost balance.
- `gpt-5.6-sol` — stronger complex professional reasoning.
- `gpt-6-astra` — **maximum-intelligence option** for the hardest analysis when the additional API cost/latency is acceptable and the model is available to your API project.

OpenAI currently identifies GPT-6 Astra as its most capable model and supports it on the Responses API.

## C. MT5 WebRequest permission

In MT5 open **Tools → Options → Expert Advisors** and verify:

- [ ] `Allow WebRequest for listed URL` is enabled.
- [ ] `https://api.openai.com` is listed exactly.
- [ ] MT5 Algo Trading is enabled.
- [ ] The EA properties allow algorithmic trading.

For standard customer-owned API keys use:

    InpAPITransportMode = GPT_API_DIRECT_OPENAI
    InpOpenAIEndpoint = https://api.openai.com/v1/responses

## D. Attach GPT_EA

- [ ] Open one liquid chart.
- [ ] Drag GPT_EA from Navigator onto the chart.
- [ ] Use one EA instance per intended account/magic configuration unless the release instructions specify otherwise.
- [ ] Load the certified non-secret preset if one was supplied.
- [ ] Confirm the preset's API-key field is blank before loading it.
- [ ] Enter your API key manually **after** loading the preset.
- [ ] Do not save or redistribute a `.set` file containing the API key.

Recommended first-run inputs:

    InpUseOpenAI = true
    InpAPITransportMode = GPT_API_DIRECT_OPENAI
    InpOpenAIAPIKey = <YOUR OWN SECRET API KEY>
    InpOpenAIEndpoint = https://api.openai.com/v1/responses
    InpOpenAIModel = <SELECTED SUPPORTED MODEL>
    InpRequireApproval = true
    InpEnableApprovedExecution = true
    InpAPIRequireProxyOnReal = false

## E. Broker and market-data checks

- [ ] GPT_EA resolves every configured symbol to the intended broker instrument.
- [ ] The resolved symbols receive live quotes.
- [ ] D1, H4, H1, M30, M15 and M5 data are synchronized.
- [ ] Spread is visible and reasonable for the session.
- [ ] Broker stop/freeze information initializes.
- [ ] Account currency, margin mode and leverage are detected correctly.
- [ ] Optional yield/intermarket symbols are either available or safely reported unavailable.

## F. Startup health checks

Open **Experts** and **Journal** and confirm:

- [ ] No unresolved critical initialization error.
- [ ] Recovery/checkpoint system initializes.
- [ ] Stop-management/observability system initializes.
- [ ] Strategy intelligence initializes.
- [ ] Release/safety gate reports an understandable state.
- [ ] API transport configuration reports DIRECT_OPENAI correctly.
- [ ] No API key or other secret appears in Journal, Experts, CSV logs, screenshots, or dashboard text.

A release gate may remain BLOCKED on demo or before certification. Do not bypass it merely to make an order open.

## G. Test a real OpenAI request on demo

WebRequest does not operate in MT5 Strategy Tester, so perform this test on a live-connected **demo** terminal.

- [ ] Trigger or allow a GPT_EA scan that requires GPT/news intelligence.
- [ ] Confirm the request reaches the OpenAI endpoint.
- [ ] Confirm HTTP 2xx or a normal OpenAI response is received.
- [ ] Confirm no 401/403 authentication failure.
- [ ] Confirm no persistent 429 quota/rate-limit failure.
- [ ] Confirm no synthetic 598/599 WebRequest transport failure.
- [ ] Confirm GPT/news output is parsed normally.
- [ ] Confirm required intelligence failure causes WAIT/NO TRADE rather than blind approval.

If the request fails, use `API_KEY_TROUBLESHOOTING.md`. Never share the secret key.

## H. Functional first-run checks

- [ ] Run **SCAN NOW** or wait for a scheduled/continuous scan.
- [ ] Verify the EA can return HIGH-CONFIDENCE, WAIT/REANALYZE, or NO TRADE.
- [ ] Verify APPROVE and DENY controls work.
- [ ] Verify approval expires when ignored.
- [ ] Verify a stale setup is rejected during final revalidation.
- [ ] Verify broker/OrderCheck rejection does not force an order.
- [ ] Verify stop-loss is attached/managed correctly on controlled demo testing.
- [ ] Verify TP1/TP2 partial-management state does not duplicate.
- [ ] Restart MT5 and verify recovery resumes without duplicate execution.

## I. Before leaving the EA running

- [ ] API billing has sufficient headroom for your selected model.
- [ ] The selected model is intentionally chosen.
- [ ] Risk remains at the certified/recommended starting level.
- [ ] Human approval remains enabled for initial deployment.
- [ ] PC/VPS clock and internet are stable.
- [ ] MT5 stays logged in to the intended account.
- [ ] You know where to find Experts, Journal, API health, execution and stop logs.

## J. PASS / FAIL record

Record:

    Date:
    MT5 build:
    GPT_EA release/version:
    Broker:
    Server:
    Account: DEMO
    Configured symbols:
    OpenAI model:
    WebRequest allow-list: PASS / FAIL
    API request: PASS / FAIL
    Market-data synchronization: PASS / FAIL
    Broker validation: PASS / FAIL
    Approval workflow: PASS / FAIL
    Restart/recovery: PASS / FAIL
    Secrets exposed: 0 required
    Critical startup errors: 0 required
    Overall first-run result: PASS / FAIL
    Notes:

A first-run PASS means the installation and basic connectivity are functioning. It does **not** mean the EA is certified for live trading or that a strategy is profitable.
