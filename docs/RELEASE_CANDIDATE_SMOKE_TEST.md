<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚦 Release-Candidate Smoke Test

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚦 **Document:** `RELEASE_CANDIDATE_SMOKE_TEST.md`

---
# 🚦 Release-Candidate Smoke Test

The smoke test is the first terminal-level check after the exact candidate EX5 is produced. It is intentionally smaller than Strategy Tester, matrices or five-day soak.

## Preconditions

- feature freeze active;
- exact Git SHA recorded;
- MetaEditor compile evidence valid;
- EX5 SHA-256 recorded;
- clean blank-secret preset;
- DEMO account only;
- release truth is allowed to remain HOLD.

## Smoke cases

| ID | Test | Required outcome |
|---|---|---|
| RCS-001 | EA appears in Navigator | candidate loads |
| RCS-002 | Attach to demo chart | no critical load failure |
| RCS-003 | OnInit | completes without unresolved critical error |
| RCS-004 | Symbol/timeframe data | required series synchronize |
| RCS-005 | Release gates | real/new-risk remains fail-closed without evidence |
| RCS-006 | API transport init | no secret logging; expected status reported |
| RCS-007 | Manual SCAN NOW | deterministic scan completes |
| RCS-008 | WAIT/NO-TRADE path | no order created |
| RCS-009 | Approval UI path | approve/deny controls render/respond |
| RCS-010 | Restart with no position | no phantom order/state |
| RCS-011 | Restart with managed demo position | lifecycle resumes without duplicate action |
| RCS-012 | Disconnect/reconnect | no duplicate execution; state recovers |
| RCS-013 | Stop-health block | new entries blocked while protection remains active |
| RCS-014 | Logs | no critical loop, secret or repeated fatal error |
| RCS-015 | Detach/re-attach | clean deinit/reinit |

## Automatic smoke NO-GO

- crash/freeze;
- unresolved initialization error;
- phantom/duplicate order;
- secret printed;
- release gate incorrectly clears;
- existing-position protection disabled by a governance block;
- EX5 identity differs from compile evidence.

Use `RELEASE_CANDIDATE_SMOKE_TEMPLATE.json` and validate:

```text
python tools/validate_release_candidate_smoke.py artifacts/release-candidate-smoke.json
```

> 🚦 **Rule:** smoke PASS is necessary but never sufficient for GO.
