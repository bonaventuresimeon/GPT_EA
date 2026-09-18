<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Automated Demo Validation Harness

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧪 **Document:** `DEMO_VALIDATION_HARNESS.md`

---
# 🧪 Automated Demo Validation Harness

The harness defines a controlled DEMO evidence run for the exact release candidate. It does not fabricate market outcomes or substitute for MetaEditor/Strategy Tester.

## Required scenario families

- BUY candidate path;
- SELL candidate path;
- breakout/retest;
- retracement;
- counter-trend candidate;
- WAIT;
- NO TRADE;
- stale approval;
- API unavailable/auth/rate-limit/5xx/backoff;
- restart;
- disconnect/reconnect;
- stop rejection/freeze;
- TP1 partial + BE;
- TP2/runner lifecycle;
- recovery/checkpoint restoration;
- release/legal/privacy gate block;
- broker mismatch/drift;
- missing/stale market data.

## Harness rule

Each scenario is an **executed observation** with start/end timestamps, candidate SHA/EX5 hash, broker/server/demo identity, steps, expected result, observed result, evidence references and PASS/FAIL.

No scenario may be marked PASS merely because a code path exists.

## Acceptance

- every required HIGH scenario executed;
- zero duplicate orders/partials;
- zero backward/missing unresolved protection;
- zero stale approval executions;
- zero gate bypass;
- zero secrets exposed;
- all failed scenarios resolved/re-run or release remains HOLD.

Use `DEMO_VALIDATION_RUN_TEMPLATE.json` and validate:

```text
python tools/validate_demo_validation_harness.py artifacts/demo-validation-run.json
```

> 🧪 **Promotion:** static → compile → smoke → demo harness → matrices/soak → final evidence.
