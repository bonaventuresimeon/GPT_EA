<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🌐 AI & API Operations

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🌐 **Document:** `API_TRANSPORT_TEST_MATRIX.md`

---

# GPT_EA API Transport Release Test Matrix

This matrix is release blocking for any candidate that enables OpenAI/web intelligence. Complete the applicable DIRECT and/or PROXY cases on demo before `InpReleaseAPITransportPassed=true` is used on a REAL account.

| ID | Priority | Mode | Test | Expected result |
|---|---|---|---|---|
| API-01 | HIGH | DIRECT | Valid OpenAI endpoint, valid local key, allow-list configured | Responses request succeeds; parser receives normal upstream JSON |
| API-02 | HIGH | DIRECT | Remove `https://api.openai.com` from MT5 allow-list | Request fails safely; no trade is approved merely because intelligence is unavailable |
| API-03 | HIGH | DIRECT | Change endpoint to non-OpenAI host | Configuration gate blocks before bearer key can be sent |
| API-04 | HIGH | DIRECT | Empty/invalid local API key | Configuration/request fails closed for required GPT intelligence |
| API-05 | HIGH | DIRECT | HTTP 401/403 | Authentication failure recorded; extended backoff applies |
| API-06 | HIGH | BOTH | HTTP 429 | Rate-limit event recorded; later calls observe backoff |
| API-07 | HIGH | BOTH | HTTP 500/502/503 | Server failure recorded; circuit/backoff activates according to policy |
| API-08 | HIGH | BOTH | Network/DNS/TLS failure | Native MT5 failure is normalized to synthetic 599 with non-secret diagnostic |
| API-09 | HIGH | BOTH | Timeout | No tight synchronous retry loop; setup follows configured WAIT/NO-TRADE failure policy |
| API-10 | HIGH | BOTH | Recovery after backoff | First successful 2xx clears failure/backoff state and logs RECOVERED |
| API-11 | HIGH | PROXY | Valid proxy token and compatible response forwarding | Existing Responses parser succeeds unchanged |
| API-12 | HIGH | PROXY | Inspect proxy request headers | OpenAI `Authorization` bearer header is absent; only scoped proxy token is present |
| API-13 | HIGH | PROXY | Proxy token equals locally configured OpenAI key | Configuration gate blocks unsafe credential reuse |
| API-14 | HIGH | PROXY | Empty/short proxy token | Configuration gate blocks |
| API-15 | HIGH | PROXY | HTTP proxy endpoint while HTTPS required | Configuration gate blocks |
| API-16 | HIGH | PROXY | `InpAPIRequireProxyOnReal=true` with DIRECT selected on controlled real-account preflight/no-send environment | Release configuration remains blocked; no order authorization |
| API-17 | HIGH | BOTH | Web-search Responses request | Web-search/news JSON passes through transport and structured parser/source checks still operate |
| API-18 | HIGH | BOTH | Deep GPT review request | Reasoning request body passes unchanged and normal review parser works |
| API-19 | HIGH | BOTH | Malformed API/proxy JSON response | Existing model-integrity/parser policy rejects or downgrades; no blind approval |
| API-20 | HIGH | BOTH | Required high-confidence intelligence unavailable | Final decision is WAIT/NO TRADE according to fail-closed policy |
| API-21 | HIGH | BOTH | `InpReleaseAPITransportPassed=false` on REAL account | R7 API release wrapper blocks new entries |
| API-22 | HIGH | BOTH | Transport config invalid while release flag true | R7 API release wrapper still blocks new entries |
| API-23 | MEDIUM | DIRECT | Successful response contains `x-request-id` | Request ID is captured in `GPT_EA_APIHealth.csv` when a health event is written |
| API-24 | MEDIUM | BOTH | Repeated failures below/above threshold | Failure counter and next-retry state follow configured threshold/backoff |
| API-25 | MEDIUM | BOTH | Local circuit active | No native WebRequest is attempted until backoff expires; synthetic 598 returned |
| API-26 | MEDIUM | BOTH | Inspect `GPT_EA_APIHealth.csv` | No OpenAI key, proxy token or broker credential appears in the file |
| API-27 | MEDIUM | PROXY | Backend returns upstream OpenAI non-2xx body/status | EA receives same failure class; proxy does not convert errors into false 2xx success |
| API-28 | MEDIUM | PROXY | Proxy request ID correlation | EA trace can be joined to proxy log and upstream `x-request-id` |
| API-29 | MEDIUM | BOTH | Strategy Tester | No live WebRequest expected; deterministic tester/failure-injection behavior remains usable |
| API-30 | MEDIUM | BOTH | Long/slow response near timeout ceiling | EA returns control within configured transport maximum; no runaway blocking loop |

## Mandatory release evidence

Archive for the selected production mode:

- MT5 Expert Advisors WebRequest allow-list screenshot/config evidence;
- selected transport mode and endpoint host;
- API test case results;
- redacted `GPT_EA_APIHealth.csv` sample;
- at least one successful request/response trace ID;
- at least one controlled failure and recovery trace;
- proof that logs contain no API/proxy secrets;
- for PROXY mode, backend evidence that the OpenAI key remains server-side and the MT5 request contains no OpenAI bearer header;
- confirmation that the web-search and deep-review paths both work through the selected transport;
- confirmation that unavailable required intelligence does not authorize a trade.

## PASS rule

All HIGH cases applicable to the selected production mode must PASS. Any credential leak, direct bearer-key delivery to an untrusted host, release-gate bypass, false approval during required-intelligence failure, uncontrolled retry loop or proxy error converted into a false success is automatic FAIL/NO-GO.
