<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Validation & Quality Assurance

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧪 **Document:** `R6_RESILIENCE_HARDENING_TEST_MATRIX.md`

---

# GPT_EA R6 Resilience Hardening Acceptance Matrix

Schema: `resilience_hardening_evidence_v1`.

Copy this file to `artifacts/r6-resilience-matrix.md`. Every RH row must be changed from HOLD to literal **PASS** and contain a concrete evidence/reference before the machine evidence may be finalized.

| ID | Domain | Mandatory acceptance condition | Status | Evidence/reference |
|---|---|---|---|---|
| RH-001 | Direct breakout | `SETUP_BREAKOUT=3` preserves old enum values and direct candidate uses it | HOLD | |
| RH-002 | Direct breakout | STRATEGY_BREAKOUT refuses BRT setup kind | HOLD | |
| RH-003 | Direct breakout | STRATEGY_BREAKOUT_RETEST refuses direct breakout setup kind | HOLD | |
| RH-004 | Direct breakout | Recovery/comment inference preserves direct BO vs BRT | HOLD | |
| RH-005 | Intent ledger | PREPARED intent is durably written before submission | HOLD | |
| RH-006 | Exactly once | SENT is persisted before broker network call | HOLD | |
| RH-007 | Exactly once | Duplicate/restart execution cannot resubmit unresolved SENT/UNCERTAIN intent | HOLD | |
| RH-008 | Exactly once | Matching broker nonce, or strict magic+symbol+time+side+volume fallback when a broker strips the comment, reconstructs FILLED/CLOSED state without retry | HOLD | |
| RH-009 | Ambiguous failure | CTrade failure remains UNCERTAIN until broker reconciliation | HOLD | |
| RH-010 | Broker reconciliation | Orphan EA position/lifecycle mismatch is detected | HOLD | |
| RH-011 | Broker reconciliation | Unexpected EA pending order is detected | HOLD | |
| RH-012 | Broker reconciliation | Unexpected external/manual exposure on configured symbol is detected | HOLD | |
| RH-013 | Broker reconciliation | Unexplained volume increase/reduction is detected and quarantined | HOLD | |
| RH-014 | Broker reconciliation | Unexplained SL/TP modification is detected and quarantined | HOLD | |
| RH-015 | Manual intervention | CLIENT/MOBILE/WEB intervention marks position and quarantines learning | HOLD | |
| RH-016 | Provenance | Raw Responses URL annotations are extracted and persisted | HOLD | |
| RH-017 | Provenance | High-risk intelligence without authoritative source annotation hard-fails | HOLD | |
| RH-018 | Freshness | Invalid/stale/future `as_of_utc` blocks high-confidence intelligence | HOLD | |
| RH-019 | Freshness | Hard provenance/timestamp failure cannot be rescued by legacy fallback | HOLD | |
| RH-020 | Clock | Broker-server/GMT offset baseline and drift protection work | HOLD | |
| RH-021 | Model health | Transport/schema/stale/provenance/disagreement/latency telemetry is recorded | HOLD | |
| RH-022 | Model health | NORMAL → REDUCED_TRUST → DETERMINISTIC_ONLY thresholds work | HOLD | |
| RH-023 | Deterministic fallback | Only allowed strategies run in deterministic-only mode and news proximity blocks them | HOLD | |
| RH-024 | Data versioning | Execution-learning V2 rows carry release/config/model/symbol/strategy versions | HOLD | |
| RH-025 | Data versioning | Shadow/lifecycle/decision/strategy-health V2 rows carry generation fields | HOLD | |
| RH-026 | Strategy registry | Versioned per-strategy registry is emitted and tied to config fingerprint | HOLD | |
| RH-027 | Quarantine | Manual/broker/connection/chaos/storage/config anomalies enter QUARANTINED_DATA | HOLD | |
| RH-028 | Quarantine | Quarantined samples cannot update confidence/event/expiry/MAE-MFE learning | HOLD | |
| RH-029 | Quarantine | Quarantined samples cannot update strategy historical evidence | HOLD | |
| RH-030 | Promotion | Challenger needs sample/PF/DD/stability plus statistical lower-bound advantage | HOLD | |
| RH-031 | Promotion rollback | Newly promoted challenger rolls back during bad probation | HOLD | |
| RH-032 | Promotion rollback | Rolled-back challenger cannot immediately re-promote without new samples | HOLD | |
| RH-033 | Stress | Portfolio scenario shock blocks excess stressed-equity loss | HOLD | |
| RH-034 | Gap risk | Proposed gap/scenario loss multiple of planned stop risk is bounded | HOLD | |
| RH-035 | Margin stress | Stressed margin level must remain above configured floor | HOLD | |
| RH-036 | Decision half-life | Strategy-specific stale candidate is blocked | HOLD | |
| RH-037 | Latency | Analysis/approval/model/SENT/ack/fill timeline is recorded | HOLD | |
| RH-038 | Latency | Learned execution latency exceeding strategy budget blocks entry | HOLD | |
| RH-039 | Storage | Critical ledger/heartbeat write failure blocks new exposure and marks open managed positions for learning quarantine | HOLD | |
| RH-040 | Configuration drift | REAL runtime config fingerprint must equal certified fingerprint | HOLD | |
| RH-041 | Causal attribution | Post-trade cause classification writes one finalized cause per closed position | HOLD | |
| RH-042 | Chaos | Fault injection categorically refuses REAL accounts | HOLD | |
| RH-043 | Chaos | API timeout/stale quote/storage failure injections fail closed | HOLD | |
| RH-044 | Chaos | Pre-send ambiguous and post-fill/pre-bind crash-window tests reconcile without duplicate | HOLD | |
| RH-045 | Chaos | Missing/duplicate trade-transaction callback tests are idempotent | HOLD | |
| RH-046 | Chaos | Stop-modification and corrupt-checkpoint injections trigger safe failure paths | HOLD | |
| RH-047 | Rollback | Previous certified release rollback ZIP builds with manifest/file hashes | HOLD | |
| RH-048 | Rollback | Independent rollback package validator detects tampering/missing files | HOLD | |

## Acceptance rule

All RH-001 through RH-048 are mandatory for the current hardening generation. The matrix itself is SHA-256 bound into the machine evidence. A single HOLD/FAIL, blank evidence reference, matrix edit after finalization, candidate mismatch, configuration-fingerprint mismatch, or unresolved critical finding keeps the release at HOLD.
