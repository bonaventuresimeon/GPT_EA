# GPT_EA API Transport Release Evidence

The API transport contract supplements the existing R6 release evidence. It is mandatory for a REAL account when OpenAI/web intelligence is enabled.

## Evidence workflow

1. Select the production transport mode: `DIRECT_OPENAI` or `SECURE_PROXY`.
2. Configure the matching MT5 WebRequest allow-list destination.
3. Complete the applicable HIGH cases in `API_TRANSPORT_TEST_MATRIX.md` on demo.
4. Populate `release_evidence.json.api_transport` from `RELEASE_EVIDENCE_TEMPLATE.json`.
5. Set `release_evidence.json.gates.api_transport=true` only after the matrix actually passes.
6. Run:

```text
python tools/validate_api_transport_evidence.py release_evidence.json
```

7. Archive `api-transport-evidence-validation.txt` and the reported `API_TRANSPORT_SHA256`.
8. Run the normal R6 release validator.
9. Run the combined supplemental validator:

```text
python tools/validate_release_evidence_r7.py release_evidence.json
```

10. Archive `release-evidence-validation-r7.txt`.
11. Only after all other release requirements pass may `InpReleaseAPITransportPassed=true` be entered in the intended MT5 terminal.

## DIRECT evidence

Archive proof that:

- the endpoint is `api.openai.com`;
- HTTPS is used;
- MT5 allow-list contains `https://api.openai.com`;
- the key is configured locally and is absent from repository/log artifacts;
- a successful deep-review request and a successful web-search request were observed;
- at least one failure/backoff/recovery cycle was tested;
- request tracing was tested;
- no secret exposure occurred.

## PROXY evidence

Archive proof that:

- the proxy endpoint is HTTPS and allow-listed in MT5;
- the MT5 OpenAI API key may be blank;
- the proxy token is separate from the OpenAI key;
- the request received by the proxy contains no OpenAI `Authorization: Bearer <OpenAI key>` header;
- the OpenAI key exists only in server-side secret storage;
- the proxy forwards the Responses JSON contract required by the EA;
- deep-review and web-search requests both work through the proxy;
- authentication failure, rate limiting, timeout/server failure and recovery behavior were tested;
- EA trace ID can be correlated to proxy/upstream request ID;
- no secret exposure occurred.

## Automatic FAIL

Any of these is release blocking:

- bearer key can be sent to an untrusted direct endpoint;
- proxy receives the OpenAI bearer key from MT5;
- proxy token equals the OpenAI key;
- HTTP/non-TLS production proxy while HTTPS is required;
- missing MT5 allow-list evidence;
- required GPT/news outage becomes trade approval;
- uncontrolled synchronous retry loop;
- secret appears in `GPT_EA_APIHealth.csv`, source control, release logs or screenshots;
- applicable HIGH API test fails;
- `gates.api_transport` is false;
- API transport evidence validator fails.

The API transport evidence does not replace MetaEditor compile, Strategy Tester, broker/recovery/stop matrices, demo soak, CI/static evidence or final GO/NO-GO review.
