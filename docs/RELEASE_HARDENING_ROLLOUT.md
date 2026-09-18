<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚀 Commercial Release Hardening Rollout

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚀 **Document:** `RELEASE_HARDENING_ROLLOUT.md`

---
# 🚀 Release Hardening Rollout

This document sequences the hardening work without adding new trading features during feature freeze.

## Sequence

1. 🧊 Freeze exact candidate SHA.
2. 🛠️ Real MetaEditor compile + compile evidence.
3. 🚦 Release-candidate smoke test.
4. 💾 Fail-closed recovery drill.
5. 🧪 Controlled demo validation harness.
6. 🛡️ Security threat-model review + secret scan.
7. 🌊 Existing matrix/five-day soak evidence.
8. 🔏 Signed-license implementation only in a **new candidate** after current frozen candidate is resolved.
9. 📦 Reproducible customer package from PASS evidence.
10. ✅ Final GO/NO-GO and immutable evidence archive.

## Why licensing runtime is deferred

Adding cryptographic entitlement verification to the current candidate would change executable behavior and invalidate the very compile/evidence cycle being prioritized. The architecture/schema can be prepared now; runtime integration belongs to the next explicitly identified candidate unless licensing is declared release-blocking.

## Current truth

Documentation/tooling presence is not PASS. MetaEditor, MT5/demo scenarios, broker behavior, soak and final review remain external evidence.

> 🚀 **Release discipline:** prove the candidate before expanding it.
