# GPT_EA Live Release Certification

`GPT_EA_Part28_ReleaseCertification.mqh` and `GPT_EA_Part29_DeploymentDriftGuard.mqh` form the final real-account release-evidence and deployment-stability gates. They do not prove that testing occurred; they force the operator to explicitly attest the required evidence and keep the validated deployment environment stable before real-account execution can be armed.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R4_20260917`

## Default behavior

All release-attestation inputs default to `false` and the validation ID defaults to blank. Therefore a real account remains blocked even if the normal live-arm phrase is entered.

Strategy Tester bypasses the evidence-attestation requirement so testing is possible. Demo/contest accounts treat the evidence flags as informational so broker tests, failure injection and demo soak remain possible.

## Required evidence before real arming

All of these inputs must be deliberately set only after the corresponding evidence has been completed and archived:

- `InpReleaseMetaEditorCompilePassed=true` — `METAEDITOR_COMPILE_GATE.md` passed with the exact candidate source/build.
- `InpReleaseArtifactIdentityArchived=true` — exact Git SHA, EX5 SHA-256 and SET SHA-256 (when a preset is used) are archived together.
- `InpReleaseStrategyTesterPassed=true` — applicable Strategy Tester scenarios passed.
- `InpReleaseIntelligenceMatrixPassed=true` — full intelligence and hardening matrices passed.
- `InpReleaseBrokerMatrixPassed=true` — intended broker/account/symbol matrix passed.
- `InpReleaseDeploymentProfilePassed=true` — `DEPLOYMENT_DRIFT_TESTS.md` and intended deployment profile passed.
- `InpReleaseRecoveryTestsPassed=true` — restart/recovery invariants passed.
- `InpReleaseStopMatrixPassed=true` — HIGH-priority stop-management matrix passed.
- `InpReleaseBrokerStopPolicyPassed=true` — broker-specific stop-failure classes/actions/retry behavior validated.
- `InpReleasePartialProtectionPassed=true` — `PARTIAL_PROTECTION_RELEASE_TEST.md` passed.
- `InpReleaseStopObservabilityPassed=true` — stop-failure observability schema/events/recovery evidence validated.
- `InpReleaseLiveNewsIntermarketPassed=true` — live-news, source, freshness and intermarket paths validated on terminal/demo.
- `InpReleaseWebFailureInjectionPassed=true` — OpenAI/WebRequest unavailable, malformed, timeout and recovery paths tested.
- `InpReleaseDemoSoakPassed=true` — `DEMO_SOAK_ACCEPTANCE.md` passed using the exact release artifacts.
- `InpReleaseOperatorReviewPassed=true` — `RELEASE_GO_NO_GO.md` final human release decision is GO.
- `InpReleaseValidationId=GPT_EA_FULL_INTELLIGENCE_R4_20260917`.

The existing `InpLiveArmPhrase=GPT_EA_LIVE_ARMED` remains separately required when configured. Neither gate bypasses the other. Stop-health, risk, broker, news, deployment-drift and execution gates remain independently enforceable.

## Deployment drift guard

`GPT_EA_Part29_DeploymentDriftGuard.mqh` captures structural properties for resolved symbols at startup and checks them during the running deployment.

Structural drift includes unexpected changes to:

- digits;
- point size;
- tick size;
- contract size;
- volume step;
- calculation mode;
- execution mode;
- filling mode;
- symbol availability.

These changes block **new entries** while existing positions continue protective management.

Dynamic spread, stop-level and freeze-level changes are not classified as structural drift because they can legitimately vary intraday and are already handled by live spread/stop/freeze gates.

Optional expected deployment identity checks can also validate broker company, server, account currency, margin mode and leverage.

## Runtime synchronization

The R4 release state is refreshed during safety initialization and timer cycles. Startup stop-observability initialization also returns control to the R4 gate, so an older intermediate certification state cannot overwrite the final release state.

Existing positions continue to be managed when certification or deployment drift blocks new entries.

## Runtime audit

When enabled, `GPT_EA_ReleaseEvidence.csv` is written to the MT5 Common Files area at initialization. It records:

- required and entered release IDs;
- account mode, broker and server;
- compile attestation;
- artifact-identity attestation;
- Strategy Tester/intelligence/broker/deployment/recovery evidence flags;
- stop/partial/observability evidence flags;
- live-news/WebRequest evidence flags;
- demo-soak/operator-review flags;
- combined certified release PASS/BLOCK result;
- blocking reason.

This snapshot is an audit record only. It does not substitute for the underlying evidence.

## Release sequence

1. Compile the exact candidate in MetaEditor and pass `METAEDITOR_COMPILE_GATE.md`.
2. Record Git SHA, EX5 SHA-256 and SET SHA-256.
3. Run Strategy Tester plus intelligence/hardening matrices.
4. Run broker/account/symbol matrix tests.
5. Run `DEPLOYMENT_DRIFT_TESTS.md` on the intended environment.
6. Run restart and recovery tests.
7. Run HIGH-priority stop-management tests.
8. Run broker-specific stop-failure policy tests.
9. Run the partial-protection release tests.
10. Validate stop-failure observability events and recovery joins.
11. Validate live-news/intermarket freshness, blocking and source behavior.
12. Run OpenAI/WebRequest failure injection and recovery.
13. Run `DEMO_SOAK_ACCEPTANCE.md` using the same candidate artifacts.
14. Review intelligence, execution, stop-failure and release-evidence journals for unresolved blockers.
15. Complete `RELEASE_EVIDENCE_MANIFEST.md`.
16. Complete `RELEASE_GO_NO_GO.md`; decision must be GO.
17. Only then set all release-attestation inputs and the live-arm phrase locally on the intended terminal.

## Invalidation of certification

Certification must be repeated when a change can materially affect execution, protection, market classification, risk, OpenAI/news behavior, broker compatibility, recovery or the release gate itself. Examples include:

- executable `.mq5`/`.mqh` source changes;
- changes to order placement or volume logic;
- changes to SL/BE/profit-lock/trailing logic;
- changes to partial-profit state handling;
- changes to broker failure classification/retry policy;
- changes to strategy selection or pre-entry gates;
- changes to live-news/intermarket authorization;
- changes to persistence/recovery logic;
- changes to release-certification/deployment-drift logic;
- a different `.set` preset that materially changes risk/execution behavior;
- deployment to a materially different broker/account/symbol environment.

A source change after certification is a new candidate build unless the release owner explicitly records that it is documentation-only and non-executable.

## Live rule

A real-account build is **not release-certified** until all of the following pass simultaneously:

1. ordinary release safety requirements, including explicit live arming;
2. stop-health/protection requirements;
3. R4 release-evidence requirements;
4. deployment identity/structural-drift requirements.

Passing release certification never guarantees a profitable trade. It verifies only that the exact candidate artifact has passed the defined engineering, protection, recovery, broker-compatibility and operational release process.