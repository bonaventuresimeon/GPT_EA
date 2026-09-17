<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚀 Release Engineering & Evidence

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚀 **Document:** `RELEASE_EVIDENCE_VALIDATION.md`

---

# GPT_EA Release Evidence Validation — R6 Base + Current API Transport Guard

This document connects the human release contracts, machine-readable evidence, GitHub Actions provenance, five-day soak acceptance, API/WebRequest validation, final review and MT5 runtime attestation.

The base release ID is read directly from `GPT_EA_Part28_ReleaseCertification.mqh`. The active runtime then layers deployment drift, supplemental CI/five-day evidence and the current API transport guard. Do not reuse evidence from an older source commit or release contract.

## Evidence files

Use:

- `RELEASE_EVIDENCE_TEMPLATE.json` → working `release_evidence.json`;
- `RUNNER_RECOVERY_EVIDENCE_SCHEMA.json` and `RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json` → hosted-runner recovery proof;
- `RUNNER_RECOVERY_ACCEPTANCE_SCHEMA.json` and `RUNNER_RECOVERY_ACCEPTANCE_TEMPLATE.json` → production acceptance of the recovered runner path;
- `MT5_VALIDATION_EVIDENCE_SCHEMA.json` and `MT5_VALIDATION_EVIDENCE_TEMPLATE.json` → exact MetaEditor/MT5 compile/test/runtime evidence;
- `CI_EVIDENCE_SCHEMA.json` and `CI_EVIDENCE_BUNDLE_SCHEMA.json` → executed GitHub Actions evidence;
- `SOAK_EVIDENCE_SCHEMA.json` → versioned machine soak contract;
- `FIVE_DAY_SOAK_ACCEPTANCE_TEMPLATE.json` → working five-day machine acceptance record (`five_day_soak_acceptance_v2`);
- `SOAK_DAY_RECONCILIATION_CHECKLIST.md` → one completed reconciliation file per accepted day;
- `FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md` → working human/operator reconciliation record;
- `DEMO_SOAK_REPORT_TEMPLATE.md` → full soak report;
- `FINAL_RELEASE_REVIEW_TEMPLATE.json` → working final review.

## 1. Compile/artifact evidence

Populate the exact candidate identity:

- Git SHA;
- EX5 path/SHA-256;
- SET path/SHA-256 or `NONE`;
- compile error/warning counts;
- MetaEditor build;
- MT5 build;
- compile evidence ID;
- compile log path.

Production certification requires 0 compile errors and 0 accepted production warnings under `METAEDITOR_COMPILE_GATE.md`.

## 2. Hosted-runner recovery evidence

Before CI can become release evidence, complete `runner_recovery_evidence_v1`. It must preserve the original pre-runner incident signature, prove a later successful minimal runner probe, and bind the exact candidate's successful static job/CI-bundle digest.

Run:

```text
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json --finalize
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json
```

Only the resulting PASS/digest may populate `runner_recovery` and `gates.runner_recovery=true`.

Then complete `runner_recovery_acceptance_v1` against `RUNNER_RECOVERY_ACCEPTANCE_MATRIX.md` and run:

```text
python tools/validate_runner_recovery_acceptance.py artifacts/runner-recovery-acceptance.json --finalize
python tools/validate_runner_recovery_acceptance.py artifacts/runner-recovery-acceptance.json
```

Only after that validator passes may `gates.runner_recovery_acceptance=true`.

## 3. Executed GitHub Actions CI evidence

A created workflow run is not enough. Follow `CI_EVIDENCE_CONTRACT.md`.

The accepted workflow must allocate an actual runner and execute the repository checks. Evidence requires at minimum:

- run ID and attempt > 0;
- numeric static job ID > 0;
- `runner_id > 0` and non-empty runner name;
- at least 7 executed static-job steps;
- static job conclusion `success`;
- candidate head SHA equal to `build.git_sha`;
- `static-check.txt` with `RESULT=PASS`;
- validated `ci-evidence.json`;
- verified GitHub artifact attestation;
- validated final `ci-bundle-manifest.json`.

