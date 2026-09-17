# GPT_EA Customer Release-Readiness Checklist

Use this checklist before distributing a customer build or authorizing a customer for live use.

## A. Build identity

- [ ] Exact Git SHA recorded.
- [ ] Exact release ID recorded.
- [ ] EX5 built from the intended source.
- [ ] MetaEditor compile: 0 errors.
- [ ] Production warnings reviewed/resolved.
- [ ] EX5 SHA-256 archived.
- [ ] Certified SET SHA-256 archived or explicit NONE.
- [ ] No secret/API key exists in source, release package or preset.

## B. Core release evidence

- [ ] Strategy Tester validation complete.
- [ ] Intelligence matrix complete.
- [ ] Broker/symbol matrix complete for intended deployment.
- [ ] Recovery matrix complete.
- [ ] Stop-management matrix complete.
- [ ] Broker stop-failure policy complete.
- [ ] Partial-protection tests complete.
- [ ] Stop observability complete.
- [ ] API transport matrix complete.
- [ ] Demo-soak acceptance complete.
- [ ] Final GO/NO-GO review complete.
- [ ] Machine-readable evidence validators PASS.

## C. Customer package

- [ ] GPT_EA.ex5 or approved source package included.
- [ ] INSTALLATION.md included.
- [ ] USER_INSTALLATION_GUIDE.md included.
- [ ] FIRST_RUN_CHECKLIST.md included.
- [ ] API_KEY_TROUBLESHOOTING.md included.
- [ ] CUSTOMER_SUPPORT_RUNBOOK.md available to support team.
- [ ] Trading risk disclosure included.
- [ ] Commercial license included.
- [ ] Terms and conditions included.
- [ ] Anti-piracy/license policy included.
- [ ] Clean preset contains blank API-key/token fields.
- [ ] Release notes identify version, hash and known limitations.

## D. Customer API setup

- [ ] Customer uses their own funded OpenAI API account.
- [ ] Customer creates their own secret API key.
- [ ] Customer is told never to share the key.
- [ ] WebRequest allow-list instructions are included.
- [ ] Supported model IDs are documented.
- [ ] Astra is described as higher-cost maximum-intelligence option, not mandatory.
- [ ] ChatGPT subscription and API billing are clearly distinguished.

## E. Licensing / anti-theft

- [ ] Customer receives a unique license reference where commercial licensing is enabled.
- [ ] License is non-transferable unless the written license permits transfer.
- [ ] Redistribution/resale restrictions are included.
- [ ] Reverse-engineering restrictions are included to the extent permitted by law.
- [ ] Circumvention/tamper restrictions are included.
- [ ] Customer does not receive vendor secrets/private signing keys.
- [ ] Source code is not distributed unless the purchased license includes source rights.
- [ ] Any account/device binding is disclosed and privacy-minimized.
- [ ] License revocation/suspension procedure is documented.

## F. Legal acknowledgement

Before live use:
- [ ] Customer has access to COMMERCIAL_LICENSE.md.
- [ ] Customer has access to TERMS_AND_CONDITIONS.md.
- [ ] Customer has access to TRADING_RISK_DISCLOSURE.md.
- [ ] Customer understands no profit/wealth is promised.
- [ ] Customer accepts responsibility for trading decisions, leverage, capital and broker choice.
- [ ] Customer understands losses, including loss of all deposited trading capital, are possible.
- [ ] Customer understands software/AI output can be wrong or unavailable.
- [ ] Required in-EA legal/risk acknowledgement is completed for real-account arming.
- [ ] Customer jurisdiction has a completed `JURISDICTION_LEGAL_REVIEW_CHECKLIST.md` review.
- [ ] Customer risk acknowledgement is bound to the current terms version and acknowledgement schema.
- [ ] Machine-readable customer acknowledgement record validates successfully.

## G. First-run support readiness

- [ ] Support intake template ready.
- [ ] Escalation contacts assigned.
- [ ] Security incident procedure ready.
- [ ] Known broker limitations documented.
- [ ] Known API limitations documented.
- [ ] No support workflow asks for API keys or MT5 passwords.

## H. Customer first run

- [ ] Customer starts on demo.
- [ ] FIRST_RUN_CHECKLIST completed.
- [ ] OpenAI request succeeds on demo.
- [ ] Required market data is synchronized.
- [ ] Approval workflow tested.
- [ ] Restart/recovery tested.
- [ ] No secrets appear in logs.
- [ ] No critical startup errors remain.

## I. Live authorization

- [ ] Exact certified build still matches.
- [ ] Deployment identity still matches.
- [ ] Legal/risk acknowledgement still valid.
- [ ] Human approval remains enabled for initial rollout.
- [ ] Conservative initial risk selected.
- [ ] No unresolved critical defect/security issue.
- [ ] Customer understands GO does not mean guaranteed profitability.

Customer release decision: **GO / HOLD / NO-GO**
