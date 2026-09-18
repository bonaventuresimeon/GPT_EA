<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 📊 Operator Runtime Dashboard

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 📊 **Document:** `OPERATOR_DASHBOARD.md`

---
# 📊 Operator Runtime Dashboard

The operator surface should summarize system health without implying profitability.

## Status tiles

| Tile | PASS | WATCH | BLOCK |
|---|---|---|---|
| Market | synchronized/fresh | thin/volatile | stale/disconnected |
| Strategy | valid current plan | developing/conflict | invalid/no setup |
| GPT | available/validated | degraded/backoff | required intelligence unavailable |
| News | clear/current | watch | blocking event/stale required feed |
| Risk | within limits | near threshold | cap/drawdown/daily block |
| Stops | protected | retrying | unprotected/critical |
| Recovery | reconciled | recovering | invariant failure |
| License | valid/grace | nearing expiry | invalid/revoked/scope mismatch |
| Privacy | approved | review due | missing/mismatch/critical finding |
| Release | PASS | HOLD | NO-GO |
| Broker | compatible | degraded | unsupported/OrderCheck block |
| Approval | ready | awaiting user | stale/denied |

## Rules

- dashboard is observability only; it does not override gates;
- WATCH must never be rendered as PASS;
- BLOCK reason must link to evidence/log context;
- secrets are never shown;
- existing-position protection status remains visible even when new entries are blocked.

> 📊 **Design principle:** one screen should explain why GPT_EA is READY, WATCHING or BLOCKED without hiding uncertainty.
