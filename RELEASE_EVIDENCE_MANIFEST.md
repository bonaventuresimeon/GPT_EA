# GPT_EA Release Evidence Manifest — R6 Base + Current API Transport Guard

Complete one copy for every production candidate. A commit, checkbox, green-looking dashboard or profitable demo result is not evidence by itself. Every PASS must be traceable to the exact Git/EX5/SET candidate and its archived validation artifacts.

## 1. Candidate/build identity

- Git commit SHA:
- Base release validation ID: `GPT_EA_FULL_INTELLIGENCE_R6_20260917`
- MetaTrader build:
- MetaEditor build:
- Windows/VPS build and architecture:
- EX5 path:
- EX5 SHA-256:
- SET path:
- SET SHA-256 or `NONE`:
- Compile evidence ID:
- Compile errors: **0 required**
- Compile warnings: **0 required for production certification**
- Compile log path:
- Compile timestamp:

Concrete Part28 inputs:

- `InpReleaseSourceCommitSha=`
- `InpReleaseEx5Sha256=`
- `InpReleaseSetSha256=`
- `InpReleaseCompileEvidenceId=`
- `InpReleaseMetaEditorBuild=`
- `InpReleaseMT5Build=`

## 2. Hosted-runner recovery evidence

Follow `RUNNER_RECOVERY_EVIDENCE.md`.

- [ ] original pre-runner incident retained (`runner_id=0`, zero executed steps);
- [ ] later runner provisioning probe PASS with `runner_id > 0`;
- [ ] exact candidate static run PASS on a real runner;
- [ ] release-static run identity matches accepted CI bundle;
- [ ] `tools/validate_runner_recovery_evidence.py` PASS;
- [ ] runner-recovery evidence ID/digest archived.

Concrete Part28B inputs:

- `InpReleaseRunnerRecoveryPassed=true`
- `InpReleaseRunnerRecoverySchemaVersion=runner_recovery_evidence_v1`
- `InpReleaseRunnerRecoveryEvidenceId=`
- `InpReleaseRunnerRecoveryDigest=`

## 3. Executed GitHub Actions CI evidence bundle

Follow `CI_EVIDENCE_CONTRACT.md`.

Accepted CI must come from an actually executed `static-release-gate` job. Record:

- workflow run ID:
- run attempt:
- run URL:
- static job ID:
- static job URL:
- runner ID: **must be > 0**
- runner name:
- executed static-job steps: **>= 7**
- head SHA: **must equal candidate Git SHA**
- static-job conclusion: **success**
- final artifact name:
- artifact archived: yes / no
- CI evidence digest:
- GitHub attestation verified: yes / no
- CI bundle schema: `ci_evidence_bundle_v1`
- CI bundle digest:
- bundle validation: PASS / FAIL

Required final bundle files:

- [ ] `static-check.txt`
- [ ] `static-check-ci.txt`
- [ ] `ci-job-metadata.json`
- [ ] `ci-evidence.json`
- [ ] `ci-evidence-validation.txt`
- [ ] `ci-evidence-manifest.txt`
- [ ] `ci-attestation-verify.txt`
- [ ] `ci-bundle-manifest.json`
- [ ] `ci-bundle-validation.txt`

Required checks:

- [ ] `static-check.txt` contains `RESULT=PASS`.
- [ ] completed job metadata shows `runner_id > 0`.
- [ ] job metadata/evidence run, job, runner, steps and head SHA agree.
- [ ] `tools/validate_ci_evidence.py` PASS.
- [ ] GitHub attestation verification PASS.
- [ ] `tools/validate_ci_bundle.py` PASS.
- [ ] final artifact retained/archived.

A run with `runner_id=0`, empty runner name or `steps=[]` remains **HOLD** and must never be manually converted to CI PASS.

Concrete Part28B inputs:

- `InpReleaseCIStaticEvidencePassed=true`
- `InpReleaseCISchemaVersion=github_actions_static_evidence_v1`
- `InpReleaseCIRunId=`
- `InpReleaseCIRunAttempt=`
- `InpReleaseCIJobId=`
- `InpReleaseCIRunnerId=`
- `InpReleaseCIStepsExecuted=`
- `InpReleaseCIHeadSha=`
- `InpReleaseCIEvidenceDigest=`
- `InpReleaseCIConclusion=success`
- `InpReleaseCIArtifactName=`
- `InpReleaseCIArtifactArchived=true`
- `InpReleaseCIAttestationVerified=true`
- `InpReleaseCIBundleSchemaVersion=ci_evidence_bundle_v1`
- `InpReleaseCIBundleDigest=`
- `InpReleaseCIBundleValidated=true`

