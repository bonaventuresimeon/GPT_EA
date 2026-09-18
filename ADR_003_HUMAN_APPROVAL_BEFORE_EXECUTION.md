<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-003 · Human Approval Before Execution

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_003_HUMAN_APPROVAL_BEFORE_EXECUTION.md`

---

# ADR-003: Human Approval Before Execution

**ADR ID:** ADR-003  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

GPT_EA can classify and rank setups, but automated analysis can be wrong and trading decisions have financial consequences.

## ✅ Decision

Human APPROVE / DENY remains a first-class execution gate for protected rollout. A high-confidence setup is a candidate, not an instruction to trade.

## 🧠 Rationale

This preserves user agency and creates a final explicit control point after analysis and before broker execution.

## ⚖️ Consequences

- Some opportunities may expire while awaiting approval.
- Pending approval must be stale-safe and revalidated before execution.

## 🔀 Alternatives considered

- Fully autonomous live execution by default — rejected for the protected commercial rollout.
- Approval before analysis only — rejected because final market state can change after approval.

## 🔗 Implementation / evidence hooks

- approval UI/event flow.
- strict pre-entry revalidation.
- first-run/customer documentation.
- release GO condition requiring approval initially.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
