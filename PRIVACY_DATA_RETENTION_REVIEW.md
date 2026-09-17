<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🔐 Privacy & Data-Retention Review

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

---

# 🔐 Privacy and Data-Retention Review

This document is a privacy-engineering and legal-review framework. It is not jurisdiction-specific legal advice. Complete it with qualified counsel before commercial rollout in each target jurisdiction.

## 🎯 Privacy principles
- **Minimize:** collect only data necessary for licensing, support, safety and evidence.
- **Separate secrets:** never collect OpenAI API keys, MT5 passwords or payment-card data merely for support/licensing.
- **Purpose-limit:** every retained field must have a documented purpose.
- **Time-limit:** define retention periods and deletion triggers.
- **Protect:** restrict access, encrypt where appropriate and avoid secret-bearing logs.
- **Explain:** customer notices must match actual processing.
- **Fail safe:** privacy controls must not weaken management of open trades.

## 🧾 Data inventory

| Data class | Example | Purpose | Default location | Secret? | Retention decision |
|---|---|---|---|---:|---|
| Release identity | Git SHA, EX5 hash, release ID | certification/audit | vendor archive | No | per release policy |
| License reference | customer license ID | entitlement/support | local/vendor license system | Sensitive | while justified |
| Account context | broker/server, masked binding | compatibility/licensing | MT5/vendor if enabled | Sensitive | minimize |
| Risk acknowledgement | terms version, jurisdiction, masked license ref | acceptance evidence | local/vendor if collected | Sensitive | counsel-approved |
| API diagnostics | HTTP status, request/trace ID | troubleshooting | MT5 logs/CSV | Usually no | short operational |
| Trading evidence | setup/execution/stop/recovery events | audit/research | MT5/release archive | Financial context | purpose-limited |
| Support records | redacted logs/messages | support | support system | May be sensitive | ticket policy |
| OpenAI API key | customer secret | API auth | customer MT5 only | **Yes** | **never vendor-retained** |
| MT5 password | customer secret | broker auth | broker/MT5 only | **Yes** | **never collect** |
| Card/payment secret | payment auth | processor | payment processor | **Yes** | **never store in GPT_EA** |

## 🚫 Prohibited collection by default
- OpenAI API keys.
- MT5 master/investor passwords.
- payment-card details.
- seed phrases/private crypto keys.
- unnecessary identity documents.
- unrestricted account statements.
- unredacted secret-bearing `.set` files.

## ⏳ Retention schedule template

Final periods must be approved per jurisdiction and business need.

| Record | Category | Trigger | Deletion/archival rule |
|---|---|---|---|
| API health diagnostics | short operational | creation | delete after troubleshooting/operational window |
| Customer support tickets | support/legal | closure | retain only for defined support/legal period |
| Risk acknowledgement evidence | contractual | acceptance/termination | retain for counsel-approved contract/limitation period |
| Release evidence | engineering/legal | release retirement | long-term integrity archive where justified |
| Demo-soak/test evidence | engineering | certification | retain with certified release |
| License records | contractual | expiry/termination | retain only as legally/business justified |
| Raw debug logs | temporary | creation | shortest practical period |
| Secrets accidentally logged | incident | discovery | purge immediately and rotate secret |

## 🧹 Deletion triggers
- expired operational usefulness;
- valid customer deletion request where applicable;
- license closure plus retention expiry;
- accidental secret exposure;
- superseded debug artifacts with no audit need;
- jurisdictional requirement.

## 🔒 Security controls
- least-privilege access;
- role-based support access;
- encryption in transit;
- encryption at rest for centralized sensitive records;
- audit access to contractual acknowledgement records;
- redaction before logs enter support systems;
- no secrets in analytics;
- credential rotation after exposure;
- signed/hash-bound release evidence;
- documented incident response.

## 🌍 Cross-border review

Before centralizing customer data, counsel should review controller/processor roles, lawful basis or consent, international transfers, subprocessors, hosting region, data-subject rights, breach notification and regulator obligations.

Use `JURISDICTION_LEGAL_REVIEW_CHECKLIST.md` for market-by-market approval.

## 👤 Customer-rights workflow
Where applicable, define access, correction, deletion, restriction/objection, portability, consent withdrawal and complaint/escalation procedures.

## 📊 Telemetry policy

Any future centralized telemetry should be opt-in or otherwise lawfully justified, documented and privacy-minimized.

Preferred telemetry: release/version, anonymized event counts, non-secret error class, API status class and health/recovery state.

Avoid raw prompts, full account identifiers, full trade history or personal data unless necessary, disclosed and legally approved.

## 🧯 Privacy incident response
1. Contain exposure.
2. Rotate/revoke exposed credentials.
3. Identify affected records/users.
4. Preserve non-secret forensic evidence.
5. Assess notification duties.
6. Notify affected users/regulators where required.
7. Purge exposed secrets from accessible logs/repositories.
8. Correct root cause.
9. Document closure and prevention.

## ✅ Privacy release checklist
- [ ] Data inventory complete.
- [ ] Every field has a purpose.
- [ ] Retention periods approved.
- [ ] Customer notice matches actual processing.
- [ ] Support never requests API/MT5 secrets.
- [ ] Risk-ack evidence is privacy-minimized.
- [ ] Cross-border processing reviewed.
- [ ] Deletion workflow tested.
- [ ] Incident procedure assigned.
- [ ] Legal counsel reviewed target jurisdiction.
- [ ] No new telemetry enabled without review.

---

> 🔐 **Default:** if data is not needed for safety, licensing, support or lawful evidence, do not collect it.