The final bundle contains the raw checker outputs, completed GitHub job metadata, machine evidence, validation output, attestation verification and bundle manifest/validation output.

A pre-runner failure (`runner_id=0`, empty runner name, `steps=[]`) remains HOLD and cannot populate a PASS record.

After a successful workflow, archive/download the final artifact and place its files under the paths recorded in `release_evidence.json -> ci_static`.

Validate independently:

```text
python tools/validate_ci_evidence.py artifacts/ci-evidence.json \
  --expected-sha <candidate-git-sha> \
  --static-check artifacts/static-check.txt \
  --ci-log artifacts/static-check-ci.txt \
  --job-metadata artifacts/ci-job-metadata.json

python tools/validate_ci_bundle.py artifacts/ci-bundle-manifest.json \
  --base-dir artifacts \
  --expected-sha <candidate-git-sha>
```

`ci_static.bundle_validated` may become true only after the final bundle validator passes.

## 4. MT5/MetaEditor validation evidence

Build the draft MT5 record from the exact retained artifacts or start from the template. At minimum archive the compile log, Strategy Tester report, Experts log, Journal log, broker-history reconciliation and completed `MT5_VALIDATION_ACCEPTANCE_MATRIX.md` working copy.

Validate:

```text
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json --finalize
python tools/validate_mt5_validation_evidence.py artifacts/mt5-validation-evidence.json
```

The release validator cross-checks the MT5 candidate Git/EX5/SET identity, MetaEditor/terminal builds and broker/server/account identity against `build` and `deployment`. Only a PASS may set `gates.mt5_validation=true`.

## 5. API/WebRequest transport evidence

The active source routes release safety through the API transport guard. Complete `API_TRANSPORT_TEST_MATRIX.md` for the selected DIRECT_OPENAI or SECURE_PROXY mode.

Populate `api_transport` with the tested mode, endpoint host, HTTPS and MT5 WebRequest allow-list verification, deep-review/web-search paths, failure/recovery behavior, request tracing, and zero secret leaks.

Run:

```text
python tools/validate_api_transport_evidence.py release_evidence.json
```

`gates.api_transport` must be true before the aggregate release validator can pass.

## 6. Five-day machine, day-by-day and operator acceptance

Part36 produces machine observations, but the five-day engineering acceptance also requires human reconciliation.

Before Day 1 create:

```text
artifacts/five-day-soak-acceptance.json
artifacts/five-day-soak-operator-record.md
artifacts/demo-soak-report.md
```

from their repository templates.

The machine record must freeze the exact Git/EX5/SET and deployment identity, contain exactly five accepted trading-day rows, require all lifecycle assertions and zero-tolerance counts, and reference the completed operator record and demo-soak report.

Each accepted day must also reference a completed dated copy of `SOAK_DAY_RECONCILIATION_CHECKLIST.md`, with literal `ACCEPT DAY`, matching date and Git SHA, `day_reconciled=true`, reviewer and timestamp.

The operator worksheet records the daily Experts/Journal, broker-history, Part36 and recovery/checkpoint evidence references supporting the JSON values.

After Day 5 and reconciliation, set the operator decision to `ACCEPT` and finalize:

```text
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json --finalize
python tools/validate_five_day_soak_record.py artifacts/five-day-soak-acceptance.json
```

Only a passing finalization produces an acceptable `record_digest`.

## 7. Soak schema and digest

Import the completed Part36 snapshot and accepted five-day record into the release evidence using the repository importer, then validate:

```text
python tools/validate_soak_evidence.py release_evidence.json
```

Required schema: `demo_soak_evidence_v1`.

The validator requires the session/event/restart/reconnect/scan/checkpoint coverage, required logs, zero-tolerance fields, soak digest and the five-day acceptance record ID/digest/path.

The five-day record candidate Git/EX5/SET must match the build identity exactly.

## 8. Pre-review release basis

The stable release-evidence basis used by final review consists of:

- release validation ID;
- `build`;
- `runner_recovery`;
- `runner_recovery_acceptance`;
- `ci_static`;
- `mt5_validation`;
- `deployment`;
- `api_transport`;
- `demo_soak`;
- all release gates except the final `operator_review` transition.

