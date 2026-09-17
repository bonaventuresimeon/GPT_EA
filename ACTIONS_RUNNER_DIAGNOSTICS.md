# GitHub Actions Runner Provisioning Diagnostics

This document records the current GPT_EA Actions failure mode and the release-safe response.

## Current observed failure signature

Affected workflow: `GPT_EA Static Release Gate`
Runner label: `ubuntu-latest`

Observed API state on failed attempts:

- job object is created;
- job reaches `completed/failure` within a few seconds;
- `runner_id = 0`;
- `runner_name = ""`;
- `runner_group_id = 0`;
- `steps = []`;
- no `Set up job`, checkout, Python setup, or repository script step executes;
- downloadable job logs are unavailable.

This signature means the failure occurs **before GitHub assigns a hosted runner**. It is not evidence that `tools/check_mql_static.py` or `tools/check_release_certification.py` failed, because neither script has started.

## Platform-status check

Before treating this as an account problem, check `https://www.githubstatus.com/` and confirm the Actions component is operational. If GitHub reports an active Actions incident, do not modify repository logic merely to work around a platform outage.

## Account/billing checks

For a personal repository, inspect the authenticated account that owns the repository:

1. GitHub → Settings.
2. Billing & licensing.
3. Usage.
4. Budgets and alerts.
5. Payment information / payment history if shown.

Verify all of the following:

- no failed or past-due payment;
- no account-level billing hold;
- no Actions budget with `Stop usage when budget limit is reached` already triggered;
- no metered-product budget set to zero in a way that blocks hosted compute;
- no payment method requiring re-verification;
- repository Actions are enabled under `Settings → Actions → General`;
- allowed-actions policy permits `actions/checkout`, `actions/setup-python`, and `actions/upload-artifact`.

Although standard GitHub-hosted runners are normally free for public repositories, GitHub can still refuse hosted-runner allocation when the account has a billing/entitlement hold. Do not assume a public repository makes an account-level hold impossible.

## How to distinguish workflow failure from provisioning failure

### Provisioning/account/policy failure

- runner ID is zero;
- runner name is empty;
- step array is empty;
- failure occurs before checkout;
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

## Recovery procedure after billing/policy repair

1. Re-run the failed GitHub Actions job or start `GPT_EA Static Release Gate` manually.
2. Confirm `runner_id` becomes non-zero.
3. Confirm `Set up job`, checkout, Python setup and checker steps appear.
4. If the workflow then fails, inspect `static-check.txt` and fix the actual repository issue.
5. Do not set release evidence flags to PASS merely because runner provisioning was restored.

## Support evidence bundle

If GitHub billing/settings appear healthy but hosted jobs still fail before allocation, provide GitHub Support:

- repository: `bonaventuresimeon/GPT_EA`;
- workflow name;
- run URL;
- run ID;
- job ID;
- UTC start/completion times;
- runner label `ubuntu-latest`;
- API evidence showing `runner_id=0`, empty runner name and `steps=[]`;
- screenshot of Actions budget/payment status;
- screenshot of repository `Settings → Actions → General`.

That evidence distinguishes a backend hosted-runner entitlement/provisioning problem from a repository workflow failure.
