<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-006 · Versioned Legal, Risk and Privacy Approvals

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_006_VERSIONED_LEGAL_RISK_PRIVACY_ACK.md`

---

# ADR-006: Versioned Legal, Risk and Privacy Approvals

**ADR ID:** ADR-006  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

Customer acceptance can become stale when terms, risk language, processing practices or jurisdiction requirements materially change.

## ✅ Decision

Legal/risk acknowledgements and privacy sign-off use explicit schema/terms versions and evidence digests. REAL-account authorization requires current matching versions; privacy approval must match the customer's jurisdiction.

## 🧠 Rationale

This prevents indefinite reuse of stale acceptance and makes commercial governance auditable without pretending contractual terms can waive non-waivable law.

## ⚖️ Consequences

- Material policy changes may require re-acknowledgement/re-sign-off.
- Jurisdiction rollout requires counsel review.
- Evidence retention must itself be privacy-reviewed.

## 🔀 Alternatives considered

- One permanent 'I agree' flag — rejected because it cannot prove version/context.
- Jurisdiction-agnostic privacy approval — rejected because obligations vary.

## 🔗 Implementation / evidence hooks

- `GPT_EA_Part38_LegalLicenseGate.mqh`.
- `GPT_EA_Part39_CustomerRiskAcknowledgement.mqh`.
- `GPT_EA_Part40_PrivacyReleaseGate.mqh`.
- legal/privacy evidence templates.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
