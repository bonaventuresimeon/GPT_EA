<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 📚 Engineering Documentation

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 📚 **Document:** `DEMO_SOAK_REPORT_TEMPLATE.md`

---

# GPT_EA R6 Demo-Soak Report

## Candidate identity

- Soak evidence ID:
- Release validation ID:
- Git commit SHA:
- EX5 SHA-256:
- SET SHA-256 or `NONE`:
- MetaEditor build:
- MT5 build:
- Compile evidence ID:

## Deployment identity

- Broker company:
- Trade server:
- Account type: demo / contest
- Margin mode:
- Account currency:
- Leverage:
- Resolved symbols:
- Relevant symbol-contract notes:

## Soak interval

- Start timestamp:
- End timestamp:
- Consecutive trading days observed:
- London sessions observed:
- New York/U.S. cash sessions observed:
- London/New York overlap observed: yes / no
- High-impact news day observed: yes / no
- Rollover spread-expansion observed: yes / no
- Restart/reinitialization observed: yes / no
- Disconnect/reconnect observed: yes / no

## Scanner and recovery evidence

- Scheduled scans:
- Continuous/new-M5 scans:
- Manual SCAN NOW observations:
- Primary checkpoint updates:
- Validated backup checkpoint observations:
- Recovery/checkpoint evidence references:

## Required log artifacts

- `GPT_EA_Execution.csv`: present / missing
- `GPT_EA_StopFailures.csv`: present / missing
- `GPT_EA_ReleaseEvidence.csv`: present / missing
- `GPT_EA_DemoSoakEvidence.csv`: present / missing
- `GPT_EA_DemoSoakSnapshot.json`: present / missing
- Experts log reference:
- Journal log reference:
- Broker order/deal history reference:

## Strategy and lifecycle observations

Document representative examples without forcing unsafe trades:

- HIGH-CONFIDENCE setup:
- WAIT/REANALYZE setup:
- NO TRADE setup:
- approval timeout/denial behavior:
- approval fresh-revalidation rejection:
- stale human-approval lifecycle reconciliation:
- restart/recovery lifecycle reconstruction:
- BUY lifecycle evidence:
- SELL lifecycle evidence:

## Adaptive execution observations

- Strategy-health mode changes, if any:
- Confidence calibration observations:
- Slippage/spread forecast observations:
- Broker-health observations:
- Correlation/macro-risk blocks:
- Per-strategy budget blocks:
- Champion/challenger shadow observations:
- Regime-transition risk reductions:

## News/intermarket observations

- Scheduled high-impact event(s):
- Live web/news behavior:
- Stale/unavailable web behavior:
- Intermarket conflict example:
- Yield-shock behavior:

## Zero-tolerance reconciliation

Every field below must be reconciled against runtime CSVs, broker history and Experts/Journal. Do not leave a machine-produced zero unreviewed.

- zero_tolerance_failures:
- unresolved_critical_states:
- duplicate_orders:
- duplicate_partials:
- sl_regressions:
- unprotected_new_authorizations:
- release_gate_bypasses:
- analytics_duplicate_finalizations:
- stop_failure_join_failures:
- dashboard_gate_mismatches:
- runtime_critical_errors:
- secrets_exposed:

For each non-zero finding, provide timestamp, evidence reference, root cause, containment and release disposition. Any non-zero R6 zero-tolerance field is release blocking.

## Stop/protection evidence

- Missing-SL cases observed:
- Partial-protection lifecycle observed:
- Stop modification failures observed:
- Stop failure class/action join verified:
- Operator-required stop states:
- Unresolved stop/protection state at soak end:

## Recovery and restart evidence

- Restart timestamp(s):
- Pending approval behavior after restart:
- Open-position reconstruction behavior:
- Checkpoint restoration behavior:
- Backup fallback behavior:
- Reconnect behavior:

## Performance observations

Informational only; profitability is not the engineering pass criterion.

- Closed trades:
- Win rate:
- Average realized R:
- Profit factor:
- Max observed MAE/MFE:
- Average slippage:
- Notable regime/session differences:

## Schema and digest

- Schema version: `demo_soak_evidence_v1`
- Final soak evidence SHA-256:
- `tools/validate_soak_evidence.py` result: PASS / FAIL
- `tools/validate_release_evidence.py` result: PASS / FAIL
- Validation output artifact paths:

## Open issues

Critical unresolved issues: **must be none for GO**

Non-critical observations:

## Operator conclusion

Reviewer:

Review timestamp:

Decision: PASS / FAIL / HOLD

Notes:
