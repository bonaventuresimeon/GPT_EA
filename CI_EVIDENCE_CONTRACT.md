# GPT_EA Executed CI Evidence Contract

This contract defines the GitHub Actions evidence required by the R6 base release and the current supplemental release-safety stack. It is intentionally fail-closed: a created workflow run is not CI evidence unless GitHub assigned a runner and the required steps actually executed.

## 1. Release purpose

The CI gate proves that the exact candidate source commit was checked by the repository release scripts on an allocated runner, that the raw results were preserved, and that the resulting machine evidence has verifiable provenance.

The CI contract does **not** replace MetaEditor compilation, Strategy Tester, broker tests, API/WebRequest tests, recovery tests, stop-management tests, or the five-day demo soak.

## 2. Accepted runner state

A CI record can pass only when all of the following are true:

- workflow run ID > 0;
- run attempt > 0;
- numeric GitHub Actions job ID > 0;
- `runner_id > 0`;
- runner name and OS are non-empty;
- the completed static job conclusion is literal `success`;
- required workflow steps executed rather than remaining an empty step list;
- the checked head SHA exactly matches the candidate `build.git_sha`;
- aggregate repository check output contains `RESULT=PASS`.

A run with `runner_id=0`, empty runner name or `steps=[]` is a provisioning failure and **cannot** satisfy this contract regardless of the workflow conclusion shown in the UI.

## 3. Raw static job

The first job, `static-release-gate`, must execute the repository checks from the exact checkout:

```text
python tools/run_release_checks.py
```

Its raw evidence is:

- `static-check.txt` — aggregate checker output;
- `static-check-ci.txt` — captured CI console copy of the aggregate check;
- exact checked Git SHA/tree;
- completed job metadata returned by the GitHub Actions API.

The job must archive the raw outputs even when checks fail, so a failed run remains diagnosable without becoming acceptable release evidence.

## 4. Final CI evidence bundle

The release-grade bundle is the artifact named in `release_evidence.json -> ci_static.artifact_name`. A passing bundle contains at least:

1. `static-check.txt`
2. `static-check-ci.txt`
3. `ci-job-metadata.json`
4. `ci-evidence.json`
5. `ci-evidence-validation.txt`
6. `ci-evidence-manifest.txt`
7. `ci-attestation-verify.txt`
8. `ci-bundle-manifest.json`
9. `ci-bundle-validation.txt`

The artifact name must include the candidate commit SHA and run attempt so evidence from separate candidates cannot be confused.

## 5. `ci-job-metadata.json`

This file is collected **after** the static job has completed. It is sourced from the GitHub Actions jobs API and records at minimum:

- repository;
- workflow run ID and attempt;
- numeric static job ID;
- job name;
- job conclusion;
- `runner_id`;
- runner name;
- runner group ID where available;
- number of executed/completed job steps;
- job URL;
- candidate head SHA.

Do not fabricate runner/job metadata from environment strings. Numeric runner/job identity must come from GitHub's completed-job API response.

## 6. `ci-evidence.json`

Schema: `github_actions_static_evidence_v1` in `CI_EVIDENCE_SCHEMA.json`.

It binds:

- run/job/runner identity;
- candidate head/tree SHA;
- static-job conclusion;
- runner platform;
- aggregate static result;
- SHA-256 of both checker outputs;
- SHA-256 of the tracked source manifest;
- canonical evidence digest.

`tools/validate_ci_evidence.py` must return PASS against the exact checked-out candidate.

## 7. Provenance attestation

The workflow must create a GitHub artifact attestation for `ci-evidence.json` using the repository Actions identity and then verify that attestation.

The verification output is archived as `ci-attestation-verify.txt`. A boolean entered manually without retained verification output is not sufficient release evidence.

## 8. Bundle manifest

`ci-bundle-manifest.json` is the final inventory of the evidence artifact. It records the bundle schema/version, release ID, candidate SHA, run/job/runner identity, artifact name, each required file and SHA-256, attestation verification state, and a canonical bundle digest.

`tools/validate_ci_bundle.py` must verify:

- all required files exist;
- all stored file hashes match;
- `ci-evidence.json` independently validates;
- job metadata and `ci-evidence.json` agree on run/job/runner/head identity;
- attestation verification output is non-empty and records success;
- bundle digest is correct.

## 9. Release binding

`RELEASE_EVIDENCE_TEMPLATE.json -> ci_static` must identify the exact accepted bundle:

- run ID / attempt / URL;
- job ID / runner ID / runner name;
- executed step count;
- head SHA;
- conclusion `success`;
- artifact name and archived=true;
- `ci-evidence.json` path and digest;
- bundle manifest path and digest;
- attestation verification path and verified=true.

The release validator must cross-check the bundle against `build.git_sha`. Part28B must remain fail-closed until the corresponding CI evidence inputs are supplied locally.

## 10. Current hosted-runner outage/provisioning condition

The existing pre-runner failure signature (`runner_id=0`, empty runner name, empty step list) remains a **HOLD**, not a source-code failure and not a CI PASS. `ACTIONS_RUNNER_DIAGNOSTICS.md` defines the account/platform remediation path.

After runner allocation is restored, freeze a candidate commit and obtain a fresh green bundle for that exact commit. Evidence from an earlier SHA cannot be carried forward after executable source changes.
