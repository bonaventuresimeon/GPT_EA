<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Validation & Quality Assurance

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧪 **Document:** `DEMO_SOAK_ACCEPTANCE.md`

---

# GPT_EA R6 Demo-Soak Acceptance Contract

This contract is **release blocking**. A demo soak is not considered passed merely because the EA stayed attached, traded profitably or displayed a healthy dashboard.

The authoritative R6 evidence flow is:

`GPT_EA_Part36_DemoSoakEvidence.mqh` → `GPT_EA_DemoSoakSnapshot.json` → operator reconciliation/report → `tools/import_soak_snapshot.py` → `tools/validate_soak_evidence.py` → `tools/validate_release_evidence.py` → Part28 local release inputs.

See `DEMO_SOAK_EVIDENCE.md`, `DEMO_SOAK_REPORT_TEMPLATE.md`, `SOAK_DAY_RECONCILIATION_CHECKLIST.md`, `FIVE_DAY_SOAK_ACCEPTANCE_SCHEMA.json` and `SOAK_EVIDENCE_SCHEMA.json`.

## 1. Candidate and run identity

Use the intended broker/account type and the exact candidate `.ex5` and `.set` preset. Before starting:

- archive the exact Git commit SHA;
- archive EX5 SHA-256;
- archive SET SHA-256 or explicit `NONE`;
- record MetaEditor and MT5 builds;
- record broker/server/account profile;
- set `InpEnableDemoSoakEvidence=true` on demo/contest only;
- set a unique `InpDemoSoakEvidenceId` of at least 8 characters;
- preserve that evidence ID for the whole run.

A material executable-source, EX5, SET/risk-profile or deployment change creates a new candidate and invalidates the prior soak.

## 2. Minimum R6 coverage

The same candidate must demonstrate at least:

- **5 consecutive trading days** with fresh configured-symbol quotes;
- London-session coverage on at least 3 days;
- New York/U.S. cash-session coverage on at least 3 days;
- at least one London/New York overlap;
- at least one relevant high-impact scheduled-news day;
- at least one rollover window with actual spread expansion;
- at least one EA/terminal restart or reinitialization under the same soak ID;
- at least one observed disconnect followed by reconnect;
- at least one scheduled scan;
- at least one continuous/new-M5 scan;
- at least one manual `SCAN NOW` cycle;
- at least one primary recovery-checkpoint update;
- at least one validated backup-checkpoint observation.

If the intended deployment trades weekend-enabled instruments, document weekend behavior separately. Weekend days do not count toward the normal Monday-Friday consecutive-day requirement unless `InpDemoSoakCountWeekendTradingDays` is explicitly enabled and justified for that release profile.

## 3. Machine evidence artifacts

Part36 writes to MT5 Common Files:

- `GPT_EA_DemoSoakEvidence.csv` — event/summary stream;
- `GPT_EA_DemoSoakSnapshot.json` — current R6 `demo_soak` object;
- existing `GPT_EA_Execution.csv`;
- existing `GPT_EA_StopFailures.csv`;
- existing `GPT_EA_ReleaseEvidence.csv`.

The runtime snapshot uses schema version:

`demo_soak_evidence_v1`

The snapshot deliberately leaves `evidence_digest` blank. Digest finalization happens offline after reconciliation.

## 4. Required operational observations

The soak must demonstrate normal operation without manufacturing unsafe trades merely to increase sample size:

- scans continue across configured symbols;
- HIGH-CONFIDENCE, WAIT/REANALYZE and NO-TRADE decisions can occur without forced execution;
- pending approvals expire/deny safely;
- stale human-approval lifecycle states reconcile to `INVALIDATED` when no pending approval or fill remains;
- market-confirmation waits are not falsely invalidated by that reconciliation;
- fresh approval validation rejects changed/stale setups;
- news/intermarket failures obey configured failure policy;
- GPT disagreement/integrity gates do not override deterministic hard risk controls;
- release/risk/stop gates remain effective through timers, restart and reconnect;
- existing positions remain protected when new entries are blocked;
- strategy health, shadow/challenger and execution-learning journals continue updating;
- recovery checkpoint and validated `.bak` evidence continue updating;
- required CSVs remain writable and internally consistent.

## 5. Position-management evidence

Across the complete release campaign—including controlled matrices plus the soak—archive at least one complete BUY and one complete SELL lifecycle where market conditions permit:

`initial SL → TP1 partial → protection/BE → profit lock → strong lock → runner/trailing/TP3 or managed exit`.

Do not manufacture unsafe market orders solely to complete this sequence. If natural soak setups do not cover every stage, reference the required controlled demo stop-management tests in the soak report.

## 6. R6 zero-tolerance fields

The final schema requires all of these to equal zero:

