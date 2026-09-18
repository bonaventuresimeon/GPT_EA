<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR-004 · Preserve Existing-Position Safety During New-Entry Blocks

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_004_EXISTING_POSITION_SAFETY_DURING_BLOCKS.md`

---

# ADR-004: Preserve Existing-Position Safety During New-Entry Blocks

**ADR ID:** ADR-004  
**Status:** Accepted  
**Decision date:** 2026-09-18  
**Scope:** GPT_EA architecture and release governance
**Supersedes:** None  
**Superseded by:** None

## 🎯 Context

License, legal, privacy, release, API or deployment gates can become blocked while positions are already open. Treating a governance block as permission to stop management could increase customer loss.

## ✅ Decision

Any governance/release/license/privacy failure may block new entries but must not intentionally remove SL/TP, disable stop repair, open punitive trades, or abandon normal safe management/closure of existing GPT_EA positions.

## 🧠 Rationale

Safety obligations for an existing position are different from authorization to add new market risk.

## ⚖️ Consequences

- Runtime layers need separate new-entry and existing-position behavior.
- Anti-piracy controls cannot be implemented as destructive kill switches.

## 🔀 Alternatives considered

- Disable the EA completely on license/privacy failure — rejected because it can strand positions.
- Punitive close/open actions — rejected as unsafe and inappropriate.

## 🔗 Implementation / evidence hooks

- R8/R9/R10 wrappers.
- stop/recovery modules.
- `ANTI_PIRACY_LICENSE_ENFORCEMENT.md`.
- privacy/legal sign-off contracts.

## 🔄 Supersession rule

A future design that materially reverses this decision must introduce a new ADR and explicitly mark this ADR as superseded.

---

> 🏛️ **Decision integrity:** this ADR explains architecture; it does not independently certify a release.
