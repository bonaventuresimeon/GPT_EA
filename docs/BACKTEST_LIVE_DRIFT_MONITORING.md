<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 📉 Research-vs-Demo/Live Drift Monitoring

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 📉 **Document:** `BACKTEST_LIVE_DRIFT_MONITORING.md`

---
# 📉 Backtest-vs-Demo/Live Drift Monitoring

Performance drift monitoring is a **safety/research signal**, not a guarantee of future returns.

## Baseline metrics

Track by symbol, strategy, regime and session where sample size is sufficient:

- spread and effective transaction cost;
- slippage;
- order latency/fill quality;
- win rate;
- average R / expectancy;
- profit factor;
- MAE/MFE;
- drawdown in R;
- rejection/invalid-fill rate;
- stop-modification failure rate.

## States

- **NORMAL** — within approved tolerance;
- **WATCH** — material degradation; gather evidence/reduce confidence;
- **HOLD** — severe/structural degradation; block strategy promotion/new-risk authorization where policy requires;
- **RESEARCH ONLY** — baseline/sample not mature enough.

## Guardrails

Do not automatically increase risk because recent performance improved. Do not treat small samples as edge. Any adaptive production change remains subject to shadow validation and release approval.

> 📉 **Rule:** drift can reduce authorization; it cannot manufacture confidence.
