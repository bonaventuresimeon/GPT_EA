<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 👤 Customer Operations

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 👤 **Document:** `CUSTOMER_SUPPORT_RUNBOOK.md`

---

# GPT_EA Customer Support Runbook

This runbook defines how customer issues should be received, triaged, investigated, communicated and closed without collecting secrets or weakening GPT_EA safety controls.

## 1. Support principles

- Never ask for an OpenAI API key, MT5 password, investor password, card details, proxy token or secret-bearing .set file.
- Never instruct a customer to disable release, stop, broker, risk, recovery or legal gates merely to make a trade open.
- Treat trading-loss complaints separately from software defects.
- Do not promise profits, signal accuracy, recovery of losses or future performance.
- Use evidence: release ID, MT5 build, broker/server, symbol names, timestamps, request IDs, redacted logs and exact error text.
- Reproduce on demo whenever possible before recommending a change.
- Security incidents take priority over ordinary configuration questions.

## 2. Customer intake template

Request only:

    Customer/license reference:
    GPT_EA release/version:
    MT5 build:
    Broker/company:
    Trade server:
    DEMO or REAL:
    Symbols:
    OpenAI model:
    API transport mode:
    Approximate time of issue:
    Exact error/status:
    OpenAI request ID or GPT_EA trace ID:
    Release-gate message:
    Experts/Journal excerpt with secrets redacted:
    Steps already tried:

Do not request account passwords or API secrets.

## 3. Severity levels

### P0 — Security / capital-protection critical

Examples:
- exposed API key or license credential;
- missing SL on an EA-managed position;
- duplicate execution from one authorization;
- release-gate bypass;
- corrupted recovery causing unsafe position management;
- suspected malicious/tampered build.

Action:
- advise customer to stop new authorization immediately;
- preserve existing-position protection where safe;
- revoke exposed credentials;
- collect evidence;
- escalate to engineering/security;
- do not resume live trading until the issue is resolved and revalidated.

### P1 — Live operation blocked or materially degraded

Examples:
- valid release cannot initialize;
- persistent WebRequest 401/403/429/5xx/598/599;
- broker execution incompatibility;
- stop-management failure that is contained but recurring;
- recovery/checkpoint failure without open-position danger.

Action:
- move troubleshooting to demo where possible;
- diagnose exact gate/error;
- do not bypass safeguards.

### P2 — Functional/configuration issue

Examples:
- symbol alias mismatch;
- model unavailable;
- chart/UI issue;
- scheduled scan not occurring;
- approval prompt issue;
- expected WAIT/NO TRADE misunderstood as failure.

### P3 — General usage/question

Examples:
- model choice;
- installation;
- log interpretation;
- documentation clarification.

## 4. API troubleshooting route

Use `API_KEY_TROUBLESHOOTING.md`.

Key points:
- 401/403: authentication/permission.
- 429: rate, spend, quota or billing condition.
- 5xx: upstream service failure.
- 599: native MT5/network/WebRequest failure.
- 598: GPT_EA local backoff/circuit state.

Never ask the customer to reveal the secret key.

## 5. Broker/execution troubleshooting route

Collect:
- broker/server;
- exact symbol;
- contract/tick/volume/stops/freeze information;
- OrderCheck result;
- trade retcode;
- spread at failure;
- account margin mode/leverage.

Do not assume broker symbols or execution rules match another customer.

## 6. Release-gate troubleshooting

Read the exact block reason.

Common classes:
- compile/artifact identity incomplete;
- broker/deployment evidence missing;
- API transport evidence missing;
- demo-soak/final review incomplete;
- stop-health hazard;
- recovery invariant;
- structural broker drift;
- legal/risk acknowledgement missing.

A blocked release is not a defect merely because trading does not start.

## 7. Trading-loss complaint handling

Do not debate whether the EA "should have won."

Respond with the evidence needed to establish whether there was:
1. expected market loss within configured risk;
2. user configuration/override issue;
3. broker execution/slippage issue;
4. software defect;
5. unauthorized/tampered build.

GPT_EA is a trading tool, not a guarantee of profit or wealth. The customer controls whether to approve setups, funding, leverage, broker choice, risk and live deployment.

Never promise reimbursement for ordinary trading losses unless a separate written commercial agreement expressly provides it.

## 8. Security incident handling

If an API key was exposed:
1. revoke/delete it immediately;
2. create a replacement;
3. remove exposed presets/logs;
4. review API usage.

If a GPT_EA build/license is suspected stolen or modified:
1. record release hash/version;
2. suspend support for the unverified build;
3. verify artifact identity;
4. rotate/revoke license credentials where available;
5. preserve evidence for enforcement.

## 9. Escalation package

Engineering escalation should include:
- reproducible steps;
- demo/real status;
- exact release SHA/version;
- EX5 hash if available;
- broker/server/symbol;
- relevant redacted logs;
- timestamps;
- screenshots with secrets removed;
- expected versus actual behavior;
- severity.

## 10. Closure criteria

Close an issue only when one of the following is documented:
- fixed and customer retested;
- configuration corrected;
- upstream/broker issue identified;
- expected behavior explained;
- unsupported/tampered build identified;
- customer declined further troubleshooting;
- issue escalated to engineering/legal/security.

Never mark a safety-critical issue resolved solely because trading resumed.
