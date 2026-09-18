<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Minimum MT5 Proof Set

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🚀 Release](RELEASE_CERTIFICATION.md) · [🧪 MT5 Evidence](MT5_VALIDATION_EVIDENCE.md)

</div>

> 🧪 **Document:** `MT5_MINIMUM_PROOF_SET.md`

---

# Minimum MT5 Proof Set

The release contract remains `mt5_validation_evidence_v2` and M5-001 through M5-053 remain mandatory. This document does **not** reduce or replace those checks. It groups them into the smallest practical proof bundles so an operator knows what must actually be captured in MT5/MetaEditor.

## MP-01 — Candidate, compile and attach safety

Covers M5-001 through M5-006.

Required proof:
- exact Git SHA, EX5 SHA-256 and SET hash/NO-SET identity;
- MetaEditor compile log with 0 errors and 0 production warnings;
- MetaEditor/MT5 build identity;
- successful demo load/init;
- symbols resolve or fail safely;
- timer/dashboard initialize;
- release remains blocked before attestations;
- attaching the EA alone submits no order.

Minimum retained artifacts: compile log, EX5 hash, Experts/Journal excerpt covering attach/init.

## MP-02 — Strategy Tester deterministic safety

Covers M5-007 through M5-009.

Required proof:
- retained Strategy Tester report;
- recorded model/date range/symbols;
- at least one representative completed run;
- zero runtime-critical errors, duplicate orders/partials, SL regressions and unprotected authorizations.

Minimum retained artifact: tester report plus validation reference.

## MP-03 — Broker, recovery and protection

Covers M5-010 through M5-022.

Required proof:
- broker/server/account/symbol profile;
- stops/freeze/tick/volume/filling/margin geometry;
- restart and reconnect reconstruction;
- primary and backup checkpoint recovery;
- stop-management and broker-stop-failure policy;
- partial protection and stop observability;
- controlled BUY and SELL lifecycle evidence;
- zero unexplained unprotected end states.

Minimum retained artifacts: broker profile/history, Experts/Journal references and stop/recovery evidence.

## MP-04 — Live API, news and provenance

Covers M5-023 through M5-030 and M5-051.

Required proof:
- MT5 WebRequest allow-list;
- GPT deep-review and live web-search/news path;
- timeout/malformed/auth/rate-limit/unavailable failure behavior;
- successful recovery after induced transport failure;
- request tracing;
- zero secret leakage;
- required intelligence failure remains fail-closed;
- raw URL annotations, authoritative-source rule and `as_of_utc` freshness.

Minimum retained artifacts: WebRequest/API evidence, web provenance journal and model-health journal.

## MP-05 — Exactly-once execution and reconciliation

Covers M5-035 through M5-045.

Required proof:
- direct breakout and breakout-retest separation;
- durable PREPARED then SENT ordering before broker submission;
- unresolved SENT/UNCERTAIN nonce cannot be resubmitted;
- ambiguous submit recovery joins positions/orders/deals without duplicates, including broker-comment truncation fallback;
- orphan/missing-lifecycle/pending/manual exposure detection;
- manual intervention quarantine;
- storage failure and config drift fail closed;
- clock-drift block;
- chaos refused on REAL;
- corrupt-checkpoint recovery remains safe.

Minimum retained artifacts: intent ledger, broker reconciliation journal, resilience runtime report and chaos matrix references.

## MP-06 — Macro, gap, margin, timing and model degradation

Covers M5-046 through M5-050.

Required proof:
- USD +1%, yields +20 bp, equity risk-off, gold ±2%, oil ±4%, volatility and correlated-gap scenarios;
- gap-loss multiple bounded;
- stressed margin above floor;
- decision half-life and learned latency invalidate stale execution;
- NORMAL → REDUCED_TRUST → DETERMINISTIC_ONLY transitions;
- deterministic-only bypass is limited to unavailable GPT/web transport for allowed strategies; available vetoes, BLOCK verdicts, stale/schema/provenance failures, calendar/yield/intermarket conflicts and disallowed strategies remain blocking.

Minimum retained artifact: completed MT5 resilience runtime report.

## MP-07 — Learning and adaptive governance

Covers M5-052 and M5-053.

Required proof:
- quarantined/manual/chaos/config-mismatch observations cannot update adaptive evidence;
- statistical challenger promotion;
- promotion probation rollback;
- requalification cooldown.

Minimum retained artifacts: learning/quarantine evidence and champion/challenger validation reference.

## MP-08 — Evidence archive and operator acceptance

Covers M5-031 through M5-034.

Required proof:
- Experts and Journal logs archived and hashed;
- broker history/reconciliation artifact archived and hashed;
- completed M5-001…M5-053 matrix archived and hashed;
- operator decision literal `ACCEPT`, reviewer and timestamp.

## Machine projection

`tools/build_mt5_minimum_proof_summary.py` derives a compact `mt5_minimum_proof_summary_v1` record from a finalized MT5 v2 evidence record and completed M5 matrix. It cannot turn a failing/partial MT5 record into PASS.

The summary is operational convenience only. Production authorization continues to depend on the authoritative `mt5_validation_evidence_v2` digest already enforced by Part28B.
