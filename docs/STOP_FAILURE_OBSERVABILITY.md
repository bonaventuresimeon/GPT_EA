<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ Execution Safety & Recovery

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🛡️ **Document:** `STOP_FAILURE_OBSERVABILITY.md`

---

# GPT_EA Stop-Failure Observability

This file is the release-document index for protective-stop observability.

Authoritative schema/behavior contract:

- `STOP_FAILURE_OBSERVABILITY_CONTRACT.md`

Release-blocking validation matrix:

- `STOP_OBSERVABILITY_TEST_MATRIX.md`

Related broker and stop-management policies:

- `BROKER_STOP_FAILURE_POLICY.md`
- `STOP_UPDATE_FAILURE_POLICY.md`
- `STOP_MANAGEMENT_TEST_MATRIX.md`
- `PARTIAL_PROTECTION_RELEASE_TEST.md`

Runtime implementation:

- `GPT_EA_Part18_StopBrokerObservability.mqh`
- `GPT_EA_Part14_StopFailurePolicy.mqh`
- `GPT_EA_Part13_AdvancedPositionManager.mqh`

Runtime stop-health file:

- `GPT_EA_StopFailures.csv`
- schema: `stop_failure_observability_v2`

The v2 schema adds stable numeric class/action codes, quote age, broker trade/execution state, next retry time, explicit partial-protection lifecycle events, stop-recovery events and emergency-close attempts/failures.

The live release attestation in `GPT_EA_Part28_ReleaseCertification.mqh` must not be marked passed until the applicable stop-observability, broker stop-policy and partial-protection tests have evidence archived.
