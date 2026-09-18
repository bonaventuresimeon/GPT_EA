<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏛️ ADR Supersession & Governance Policy

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏛️ **Document:** `ADR_SUPERSESSION_POLICY.md`

---

# 🏛️ ADR Supersession Rules

Architecture decisions are historical records. They may be replaced, but they must not be silently rewritten or deleted in a way that hides how GPT_EA evolved.

## ✅ Allowed statuses

- **Proposed** — under review; not yet authoritative.
- **Accepted** — current architecture decision.
- **Superseded** — replaced by one or more newer ADRs.
- **Rejected** — considered but not adopted.
- **Deprecated** — no longer recommended, with no direct replacement yet.

## 🔢 ID and numbering rules

1. ADR IDs are immutable once published.
2. IDs are never reused, even if an ADR is rejected or superseded.
3. New ADRs use the next available numeric ID.
4. Existing ADRs are never renumbered to close gaps.
5. The filename must begin with `ADR_NNN_` and the document must declare the matching `ADR-NNN`.

## 🔄 Supersession rules

A material change to an Accepted decision requires a **new ADR**.

The old ADR must then change only its governance metadata:

```text
Status: Superseded
Superseded by: ADR-NNN
```

The replacement ADR must reciprocally declare:

```text
Supersedes: ADR-OLD
```

Rules:

- supersession references must point to existing ADRs;
- reciprocal references are mandatory;
- an ADR cannot supersede itself;
- supersession cycles are prohibited;
- many-to-one or one-to-many supersession is allowed only when every relationship is explicit;
- superseded ADR files remain in the repository permanently;
- superseded ADRs remain readable from `ADR_INDEX.md`;
- a Superseded ADR may not be treated as the active architecture decision.

## 📝 Editing accepted ADRs

After an ADR is Accepted:

- spelling, formatting and broken-link corrections are allowed;
- implementation/evidence links may be appended;
- the decision, rationale and architectural intent must not be materially rewritten;
- a material policy/architecture change requires a new ADR;
- any material clarification that could alter interpretation should be recorded as a dated amendment or new ADR.

## 🚫 Prohibited history manipulation

Do not:

- delete an old ADR because it is inconvenient;
- reuse its number;
- change an old decision so it appears the new design was always intended;
- mark a decision Superseded without identifying its replacement;
- make a replacement ADR without cross-linking the older record;
- create circular supersession chains.

## 🧾 Registry contract

`ADR_REGISTRY.json` is the machine-readable index. Each record contains:

- ADR ID;
- filename;
- title;
- status;
- `supersedes`;
- `superseded_by`.

`tools/check_architecture_release_truth.py` validates file/registry/index consistency and the supersession graph.

## 🧪 Example

Old ADR:

```text
ADR ID: ADR-003
Status: Superseded
Supersedes: None
Superseded by: ADR-009
```

Replacement:

```text
ADR ID: ADR-009
Status: Accepted
Supersedes: ADR-003
Superseded by: None
```

## 🧭 Decision precedence

When ADRs conflict:

1. current **Accepted** ADRs take precedence;
2. a valid replacement explicitly supersedes the older record;
3. release/runtime safety gates still take precedence over descriptive documentation;
4. ADRs do not independently certify a release.

---

> 🏛️ **Governance principle:** replace decisions explicitly; preserve the record of how and why they changed.
