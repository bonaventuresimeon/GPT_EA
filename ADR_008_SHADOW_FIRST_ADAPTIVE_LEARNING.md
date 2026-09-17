<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-008 · Shadow-First Adaptive Learning

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_008_SHADOW_FIRST_ADAPTIVE_LEARNING.md`

---

# ADR-008: Shadow-First Adaptive Learning

**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance

## 🎯 Context

Execution learning, champion/challenger logic and adaptive risk can improve research, but an unvalidated learner changing live behavior can create hidden strategy drift.

## ✅ Decision

Adaptive/challenger changes are evaluated in shadow/research mode first. Promotion to live behavior requires explicit evidence and release approval; no silent model/strategy auto-promotion is allowed.

## 🧠 Rationale

This separates research feedback from production authority and keeps live behavior reviewable.

## ⚖️ Consequences

- Adaptation is slower than fully online self-modifying systems.
- More evidence and sample-size discipline are required before promotion.

## 🔀 Alternatives considered

- Continuous self-modifying live strategy — rejected because it undermines reproducibility and certification.
- Ignore post-trade learning entirely — rejected because useful evidence would be lost.

## 🔗 Implementation / evidence hooks

- Parts 30–35 adaptive stack.
- champion/challenger and execution-learning matrices.
- release gates for adaptive portfolio/execution learning/champion-challenger.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
