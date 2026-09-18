<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🛡️ AI-Assisted Multi-Timeframe MT5 Trading Intelligence

**Research • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

---

# 🏗️ System Architecture

GPT_EA is designed as a layered, fail-closed MetaTrader 5 Expert Advisor. AI assists analysis; deterministic broker, risk, recovery, release and legal gates retain final authority.

## 🌐 End-to-end architecture

```mermaid
flowchart TD
    U[👤 Trader / Human Approval] --> MT5[💹 MetaTrader 5]
    MT5 --> SCAN[🔭 Continuous + Scheduled Scanner]
    SCAN --> MTF[🧭 D1/H4/H1/M30/M15/M5 Intelligence]
    MTF --> REGIME[🌦️ Regime + Market-State Classifier]
    REGIME --> STRAT[🧠 Strategy Selector]
    STRAT --> TECH[📐 Structure / Liquidity / Momentum / Volatility]
    TECH --> NEWS[📰 Calendar + Yield + Intermarket + Web Intelligence]
    NEWS --> THESIS[🧾 Mandatory 25-Point Thesis]
    THESIS --> GPT[🤖 OpenAI Adversarial Review]
    GPT --> REVAL[🔁 Strict Pre-Entry Revalidation]
    REVAL --> RISK[🛡️ Portfolio / Daily / Correlation Risk]
    RISK --> RELEASE[🔐 R7 API → R8 Legal → R9 Customer Ack]
    RELEASE --> BROKER[🏦 Broker Rules + OrderCheck]
    BROKER --> APPROVE{✅ Human APPROVE?}
    APPROVE -- No --> WAIT[⏸️ WAIT / NO TRADE]
    APPROVE -- Yes --> EXEC[⚡ Execution]
    EXEC --> LIFE[🔄 Lifecycle / TP1 / TP2 / BE / Trailing]
    LIFE --> OBS[📊 Analytics + Stop Observability]
    OBS --> REC[💾 Restart / Checkpoint Recovery]
    REC --> MT5
```

## 🧩 Trust boundary

```mermaid
flowchart LR
    API[🌐 OpenAI API] -->|HTTPS WebRequest| T[🔌 API Transport]
    T --> I[🧠 Intelligence]
    I --> D[⚙️ Deterministic Gates]
    D --> B[🏦 Broker]
    B --> M[💰 Market]
    L[📜 License / Legal / Risk Ack] --> D
    E[📦 Release Evidence] --> D
    S[🛡️ Stop Health] --> D
    R[💾 Recovery Integrity] --> D
    K[🔑 Customer API Key] -. local only .-> T
```

**Trust rule:** GPT output never overrides deterministic safety, release, broker, stop, recovery or legal gates.

## 🛡️ Safety stack

1. 📡 Fresh synchronized market data.
2. 🧠 Strategy and regime alignment.
3. 📰 News/intermarket contradiction checks.
4. 🧾 Mandatory thesis and adversarial GPT review.
5. 🔁 Fresh pre-entry revalidation.
6. 💼 Portfolio/daily/correlation risk.
7. 🔐 Release evidence and deployment identity.
8. 🌐 API transport gate.
9. ⚖️ Legal/license acknowledgement.
10. 👤 Customer risk acknowledgement.
11. 🏦 Broker capability + OrderCheck.
12. ✅ Human approval.
13. 🛑 Monotonic stop protection and recovery.

## 🔐 Customer credential architecture

```text
Customer MT5
   │
   ├── customer-owned OpenAI API key
   │
   └── HTTPS → https://api.openai.com/v1/responses
```

The key must not be committed, logged, placed in screenshots, or shipped in vendor presets.

## 💾 Evidence and recovery architecture

```mermaid
flowchart TD
    INTENT[🧾 Trade Intent / Decision Evidence] --> ORDER[⚡ Broker Order]
    ORDER --> POS[📍 Position]
    POS --> CP[💾 Checkpoint + Backup]
    POS --> STOP[🛑 Stop Failure Observability]
    POS --> ANA[📊 Analytics]
    CP --> RESTART[🔄 Restart Reconciliation]
    STOP --> RESTART
    ANA --> RESTART
    RESTART --> SAFE{Integrity OK?}
    SAFE -- Yes --> MANAGE[🛡️ Continue Position Management]
    SAFE -- No --> BLOCK[⛔ Block New Entries]
```

## 🏛️ Architecture decisions

The major irreversible or safety-relevant design choices are recorded in **[ADR_INDEX.md](ADR_INDEX.md)** rather than being left implicit in code comments.

Supersession and history-preservation are governed by **[ADR_SUPERSESSION_POLICY.md](ADR_SUPERSESSION_POLICY.md)** and the machine-readable `ADR_REGISTRY.json`.

Current accepted ADR themes include fail-closed new-entry governance, customer-owned API keys, human approval, existing-position safety during governance blocks, evidence-bound releases, versioned legal/risk/privacy approval, privacy-minimized licensing/telemetry, and shadow-first adaptive learning.

```mermaid
flowchart LR
    ADR[🏛️ ADR] --> CODE[⚙️ Implementation]
    CODE --> TEST[🧪 Validation]
    TEST --> EVID[📦 Release Evidence]
    EVID --> DASH[🚦 Release Truth]
    DASH --> GO{✅ GO?}
```

See also **[RELEASE_TRUTH_DASHBOARD.md](RELEASE_TRUTH_DASHBOARD.md)**.
Dashboard/evidence drift is defined in **[DASHBOARD_DRIFT_DETECTION.md](DASHBOARD_DRIFT_DETECTION.md)**.

## ⚠️ Non-goals

GPT_EA does not guarantee profitable outcomes, remove market risk, make AI infallible, replace broker infrastructure, or permit release gates to be bypassed for convenience.

---

> 🧭 **Design principle:** fail closed for new entries, continue safe management of existing positions.
