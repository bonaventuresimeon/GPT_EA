# GPT_EA Release Evidence Validation

This document connects the human release contracts to the runtime release inputs and the machine-readable validator.

## Purpose

The release booleans in `GPT_EA_Part28_ReleaseCertification.mqh` are attestations, not proof by themselves. Before a real-account build is armed, the release owner should create one evidence JSON file from `RELEASE_EVIDENCE_TEMPLATE.json`, populate it from the actual candidate artifacts and test campaign, and validate it with:

```text
python tools/validate_release_evidence.py path/to/release_evidence.json
```

A PASS produces `release-evidence-validation.txt` and an `EVIDENCE_JSON_SHA256` digest. Archive both the JSON and the validation output with the candidate `.ex5`, `.set`, compile log and demo-soak report.

## Compile evidence mapping

The following JSON fields must correspond to the same candidate used in MetaTrader:

- `build.git_sha` → `InpReleaseSourceCommitSha`
- `build.ex5_sha256` → `InpReleaseEx5Sha256`
- `build.set_sha256` → `InpReleaseSetSha256`; use literal `NONE` only when no preset is used
- `build.compile_evidence_id` → `InpReleaseCompileEvidenceId`
- `build.metaeditor_build` → `InpReleaseMetaEditorBuild`
- `build.mt5_build` → `InpReleaseMT5Build`

The validator requires:

- exact current release validation ID;
- 40-hex Git commit SHA;
- 64-hex EX5 SHA-256;
- 64-hex SET SHA-256 or `NONE`;
- zero compile errors;
- zero compile warnings for production certification;
- MetaEditor and MT5 build identifiers;
- compile-evidence reference;
- compile log path;
- EX5/SET file hash equality when the referenced files are locally available;
- repository `HEAD` to equal the evidence Git SHA when the validator is run from a Git checkout.

Do not set `InpReleaseMetaEditorCompilePassed=true` or `InpReleaseArtifactIdentityArchived=true` until these checks pass and evidence is archived.

## Demo-soak evidence mapping

The following JSON fields map to runtime attestation inputs:

- `demo_soak.evidence_id` → `InpReleaseSoakEvidenceId`
- `demo_soak.trading_days` → `InpReleaseSoakTradingDays`
- `demo_soak.london_sessions` → `InpReleaseSoakLondonSessions`
- `demo_soak.ny_sessions` → `InpReleaseSoakNYSessions`
- `demo_soak.overlap_observed` → `InpReleaseSoakOverlapObserved`
- `demo_soak.news_day_observed` → `InpReleaseSoakNewsDayObserved`
- `demo_soak.rollover_observed` → `InpReleaseSoakRolloverObserved`
- `demo_soak.restart_observed` → `InpReleaseSoakRestartObserved`
- `demo_soak.reconnect_observed` → `InpReleaseSoakReconnectObserved`
- `demo_soak.zero_tolerance_failures` → `InpReleaseSoakZeroToleranceFailures`
- `demo_soak.unresolved_critical_states` → `InpReleaseSoakUnresolvedCriticalStates`

The real-account runtime gate independently requires:

- at least 5 consecutive trading days;
- at least 3 London sessions;
- at least 3 New York/U.S. cash sessions;
- London/New York overlap observed;
- a relevant high-impact news day observed;
- rollover/spread-expansion window observed;
- restart observed;
- disconnect/reconnect observed;
- zero zero-tolerance failures;
- zero unresolved critical states at soak end.

These numeric/boolean fields do not replace `DEMO_SOAK_ACCEPTANCE.md`; they make its minimum coverage and zero-tolerance rules impossible to satisfy with the `InpReleaseDemoSoakPassed` checkbox alone.

## Deployment evidence

Populate `deployment` with the intended broker/server/account profile. It must agree with the deployment profile used for `DEPLOYMENT_DRIFT_TESTS.md` and, where configured, the expected identity inputs in `GPT_EA_Part29_DeploymentDriftGuard.mqh`.

A materially different broker, server, margin mode, account currency/leverage or structural symbol contract invalidates the release evidence until reviewed/retested.

## Full gate record

Every field under `gates` must be `true` only after its underlying evidence exists. The validator rejects a candidate when any mandatory R5 gate remains false.

The machine validator does not claim to prove the truth of every human test. Its purpose is to detect:

- wrong release ID;
- mismatched source/artifact identity;
- malformed or missing hashes;
- missing compile evidence;
- incomplete demo-soak coverage;
- non-zero critical/zero-tolerance failures;
- missing deployment identity;
- an incomplete mandatory gate set.

## Final archive set

For each production candidate archive at minimum:

1. `release_evidence.json` completed from the template;
2. `release-evidence-validation.txt`;
3. evidence JSON SHA-256 from the validator;
4. exact Git commit SHA;
5. candidate `.ex5` and SHA-256;
6. candidate `.set` and SHA-256 when used;
7. MetaEditor compile log;
8. demo-soak report and timestamps;
9. broker/deployment profile;
10. required runtime CSVs and terminal logs listed in `RELEASE_EVIDENCE_MANIFEST.md`;
11. final signed GO/NO-GO record.

Any executable change after this evidence is generated invalidates the candidate artifact identity and requires a new compile/hash plus whatever downstream revalidation the change affects.
