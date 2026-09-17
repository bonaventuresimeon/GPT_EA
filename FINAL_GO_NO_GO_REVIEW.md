# GPT_EA Final GO / NO-GO Review Procedure

This is the final human release review for the **exact candidate artifact** after all automated and controlled validation is complete. It does not replace any technical gate.

Current review schema: `final_release_review_v1`.

## 1. Inputs to the review

The reviewer must have all of the following before opening the review:

- exact Git commit SHA;
- current release validation ID from `GPT_EA_Part28_ReleaseCertification.mqh`;
- EX5 SHA-256;
- SET SHA-256 or explicit `NONE`;
- MetaEditor compile evidence and full compile log;
- `release_evidence.json` completed for the exact candidate;
- `soak-evidence-validation.txt` showing PASS;
- `release-evidence-validation.txt` showing PASS for all pre-review evidence;
- broker/deployment profile evidence;
- all required matrix/test results;
- Experts/Journal logs;
- execution, stop, intelligence, lifecycle and release evidence CSVs;
- demo-soak report;
- list of known limitations and open noncritical issues.

If any required artifact is missing, the decision is **HOLD** or **NO-GO**, never GO.

## 2. Candidate identity check

The reviewer must verify that the final review refers to the same:

- release validation ID;
- Git SHA;
- EX5 SHA-256;
- SET SHA-256 / `NONE`;
- broker company;
- trade server;
- account currency;
- margin mode;
- leverage;
- validated symbol set/profile.

Any unexplained mismatch is automatic **NO-GO**.

## 3. Mandatory technical confirmations

The reviewer must confirm all of these are PASS:

- MetaEditor compile contract;
- artifact identity/archive contract;
- Strategy Tester validation;
- full intelligence matrix;
- adaptive portfolio/risk supervisor;
- execution-learning validation;
- champion/challenger validation;
- lifecycle/integrity/replay validation;
- broker/account/symbol matrix;
- deployment drift validation;
- recovery/restart matrix;
- HIGH-priority stop-management matrix;
- broker-specific stop-failure policy;
- partial-protection test;
- stop-observability test;
- live-news/intermarket validation;
- WebRequest/OpenAI failure injection;
- demo-soak schema validation;
- demo-soak acceptance contract.

No PASS may be inferred from profitability alone.

## 4. Zero-tolerance review

GO requires all of the following to be zero/unobserved:

- unresolved critical state;
- zero-tolerance soak failure;
- duplicate order from one authorization;
- duplicate TP1/TP2 partial;
- stop-loss regression caused by EA logic;
- unprotected-position new authorization;
- release-gate bypass;
- duplicate analytics finalization;
- unexplained stop-observability join failure;
- dashboard/release-gate mismatch;
- runtime critical error loop;
- secret/API-key exposure;
- unexplained recovery inconsistency.

Any non-zero item is automatic **NO-GO** until corrected and the required validation is repeated.

## 5. Known limitations

Known limitations may be accepted only when they are:

1. explicitly documented;
2. noncritical to protection/execution/recovery integrity;
3. understood by the reviewer;
4. not a hidden release-gate failure;
5. accompanied by an owner/mitigation where appropriate.

An unexplained issue is not a known limitation; it is a **HOLD**.

## 6. Initial live-deployment controls

For the initial live deployment the reviewer must confirm:

- `InpRequireApproval=true` unless a later separately certified release deliberately changes this policy;
- conservative initial risk is selected;
- live arm phrase is entered only after GO;
- expected broker/server/deployment identity is configured where required;
- optional DOM/ONNX components are enabled only if validated on the intended broker;
- existing stop/release/risk gates remain enabled;
- no evidence flag is set merely to make the EA start trading.

## 7. Decision definitions

### GO

Use only when every mandatory gate passes, identity matches, all zero-tolerance counts are zero, evidence validators pass and the reviewer accepts the documented noncritical limitations.

### HOLD

Use when the candidate may still become releasable without a redesign, but evidence is incomplete, a noncritical item needs investigation, or the reviewer cannot yet make a defensible GO decision.

HOLD must not arm live trading.

### NO-GO

Use for any failed hard gate, artifact mismatch, deployment mismatch, zero-tolerance failure, unresolved critical state, protection/recovery integrity failure, source change after validation, or other condition requiring code/configuration change and revalidation.

## 8. Machine-readable final review

Start from `FINAL_RELEASE_REVIEW_TEMPLATE.json` and populate:

- `review_evidence_id`;
- `review_timestamp`;
- `reviewer`;
- candidate hashes;
- stable release-evidence basis digest;
- deployment identity;
- all review booleans;
- known limitations/open noncritical issues;
- decision.

Run:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

GO is valid only if this command returns PASS.

Archive `final-release-review-validation.txt` and its reported `FINAL_REVIEW_SHA256`.

## 9. Runtime attestation

Only after the final review validator passes may the operator set:

- `InpReleaseOperatorReviewPassed=true`;
- `InpReleaseFinalReviewEvidenceId=<review evidence id>`;
- `InpReleaseFinalReviewDigest=<FINAL_REVIEW_SHA256>`;
- `InpReleaseFinalDecision=GO`;
- `InpReleaseFinalReviewer=<reviewer>`;
- `InpReleaseFinalReviewTimestamp=<review timestamp>`.

These values must refer to the archived review for the exact release candidate.

## 10. Certification invalidation

A GO becomes stale when executable source changes, release preset/risk controls change materially, the compiled EX5 changes, the intended deployment identity changes materially, or a post-review discovery invalidates a hard-gate assumption.

When stale, the correct state is HOLD/NO-GO until the required compile/test/soak/review sequence is repeated.
