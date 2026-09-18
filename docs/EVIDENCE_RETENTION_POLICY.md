<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🗄️ Evidence Retention & Disposal

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🗄️ **Document:** `EVIDENCE_RETENTION_POLICY.md`

---
# 🗄️ Evidence Retention Policy

This policy defines release/support evidence categories and retention triggers. Final legal periods must be reviewed for each jurisdiction.

## Principles

- retain what is needed to prove release identity, safety testing, customer acceptance and incident response;
- retain secrets **never**;
- use purpose-based categories rather than indefinite storage;
- legal hold overrides ordinary deletion while the hold remains valid;
- deletion should include accessible copies/backups according to the documented lifecycle.

## Retention classes

| Class | Examples | Default policy |
|---|---|---|
| R1 Release identity | Git SHA, EX5 hash, compile record, final review | long-lived with certified release |
| R2 Validation | tester/matrix/recovery/stop/smoke/drill evidence | retain with release lifecycle |
| R3 Soak/operations | five-day soak logs, drift evidence | retain with certified candidate and incident needs |
| R4 Contractual | license, risk acknowledgement, privacy sign-off | counsel-approved contract/limitation period |
| R5 Support | redacted logs/tickets | shortest period consistent with support/legal need |
| R6 Incident/security | incident evidence, compromise timeline | incident/legal retention schedule |
| R7 Temporary debug | raw debug traces | shortest practical period |
| X Secrets | API keys, MT5 passwords, card data, private signing keys | **do not retain; purge/rotate on discovery** |

## Release deletion rule

A superseded release may be removed from hot storage only after the replacement release is independently archived, rollback no longer requires the old package, no open incident/legal hold exists, and contractual/regulatory retention is satisfied.

## Legal hold

1. suspend normal deletion for affected evidence;
2. document hold scope/date/owner;
3. restrict access;
4. do not expand collection beyond the hold purpose;
5. resume disposal only after authorized hold release.

## Secret discovery

1. revoke/rotate the credential;
2. quarantine the artifact;
3. create a redacted replacement if evidence is required;
4. purge accessible secret-bearing copies where feasible;
5. document the incident without reproducing the secret.

## Required retention register

For each evidence class record owner, purpose, storage location, access role, retention trigger, disposal method, legal-hold handling and jurisdiction notes.

> 🗄️ **Default:** if evidence no longer has a legitimate release, support, contractual, security or legal purpose, do not retain it indefinitely.
