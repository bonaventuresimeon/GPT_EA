# GPT_EA API Transport Architecture

GPT_EA supports two OpenAI/WebRequest transport modes through `GPT_EA_Part37_APITransport.mqh`.

## Product default: each user supplies their own OpenAI API key

For normal GPT_EA customer installation, the intended onboarding model is:

`Customer MT5 -> OpenAI Responses API using that customer's own OpenAI API key`

Each user creates and funds their own OpenAI API account, creates their own secret key, and enters that key locally in the GPT_EA inputs.

This keeps API usage, billing, quota and rate limits associated with the individual user's OpenAI account rather than sharing one vendor OpenAI key across all installations.

The API key itself is not purchased. The user creates a secret key and separately enables/funds API billing. ChatGPT subscriptions and OpenAI API billing are separate.

The user must never send their API key to the GPT_EA vendor, broker, support staff or another user.

See `USER_INSTALLATION_GUIDE.md` for the complete customer installation procedure.

## 1. DIRECT_OPENAI — standard customer mode

Flow:

`MT5 EA -> https://api.openai.com/v1/responses`

Use this when each GPT_EA user supplies their own OpenAI API key.

Properties:

- no GPT_EA backend hosting is required;
- each user owns and pays for their own OpenAI API usage;
- one customer's API quota/billing does not need to be shared with another customer's installation;
- lowest architectural complexity and one less network hop;
- MT5 must allow-list `https://api.openai.com`;
- the user's OpenAI API key is configured locally in the EA input and is therefore present on that user's terminal;
- the transport refuses to send that bearer key to any endpoint outside `https://api.openai.com`;
- a unique `X-Client-Request-Id` is attached for request tracing;
- OpenAI response `x-request-id` is captured when available;
- failures feed the transport circuit/backoff state.

Recommended customer settings:

```text
InpUseOpenAI = true
InpAPITransportMode = GPT_API_DIRECT_OPENAI
InpOpenAIAPIKey = <USER'S OWN SECRET KEY>
InpOpenAIEndpoint = https://api.openai.com/v1/responses
InpAPIRequireProxyOnReal = false
```

The default model remains `gpt-5.6-luna`. Users may select another supported model if their API project permits it and they accept the corresponding cost/latency profile.

Security requirement: do not save or distribute a `.set` preset after entering a real API key unless the preset is being stored privately by that same user. Vendor/release presets must keep the API-key field blank.

## 2. SECURE_PROXY — optional centralized mode

Flow:

`MT5 EA -> your HTTPS proxy -> OpenAI Responses API`

This remains available for deployments that deliberately want centralized licensing, API routing, organization-managed OpenAI billing or server-side policy control.

The proxy endpoint must accept the same OpenAI Responses JSON body used by GPT_EA. The EA deliberately drops the caller's OpenAI `Authorization` header before contacting the proxy and sends only:

- `Content-Type: application/json`;
- `Accept: application/json`;
- `X-GPT-EA-Token` — a scoped/revocable proxy credential;
- `X-GPT-EA-Request-Id` — per-request trace ID;
- `X-GPT-EA-Upstream: openai-responses`.

The proxy should inject its own OpenAI API credential server-side, forward to the Responses API, and return the upstream HTTP status and JSON response body without changing the response structure expected by the EA.

Recommended proxy controls:

- HTTPS only;
- OpenAI key stored only as a server secret/environment variable;
- per-user or per-license proxy tokens;
- token revocation;
- request/body-size limits;
- per-user and global rate limits;
- model allow-list;
- request timeout;
- no broker password, MT5 master password or trading credential accepted by the proxy;
- structured audit records using the EA request ID plus upstream `x-request-id`;
- no API keys/tokens written to application logs;
- preserve useful upstream rate-limit headers where practical;
- fail closed on authentication errors;
- health/metrics endpoint separate from the trading-analysis endpoint.

Proxy mode is optional. It is not required for a normal GPT_EA user who supplies their own OpenAI API key.

## 3. Transport failure policy

`WebRequest()` is synchronous in MT5, so GPT_EA does not perform tight immediate retry loops. Repeated synchronous retries would block the EA event thread.

The transport instead maintains a cross-call circuit state:

- 2xx -> clears prior failure/backoff state;
- 401/403 -> authentication block and longer backoff;
- 429 -> rate-limit/backoff path;
- 5xx -> server/transport backoff;
- native MT5 `WebRequest()` failure -> synthetic status `599` with deterministic diagnostic text;
- local circuit/backoff block -> synthetic status `598`;
- recovery after a prior failure -> `RECOVERED` health event.

Existing high-confidence news/GPT policies remain responsible for deciding whether unavailable intelligence means WAIT/NO TRADE. The transport layer must never convert missing intelligence into approval.

## 4. MT5 WebRequest requirement

For DIRECT_OPENAI, each user must add this URL in:

**Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL**

```text
https://api.openai.com
```

MQL5 does not permit an EA to silently add this allow-list entry for the user. It must be configured by the terminal user.

WebRequest is not executed in the MetaTrader Strategy Tester, so real API connectivity must be validated on a demo chart/terminal.

## 5. Observability

`GPT_EA_APIHealth.csv` contains only non-secret transport diagnostics:

- timestamp;
- transport mode;
- client trace ID;
- HTTP/synthetic status;
- MT5 error code when applicable;
- consecutive failure count;
- next retry time;
- upstream/proxy request ID when returned;
- outcome class.

Do not add the OpenAI API key or proxy token to this file.

## 6. Customer secret-handling rule

The user's OpenAI key is a personal secret.

GPT_EA support procedures must never ask the customer to provide the full key. Troubleshooting should use:

- HTTP status/error code;
- request ID;
- model name;
- MT5 build;
- broker/server;
- redacted Journal/Experts messages;
- redacted screenshots.

If a key is accidentally exposed, the user should revoke/delete it in the OpenAI API platform and create a new one.

## 7. Real-account release rule

`InpReleaseAPITransportPassed` defaults to `false`. A REAL account cannot pass the API transport release wrapper until the applicable cases in `API_TRANSPORT_TEST_MATRIX.md` have been completed and the selected transport configuration is valid.

`InpAPIRequireProxyOnReal` should remain `false` for the standard customer-owned DIRECT_OPENAI deployment. A production operator may deliberately set it to `true` only for a separately certified proxy-only deployment.

This transport gate is additive. It does not bypass compile, CI, soak, broker, stop, news, final-review, live-arm or risk gates.
