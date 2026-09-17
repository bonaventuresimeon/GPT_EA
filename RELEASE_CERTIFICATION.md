# GPT_EA Live Release Certification

`GPT_EA_Part28_ReleaseCertification.mqh` is a final real-account release gate. It does not prove that testing occurred; it forces the operator to explicitly attest the required evidence before real-account execution can be armed.

Current required release validation ID:

`GPT_EA_FULL_INTELLIGENCE_R2_20260917`

## Default behavior

All release-attestation inputs default to `false` and the validation ID defaults to blank. Therefore a real account remains blocked even if the normal live-arm phrase is entered.

Strategy Tester bypasses this attestation gate so testing is possible. Demo/contest accounts treat the gate as informational so demo-soak and failure-injection tests remain possible.

## Required evidence before real arming

All of these inputs must be deliberately set after the matching evidence has been completed and archived:

- `InpReleaseMetaEditorCompilePassed=true` — MetaEditor compile completed with 0 errors and warnings reviewed.
- `InpReleaseStrategyTesterPassed=true` — applicable Strategy Tester scenarios passed.
- `InpReleaseBrokerMatrixPassed=true` — intended broker/account/symbol matrix passed.
- `InpReleaseRecoveryTestsPassed=true` — restart/recovery invariants passed.
- `InpReleaseStopMatrixPassed=true` — HIGH-priority stop-management tests passed.
- `InpReleasePartialProtectionPassed=true` — `PARTIAL_PROTECTION_RELEASE_TEST.md` passed.
- `InpReleaseWebFailureInjectionPassed=true` — OpenAI/WebRequest unavailable, malformed, timeout and recovery paths tested.
- `InpReleaseDemoSoakPassed=true` — controlled demo soak completed without unresolved release blockers.
- `InpReleaseOperatorReviewPassed=true` — final human review completed.
- `InpReleaseValidationId=GPT_EA_FULL_INTELLIGENCE_R2_20260917`.

The existing `InpLiveArmPhrase=GPT_EA_LIVE_ARMED` remains separately required when configured. Neither gate bypasses the other.

## Runtime audit

When enabled, `GPT_EA_ReleaseEvidence.csv` is written to the MT5 Common Files area at initialization. It records:

- required and entered release IDs;
- account mode, broker and server;
- each release attestation flag;
- PASS/BLOCK result;
- blocking reason.

This snapshot is an audit record only. It does not substitute for the underlying evidence.

## Release sequence

1. Compile in MetaEditor and archive the compile result.
2. Run Strategy Tester and the intelligence matrices.
3. Run broker/account/symbol matrix tests.
4. Run restart and recovery tests.
5. Run HIGH-priority stop-management tests.
6. Run the partial-protection release tests.
7. Run OpenAI/WebRequest failure injection and recovery.
8. Run a controlled demo soak.
9. Review stop/intelligence journals and unresolved alerts.
10. Archive the evidence pack with the exact Git commit SHA and MT5 build.
11. Complete final operator review.
12. Only then set the release-attestation inputs and live-arm phrase locally on the intended terminal.

## Invalidation of certification

Certification must be repeated when a change can materially affect execution, protection, market classification, risk, OpenAI/news behavior, broker compatibility or recovery. Examples include:

- changes to order placement or volume logic;
- changes to SL/BE/profit-lock/trailing logic;
- changes to partial-profit state handling;
- changes to broker failure classification/retry policy;
- changes to strategy selection or pre-entry gates;
- changes to live-news/intermarket authorization;
- changes to persistence/recovery logic;
- deployment to a materially different broker/account/symbol environment.

A source change after certification should be treated as a new candidate build unless it is proven non-executable/documentation-only and the release owner explicitly records that determination.

## Live rule

A real-account build is **not release-certified** until both runtime gates pass:

1. normal `ReleaseSafetyAllows()` requirements, including explicit live arming; and
2. `ReleaseEvidenceAllows()` requirements for the current release validation ID.

Existing positions continue to be managed even when new-entry release certification is blocked.
