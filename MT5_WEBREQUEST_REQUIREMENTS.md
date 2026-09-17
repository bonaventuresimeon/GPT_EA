# GPT_EA MT5 WebRequest Requirements

This document is the operator checklist for external API access from MetaTrader 5.

## Required MT5 configuration

1. Run GPT_EA as an **Expert Advisor**, not an indicator. MQL5 `WebRequest()` is available to EAs/scripts and is not available to indicators.
2. Open `Tools -> Options -> Expert Advisors` in the MT5 terminal.
3. Enable `Allow WebRequest for listed URL`.
4. Add the selected transport destination to the list:
   - DIRECT mode: `https://api.openai.com`
   - PROXY mode: the HTTPS origin/endpoint configured in `InpAPIProxyEndpoint`.
5. Keep Algo Trading/EA permissions enabled as required by the rest of the release gate.
6. Ensure the terminal/VPS has working DNS, internet access and TLS connectivity to the allow-listed host.
7. Use HTTPS for production. GPT_EA can reject non-HTTPS transport when `InpAPIRequireHTTPS=true`.
8. Configure a finite timeout. `InpOpenAITimeoutMs` remains the call-specific timeout and `InpAPITransportMaxTimeoutMs` caps transport blocking time.
9. Do not expect live WebRequest behavior in MetaTrader Strategy Tester. MQL5 does not execute `WebRequest()` there; test external-service failure/recovery with the repository's deterministic mocks/failure-injection procedures and validate live transport on demo.
10. Treat HTTP and MT5 transport failures separately. Native `WebRequest()` returns an HTTP status on server response and `-1` for an MT5/network failure. The R7 transport normalizes native failure to internal status `599` and circuit-backoff to `598` for deterministic downstream handling.
11. Do not implement rapid synchronous retry loops. `WebRequest()` blocks the EA thread until the response or timeout. GPT_EA uses backoff across later calls instead.
12. Never put API keys/tokens in source control or logs. DIRECT mode uses the OpenAI key only on the local terminal. PROXY mode uses a separate scoped proxy token while the OpenAI key stays server-side.
13. In DIRECT mode, keep `InpOpenAIEndpoint` on `https://api.openai.com/...`. The R7 transport refuses to send the bearer key to another host.
14. In PROXY mode, the proxy must return an OpenAI-Responses-compatible JSON body so the existing response parser/news/deep-review logic remains unchanged.
15. Archive API transport test evidence before setting `InpReleaseAPITransportPassed=true` on a REAL account.

## Expected DIRECT configuration

- `InpAPITransportMode = GPT_API_DIRECT_OPENAI`
- `InpOpenAIEndpoint = https://api.openai.com/v1/responses`
- `InpOpenAIAPIKey` configured locally
- `InpAPIProxyEndpoint` may remain blank
- `InpAPIProxyToken` may remain blank
- MT5 WebRequest allow-list contains `https://api.openai.com`

## Expected PROXY configuration

- `InpAPITransportMode = GPT_API_SECURE_PROXY`
- `InpAPIProxyEndpoint = https://<your-domain>/<responses-endpoint>`
- `InpAPIProxyToken` is a scoped/revocable credential issued by your backend
- OpenAI API key should not be distributed to customer terminals
- MT5 WebRequest allow-list contains the proxy HTTPS host/endpoint
- optional production enforcement: `InpAPIRequireProxyOnReal=true`

## Request tracing

DIRECT requests add `X-Client-Request-Id`.

PROXY requests add `X-GPT-EA-Request-Id`; the proxy should log that value and associate it with the upstream OpenAI `x-request-id` when available.

This gives a trace even when a timeout prevents the EA from receiving an upstream request ID.
