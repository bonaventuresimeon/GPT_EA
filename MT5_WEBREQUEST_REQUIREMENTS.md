# GPT_EA MT5 WebRequest Requirements

This document is the operator checklist for external API access from MetaTrader 5.

For standard GPT_EA customer installations, use **DIRECT_OPENAI** with the **user's own OpenAI API key**. Proxy mode is optional and is intended only for separately managed centralized deployments.

## Required MT5 configuration

1. Run GPT_EA as an **Expert Advisor**, not an indicator. MQL5 `WebRequest()` is available to EAs/scripts and is not available to indicators.
2. Open `Tools -> Options -> Expert Advisors` in the MT5 terminal.
3. Enable `Allow WebRequest for listed URL`.
4. Add the selected transport destination to the list:
   - standard customer DIRECT mode: `https://api.openai.com`
   - optional PROXY mode: the HTTPS origin/endpoint configured in `InpAPIProxyEndpoint`.
5. Keep Algo Trading/EA permissions enabled as required by the rest of the release gate.
6. Ensure the terminal/VPS has working DNS, internet access and TLS connectivity to the allow-listed host.
7. Use HTTPS for production. GPT_EA can reject non-HTTPS transport when `InpAPIRequireHTTPS=true`.
8. Configure a finite timeout. `InpOpenAITimeoutMs` remains the call-specific timeout and `InpAPITransportMaxTimeoutMs` caps transport blocking time.
9. Do not expect live WebRequest behavior in MetaTrader Strategy Tester. MQL5 does not execute `WebRequest()` there; test external-service failure/recovery with the repository's deterministic mocks/failure-injection procedures and validate live transport on demo.
10. Treat HTTP and MT5 transport failures separately. Native `WebRequest()` returns an HTTP status on server response and `-1` for an MT5/network failure. The API transport normalizes native failure to internal status `599` and circuit-backoff to `598` for deterministic downstream handling.
11. Do not implement rapid synchronous retry loops. `WebRequest()` blocks the EA thread until the response or timeout. GPT_EA uses backoff across later calls instead.
12. Never put API keys/tokens in source control or logs. DIRECT mode uses the customer's OpenAI key only on that customer's terminal. PROXY mode uses a separate scoped proxy token while the OpenAI key stays server-side.
13. In DIRECT mode, keep `InpOpenAIEndpoint` on `https://api.openai.com/...`. The transport refuses to send the bearer key to another host.
14. In PROXY mode, the proxy must return an OpenAI-Responses-compatible JSON body so the existing response parser/news/deep-review logic remains unchanged.
15. Archive API transport test evidence before setting `InpReleaseAPITransportPassed=true` on a REAL account.

## OpenAI account requirement for each user

Each GPT_EA user should:

1. sign in to their own OpenAI API platform account;
2. enable/fund API billing separately from any ChatGPT subscription;
3. create their own secret API key;
4. keep the key private;
5. enter the key locally in GPT_EA;
6. never send the full key to GPT_EA support or another person.

The secret key itself is not purchased. The user creates the key and pays for API usage through the OpenAI API billing system.

See `USER_INSTALLATION_GUIDE.md` for the complete customer procedure.

## Expected DIRECT customer configuration

```text
InpUseOpenAI = true
InpAPITransportMode = GPT_API_DIRECT_OPENAI
InpOpenAIEndpoint = https://api.openai.com/v1/responses
InpOpenAIAPIKey = <USER'S OWN SECRET KEY>
InpAPIRequireProxyOnReal = false
```

Additional notes:

- `InpAPIProxyEndpoint` may remain blank;
- `InpAPIProxyToken` may remain blank;
- MT5 WebRequest allow-list must contain `https://api.openai.com`;
- vendor/release `.set` files should keep `InpOpenAIAPIKey` blank;
- the user should enter the secret only after loading the non-secret preset;
- do not share/export a `.set` file after it contains a real API key.

## Optional PROXY configuration

- `InpAPITransportMode = GPT_API_SECURE_PROXY`
- `InpAPIProxyEndpoint = https://<your-domain>/<responses-endpoint>`
- `InpAPIProxyToken` is a scoped/revocable credential issued by your backend
- OpenAI API key should not be distributed to customer terminals in this mode
- MT5 WebRequest allow-list contains the proxy HTTPS host/endpoint
- optional enforcement: `InpAPIRequireProxyOnReal=true`

Proxy mode is not required for the standard user-owned API-key deployment.

## Request tracing

DIRECT requests add `X-Client-Request-Id`.

PROXY requests add `X-GPT-EA-Request-Id`; the proxy should log that value and associate it with the upstream OpenAI `x-request-id` when available.

This gives a trace even when a timeout prevents the EA from receiving an upstream request ID.
