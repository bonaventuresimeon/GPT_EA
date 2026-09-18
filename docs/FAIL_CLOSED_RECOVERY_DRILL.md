<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 💾 Fail-Closed Recovery Drill

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 💾 **Document:** `FAIL_CLOSED_RECOVERY_DRILL.md`

---
# 💾 Fail-Closed Recovery Drill

This drill proves that recovery faults block **new risk** without abandoning existing-position protection.

## Required scenarios

| ID | Injected condition | Required result |
|---|---|---|
| FCR-001 | Missing primary checkpoint; valid backup | recover from validated backup; no duplicate execution |
| FCR-002 | Corrupt primary checkpoint | reject corrupt state; use valid source-of-truth path |
| FCR-003 | Corrupt primary + corrupt backup | block new entries; preserve existing-position management |
| FCR-004 | Broker position exists but checkpoint missing | broker position remains authoritative; rebuild safe state |
| FCR-005 | Checkpoint says position exists but broker has none | do not recreate a trade |
| FCR-006 | Pending approval exists across restart | do not execute stale approval; force fresh revalidation |
| FCR-007 | Position ticket changes but identifier persists | rebuild ticket-scoped management by POSITION_IDENTIFIER |
| FCR-008 | Netting direction reversal | quarantine/pause new entries; do not reuse old lifecycle state |
| FCR-009 | Missing SL after restart | attempt repair; block new entries until protection is safe |
| FCR-010 | TP1 partial occurred, BE not completed | resume protection only; do not duplicate TP1 partial |
| FCR-011 | Disconnect during stop update | preserve retry state; no protection regression |
| FCR-012 | Recovery metadata account/server/magic mismatch | reject foreign recovery state |
| FCR-013 | Duplicate lifecycle-finalization evidence | exactly-once finalization; no duplicate analytics/partial |
| FCR-014 | Recovery gate fails while position open | new entries blocked; open position still managed |
| FCR-015 | Recovery completes | gate clears only after invariants are re-established |

## Zero-tolerance failures

- duplicate order or partial close;
- protective SL removed or moved backward;
- stale approval executed;
- new trade authorized while recovery is unsafe;
- checkpoint creates a broker position;
- foreign account/server/magic state accepted;
- existing position abandoned because recovery gate is blocked;
- critical recovery error cleared without reconciliation.

## Evidence

```text
artifacts/fail-closed-recovery-drill.json
artifacts/fail-closed-recovery-drill-validation.txt
artifacts/recovery-drill/
  Experts.log
  Journal.log
  checkpoint-before/
  checkpoint-after/
  broker-history-export/
```

Use the bundled `FAIL_CLOSED_RECOVERY_DRILL_TEMPLATE.json` and validate with:

```text
python tools/validate_fail_closed_recovery_drill.py artifacts/fail-closed-recovery-drill.json
```

A static/template PASS does not prove the drill ran; all FCR scenarios must contain executed evidence.

> 💾 **Safety principle:** uncertain recovery blocks new entries; it never instructs GPT_EA to abandon protection of an existing trade.
