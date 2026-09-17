# GPT_EA Release Evidence Validation — R6

This document connects the human release contracts, machine-readable evidence, final review and MT5 runtime attestation.

Current release ID is read directly from `GPT_EA_Part28_ReleaseCertification.mqh`. Do not reuse an older release ID.

## Evidence files

Use:

- `RELEASE_EVIDENCE_TEMPLATE.json` → working `release_evidence.json`;
- `SOAK_EVIDENCE_SCHEMA.json` → versioned soak contract;
- `FINAL_RELEASE_REVIEW_TEMPLATE.json` → working `final_release_review.json`.

## 1. Compile/artifact evidence

Populate the release evidence with the exact candidate:

- Git SHA;
- EX5 path/SHA-256;
- SET path/SHA-256 or `NONE`;
- compile error/warning counts;
- MetaEditor build;
- MT5 build;
- compile evidence ID;
- compile log path.

Run only against the exact candidate compiled under `METAEDITOR_COMPILE_GATE.md`.

## 2. Soak schema and digest

The required soak schema is:

`demo_soak_evidence_v1`

Populate every field in `demo_soak` using actual soak observations.

The soak SHA-256 is calculated over the canonical `demo_soak` object **with `evidence_digest` removed**. This avoids a self-referential digest.

Run:

```text
python tools/validate_soak_evidence.py release_evidence.json
```

If the digest field is blank/incorrect, the validator reports the expected `SOAK_EVIDENCE_SHA256`. Copy that exact digest into `demo_soak.evidence_digest` and rerun. PASS writes `soak-evidence-validation.txt`.

The schema requires at least 5 trading days, 3 London sessions, 3 New York sessions, required overlap/news/rollover/restart/reconnect coverage, scheduled and continuous scans, primary and backup checkpoint activity, required logs and all defined zero-tolerance counters equal to zero.

## 3. Pre-review release basis

The stable release-evidence basis used by the final review consists of:

- release validation ID;
- `build`;
- `deployment`;
- `demo_soak`;
- all release gates **except** `operator_review`.

This basis remains stable when the final operator-review flag is later set to true.

## 4. Final GO/NO-GO review

Complete `final_release_review.json` from `FINAL_RELEASE_REVIEW_TEMPLATE.json` following `FINAL_GO_NO_GO_REVIEW.md`.

The review must match the candidate Git SHA, EX5/SET hashes and deployment identity from `release_evidence.json`.

`candidate.release_evidence_digest` is the SHA-256 of the stable pre-review release basis described above.

The final review SHA-256 is calculated over the review JSON **with `review_digest` removed**.

Run:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

If either digest is wrong, the validator reports the expected `RELEASE_EVIDENCE_BASIS_SHA256` and `FINAL_REVIEW_SHA256`. Insert them into the review and rerun.

PASS writes `final-release-review-validation.txt`.

Only literal decision `GO` can pass.

## 5. Copy final review identity into release evidence

After the final review validator passes:

- set `gates.operator_review=true`;
- set `final_review.schema_version=final_release_review_v1`;
- copy `review_evidence_id`;
- copy `FINAL_REVIEW_SHA256` to `final_review.review_digest`;
- set `final_review.decision=GO`;
- copy reviewer and review timestamp.

## 6. Final release evidence validation

Run:

```text
python tools/validate_release_evidence.py release_evidence.json
```

The validator checks:

- current release ID;
- Git/hash formats and repository HEAD when available;
- actual EX5/SET file hashes when files are available;
- zero compile errors/warnings;
- MetaEditor/MT5 build identity;
- compile log;
- deployment identity;
- `SOAK_EVIDENCE_SCHEMA.json` compliance and soak digest;
- all mandatory release gates;
- final-review schema, ID, digest, GO decision, reviewer and timestamp.

PASS writes `release-evidence-validation.txt` and the final evidence JSON SHA-256.

## 7. Runtime mapping

Map the validated evidence to MT5 inputs exactly.

Compile/artifact fields:

- `build.git_sha` → `InpReleaseSourceCommitSha`
- `build.ex5_sha256` → `InpReleaseEx5Sha256`
- `build.set_sha256` → `InpReleaseSetSha256`
- `build.compile_evidence_id` → `InpReleaseCompileEvidenceId`
- `build.metaeditor_build` → `InpReleaseMetaEditorBuild`
- `build.mt5_build` → `InpReleaseMT5Build`

Soak fields map to the corresponding `InpReleaseSoak*` inputs, including schema version, evidence ID/digest, scan/checkpoint counts, zero-tolerance counters and required log-presence booleans.

Final review fields:

- review evidence ID → `InpReleaseFinalReviewEvidenceId`
- final review SHA-256 → `InpReleaseFinalReviewDigest`
- decision → `InpReleaseFinalDecision`
- reviewer → `InpReleaseFinalReviewer`
- timestamp → `InpReleaseFinalReviewTimestamp`
- `gates.operator_review` → `InpReleaseOperatorReviewPassed`

## 8. Archive set

Archive together:

1. exact candidate source/Git SHA;
2. EX5 and SHA-256;
3. SET and SHA-256/`NONE`;
4. compile log;
5. `release_evidence.json`;
6. `soak-evidence-validation.txt`;
7. demo-soak report;
8. `final_release_review.json`;
9. `final-release-review-validation.txt`;
10. `release-evidence-validation.txt`;
11. broker/deployment profile;
12. runtime CSVs/terminal logs required by `RELEASE_EVIDENCE_MANIFEST.md`.

## Invalidation rule

Any executable source change after evidence is captured creates a new candidate unless explicitly recorded as documentation-only and non-executable. Material preset, broker/deployment or release-contract changes also require the affected validation to be repeated.