Set these only from the accepted bundle.

## 4. Broker/deployment identity

- Broker company:
- Trade server:
- Account type:
- Margin mode:
- Account currency:
- Leverage:
- Resolved symbols:
- broker symbol profiles archived:
- deployment-drift evidence archived:

Verify stable-environment PASS, controlled structural-drift block and continued position management during a new-entry block.

## 5. API/WebRequest transport evidence

Follow `API_TRANSPORT_ARCHITECTURE.md`, `MT5_WEBREQUEST_REQUIREMENTS.md` and `API_TRANSPORT_TEST_MATRIX.md`.

Record:

- selected mode: DIRECT_OPENAI / SECURE_PROXY
- endpoint host/origin:
- HTTPS required: yes
- MT5 WebRequest allow-list verified: yes / no
- deep-review path PASS:
- live web-search path PASS:
- timeout/failure/recovery PASS:
- request-ID tracing PASS:
- secret leak count: **0**
- API transport validation artifact:

Required:

- [ ] `tools/validate_api_transport_evidence.py release_evidence.json` PASS.
- [ ] `gates.api_transport=true` only after matching evidence.
- [ ] `InpReleaseAPITransportPassed=true` only for the tested mode/endpoint.

## 6. Adaptive/intelligence evidence

Complete and archive evidence for:

- [ ] `INTELLIGENCE_TEST_MATRIX.md`
- [ ] `INTELLIGENCE_HARDENING_TESTS.md`
- [ ] `ADAPTIVE_EXECUTION_TEST_MATRIX.md`
- [ ] market-state/strategy classification coverage
- [ ] counter-trend strict gate
- [ ] realistic R:R/cost model
- [ ] confidence calibration
- [ ] execution learning and MAE/MFE
- [ ] strategy health/degradation states
- [ ] portfolio correlation/macro exposure
- [ ] strategy risk budgets/dynamic sizing
- [ ] champion/challenger and counterfactual shadow behavior
- [ ] GPT disagreement/integrity gate
- [ ] deterministic supervisor precedence
- [ ] WAIT and NO-TRADE examples
- [ ] 25-point thesis/adversarial review

Auto-promotion remains disabled unless separately validated.

## 7. Broker/recovery/stop evidence

Archive PASS evidence for:

- [ ] broker/account/symbol matrix
- [ ] restart/recovery tests
- [ ] deployment drift tests
- [ ] HIGH stop-management matrix
- [ ] broker-specific stop-failure policy
- [ ] partial-protection release test
- [ ] stop observability contract/tests
- [ ] BUY full management lifecycle
- [ ] SELL full management lifecycle
- [ ] TP1 partial/BE failure without duplicate partial
- [ ] missing-SL/emergency-protection path
- [ ] stop/freeze/requote/disconnect/market-closed/backoff paths as applicable
- [ ] position-identifier/ticket reconciliation
- [ ] checkpoint and validated `.bak` fallback

## 7. Five-day demo-soak machine acceptance

Follow `DEMO_SOAK_ACCEPTANCE.md`, `DEMO_SOAK_EVIDENCE.md`, `SOAK_EVIDENCE_SCHEMA.json` and `FIVE_DAY_SOAK_ACCEPTANCE_RECORD.md`.

Record:

- schema version: `demo_soak_evidence_v1`
- soak evidence ID:
- soak evidence SHA-256:
- soak start/end:
- trading days: **>=5**
- London sessions: **>=3**
- New York/U.S. cash sessions: **>=3**
- overlap/news/rollover/restart/reconnect: **all observed**
- scheduled scans: **>=1**
- continuous scans: **>=1**
- manual SCAN NOW: **>=1 in five-day acceptance record**
- primary checkpoint updates: **>=1**
- validated backup checkpoint updates: **>=1**
- all zero-tolerance counters: **0**
- unresolved critical states: **0**
- execution/stop/release logs: **present**

Five-day machine record:

- record ID:
- record digest:
- record path:
- validator result: PASS / FAIL

Concrete Part28B fields:

- `InpReleaseSoakAcceptanceRecordId=`
- `InpReleaseSoakAcceptanceRecordDigest=`

## 8. Five-day operator record

Create a working copy of `FIVE_DAY_SOAK_OPERATOR_RECORD_TEMPLATE.md` and bind it through `operator_record_path` in the machine acceptance JSON.

The completed operator worksheet must include per-day evidence references for:

