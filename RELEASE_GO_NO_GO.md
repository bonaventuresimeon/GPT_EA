# GPT_EA Final GO / NO-GO Release Contract

This is the final production decision record. A candidate build is **GO** only when every mandatory release gate is PASS and the archived evidence identifies the exact compiled artifact and deployment environment.

## GO requires all of the following

- MetaEditor compile gate PASS.
- Exact Git commit recorded.
- Exact `.ex5` SHA-256 archived.
- Exact `.set` SHA-256 archived when a preset is used; otherwise explicit `NONE` recorded.
- `RELEASE_EVIDENCE_TEMPLATE.json` completed for the exact candidate.
- `tools/validate_release_evidence.py` returns PASS.
- `release-evidence-validation.txt` archived.
- Evidence JSON SHA-256 archived.
- Strategy Tester PASS for applicable deterministic scenarios.
- Intelligence test matrix PASS.
- Adaptive portfolio/risk-supervisor matrix PASS.
- Execution-learning/calibration/event/MAE-MFE matrix PASS.
- Champion/challenger/counterfactual matrix PASS.
- Lifecycle/GPT-integrity/replay matrix PASS.
- Broker/account/symbol matrix PASS.
- Deployment-profile/drift matrix PASS.
- Recovery/restart matrix PASS.
- HIGH-priority stop-management matrix PASS.
- Broker-specific stop-failure policy PASS.
- Partial-protection release test PASS.
- Stop-failure observability matrix PASS.
- Live-news/intermarket validation PASS.
- WebRequest/OpenAI failure-injection PASS.
- Demo-soak acceptance contract PASS.
- Demo-soak quantitative evidence records at least 5 consecutive trading days, 3 London sessions, 3 New York sessions, overlap, relevant news day, rollover, restart and reconnect.
- Demo soak records zero zero-tolerance failures and zero unresolved critical states.
- Zero unexplained critical protection/recovery/release blockers.
- Final operator review PASS.
- Required release validation ID matches the current source contract.

## Automatic NO-GO conditions

The release is **NO-GO** if any of the following is true:

- compile error or unresolved release-blocking warning;
- compile evidence cannot identify the MetaEditor/MT5 builds used;
- candidate `.ex5` cannot be tied to the recorded source commit;
- EX5 hash differs from the archived evidence;
- release `.set` differs from the archived preset without revalidation;
- evidence JSON release ID differs from the current source contract;
- machine-readable release evidence validation returns FAIL;
- broker/account/server differs materially from the validated deployment without review;
- structural symbol contract drift is detected;
- any open GPT_EA position is unprotected;
- unresolved critical stop failure or partial-protection hazard exists;
- duplicate order/partial behavior is observed;
- recovery state is inconsistent or non-idempotent;
- live-news/intermarket path behaves contrary to configured failure policy;
- certified release/dashboard state can report PASS while an underlying hard gate is blocked;
- demo soak did not meet coverage/acceptance criteria;
- demo soak has any zero-tolerance failure;
- demo soak ends with any unresolved critical state;
- executable source changed after compile/soak evidence was captured;
- required evidence artifact is missing;
- release owner cannot explain any unresolved critical Journal/Experts error.

## Required release identity

Record:

- Git SHA;
- release validation ID;
- MetaTrader build;
- MetaEditor build;
- compile evidence ID/reference;
- EX5 SHA-256;
- SET SHA-256 or `NONE`;
- release-evidence JSON SHA-256;
- broker company;
- server;
- account margin mode;
- account currency/leverage;
- resolved symbols;
- test date range;
- demo-soak evidence ID;
- demo-soak date range;
- demo-soak trading-day/session/event coverage counts;
- zero-tolerance failure count;
- unresolved critical state count;
- release owner/reviewer.

## Deployment rule

A GO decision applies only to the exact candidate artifact and validated environment. Material changes to executable source, preset/risk controls, broker/server/account mode, symbol contract specification or release-gate behavior invalidate the GO decision and require revalidation.

## Runtime attestation rule

For a REAL account, the runtime release gate requires the exact source commit SHA, EX5 hash, SET hash/`NONE`, compile evidence ID, MetaEditor/MT5 build identifiers, demo-soak evidence ID and quantitative soak coverage fields in addition to the release PASS booleans.

A checkbox copied from an older build is not sufficient to arm a materially different candidate.

## Decision

Release reviewer:

Candidate Git SHA:

Release validation ID:

Evidence JSON SHA-256:

Decision: **GO / NO-GO / HOLD**

Notes:

Passing this release contract does not mean a strategy is guaranteed to be profitable. It means the candidate has met the defined engineering, protection, recovery, broker-compatibility, evidence-integrity and operational-safety requirements for controlled deployment.