- `zero_tolerance_failures`;
- `unresolved_critical_states`;
- `duplicate_orders`;
- `duplicate_partials`;
- `sl_regressions`;
- `unprotected_new_authorizations`;
- `release_gate_bypasses`;
- `analytics_duplicate_finalizations`;
- `stop_failure_join_failures`;
- `dashboard_gate_mismatches`;
- `runtime_critical_errors`;
- `secrets_exposed`.

A machine-produced zero is not sufficient proof. The operator must reconcile each category against broker history, Experts/Journal, execution/stop/lifecycle/intelligence CSVs and the completed soak report. Any discovered event must be reflected as a non-zero count and is release blocking.

Examples of immediate soak failure include duplicate orders/partials, stop regression, unintentionally removed protection, new authorization while a position is unprotected, release-gate bypass, stale approval execution after restart, duplicated analytics lifecycle finalization, unexplained critical runtime errors or credential exposure.

## 7. End-of-soak state

At soak end there must be no unexplained critical state, including:

- no GPT_EA position with `SL=0` unless an explicitly documented broker-transition policy is actively handling it;
- no unresolved critical/operator-required stop state;
- no stale partial-protection hazard;
- no orphaned human-approval `WAIT_CONFIRMATION`;
- no duplicate pending approval;
- no corrupt checkpoint without a valid fallback;
- no unexplained broker rejection loop;
- no repeated OpenAI/WebRequest failure loop contrary to configured policy;
- no release/dashboard state mismatch;
- no candidate artifact or deployment identity mismatch.

A deliberately induced safety pause may remain paused only if its cause, evidence, recovery status and operator decision are explicitly documented.

## 8. Per-day reconciliation

The five-day acceptance record uses `five_day_soak_acceptance_v2`. Every accepted day must have a unique completed copy of `SOAK_DAY_RECONCILIATION_CHECKLIST.md` containing the day date, frozen candidate Git SHA and literal `Decision: **ACCEPT DAY**`.

The matching machine day row must set:

- `reconciliation_checklist_path`;
- `day_reconciled=true`;
- `reconciled_by`;
- `reconciled_at`.

A missing, duplicated, HOLD, wrong-date or wrong-candidate checklist prevents the day from counting.

## 9. Evidence report and reconciliation

Copy `DEMO_SOAK_REPORT_TEMPLATE.md` to the report path referenced by the snapshot and complete every applicable section. Archive:

- candidate and deployment identity;
- soak start/end;
- session/news/rollover coverage;
- restart/reconnect evidence;
- scheduled/continuous/manual scan counts;
- primary and backup checkpoint observations;
- Experts and Journal logs;
- broker order/deal history;
- `GPT_EA_Execution.csv`;
- `GPT_EA_StopFailures.csv`;
- `GPT_EA_Intelligence.csv` and adaptive journals where applicable;
- `GPT_EA_ReleaseEvidence.csv`;
- `GPT_EA_DemoSoakEvidence.csv`;
- `GPT_EA_DemoSoakSnapshot.json`;
- recovery checkpoint and `.bak` samples;
- screenshots/trade-history exports for material events;
- reconciliation of every zero-tolerance field.

Performance metrics—win rate, realized R, MAE/MFE, slippage, spread and strategy/session performance—are recorded for research but are **not by themselves the engineering PASS criterion** for a five-day soak.

## 10. Finalize the soak JSON and digest

Part36's live snapshot is intentionally not release-ready because its digest is blank. After the report is complete and the counters have been reconciled, import it into a copy of the release evidence:

```text
python tools/import_soak_snapshot.py \
  path/to/GPT_EA_DemoSoakSnapshot.json \
  artifacts/five-day-soak-acceptance.json \
  path/to/release_evidence.json
```

The importer refuses an incomplete/invalid snapshot or five-day record, verifies all five per-day reconciliation files and the report, copies `acceptance_record_schema_version=five_day_soak_acceptance_v2`, calculates the canonical SHA-256 excluding `evidence_digest`, and updates the `demo_soak` object.

Then run:

```text
python tools/validate_soak_evidence.py path/to/release_evidence.json
python tools/validate_release_evidence.py path/to/release_evidence.json
```

Both must PASS. Archive `soak-evidence-validation.txt`, `release-evidence-validation.txt` and the completed evidence JSON.

## 11. Part28 promotion rule

`InpReleaseDemoSoakPassed=true` may be set locally only after all of the following are true:

1. the exact candidate identity is archived;
2. machine coverage requirements are complete;
3. the operator reconciled all zero-tolerance categories;
4. the completed report exists;
5. the `demo_soak` object passes `SOAK_EVIDENCE_SCHEMA.json`;
6. its canonical digest is archived;
7. `tools/validate_soak_evidence.py` passes;
8. the complete release bundle passes `tools/validate_release_evidence.py`;
9. all Part28 soak fields match the archived evidence exactly;
10. final human GO/NO-GO review is still separately completed.

Part36 never changes release-attestation inputs and never authorizes REAL-account execution. R6 remains fail-closed until the complete engineering and operator release process is satisfied.
