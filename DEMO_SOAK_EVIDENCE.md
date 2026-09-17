# GPT_EA R6 Demo-Soak Evidence Contract

This document defines how the R6 demo-soak evidence is produced, reconciled, hashed and promoted into release evidence. It complements `DEMO_SOAK_ACCEPTANCE.md`, `SOAK_EVIDENCE_SCHEMA.json`, `GPT_EA_Part36_DemoSoakEvidence.mqh` and the release gate in `GPT_EA_Part28_ReleaseCertification.mqh`.

## Purpose

A soak result is not accepted because the EA stayed attached, produced profit, or displayed a healthy dashboard. R6 requires measurable operational coverage, zero-tolerance reconciliation, durable logs, artifact identity and a human-reviewed report.

`GPT_EA_Part36_DemoSoakEvidence.mqh` is an **evidence collector**, not a certification engine. It cannot set `InpReleaseDemoSoakPassed=true`, cannot arm a REAL account and refuses to run its soak collector on a REAL account.

## Start a new soak

Use the exact candidate EX5/SET intended for release. On a demo/contest terminal:

1. Set `InpEnableDemoSoakEvidence=true`.
2. Set `InpDemoSoakEvidenceId` to a unique identifier of at least 8 characters, for example `R6-20260917-A`.
3. Keep the same evidence ID for the complete soak. A changed evidence ID resets the machine counters for the new run.
4. Do not change executable source, EX5, risk preset or materially relevant inputs during the run. A material change creates a new candidate and requires a new evidence ID.
5. Preserve the MT5 Common Files outputs throughout the run.

## Machine-generated artifacts

Part36 writes:

- `GPT_EA_DemoSoakEvidence.csv` — append-only event and summary observations.
- `GPT_EA_DemoSoakSnapshot.json` — current `demo_soak` object aligned to `SOAK_EVIDENCE_SCHEMA.json`.

The JSON snapshot deliberately leaves `evidence_digest` blank. The digest is finalized offline after the operator has reconciled the machine observations and completed the soak report.

## Automatically observed fields

The runtime collector directly observes or infers:

- maximum consecutive trading days with fresh configured-symbol quotes;
- London-session days;
- New York/U.S. cash-session days;
- London/New York overlap;
- high-impact calendar day observation;
- rollover window plus spread expansion relative to M5 ATR;
- EA restart/reinitialization under the same soak ID;
- terminal disconnect followed by reconnect;
- scheduled scan count;
- continuous/new-M5 scan count;
- manual `SCAN NOW` count as an additional engineering requirement;
- primary recovery-checkpoint updates;
- validated `.bak` checkpoint observations;
- current unresolved machine-observed critical protection states;
- unprotected-position + active-authorization overlap;
- release-summary/runtime-block mismatch;
- required execution, stop-failure and release-evidence log presence.

The collector also exposes `RecordDemoSoakIncident(code, detail, zeroTolerance)` so additional runtime detectors can increment the stable R6 failure buckets.

## Fields requiring reconciliation, not blind trust

A zero in the runtime snapshot is **not by itself proof** that an event never occurred. The release reviewer must reconcile the following against terminal history, Experts/Journal, CSVs and the soak report:

- duplicate orders;
- duplicate partial exits;
- stop-loss regressions;
- unprotected new authorizations;
- release-gate bypasses;
- duplicate analytics finalizations;
- stop-failure join failures;
- dashboard/release-gate mismatches;
- runtime critical errors;
- secret exposure.

If any such failure is discovered outside the runtime collector, update the completed release evidence to the real non-zero count. Any non-zero value is release blocking under R6.

## Stale approval lifecycle closure

R6 distinguishes two meanings of `WAIT_CONFIRMATION`:

- `LIFECYCLE_WAIT_MARKET_CONFIRMATION` — the strategy is waiting for price/structure confirmation.
- `LIFECYCLE_WAIT_HUMAN_APPROVAL` — a high-confidence setup has an active human approval request.

The Part36 reconciler checks human-approval waits independently of soak collection. If the pending approval disappears and there is no filled position, the symbol lifecycle is transitioned to `INVALIDATED` and the wait-kind marker is cleared. This closes the stale state produced when an approval is consumed but fresh revalidation later rejects the order.

Market-confirmation waits are not cleared by this rule.

## R6 minimum coverage

Machine coverage is `READY_FOR_HUMAN_RECONCILIATION` only when all of the following are true:

- at least 5 consecutive trading days;
- at least 3 London-session observations;
- at least 3 New York/U.S. cash-session observations;
- overlap observed;
- high-impact news day observed;
- rollover spread-expansion observed;
- at least one restart/reinitialization;
- at least one disconnect/reconnect cycle;
- at least one scheduled scan;
- at least one continuous/new-M5 scan;
- at least one manual `SCAN NOW` scan;
- at least one primary checkpoint update;
- at least one validated backup checkpoint observation;
- all detailed zero-tolerance counters remain zero;
- current unresolved critical state count is zero;
- execution log is present;
- stop-failure log is present;
- release-evidence log is present.

This machine-ready state is necessary but not sufficient for release.

## Evidence schema and digest

The authoritative machine-soak schema is `SOAK_EVIDENCE_SCHEMA.json` and the required version is:

`demo_soak_evidence_v1`

The bound five-day acceptance sub-schema is:

`five_day_soak_acceptance_v2`

Each accepted day requires a completed `SOAK_DAY_RECONCILIATION_CHECKLIST.md` copy with `ACCEPT DAY`, matching date/Git SHA, reviewer and timestamp.

The final `demo_soak` object must contain a SHA-256 digest calculated over the canonical JSON object **excluding** the `evidence_digest` field. `tools/validate_soak_evidence.py` verifies both schema and digest.

Use `tools/import_soak_snapshot.py` with the completed Part36 snapshot, finalized five-day v2 acceptance JSON, and release-evidence JSON. The importer binds the acceptance schema/ID/digest and calculates the soak digest automatically.

Then run:

```text
python tools/import_soak_snapshot.py path/to/GPT_EA_DemoSoakSnapshot.json artifacts/five-day-soak-acceptance.json path/to/release_evidence.json
python tools/validate_soak_evidence.py path/to/release_evidence.json
python tools/validate_release_evidence.py path/to/release_evidence.json
```

Both must return PASS for the exact release candidate.

## Report requirement

Copy `DEMO_SOAK_REPORT_TEMPLATE.md` to the path referenced by `demo_soak.report_path` and complete it with:

- exact candidate Git/EX5/SET identity;
- broker/account identity;
- soak start/end;
- coverage evidence;
- scan/checkpoint counts;
- restart/reconnect evidence;
- news and rollover evidence;
- trade/lifecycle observations;
- all zero-tolerance reconciliations;
- unresolved issues;
- operator conclusion.

The report must exist when the soak validator is run.

## Promotion into Part28 inputs

Only after the schema validator, release-evidence validator and human review pass should the matching values be entered into Part28 locally, including:

- `InpReleaseSoakSchemaVersion=demo_soak_evidence_v1`;
- soak evidence ID and digest;
- day/session/event coverage;
- scheduled/continuous scans;
- checkpoint/backup counts;
- all zero-tolerance counters;
- log-presence booleans;
- `InpReleaseDemoSoakPassed=true`.

The Part28 runtime gate remains fail-closed if any required field is missing, stale, malformed or non-zero where zero is required.

## Certification invalidation

The soak is invalidated by any material executable-source change, different EX5, materially different SET/risk profile, different release validation contract, or deployment to a materially different broker/account/symbol environment. Such a candidate requires new evidence and a new digest.
