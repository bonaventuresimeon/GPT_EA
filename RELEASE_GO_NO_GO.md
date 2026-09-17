# GPT_EA Final GO / NO-GO Release Contract

This is the final production decision record. A candidate build is **GO** only when every mandatory release gate is PASS and the archived evidence identifies the exact compiled artifact and deployment environment.

## GO requires all of the following

- MetaEditor compile gate PASS.
- Exact Git commit recorded.
- Exact `.ex5` SHA-256 archived.
- Exact `.set` SHA-256 archived when a preset is used.
- Strategy Tester PASS for applicable deterministic scenarios.
- Intelligence test matrix PASS.
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
- Zero unexplained critical protection/recovery/release blockers.
- Final operator review PASS.
- Required release validation ID matches the current source contract.

## Automatic NO-GO conditions

The release is **NO-GO** if any of the following is true:

- compile error or unresolved release-blocking warning;
- candidate `.ex5` cannot be tied to the recorded source commit;
- release `.set` differs from the archived preset without revalidation;
- broker/account/server differs materially from the validated deployment without review;
- structural symbol contract drift is detected;
- any open GPT_EA position is unprotected;
- unresolved critical stop failure or partial-protection hazard exists;
- duplicate order/partial behavior is observed;
- recovery state is inconsistent or non-idempotent;
- live-news/intermarket path behaves contrary to configured failure policy;
- certified release/dashboard state can report PASS while an underlying hard gate is blocked;
- demo soak did not meet coverage/acceptance criteria;
- executable source changed after compile/soak evidence was captured;
- required evidence artifact is missing;
- release owner cannot explain any unresolved critical Journal/Experts error.

## Required release identity

Record:

- Git SHA;
- release validation ID;
- MetaTrader build;
- MetaEditor build;
- EX5 SHA-256;
- SET SHA-256;
- broker company;
- server;
- account margin mode;
- account currency/leverage;
- resolved symbols;
- test date range;
- demo-soak date range;
- release owner/reviewer.

## Deployment rule

A GO decision applies only to the exact candidate artifact and validated environment. Material changes to executable source, preset/risk controls, broker/server/account mode, symbol contract specification or release-gate behavior invalidate the GO decision and require revalidation.

Passing this release contract does not mean a strategy is guaranteed to be profitable. It means the candidate has met the defined engineering, protection, recovery, broker-compatibility and operational-safety requirements for controlled deployment.