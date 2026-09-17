# GPT_EA R6 Runner-Recovery Acceptance Matrix

This matrix is the production acceptance layer for recovery from the known GitHub hosted-runner pre-execution failure. It is distinct from `RUNNER_RECOVERY_TEST_MATRIX.md`: the test matrix defines cases to exercise, while this matrix defines the evidence that must exist before the recovery is accepted for an R6 production candidate.

Machine schema: `runner_recovery_acceptance_v1`.

Create `artifacts/runner-recovery-acceptance.json` from `RUNNER_RECOVERY_ACCEPTANCE_TEMPLATE.json`. Every mandatory row below must be represented by a true machine check and supporting archived evidence.

| ID | Acceptance domain | Mandatory PASS criterion | Evidence source |
|---|---|---|---|
| RA-001 | Original incident preserved | Original job/run proves `runner_id=0`, blank runner name and zero executed steps | runner recovery incident record |
| RA-002 | Failure classified correctly | Incident classification is `PRE_RUNNER_NO_STEPS`; not a source/test failure | runner recovery evidence |
| RA-003 | GitHub service/status review | Platform status was checked and any incident noted | operator remediation record |
| RA-004 | Account Actions eligibility | Actions/billing/usage state reviewed for the repository/account | operator remediation record |
| RA-005 | Budget/spending eligibility | Relevant budget/spending limits checked | operator remediation record |
| RA-006 | Payment state | Payment/payment-history warnings checked | operator remediation record |
| RA-007 | Recovery probe allocated | Later `runner-probe` has real job ID, `runner_id>0`, runner name and executed step | GitHub job API |
| RA-008 | Recovery probe completed | Probe conclusion is literal `success` | GitHub job API |
| RA-009 | Exact run attempt | Probe evidence is pinned to its recorded run attempt | GitHub job API |
| RA-010 | Candidate static runner allocated | Exact-candidate `static-release-gate` has `runner_id>0` | CI job metadata |
| RA-011 | Candidate static steps executed | Static job executed at least seven non-skipped completed steps | CI job metadata |
| RA-012 | Candidate static conclusion | Static job conclusion is literal `success` | CI job metadata |
| RA-013 | Candidate identity | Static head SHA equals frozen release Git SHA | CI evidence/build identity |
| RA-014 | Static repository result | Aggregate repository checker ends in `RESULT=PASS` | static-check.txt |
| RA-015 | CI evidence validation | `ci-evidence.json` validates against completed job metadata | ci-evidence-validation.txt |
| RA-016 | Provenance attestation | GitHub attestation is created and verification returns PASS | ci-attestation-verify.txt |
| RA-017 | CI bundle validation | `ci_evidence_bundle_v1` validates and digest is archived | ci-bundle-validation.txt |
| RA-018 | Recovery-to-CI identity join | Recovery static run/job/runner/steps equal accepted `ci_static` identity | release validator |
| RA-019 | Recovery-to-bundle join | Recovery bundle digest equals accepted CI bundle digest | release validator |
| RA-020 | No post-recovery regression | No later relevant candidate run has reverted to the same pre-runner signature without review | operator review |
| RA-021 | Evidence digest | Runner-recovery evidence and acceptance record digests validate | validators |
| RA-022 | Operator acceptance | Reviewer explicitly records `ACCEPT` with timestamp | acceptance record |

## Acceptance rule

All RA-001 through RA-022 are mandatory. A single FAIL, HOLD, missing artifact, identity mismatch, digest mismatch, `runner_id=0`, absent step list, or later unexplained regression keeps `runner_recovery_acceptance` at HOLD.

Validate:

```text
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json
python tools/validate_runner_recovery_acceptance.py artifacts/runner-recovery-acceptance.json
```

Only after both return PASS may the matching Part28B runner-recovery and runner-acceptance inputs be populated. The acceptance matrix does not substitute for the actual CI bundle.
