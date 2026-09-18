<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🔏 Signed Commercial Licensing Architecture

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🔏 **Document:** `SIGNED_LICENSE_ARCHITECTURE.md`

---
# 🔏 Signed Commercial Licensing Architecture

This is the production licensing target. Runtime integration should occur only after the current feature-frozen candidate completes its compile/evidence cycle.

## Entitlement model

```text
Purchase / renewal
  ↓
License service
  ↓
Signed entitlement
  ├─ license_id
  ├─ product / release scope
  ├─ permitted account/server scope
  ├─ issued_at / expires_at
  ├─ offline_grace_until
  ├─ entitlement_version
  └─ signature
  ↓
GPT_EA verifies with embedded PUBLIC key only
```

## Security rules

- private signing key never ships in EX5/source/customer package;
- customer terminal stores only entitlement + public verification material;
- entitlement signature covers every authorization field;
- revoked/expired/invalid entitlement blocks **new entries only**;
- existing positions remain protected/managed;
- network/license outage may use a short, explicit offline grace period;
- replay protection uses version/expiry/scope and server-side revocation state;
- account/server binding is privacy-minimized;
- no OpenAI key or MT5 password is part of licensing.

## Required entitlement states

VALID, GRACE, EXPIRED, REVOKED, INVALID_SIGNATURE, SCOPE_MISMATCH, UNAVAILABLE.

Only VALID (and policy-approved GRACE) can permit new-risk licensing. REVOKED/EXPIRED/INVALID_SIGNATURE/SCOPE_MISMATCH fail closed.

## Rollout sequence

1. define entitlement schema and signing algorithm;
2. isolate private signing keys in a controlled signing service/HSM or equivalent;
3. implement verifier in shadow/demo;
4. test expiry/revocation/replay/offline cases;
5. security review;
6. new ADR if licensing changes release semantics;
7. fresh compile/evidence cycle before production.

> 🔏 **Rule:** a license check is an authorization gate, never a mechanism for destructive behavior.
