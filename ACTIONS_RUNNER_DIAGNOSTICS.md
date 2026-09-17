# GitHub Actions Runner Provisioning Diagnostics

This document records the current GPT_EA Actions failure mode and the release-safe response.

## Current observed failure signature

Affected workflows:

- `GPT_EA Static Release Gate`
- `GPT_EA Runner Provisioning Probe`

Runner label: `ubuntu-latest`

Observed API state on failed attempts:

- job object is created;
- job reaches `completed/failure` within a few seconds;
- `runner_id = 0`;
- `runner_name = ""`;
- `runner_group_id = 0`;
- `steps = []`;
- no `Set up job`, checkout, Python setup, repository script step or even a plain shell step executes;
- downloadable job logs are unavailable.

This signature means the failure occurs **before GitHub assigns a hosted runner**. It is not evidence that `tools/check_mql_static.py` or `tools/check_release_certification.py` failed, because neither script has started.

## Minimal no-action probe result

A separate diagnostic workflow was added at:

`.github/workflows/runner-probe.yml`

It deliberately uses **no external GitHub Action at all**. It contains only a native shell `run:` step on `ubuntu-latest`.

Observed probe result:

- workflow run ID: `35275383852`;
- job ID: `105384628531`;
- conclusion: `failure`;
- duration: about 3 seconds;
- `runner_id = 0`;
- `runner_name = ""`;
- `steps = []`.

Therefore the current failure is **not caused by**:

- `actions/checkout` policy;
- `actions/setup-python` policy;
- `actions/upload-artifact` policy;
- repository Python scripts;
- the GPT_EA static checker;
- workflow shell syntax inside a normal job step.

The job never reaches a runner where any of those could execute.

## Repository Actions-policy conclusion

The repository is functionally capable of creating Actions runs: push-triggered workflows are created and failed jobs can be re-run through the GitHub API. The minimal no-action workflow is also discovered and instantiated by GitHub.

That makes a repository-level third-party action allow-list restriction an implausible explanation for the current failure. Even a workflow containing no marketplace/reusable actions receives no hosted runner.

The remaining failure domain is therefore **hosted-runner allocation at the account/service entitlement layer** or an equivalent GitHub backend provisioning restriction.

## Platform-status check

Before treating this as an account problem, check `https://www.githubstatus.com/` and confirm the Actions component is operational. If GitHub reports an active Actions incident, do not modify repository logic merely to work around a platform outage.

At the time of this investigation GitHub Actions was reported operational, so no platform-wide incident explained the failures.

## Billing-hold conclusion

The connected GitHub API does not expose the owner's private billing ledger, invoices, card state, Actions budget values or internal entitlement flags. Therefore the repository API can prove that hosted-runner allocation is blocked, but it **cannot reveal which private billing flag GitHub has set**.

The observed signature is consistent with GitHub's documented/community-reported billing/entitlement failure class in which jobs fail before hosted-runner allocation because of one of the following:

- a failed or past-due payment;
- an Actions/meters budget or spending cap that has stopped usage;
- a zero/insufficient spending limit;
- a payment method/account requiring billing re-validation;
- a GitHub backend billing-entitlement state that remains locked even after visible billing settings are corrected.

Because this is a personal repository, organization/enterprise billing inheritance is not the likely scope.

### What must be checked in the private Billing UI

GitHub → **Settings → Billing & licensing**:

1. **Usage** — inspect Actions/meters usage and any stopped meter.
2. **Budgets and alerts** — verify no applicable budget has `Stop usage when budget limit is reached` active at/above its limit and no relevant budget is effectively zero.
3. **Payment information / payment history** — confirm there is no failed, declined, pending or past-due payment and no verification warning.
4. Inspect any account-level warning banner indicating that metered services or Actions are suspended.

If those pages are clean but the minimal runner probe still returns `runner_id=0`, open a GitHub Support ticket and request that GitHub verify/clear the hosted-runner billing entitlement for the personal account.

## How to distinguish workflow failure from provisioning failure

### Provisioning/account/policy failure

- runner ID is zero;
- runner name is empty;
- step array is empty;
- failure occurs before checkout or any shell command;
- no job log is generated.

### Repository/workflow failure

- runner ID is non-zero;
- `Set up job` appears;
- one or more steps appear;
- logs identify a command/action failure.

Only the second case should be debugged by changing workflow code.

## Offline release-check fallback

While hosted Actions are unavailable, run the same repository-level static checks locally:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_release_checks.ps1
```

Portable Python:

```text
python tools/run_release_checks.py
```

The aggregate checker writes `static-check.txt` at repository root and exits non-zero on failure.

This offline fallback does **not** replace:

- MetaEditor compile gate;
- Strategy Tester;
- broker matrix;
- recovery tests;
- stop-management tests;
- demo-soak acceptance.

## Recovery procedure after billing/entitlement repair

1. Run `GPT_EA Runner Provisioning Probe` manually first.
2. Confirm `runner_id` becomes non-zero and its shell step appears.
3. Run `GPT_EA Static Release Gate` manually.
4. Confirm `Set up job`, checkout, Python setup and checker steps appear.
5. If the static workflow then fails, inspect `static-check.txt` and fix the actual repository issue.
6. Do not set release evidence flags to PASS merely because runner provisioning was restored.

## Support evidence bundle

If GitHub billing/settings appear healthy but hosted jobs still fail before allocation, provide GitHub Support:

- account owner: `bonaventuresimeon`;
- repository: `bonaventuresimeon/GPT_EA`;
- standard workflow name and run ID;
- minimal probe workflow name and run ID `35275383852`;
- minimal probe job ID `105384628531`;
- UTC start/completion times;
- runner label `ubuntu-latest`;
- API evidence showing `runner_id=0`, empty runner name and `steps=[]` on a workflow containing no external actions;
- screenshot of Billing & licensing → Usage;
- screenshot of Budgets and alerts;
- screenshot of payment/payment-history state;
- screenshot of repository `Settings → Actions → General` if needed.

The no-action probe is particularly useful because it demonstrates that the block occurs before any repository code or third-party action is involved.


## R6 runner-recovery release evidence

After hosted-runner allocation is restored, recovery is not considered release evidence merely because a workflow becomes green.

Create `artifacts/runner-recovery-evidence.json` from `RUNNER_RECOVERY_EVIDENCE_TEMPLATE.json` and follow `RUNNER_RECOVERY_EVIDENCE.md`. The record must preserve the original pre-runner signature and bind both:

- a later successful `GPT_EA Runner Provisioning Probe` with `runner_id > 0` and executed steps; and
- the exact release candidate's successful `static-release-gate` plus validated CI-bundle digest.

Finalize with:

```text
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json --finalize
python tools/validate_runner_recovery_evidence.py artifacts/runner-recovery-evidence.json
```

Archive `runner-recovery-evidence-validation.txt`. Until that evidence is validated, `InpReleaseRunnerRecoveryPassed` remains false and REAL trading stays blocked.