Do not perform final review against a basis that later changes.

## 9. Final GO/NO-GO review

Complete `final_release_review.json` following `FINAL_GO_NO_GO_REVIEW.md`.

The final review must match the exact Git SHA, EX5/SET hashes, CI bundle, API transport, deployment and soak identities in `release_evidence.json`.

Run:

```text
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
```

Only literal `GO` can pass. Archive `final-release-review-validation.txt`.

After it passes, copy the final review identity into `release_evidence.json` and set `gates.operator_review=true`.

## 10. Final aggregate validation

Run:

```text
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

The aggregate validator now checks:

- current release ID;
- source/EX5/SET identity and compile evidence;
- executed CI run/job/runner/step identity;
- CI evidence and final bundle digests;
- archived attestation verification;
- deployment identity;
- API transport evidence and `gates.api_transport`;
- soak schema/digest;
- five-day machine record, operator record reference and candidate identity;
- all mandatory release gates;
- final-review schema/digest/GO/reviewer/timestamp.

PASS writes the release validation outputs and hashes. A failure in any one of those evidence chains keeps the candidate HOLD/NO-GO.

## 9. Runtime mapping

Map the validated evidence into local MT5 inputs exactly.

Compile/artifact:

- `build.git_sha` → `InpReleaseSourceCommitSha`
- `build.ex5_sha256` → `InpReleaseEx5Sha256`
- `build.set_sha256` → `InpReleaseSetSha256`
- compile/build identity → matching Part28 inputs.

Executed CI / Part28B:

- schema → `InpReleaseCISchemaVersion`
- run ID → `InpReleaseCIRunId`
- attempt → `InpReleaseCIRunAttempt`
- job ID → `InpReleaseCIJobId`
- runner ID → `InpReleaseCIRunnerId`
- executed step count → `InpReleaseCIStepsExecuted`
- head SHA → `InpReleaseCIHeadSha`
- CI evidence digest → `InpReleaseCIEvidenceDigest`
- conclusion → `InpReleaseCIConclusion`
- artifact name/archive/attestation → corresponding Part28B inputs
- bundle schema → `InpReleaseCIBundleSchemaVersion`
- bundle digest → `InpReleaseCIBundleDigest`
- validated bundle → `InpReleaseCIBundleValidated=true`
- only then `InpReleaseCIStaticEvidencePassed=true`.

Five-day record / Part28B:

- accepted record ID → `InpReleaseSoakAcceptanceRecordId`
- accepted record digest → `InpReleaseSoakAcceptanceRecordDigest`.

Soak quantitative fields map to the corresponding `InpReleaseSoak*` inputs in Part28.

API transport:

- set `InpReleaseAPITransportPassed=true` only for the exact selected/tested transport evidence.

Final review maps to the corresponding Part28 final-review inputs and `InpReleaseOperatorReviewPassed=true` only after final GO validation.

## 10. Archive set

Archive together:

1. exact source/Git SHA;
2. EX5 + SHA-256;
3. SET + SHA-256/`NONE`;
4. compile log and compile validation;
5. final GitHub Actions CI evidence artifact, including `ci-job-metadata.json`, `ci-evidence.json`, attestation verification, `ci-bundle-manifest.json` and bundle validation;
6. API transport evidence and validation;
7. `GPT_EA_DemoSoakSnapshot.json` / Part36 CSV;
8. finalized five-day acceptance JSON;
9. completed five-day operator record;
10. completed demo-soak report;
11. soak and five-day validation outputs;
12. final review JSON/validation;
13. `release_evidence.json` + final release validation outputs;
14. broker/deployment profile;
15. required runtime CSVs, Experts/Journal logs, broker history and recovery/checkpoint artifacts.

## Invalidation rule

Any executable-source change after evidence is captured creates a new candidate. Changes to EX5/SET, release contract, API transport/endpoint, broker/server/account or material symbol/deployment profile invalidate the affected evidence and require revalidation. Documentation-only changes may be treated separately only when they cannot alter executable/release behavior and are explicitly recorded in the review.
