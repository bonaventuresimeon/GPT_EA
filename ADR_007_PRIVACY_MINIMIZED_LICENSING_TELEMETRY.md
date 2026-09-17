<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-007 · Privacy-Minimized Licensing and Telemetry

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_007_PRIVACY_MINIMIZED_LICENSING_TELEMETRY.md`

---

# ADR-007: Privacy-Minimized Licensing and Telemetry

**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance

## 🎯 Context

Licensing, support and telemetry can easily become a channel for collecting unnecessary financial identifiers or customer secrets.

## ✅ Decision

Licensing/support must use the minimum identifiers needed. OpenAI API keys, MT5 passwords, card credentials and private signing keys are excluded from ordinary collection. Central telemetry is disabled unless specifically reviewed/approved.

## 🧠 Rationale

Data minimization reduces breach impact and simplifies legal/compliance obligations while preserving the evidence needed for licensing and support.

## ⚖️ Consequences

- Some diagnostics may require customer-provided redacted evidence.
- Telemetry features require explicit privacy review before rollout.

## 🔀 Alternatives considered

- Collect everything for easier support — rejected as disproportionate.
- Store API keys centrally for convenience — rejected as unnecessary secret custody.

## 🔗 Implementation / evidence hooks

- `PRIVACY_DATA_RETENTION_REVIEW.md`.
- R10 telemetry state `DISABLED` / `APPROVED`.
- support runbook and anti-piracy policy.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
