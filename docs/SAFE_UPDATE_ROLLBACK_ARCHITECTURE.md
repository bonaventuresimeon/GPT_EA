<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🔄 Safe Update & Rollback Architecture

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🔄 **Document:** `SAFE_UPDATE_ROLLBACK_ARCHITECTURE.md`

---
# 🔄 Safe Update & Rollback Architecture

Updates must never silently change certified trading/risk behavior or strand positions.

## Update contract

- version notification is informational until user/operator accepts;
- download/package identity must be verified before activation;
- new version has its own release evidence;
- risk defaults/preset changes are surfaced explicitly;
- update never overwrites customer API keys into distributed presets;
- open positions remain managed by the active certified version until a safe transition point.

## Rollback requirements

Maintain the last certified package while rollback support is active. A rollback target must include its EX5 hash, compatible preset, release evidence reference and known broker/runtime compatibility.

## Automatic HOLD

- package hash/signature mismatch;
- update is not independently certified;
- downgrade would make checkpoint/schema state unreadable;
- rollback target has known critical defect;
- active position cannot be safely migrated.

## Migration rule

State-schema changes require forward/backward compatibility testing or an explicit migration. Never assume checkpoint compatibility across releases.

> 🔄 **Rule:** update convenience is subordinate to position safety and artifact identity.
