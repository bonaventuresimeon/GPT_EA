<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧊 Release Candidate Feature Freeze

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧊 **Document:** `FEATURE_FREEZE_RELEASE_POLICY.md`

---
# 🧊 Release Candidate Feature Freeze

Once a candidate enters compile/evidence validation, executable feature work is frozen until that candidate is released or abandoned.

## Freeze boundary

The freeze applies to `GPT_EA.mq5`, production presets, release/runtime gate semantics, API transport behavior, risk/stop/recovery behavior and any model/strategy change that can alter authorization or orders.

Documentation and non-executable validation tooling may continue only when they do not change runtime semantics.

## Candidate record

```text
Release candidate ID:
Git SHA:
Branch/tag:
Release validation ID:
Freeze timestamp UTC:
Freeze owner:
MetaEditor build:
MT5 build:
```

## Allowed during freeze

Only release-blocking fixes are allowed. Any executable fix creates a new candidate SHA and invalidates stale compile/EX5/test/soak evidence as applicable.

## Prohibited during freeze

- new trading strategies or indicators;
- silent parameter tuning;
- changed risk defaults;
- changed stop/partial logic;
- changed broker/execution behavior;
- changed model policy that can alter authorization;
- editing source after certified compile without restarting evidence.

## Exit

Freeze ends only when the candidate is **GO and archived** or **abandoned/HOLD/NO-GO**.

> 🧊 **Rule:** changed executable source means a new release candidate and a new evidence cycle.
