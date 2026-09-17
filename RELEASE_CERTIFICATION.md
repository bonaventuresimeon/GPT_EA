# GPT_EA Live Release Certification

`GPT_EA_Part28_ReleaseCertification.mqh` is the final real-account release-evidence gate. It does not prove that testing occurred; it forces the operator to explicitly attest the required evidence before real-account execution can be armed.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R3_20260917`

## Default behavior

All release-attestation inputs default to `false` and the validation ID defaults to blank. Therefore a real account remains blocked even if the normal live-arm phrase is entered.

Strategy Tester bypasses the evidence-attestation requirement so testing is possible. Demo/contest accounts treat the evidence flags as informational so broker tests, failure injection and demo soak remain possible.

## Required evidence before real arming

All of these inputs must be deliberately set only after the corresponding evidence has been completed and archived:

- `InpReleaseMetaEditorCompilePassed=true` — MetaEditor compile completed with 0 errors and warnings reviewed.
- `InpReleaseStrategyTesterPassed=true` — applicable Strategy Tester scenarios passed.
- `InpReleaseIntelligenceMatrixPassed=true` — full intelligence and hardening matrices passed.
- `InpReleaseBrokerMatrixPassed=true` — intended broker/account/symbol matrix passed.
- `InpReleaseRecoveryTestsPassed=true` — restart/recovery invariants passed.
- `InpReleaseStopMatrixPassed=true` — HIGH-priority stop-management matrix passed.
- `InpReleaseBrokerStopPolicyPassed=true` — broker-specific stop-failure classes/actions/retry behavior validated.
- `InpReleasePartialProtectionPassed=true` — `PARTIAL_PROTECTION_RELEASE_TEST.md` passed.
- `InpReleaseStopObservabilityPassed=true` — stop-failure observability schema/events/recovery evidence validated.
- `InpReleaseLiveNewsIntermarketPassed=true` — live-news, source, freshness and intermarket paths validated on terminal/demo.
- `InpReleaseWebFailureInjectionPassed=true` — OpenAI/WebRequest unavailable, malformed, timeout and recovery paths tested.
- `InpReleaseDemoSoakPassed=true` — controlled demo soak completed without unresolved release blockers.
- `InpReleaseOperatorReviewPassed=true` — final human release review completed.
- `InpReleaseValidationId=GPT_EA_FULL_INTELLIGENCE_R3_20260917`.

The existing `InpLiveArmPhrase=GPT_EA_LIVE_ARMED` remains separately required when configured. Neither gate bypasses the other. Stop-health, risk, broker, news and execution gates also remain independently enforceable.

## Runtime synchronization

The certified release state is refreshed during safety initialization and safety timer cycles. The global release state therefore reflects certification/stop-health failures instead of merely checking them at order-send time.

Existing positions continue to be managed when certification blocks new entries.

## Runtime audit

When enabled, `GPT_EA_ReleaseEvidence.csv` is written to the MT5 Common Files area at initialization. It records:

- required and entered release IDs;
- account mode, broker and server;
- every release-attestation flag;
- combined certified release PASS/BLOCK result;
- blocking reason.

This snapshot is an audit record only. It does not substitute for the underlying evidence.

## Release sequence

1. Compile in MetaEditor and archive the compile result.
2. Run Strategy Tester plus intelligence/hardening matrices.
3. Run broker/account/symbol matrix tests.
4. Run restart and recovery tests.
5. Run HIGH-priority stop-management tests.
6. Run broker-specific stop-failure policy tests.
7. Run the partial-protection release tests.
8. Validate stop-failure observability events and recovery joins.
9. Validate live-news/intermarket freshness, blocking and source behavior.
10. Run OpenAI/WebRequest failure injection and recovery.
11. Run a controlled demo soak.
12. Review intelligence, execution, stop-failure and release-evidence journals for unresolved blockers.
13. Archive the evidence pack with the exact Git commit SHA, MT5 build, broker/server and `.set` files.
14. Complete final operator review.
15. Only then set the release-attestation inputs and live-arm phrase locally on the intended terminal.

## Invalidation of certification

Certification must be repeated when a change can materially affect execution, protection, market classification, risk, OpenAI/news behavior, broker compatibility, recovery or the release gate itself. Examples include:

- changes to order placement or volume logic;
- changes to SL/BE/profit-lock/trailing logic;
- changes to partial-profit state handling;
- changes to broker failure classification/retry policy;
- changes to strategy selection or pre-entry gates;
- changes to live-news/intermarket authorization;
- changes to persistence/recovery logic;
- changes to release-certification logic;
- deployment to a materially different broker/account/symbol environment.

A source change after certification should be treated as a new candidate build unless it is proven non-executable/documentation-only and the release owner explicitly records that determination.

## Live rule

A real-account build is **not release-certified** until the combined certified gate passes all of the following:

1. ordinary `ReleaseSafetyAllows()` requirements, including explicit live arming;
2. `StopObservabilityAllowsNewEntries()` protection-health requirements; and
3. `ReleaseEvidenceAllows()` requirements for the current release validation ID.

Passing release certification never guarantees a profitable trade. It only verifies that the build has passed the required technical release process and remains subject to all trading/risk filters.
