# GPT_EA API Transport Architecture

GPT_EA supports two OpenAI/WebRequest transport modes through `GPT_EA_Part37_APITransport.mqh`.

## 1. DIRECT_OPENAI

Flow:

`MT5 EA -> https://api.openai.com/v1/responses`

Use this for private development, a personally controlled terminal, or controlled demo testing.

Properties:

- no backend hosting is required;
- lowest architectural complexity and one less network hop;
- MT5 must allow-list `https://api.openai.com`;
- the OpenAI API key is configured locally in the EA input and is therefore present on that terminal;
- the transport refuses to send that bearer key to any endpoint outside `https://api.openai.com`;
- a unique `X-Client-Request-Id` is attached for request tracing;
- OpenAI response `x-request-id` is captured when available;
- failures feed the transport circuit/backoff state.

Direct mode is not the preferred distribution model for an EA supplied to multiple customers because the OpenAI secret would have to exist on each customer terminal.

## 2. SECURE_PROXY

Flow:

`MT5 EA -> your HTTPS proxy -> OpenAI Responses API`

Use this for multi-user production deployment, licensing, centralized usage control, or whenever the OpenAI key must remain off client terminals.

The proxy endpoint must accept the same OpenAI Responses JSON body used by GPT_EA. The EA deliberately drops the caller's OpenAI `Authorization` header before contacting the proxy and sends only:

- `Content-Type: application/json`;
- `Accept: application/json`;
- `X-GPT-EA-Token` — a scoped/revocable proxy credential;
- `X-GPT-EA-Request-Id` — per-request trace ID;
- `X-GPT-EA-Upstream: openai-responses`.

The proxy should inject the OpenAI API key server-side, forward to the Responses API, and return the upstream HTTP status and JSON response body without changing the response structure expected by the EA.

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

## 3. Transport failure policy

`WebRequest()` is synchronous in MT5, so GPT_EA does not perform tight immediate retry loops. Repeated synchronous retries would block the EA event thread.

The transport instead maintains a cross-call circuit state:

- 2xx -> clears prior failure/backoff state;
- 401/403 -> authentication block and longer backoff;
- 429 -> rate-limit backoff;
- 5xx -> server/transport backoff;
- native MT5 `WebRequest()` failure -> synthetic status `599` with deterministic diagnostic text;
- local circuit/backoff block -> synthetic status `598`;
- recovery after a prior failure -> `RECOVERED` health event.

Existing high-confidence news/GPT policies remain responsible for deciding whether unavailable intelligence means WAIT/NO TRADE. The transport layer must never convert missing intelligence into approval.

## 4. Observability

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

## 5. Real-account release rule

`InpReleaseAPITransportPassed` defaults to `false`. A REAL account cannot pass the R7 API transport release wrapper until the applicable cases in `API_TRANSPORT_TEST_MATRIX.md` have been completed and the selected transport configuration is valid.

`InpAPIRequireProxyOnReal=true` can be used by a production operator to make DIRECT mode invalid on a real account.

This transport gate is additive. It does not bypass compile, CI, soak, broker, stop, news, final-review, live-arm or risk gates.
