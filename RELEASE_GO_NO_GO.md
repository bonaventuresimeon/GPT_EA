# GPT_EA Final GO / NO-GO Release Contract — R6

This is the final production decision contract. A candidate is **GO** only when every mandatory release gate is PASS, the exact artifact/deployment identity is archived, the soak schema validates, and the machine-validated final review returns GO.

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
- Demo-soak acceptance contract PASS using the same EX5/SET candidate.
- All soak zero-tolerance counters equal 0.
- All required soak evidence logs/checkpoints observed.
- `FINAL_RELEASE_REVIEW_TEMPLATE.json` completed for the exact candidate.
- `tools/validate_final_release_review.py` returns PASS.
- `final-release-review-validation.txt` archived.
- Final decision is literal `GO`.
- `tools/validate_release_evidence.py` returns PASS after final-review identity is copied into the release evidence.
- `release-evidence-validation.txt` archived.
- Required release validation ID matches the current source contract.

## Automatic NO-GO conditions

The release is **NO-GO** for any of the following:

- compile error or unresolved production warning;
- compiled EX5 cannot be tied to the recorded source commit;
- EX5/SET hash mismatch;
- stale release validation ID;
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
- secret/API-key exposure;
- deployment identity mismatch or structural drift not reviewed/revalidated;
- recovery inconsistency or non-idempotent lifecycle;
- final review decision other than `GO`;
- final review candidate hashes differ from release evidence;
- final review release-evidence basis digest mismatch;
- final review validator FAIL;
- release evidence validator FAIL;
- executable source changed after validation;
- required evidence artifact missing;
- any unexplained critical Journal/Experts error.

## HOLD conditions

Use **HOLD** when the candidate may still become releasable but evidence is incomplete, a noncritical issue requires investigation, a required reviewer is unavailable, or a deployment change requires targeted revalidation.

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
- soak schema version;
- soak evidence ID/digest;
- final review evidence ID/digest;
- final reviewer/timestamp;
- broker company/server;
- account margin mode/currency/leverage;
- resolved symbols;
- test/soak date range.

## Final human review

Follow `FINAL_GO_NO_GO_REVIEW.md`.

The reviewer must verify artifact identity, deployment identity, all hard gates, all zero-tolerance counters, known limitations and conservative initial deployment controls.

The machine-readable review must be based on `FINAL_RELEASE_REVIEW_TEMPLATE.json` and must pass:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

Only then may `InpReleaseOperatorReviewPassed=true` and the matching final-review identity fields be entered in MT5.

## Final machine validation

After the final review has been incorporated into `release_evidence.json`, run:

```text
python tools/validate_release_evidence.py release_evidence.json
```

This result must be PASS.

## Deployment rule

A GO applies only to the exact candidate artifact and validated environment. Material source, preset/risk, broker/server/account or structural symbol-contract changes invalidate GO and require appropriate revalidation.

## Decision record

Release reviewer:

Candidate Git SHA:

Release validation ID:

Soak evidence SHA-256:

Final review SHA-256:

Final release-evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:

Passing this contract does not guarantee profitability. It means the exact candidate has met the defined engineering, protection, recovery, broker-compatibility, evidence-integrity and operational release requirements.
