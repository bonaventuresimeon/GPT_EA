<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-005 · Evidence-Bound Production Releases

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_005_EVIDENCE_BOUND_RELEASES.md`

---

# ADR-005: Evidence-Bound Production Releases

**ADR ID:** ADR-005  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

Checkboxes and source presence do not establish which binary was compiled, tested, soaked or approved. A release must remain traceable across source, EX5, preset, broker/deployment and final review.

## ✅ Decision

Production GO is bound to exact Git SHA, EX5 SHA-256, SET SHA-256/NONE, build identities, validator outputs, soak evidence, deployment identity and final review. Material source/environment changes invalidate the relevant evidence.

## 🧠 Rationale

This makes release claims auditable and crash/restart/operator resistant. It also prevents stale test evidence from being reused for a changed artifact.

## ⚖️ Consequences

- Release work is more rigorous and slower.
- Every executable change requires a fresh compile/evidence cycle.
- Evidence tooling must never synthesize external PASS results.

## 🔀 Alternatives considered

- Human checkbox-only release — rejected as too easy to drift.
- Latest-build implicit certification — rejected because 'latest' is not identity.

## 🔗 Implementation / evidence hooks

- `RELEASE_EVIDENCE_TEMPLATE.json`.
- `COMPILE_EVIDENCE_TEMPLATE.json`.
- `RELEASE_EVIDENCE_PACK.md`.
- R10 release/final validators.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
