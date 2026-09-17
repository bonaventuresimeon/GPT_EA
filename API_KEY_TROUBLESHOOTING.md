# GPT_EA Safe API-Key Troubleshooting

Use this guide when GPT_EA cannot reach OpenAI, returns an authentication/quota error, or repeatedly enters API transport backoff.

## Non-negotiable security rule

Never send or post your full OpenAI API key.

Do not send it to GPT_EA support, the EA seller/developer, your broker, Telegram/WhatsApp/Discord groups, GitHub issues, screenshots, public logs or remote-support chats.

Support can diagnose almost every API problem from the **HTTP status, redacted OpenAI error text, request ID, MT5 build, GPT_EA version and transport status**.

If a key was exposed, revoke/delete it in the OpenAI API platform and create a new one.

## 1. Confirm the local configuration

For standard customer-owned direct API access verify:

    InpUseOpenAI = true
    InpAPITransportMode = GPT_API_DIRECT_OPENAI
    InpOpenAIEndpoint = https://api.openai.com/v1/responses
    InpOpenAIAPIKey = <YOUR OWN KEY>
    InpOpenAIModel = <SUPPORTED MODEL ID>

Do not paste the key into the endpoint field.

Do not change the endpoint to a third-party host. GPT_EA's direct transport is designed to refuse sending the OpenAI bearer key to a non-OpenAI host.

## 2. Confirm MT5 WebRequest permission

Open **Tools → Options → Expert Advisors** and verify:

- `Allow WebRequest for listed URL` is enabled.
- `https://api.openai.com` appears in the list.
- Internet/DNS/TLS connectivity works on the PC/VPS.

WebRequest does not operate in Strategy Tester. Test real API connectivity on a demo terminal.

## 3. HTTP 401 — authentication failed

Typical causes include a mistyped/truncated key, revoked key, wrong project/key permission, or entering another token instead of the OpenAI key.

Safe fix:

1. Do **not** post the existing key.
2. Open your OpenAI API project's API Keys page.
3. Confirm the intended key is active.
4. If uncertain, revoke it and create a new key.
5. Enter the new key locally in MT5.
6. Restart/reload GPT_EA if necessary.
7. Retest on demo.

## 4. HTTP 403 — permission/access denied

Check project/key permissions, whether the selected model is available to the project, account/organization restrictions, and whether the request is being made from the intended project.

Do not solve a 403 by sharing your key with support.

## 5. HTTP 429 — rate limit, usage limit or billing/credit issue

Read the returned OpenAI error text because 429 can have different causes.

Check:

- API billing/credit balance;
- project/organization usage limits;
- API rate limits;
- whether many GPT_EA instances are using the same project/key;
- selected model's rate limits;
- whether GPT_EA transport backoff is already active.

GPT_EA should respect its backoff instead of hammering the API repeatedly.

## 6. HTTP 5xx — upstream service failure

A 5xx response generally indicates an upstream/service-side failure.

Allow GPT_EA's backoff to operate. Check OpenAI service status if necessary. Do not repeatedly reload the EA to force rapid retries. Required GPT/news intelligence should remain WAIT/NO TRADE when the configured policy requires it.

## 7. Synthetic 599 — MT5/network/WebRequest failure

GPT_EA uses synthetic `599` for native MT5/network transport failure.

Check:

- `https://api.openai.com` is allow-listed;
- internet works on the terminal/VPS;
- DNS resolves normally;
- HTTPS/TLS is not blocked by firewall/security software;
- MT5 is not being tested inside Strategy Tester;
- the configured endpoint is correct.

## 8. Synthetic 598 — GPT_EA transport backoff

Synthetic `598` means GPT_EA is deliberately blocking another request while the local circuit/backoff is active.

Do not keep clicking Scan Now repeatedly.

Find the earlier failure first—401/403, 429, 5xx, timeout or 599—and correct that cause. After the backoff expires, a successful request should clear the failure state.

## 9. Invalid/unsupported model

If the API reports that the model is unavailable or unsupported:

1. Check the current OpenAI API model documentation.
2. Use a model available to your API project.
3. Enter the exact model ID.

Current documented GPT_EA choices include:

- `gpt-5.6-luna`
- `gpt-5.6-terra`
- `gpt-5.6-sol`
- `gpt-6-astra`

GPT-6 Astra is the maximum-intelligence option and is supported on the Responses API, but it has materially higher token pricing than the lower GPT-5.6 tiers. Model availability and pricing can change.

## 10. API works elsewhere but not MT5

Check the MT5 WebRequest allow-list, exact endpoint, Windows/VPS firewall, EA transport mode, Strategy Tester limitation, whether the key was entered into the correct EA instance, and whether a `.set` preset overwrote the key/model after you entered it.

## 11. API works once, then stops

Check 429 rate/usage limits, API account credit/billing, configured timeout, repeated 5xx/timeouts, `GPT_EA_APIHealth.csv` for failure/backoff state, and whether many symbols/scans are producing more API calls than expected.

Never upload `GPT_EA_APIHealth.csv` without first confirming it contains no accidentally added secrets. The current transport is designed not to log keys/tokens.

## 12. Key accidentally saved in an MT5 `.set` file

Treat that preset as secret.

If the preset was shared or uploaded:

1. Revoke/delete the exposed API key immediately.
2. Create a replacement key.
3. Remove the exposed preset from shared locations.
4. Load a clean vendor preset with a blank API-key field.
5. Enter the replacement key locally.

## 13. Key accidentally committed to GitHub or sent publicly

Revoke it immediately. Deleting the visible message/commit later is not enough because the secret may already have been copied or retained in history/caches.

Create a new key and review API usage for unexpected activity.

## 14. Safe support bundle

Provide only:

    GPT_EA version/release ID:
    MT5 build:
    Broker/company:
    Trade server:
    DEMO or REAL:
    API transport mode:
    OpenAI model ID:
    HTTP/synthetic status:
    Redacted OpenAI error text:
    OpenAI x-request-id or GPT_EA trace ID:
    Time of failure:
    WebRequest allow-list configured: YES/NO
    Internet on VPS/PC: YES/NO
    Relevant Experts/Journal lines with secrets redacted:

Never provide the API key itself.

## 15. When the connection is fixed

Retest on demo and confirm:

- one normal 2xx request;
- live web/news path works;
- deep GPT review works;
- request/trace IDs are recorded as expected;
- prior backoff clears;
- no secrets appear in logs;
- required-intelligence failure still fails safely.

A working API connection does not override GPT_EA's release, risk, broker, stop, approval or market-quality gates.
