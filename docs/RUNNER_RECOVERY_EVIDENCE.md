<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `RUNNER_RECOVERY_EVIDENCE.md`

---

# GPT_EA R6 Runner-Recovery Evidence Contract

This contract proves that the known GitHub Actions pre-runner failure was actually resolved before CI evidence is accepted for release.

The historical failure signature was: job created, `runner_id=0`, empty runner name, `steps=[]`, no job logs and no repository step execution. A later successful source check is not enough by itself; R6 requires evidence of recovery from that exact failure class.

Schema: `runner_recovery_evidence_v1`.

## Required proof

A PASS record binds three stages:

1. **Pre-recovery incident** — a retained failed probe/run showing `runner_id=0` and zero executed steps.
2. **Recovery probe** — a later `GPT_EA Runner Provisioning Probe` job with a real `job_id`, `runner_id>0`, non-empty runner name, at least one executed step and conclusion `success`.
3. **Release static run** — the exact candidate's `static-release-gate` has `runner_id>0`, at least seven executed steps, conclusion `success`, candidate head SHA match and a validated `ci_evidence_bundle_v1` digest.

The release-static run must agree with the accepted CI bundle in `release_evidence.json`.

## Private account remediation record

Because GitHub's repository API cannot prove private billing state, the operator records which remediation path was checked:

- Actions/platform status checked;
- Billing & licensing usage checked;
- budgets/spending limits checked;
- payment/payment-history warnings checked;
- GitHub Support case ID if escalation was necessary.

These fields document remediation but do not replace executed-runner proof.

## Machine record

Preferred path after runner recovery is to build the GitHub-derived sections automatically:

```text
GITHUB_TOKEN=<token> python tools/build_runner_recovery_evidence.py \
  --probe-run-id <successful-probe-run> \
  --static-run-id <successful-release-run> \
  --candidate-sha <candidate-git-sha> \
  --ci-bundle-manifest artifacts/ci-bundle-manifest.json
```

The builder reads exact run-attempt job metadata from GitHub and leaves remediation/operator fields fail-closed for manual completion.

Alternatively start from `RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json`. Save the working copy at:

`artifacts/runner-recovery-evidence.json`

Then populate only from actual GitHub API/UI evidence. The record remains `HOLD` until both the recovery probe and exact-candidate static run executed on real runners.

Finalize/validate with:

```text
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json --finalize
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json
```

The validator writes `runner-recovery-evidence-validation.txt` and a canonical SHA-256 digest.

## Production acceptance matrix

Recovery evidence by itself proves the technical transition, but R6 production acceptance additionally requires `RUNNER_RECOVERY_ACCEPTANCE_MATRIX.md` and a finalized `runner_recovery_acceptance_v1` record.

Copy `RUNNER_RECOVERY_ACCEPTANCE_MATRIX.md` to `artifacts/runner-recovery-acceptance.md` and complete RA-001 through RA-022 only from actual evidence. Every row must be literal `PASS` with a non-empty evidence/reference.

Then build the draft acceptance JSON from the validated recovery record and completed matrix:

```text
python tools/build_runner_recovery_acceptance.py \
  --runner-recovery artifacts/runner-recovery-evidence.json \
  --matrix artifacts/runner-recovery-acceptance.md \
  --candidate-sha <candidate-git-sha> \
  --ci-bundle-digest <accepted-ci-bundle-sha256>
```

The acceptance JSON binds `matrix_path` and `matrix_sha256`, so a matrix edit after finalization invalidates the acceptance digest. Machine-derived checks are populated by the builder; account/billing/status, attestation, regression review and operator-dependent checks remain fail-closed until explicitly evidenced.

Then run:

```text
python tools/validate_runner_recovery_acceptance.py artifacts/runner-recovery-acceptance.json --finalize
python tools/validate_runner_recovery_acceptance.py artifacts/runner-recovery-acceptance.json
```

The acceptance validator revalidates the referenced runner-recovery record, verifies the completed matrix SHA-256, parses every RA-001 through RA-022 row for PASS/evidence, and joins its candidate SHA and CI-bundle digest. Both the recovery evidence and the acceptance record must PASS before Part28B may be attested.

## Release binding

`RELEASE_EVIDENCE_TEMPLATE.json -> runner_recovery` must reference the finalized evidence file, ID and digest. The release validator cross-checks its static-run identity against `ci_static` and the candidate Git SHA.

Part28B remains fail-closed on REAL until both the matching runner-recovery evidence and runner-recovery acceptance matrix records are supplied and validated.

## Invalidation

Runner-recovery evidence must be repeated when:

- the recovered runner condition later regresses to the same pre-runner signature;
- the release candidate uses a different CI run/bundle than the record binds;
- evidence metadata is edited after digest finalization;
- a workflow change materially alters the runner/evidence process.

A new executable candidate does not need a new historical incident, but it **does** need a runner-recovery record whose release-static section binds to that candidate's executed CI bundle.
