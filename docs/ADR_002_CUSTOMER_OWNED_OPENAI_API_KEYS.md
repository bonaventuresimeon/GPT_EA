<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-002 · Customer-Owned OpenAI API Keys

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_002_CUSTOMER_OWNED_OPENAI_API_KEYS.md`

---

# ADR-002: Customer-Owned OpenAI API Keys

**ADR ID:** ADR-002  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

Customers need GPT-assisted analysis without sharing one vendor API credential across unrelated terminals or exposing a vendor master key inside distributable EA binaries.

## ✅ Decision

Standard deployment uses each customer's own funded OpenAI API account and secret key, entered locally in MT5. Direct mode sends it only to the approved OpenAI origin. Proxy mode remains optional for separately designed centralized deployments.

## 🧠 Rationale

Customer-owned credentials isolate billing/quota, reduce blast radius, avoid embedding a shared secret in the EA, and make support boundaries clearer.

## ⚖️ Consequences

- Customers must manage API billing, limits and credential rotation.
- Vendor presets must keep secret fields blank.
- Support must never request the key.

## 🔀 Alternatives considered

- Vendor-wide shared key in EX5 — rejected due to extraction, abuse and billing risk.
- Mandatory proxy for every customer — rejected as unnecessary complexity for standard deployments.

## 🔗 Implementation / evidence hooks

- `API_TRANSPORT_ARCHITECTURE.md`.
- `API_KEY_TROUBLESHOOTING.md`.
- `GPT_EA_Part37_APITransport.mqh`.
- `USER_INSTALLATION_GUIDE.md`.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