- session/news/rollover observations;
- scheduled/continuous/manual scans;
- checkpoint/backup events;
- restart/reconnect;
- HIGH-CONFIDENCE / WAIT / NO-TRADE observations;
- broker history;
- Experts/Journal;
- Part36 snapshot/CSV evidence;
- zero-tolerance reconciliation.

All five lifecycle assertions must be evidenced and PASS:

- [ ] stale human-approval WAIT closed;
- [ ] genuine market-confirmation WAIT preserved;
- [ ] denial/timeout terminal;
- [ ] restart reconstruction safe;
- [ ] no illegal lifecycle transition accepted.

Operator five-day decision remains `HOLD` until reconciliation is complete, then may become `ACCEPT` before finalization.

## 9. Required observability archive

Archive as applicable:

- `GPT_EA_Execution.csv`
- `GPT_EA_StopFailures.csv`
- `GPT_EA_Intelligence.csv`
- `GPT_EA_ExecutionLearning.csv`
- `GPT_EA_ShadowValidation.csv`
- `GPT_EA_Lifecycle.csv`
- `GPT_EA_DecisionSnapshots.csv`
- `GPT_EA_StrategyHealth.csv`
- `GPT_EA_ReleaseEvidence.csv`
- `GPT_EA_R6SupplementalEvidence.csv`
- `GPT_EA_APIHealth.csv`
- `GPT_EA_DemoSoakEvidence.csv`
- `GPT_EA_DemoSoakSnapshot.json`
- Experts log
- Journal log
- broker order/deal history
- recovery checkpoint + `.bak`
- material screenshots/exports.

## 10. Final GO/NO-GO review

Follow `FINAL_GO_NO_GO_REVIEW.md` and start from `FINAL_RELEASE_REVIEW_TEMPLATE.json`.

Record/archive:

- final review evidence ID:
- reviewer:
- timestamp:
- stable release-evidence basis SHA-256:
- final review SHA-256:
- decision: GO / HOLD / NO-GO
- known limitations/noncritical issues:

Only literal `GO` can support REAL arming.

Concrete Part28 inputs:

- `InpReleaseFinalReviewEvidenceId=`
- `InpReleaseFinalReviewDigest=`
- `InpReleaseFinalDecision=GO`
- `InpReleaseFinalReviewer=`
- `InpReleaseFinalReviewTimestamp=`
- `InpReleaseOperatorReviewPassed=true`

## 11. Final machine validation

Run and archive:

```text
python tools/validate_ci_evidence.py ...
python tools/validate_ci_bundle.py ...
python tools/validate_five_day_soak_record.py ...
python tools/validate_soak_evidence.py release_evidence.json
python tools/validate_api_transport_evidence.py release_evidence.json
python tools/validate_final_release_review.py release_evidence.json final_release_review.json
python tools/validate_release_evidence.py release_evidence.json
python tools/validate_release_evidence_r7.py release_evidence.json
```

Final checklist:

- [ ] exact candidate identity archived;
- [ ] executed CI bundle PASS;
- [ ] compile PASS;
- [ ] Strategy Tester/matrices PASS;
- [ ] deployment/broker/recovery/stop PASS;
- [ ] API transport PASS;
- [ ] five-day machine record PASS;
- [ ] five-day operator record complete;
- [ ] soak schema PASS;
- [ ] all zero-tolerance fields zero;
- [ ] final review GO/PASS;
- [ ] aggregate release validator PASS;
- [ ] all local MT5 release inputs match archived evidence exactly;
- [ ] live arm phrase is entered only after final GO.

Release reviewer:

Candidate Git SHA:

CI bundle SHA-256:

Five-day record SHA-256:

Soak SHA-256:

API transport evidence SHA-256:

Final review SHA-256:

Final evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:


## Five-day per-day reconciliation

Acceptance schema: `five_day_soak_acceptance_v2`.

For each of the five accepted days archive a dated copy of `SOAK_DAY_RECONCILIATION_CHECKLIST.md` showing:

- exact candidate/date identity;
- broker/order/deal vs EA authorization reconciliation;
- stop/protection state;
- lifecycle/pending-approval state;
- recovery/checkpoint state;
- GPT/API fail-closed integrity;
- risk/dashboard consistency;
- required logs;
- all daily zero-tolerance values = 0;
- literal `Decision: **ACCEPT DAY**`;
- reconciler and timestamp.

The machine day's `reconciliation_checklist_path`, `day_reconciled`, `reconciled_by` and `reconciled_at` must match the retained artifact.
