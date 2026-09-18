<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-001 · Fail-Closed New-Entry Governance

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_001_FAIL_CLOSED_NEW_ENTRY_GOVERNANCE.md`

---

# ADR-001: Fail-Closed New-Entry Governance

**ADR ID:** ADR-001  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

GPT_EA depends on market data, broker capability, recovery state, API/news intelligence, release evidence, legal acknowledgements and privacy approval. Treating missing mandatory evidence as implicit approval could create unbounded operational risk.

## ✅ Decision

New REAL-account entries must default to blocked whenever a mandatory gate is missing, stale, contradictory or explicitly failed. WAIT/HOLD/NO-GO is preferred over guessing.

## 🧠 Rationale

This preserves deterministic control when AI, data, infrastructure or evidence is uncertain. It also prevents a green-looking UI or source-code presence from being interpreted as release authorization.

## ⚖️ Consequences

- More false negatives are acceptable: some legitimate trades will be skipped.
- Operators must resolve evidence/state rather than bypass a gate.
- Existing-position management is governed separately and remains active.

## 🔀 Alternatives considered

- Fail open on infrastructure/evidence uncertainty — rejected because it converts uncertainty into financial authorization.
- Let GPT decide whether to ignore a failed gate — rejected because AI is not the final safety authority.

## 🔗 Implementation / evidence hooks

- `ReleaseSafetyAllows*` chain.
- `ReleaseEvidenceAllows` and stop/recovery gates.
- `RELEASE_GO_NO_GO.md`.
- `RELEASE_TRUTH_DASHBOARD.md`.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
