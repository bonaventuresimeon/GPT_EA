# GPT_EA Final GO / NO-GO Review Procedure

This is the final human release review for the **exact candidate artifact** after all automated and controlled validation is complete. It does not replace any technical gate.

Current review schema: `final_release_review_v1`.

The review digest is calculated from a stable pre-review basis that includes the exact build identity, runner-recovery evidence, executed CI evidence, deployment identity, API transport evidence, demo-soak/five-day evidence and all non-operator release gates. Any material change to those objects invalidates the review digest.

## 1. Inputs required before review

The reviewer must have:

- exact Git commit SHA;
- current base release validation ID;
- EX5 SHA-256 and SET SHA-256/`NONE`;
- MetaEditor compile evidence and full log;
- completed `release_evidence.json` for the exact candidate;
- validated runner-recovery evidence and validation output;\n- final executed CI evidence artifact;
- `ci-job-metadata.json` proving job/runner/steps execution;
- `ci-evidence-validation.txt` PASS;
- `ci-attestation-verify.txt` PASS;
- `ci-bundle-validation.txt` PASS;
- API transport evidence and validator PASS;
- finalized five-day acceptance JSON and validation PASS;
- completed five-day operator record;
- completed demo-soak report;
- soak-evidence validation PASS;
- broker/deployment profile evidence;
- all required matrix/test results;
- Experts/Journal, broker history and required CSVs;
- known limitations and open noncritical issues.

If any required artifact is missing, the decision is **HOLD** or **NO-GO**, never GO.

## 2. Candidate identity check

Verify one consistent candidate across:

- release validation ID;
- Git SHA;
- EX5 hash;
- SET hash/`NONE`;
- CI head SHA and CI bundle candidate SHA;
- five-day acceptance candidate SHA/EX5/SET;
- broker company/server/account profile;
- selected API transport mode/endpoint;
- validated symbol profile.

Any unexplained mismatch is automatic **NO-GO**.

## 3. Mandatory technical confirmations

The reviewer must confirm PASS for:

- compile/artifact identity;
- runner recovery from the known pre-runner failure;\n- executed CI static checks;
- CI provenance attestation and final bundle validation;
- Strategy Tester;
- full intelligence matrix;
- adaptive portfolio/risk supervisor;
- execution learning;
- champion/challenger;
- lifecycle/integrity/replay;
- broker/account/symbol matrix;
- deployment drift;
- recovery/restart;
- HIGH stop-management matrix;
- broker-specific stop-failure policy;
- partial protection;
- stop observability;
- live news/intermarket;
- WebRequest/OpenAI failure injection;
- selected API transport matrix/evidence;
- five-day machine acceptance record using `five_day_soak_acceptance_v2`;\n- all five dated soak-day reconciliation checklists with `ACCEPT DAY`;
- five-day operator reconciliation record;
- demo-soak schema/digest.

No PASS may be inferred from profitability alone.

## 4. Runner-recovery and CI review

Confirm runner-recovery evidence preserves the original `runner_id=0 / steps=0` incident, then proves a successful later runner probe and the exact candidate's static run/CI bundle. The runner-recovery evidence ID/digest must validate and `gates.runner_recovery=true`.

Then confirm the CI evidence below.

## 5. CI-specific review

Confirm:

- static job ID > 0;
- runner ID > 0;
- runner name present;
- executed steps >=7;
- conclusion `success`;
- CI head SHA equals build Git SHA;
- raw checker result is PASS;
- CI evidence digest validates;
- artifact attestation verification PASS;
- bundle digest validates;
- `ci_static.bundle_validated=true`.

`runner_id=0`, blank runner name or `steps=[]` is HOLD, not CI evidence.

## 6. Five-day/operator review

Confirm:

- exactly five accepted trading-day rows under `five_day_soak_acceptance_v2`;\n- every day has a completed reconciliation checklist and `ACCEPT DAY` decision;
- session/news/rollover/restart/reconnect/scan/checkpoint coverage meets the contract;
- operator worksheet exists and contains per-day evidence references;
- demo-soak report exists;
- all five lifecycle assertions are true;
- all zero-tolerance reconciliation fields are zero;
- acceptance record ID/digest matches `demo_soak`;
- acceptance candidate identity matches the build.

## 7. API transport review

For DIRECT_OPENAI:

- endpoint is `api.openai.com`;
- user API key remains local-only and absent from source/logs;
- MT5 WebRequest allow-list is correct.

For SECURE_PROXY:

- OpenAI key remains server-side;
- MT5 does not send the OpenAI bearer header;
- proxy token is separately scoped/revocable;
- tested proxy endpoint equals deployment endpoint.

In either mode, the high-priority matrix, live deep-review path, web-search path, failure/recovery, request tracing and zero secret leaks must pass.

## 8. Zero-tolerance review

GO requires zero/unobserved:

- unresolved critical state;
- zero-tolerance soak failure;
- duplicate order/partial;
- SL regression;
- unprotected new authorization;
- release-gate bypass;
- duplicate analytics finalization;
- stop-observability join failure;
- dashboard/gate mismatch;
- runtime critical loop;
- secret/API-key exposure;
- unexplained recovery inconsistency.

Any non-zero hard item is **NO-GO** until corrected and revalidated.

## 9. Initial live-deployment controls

Confirm:

- `InpRequireApproval=true` unless a separately certified release changes policy;
- conservative initial risk;
- live arm phrase entered only after GO;
- expected broker/deployment identity configured;
- optional DOM/ONNX enabled only if separately validated;
- stop/release/risk/API gates remain enabled;
- no evidence flag was set merely to make the EA start trading.

## 9. Decision definitions

**GO** — every mandatory gate/evidence identity passes and all hard counters are zero.

**HOLD** — evidence/infrastructure/reviewer work is incomplete but the candidate may still become releasable without redesign. HOLD never arms REAL trading.

**NO-GO** — failed hard gate, identity/digest mismatch, protection/recovery/CI/API integrity failure, zero-tolerance finding, or source/config change requiring revalidation.

## 10. Machine-readable final review

Start from `FINAL_RELEASE_REVIEW_TEMPLATE.json`. Every review boolean must be true, including:

- `compile_contract_pass`;
- `ci_bundle_pass`;
- `ci_attestation_verified`;
- `api_transport_pass`;
- `five_day_acceptance_pass`;
- `five_day_operator_record_complete`;
- `soak_schema_pass`;
- all remaining identity, gate, zero-tolerance and deployment checks.

The stable release-evidence basis digest now binds `build`, `ci_static`, `deployment`, `api_transport`, `demo_soak` and all gates except the final operator-review transition.

Run:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

GO is valid only if this command returns PASS. Archive `final-release-review-validation.txt` and `FINAL_REVIEW_SHA256`.

## 11. Runtime attestation

Only after the final review validator passes may the operator set the corresponding Part28 review fields, including `InpReleaseOperatorReviewPassed=true` and `InpReleaseFinalDecision=GO`.

Part28B CI/five-day fields and Part37 API transport PASS fields must already correspond exactly to the archived evidence.

## 12. Certification invalidation

GO becomes stale when executable source, EX5/SET/material risk preset, release evidence contract, CI candidate identity, selected API transport/endpoint, or intended broker/server/account/symbol environment changes materially, or when a post-review discovery invalidates a hard assumption.

When stale, return to HOLD/NO-GO and repeat the affected validation sequence.
