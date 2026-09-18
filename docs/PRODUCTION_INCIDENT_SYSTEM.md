<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚨 Production Incident System

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚨 **Document:** `PRODUCTION_INCIDENT_SYSTEM.md`

---
# 🚨 Production Incident System

Incidents are recorded as evidence-bearing operational events. Ordinary trading losses are not automatically software incidents.

## Severity

| Severity | Examples | Immediate action |
|---|---|---|
| P0 | duplicate order, missing/unrepairable SL, release bypass, exposed key, tampered binary, corrupted recovery affecting open position | block new risk, preserve protection, rotate secrets, escalate immediately |
| P1 | contained live degradation, repeated broker/API failures, recovery warning with no immediate capital hazard | move testing to demo/HOLD, investigate |
| P2 | functional/configuration defect | triage/support |
| P3 | documentation/usage question | normal support |

## Incident ID

Use `GPT-EA-INC-YYYYMMDD-NNNN` and bind it to release SHA/EX5 hash, broker/server, timestamps, severity and redacted evidence.

## Evidence bundle

- incident metadata;
- redacted Experts/Journal excerpts;
- release identity/hash;
- broker order/deal references;
- recovery/stop state;
- relevant API request IDs;
- timeline;
- containment/remediation;
- root cause and follow-up tests.

Never include OpenAI keys, MT5 passwords, payment data or private signing keys.

## Closure

P0/P1 closes only after root cause or external cause is established, safety controls are restored, affected evidence is archived and required regression tests pass.

> 🚨 **Rule:** protect capital first, preserve evidence second, resume new risk only after the blocking condition is resolved.
