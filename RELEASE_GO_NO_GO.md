# GPT_EA Final GO / NO-GO Release Contract — R6 + R7 API Transport

This is the final production decision contract. A candidate is **GO** only when every mandatory release gate is PASS, the exact artifact/deployment identity is archived, the soak schema validates, the selected API/WebRequest transport passes its release matrix, and the machine-validated final review returns GO.

## GO requires all of the following

- MetaEditor compile gate PASS with 0 errors and 0 production warnings.
- Exact Git SHA recorded.
- Exact EX5 SHA-256 archived.
- Exact SET SHA-256 archived, or explicit `NONE`.
- `RELEASE_EVIDENCE_TEMPLATE.json` completed for the exact candidate.
- `SOAK_EVIDENCE_SCHEMA.json` validation PASS.
- `soak-evidence-validation.txt` archived with the correct soak digest.
- Strategy Tester and every applicable intelligence/adaptive/broker/recovery/stop/news matrix PASS.
- Deployment profile/drift validation PASS.
- `API_TRANSPORT_TEST_MATRIX.md` HIGH-priority cases applicable to the selected mode PASS.
- `api_transport` evidence records the tested DIRECT_OPENAI or SECURE_PROXY mode, WebRequest allow-list verification, deep-review path, web-search path, failure/recovery behavior, request tracing and zero secret leaks.
- `tools/validate_api_transport_evidence.py` returns PASS.
- `InpReleaseAPITransportPassed=true` is set only from matching archived evidence.
- Demo-soak acceptance contract PASS using the same EX5/SET candidate.
- All soak zero-tolerance counters equal 0.
- All required soak evidence logs/checkpoints observed.
- `FINAL_RELEASE_REVIEW_TEMPLATE.json` completed for the exact candidate.
- `tools/validate_final_release_review.py` returns PASS.
- `final-release-review-validation.txt` archived.
- Final decision is literal `GO`.
- base `tools/validate_release_evidence.py` returns PASS.
- supplemental `tools/validate_release_evidence_r7.py` returns PASS so API transport evidence is included in final certification.
- `release-evidence-validation.txt` and `release-evidence-validation-r7.txt` archived.
- Required base release validation ID and R7 API transport wrapper match the current source contract.

## Automatic NO-GO conditions

The release is **NO-GO** for any of the following:

- compile error or unresolved production warning;
- compiled EX5 cannot be tied to the recorded source commit;
- EX5/SET hash mismatch;
- stale release validation/evidence contract;
- API transport release matrix FAIL;
- `gates.api_transport` is not true;
- WebRequest allow-list not verified for the selected endpoint;
- DIRECT mode attempts to use a non-`api.openai.com` endpoint with the OpenAI bearer key;
- PROXY mode exposes or forwards the OpenAI bearer key from MT5;
- proxy credential reuses the OpenAI API key;
- API/proxy secret appears in source or health/release logs;
- required GPT/web intelligence failure can authorize a trade instead of following WAIT/NO-TRADE policy;
- uncontrolled synchronous API retry loop;
- API transport evidence validator FAIL;
- soak schema validation FAIL;
- soak digest mismatch;
- fewer than 5 soak trading days;
- insufficient London/New York/session-event coverage;
- missing scheduled or continuous scan evidence;
- missing primary/backup checkpoint evidence;
- any zero-tolerance soak counter above zero;
- any unresolved critical state;
- duplicate order or duplicate partial;
- stop regression;
- unprotected-position new authorization;
- release-gate bypass;
- duplicate analytics finalization;
- stop-observability join failure;
- dashboard/gate mismatch;
- runtime critical-error loop;
- deployment identity mismatch or structural drift not reviewed/revalidated;
- recovery inconsistency or non-idempotent lifecycle;
- final review decision other than `GO`;
- final review candidate hashes differ from release evidence;
- final review release-evidence basis digest mismatch;
- final review validator FAIL;
- base or R7 supplemental release evidence validator FAIL;
- executable source changed after validation;
- required evidence artifact missing;
- any unexplained critical Journal/Experts error.

## HOLD conditions

Use **HOLD** when the candidate may still become releasable but evidence is incomplete, a noncritical issue requires investigation, a required reviewer is unavailable, a deployment/API endpoint change requires targeted revalidation, or GitHub/MetaEditor external release infrastructure is unavailable.

HOLD must never arm real trading.

## Required release identity

Record and reconcile:

- Git SHA;
- release validation ID;
- MetaTrader build;
- MetaEditor build;
- compile evidence ID;
- EX5 SHA-256;
- SET SHA-256/`NONE`;
- selected API transport mode;
- API endpoint host/origin;
- API transport evidence digest/output;
- soak schema version;
- soak evidence ID/digest;
- final review evidence ID/digest;
- final reviewer/timestamp;
- broker company/server;
- account margin mode/currency/leverage;
- resolved symbols;
- test/soak date range.

## Final human review

Follow `FINAL_GO_NO_GO_REVIEW.md` and explicitly include API transport evidence in the reviewed artifact set.

For DIRECT mode, confirm the OpenAI key is local-only and the endpoint is `api.openai.com`. For PROXY mode, confirm the OpenAI key is server-side only, the MT5 request contains no OpenAI bearer header, and the proxy token is separately scoped/revocable.

Only then may `InpReleaseOperatorReviewPassed=true` and `InpReleaseAPITransportPassed=true` be entered in MT5 from their matching evidence.

## Final machine validation

After final review has been incorporated into `release_evidence.json`, run:

```text
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_api_transport_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

All results must be PASS.

## Deployment rule

A GO applies only to the exact candidate artifact, selected API transport, endpoint and validated environment. Material source, preset/risk, API transport/endpoint, broker/server/account or structural symbol-contract changes invalidate GO and require appropriate revalidation.

## Decision record

Release reviewer:

Candidate Git SHA:

Release validation ID:

API transport mode/evidence:

Soak evidence SHA-256:

Final review SHA-256:

Final release-evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:

Passing this contract does not guarantee profitability. It means the exact candidate has met the defined engineering, protection, recovery, broker-compatibility, API-transport, evidence-integrity and operational release requirements.
