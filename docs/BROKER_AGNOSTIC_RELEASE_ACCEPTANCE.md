<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🏦 Universal Broker Coverage Release Acceptance

**Full Catalogue Discovery • Asset Classification • Broker Geometry • Macro Context • Fail-Closed Live Authorization**

[🏠 Home](../README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🛡 Broker Matrix](BROKER_MATRIX_TESTS.md) · [🚀 Release Certification](RELEASE_CERTIFICATION.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🏦 **Document:** `BROKER_AGNOSTIC_RELEASE_ACCEPTANCE.md`

---

# Purpose

This contract turns "broker-agnostic" from a source-code capability claim into a release-evidence requirement.

The EA may discover, select, classify, scan and analyze the broker's complete symbol catalogue in demo/test environments. **REAL execution is narrower:** a symbol may open new exposure only when the exact release candidate has valid universal-discovery evidence and the symbol's resolved asset class is explicitly live-certified.

This separates three different claims:

1. **Discovery coverage** — the broker instrument is found and selected correctly.
2. **Analysis coverage** — D1/H4/H1/M30/M15/M5, broker metadata and relevant macro/news context can be evaluated.
3. **Execution coverage** — tick/volume/stop/margin/order-mode behavior has been proven safe enough for that asset class on the release broker.

A PASS in one layer does not imply PASS in the next.

# Runtime acceptance rule

For REAL accounts the active release chain must satisfy:

`general release evidence → broker coverage evidence → class-specific certification → per-symbol broker rules → OrderCheck() → human approval`.

The broker-coverage inputs are fail-closed:

- `InpReleaseBrokerDiscoveryPassed=false` by default.
- every `InpReleaseAssetClass*Passed` flag defaults to `false`.
- `GEN/OTHER` remains analyzable but cannot open REAL exposure unless `InpReleaseAssetClassOtherPassed=true` is generated from validated evidence.
- demo/contest and Strategy Tester remain available for evidence generation.

The required evidence schema is:

`broker_agnostic_coverage_v1`.

# Release acceptance gates

A broker-coverage record is acceptable only when all applicable gates below pass.

| Gate | Mandatory evidence | Automatic failure |
|---|---|---|
| Candidate identity | Git SHA, EX5 SHA-256, SET SHA-256/NONE | Identity mismatch |
| Broker identity | company, server, account currency, margin mode, catalogue timestamp | Missing or different deployment |
| Full catalogue discovery | `SymbolsTotal(false)`/full-catalogue enumeration proven | Market-Watch-only proof |
| Selection safety | unselected symbols admitted provisionally, selected, then trade metadata rechecked | pre-selection disabled/invalid metadata used as final truth |
| Market Watch independence | symbols outside Market Watch demonstrably discoverable | ALL depends on Market Watch |
| Ambiguous mapping | 0 unresolved materially ambiguous mappings | any unresolved alias collision |
| Misclassification | 0 confirmed class misclassifications | any stock/ETF/future/bond/crypto false classification |
| Generic handling | unknown executable symbol remains analyzable | unknown symbol silently dropped |
| Generic live safety | uncertified OTHER/GEN cannot execute on REAL | generic class inherits another class's certification |
| Collateral safety | service-collateral instruments excluded from execution universe | collateral treated as tradable market |
| Broker metadata | description/path + base/profit/margin currency + calc mode tested | name-only classification accepted as universal proof |
| Trade restrictions | FULL/LONGONLY/SHORTONLY/CLOSEONLY/DISABLED behavior proven | forbidden direction/order accepted |
| Price geometry | digits/point/tick size/tick value/contract size checked | theoretical pip assumptions substituted |
| Volume geometry | min/max/step/limit checked | invalid lot request possible |
| Stop/freeze geometry | current stop/freeze restrictions checked | invalid protection accepted |
| Margin | `OrderCalcMargin` and account free-margin policy proven | leverage shortcut used as final authorization |
| Profit/risk | `OrderCalcProfit`-based risk proven | fixed pip-value assumption |
| Order preflight | `OrderCheck()` exercised for class/broker | order sent without preflight evidence |
| Macro/calendar mapping | contract currencies + regional/global mappings checked | class has no appropriate event context |
| Round-robin scanning | batch cursor reaches complete discovered universe over successive cycles | fixed first-N subset repeatedly scanned |
| Operator review | named reviewer, UTC timestamp, literal PASS | HOLD/blank review |

# Asset-class discovery and execution risk comparison

The risk levels below are release-engineering risk, not a prediction of market profitability.

| Asset class | Discovery risk | Execution risk | Principal discovery hazards | Minimum class-specific acceptance |
|---|---|---|---|---|
| FX | MODERATE | MODERATE | suffix/prefix, exotic currencies, reversed pair presentation, CNH/CNY normalization | base/profit currency pair agrees with canonical pair; 5/3-digit and exotic examples; calendar currencies; margin/tick/volume/order modes |
| METAL | MODERATE | HIGH | GOLD/SILVER aliases, spot vs derivative naming, non-USD quote | XAU/XAG/XPT/XPD aliases; contract size/tick value; quote currency; stops/spread stress; USD/yield macro context |
| INDEX | HIGH | HIGH | cash vs derivative alias, regional names, proprietary tickers, index description collisions | alias + calc-mode proof; session/tick geometry; regional currency mapping; index-specific spread/stops |
| ENERGY | HIGH | HIGH | WTI/Brent/NatGas aliases, cash vs futures-style contracts, contract-unit variation | underlying identity; contract/tick geometry; session/roll behavior where applicable; inventory/OPEC/supply context |
| COMMODITY | HIGH | VERY_HIGH | soft/agriculture/industrial-metal naming, units, futures-style tick rules | commodity family classification; non-decimal tick examples; contract unit/value; session/limit behavior where exposed; supply/weather/inventory context |
| CRYPTO | HIGH | HIGH | token substring collisions, quote-asset variants, 24/7 broker presentation | token/quote structure; contract size/tick value; quote currency; weekend/24h data; volatility/spread stress; crypto-specific context |
| STOCK | HIGH | VERY_HIGH | ticker collisions, company description containing index/metal/crypto words, multi-exchange symbols | exchange/stock calc mode or stock path precedence; quote currency; session/short-only rules; corporate-action awareness; non-decimal tick/volume |
| ETF | HIGH | VERY_HIGH | description names underlying index/commodity, ticker collision, exchange session | ETF identity must outrank underlying description; quote currency/session; holdings/index macro context; exchange execution geometry |
| FUTURE | VERY_HIGH | VERY_HIGH | expiry codes, roll months, underlying aliases, multiplier/tick rules, exchange modes | future identity precedence; expiry/roll review; multiplier/tick value; price limits/session; exchange filling/order modes; no silent roll to different contract |
| BOND_RATE | VERY_HIGH | VERY_HIGH | bond price vs yield instrument semantics, maturity aliases, treasury/gilt/bund naming | instrument semantics documented; price/yield distinction; tick value; maturity/session; central-bank/auction/rate context; no inverse-semantic assumption |
| OTHER / GEN | CRITICAL | CRITICAL | unknown economic meaning, proprietary synthetic products, incomplete metadata | analysis may proceed generically; REAL execution remains blocked unless instrument examples are explicitly reviewed and all runtime/geometry/context evidence passes |

# Per-class certification semantics

Every class row in the evidence record contains:

- `classification_passed`
- `broker_runtime_required`
- `broker_runtime_passed`
- `execution_geometry_passed`
- `macro_context_passed`
- `live_execution_certified`
- tested `examples`

Rules:

1. **All eleven classes require classification tests**, even if the exact release broker does not offer every class. Synthetic/static fixtures may satisfy classification-only coverage.
2. If the exact broker offers a class and it is intended for REAL execution, set `broker_runtime_required=true`; runtime, execution geometry and macro/context must all PASS before `live_execution_certified=true`.
3. A class absent from the exact broker may remain `broker_runtime_required=false` and `live_execution_certified=false`; this does not invalidate discovery logic for that class, but it does not certify live use.
4. `OTHER` is special: generic analysis is allowed, but live execution should normally remain uncertified. Any exception requires explicit tested symbols and full runtime evidence.
5. A validated class flag cannot be borrowed by another class. For example, INDEX evidence does not certify an ETF that tracks the same index.

# Required evidence workflow

1. Freeze candidate Git/EX5/SET identity.
2. Export or capture the broker's complete catalogue and broker identity.
3. Demonstrate discovery outside Market Watch.
4. Exercise selection/recheck behavior for unselected symbols.
5. Record classification fixtures for every canonical class.
6. For each class present on the broker, test representative symbols through data readiness, technical scan, macro mapping, spread, tick/volume/stops, margin, filling/order modes and `OrderCheck()`.
7. Record alias collisions and prove zero unresolved ambiguous mappings.
8. Prove service-collateral exclusion and OTHER/GEN live fail-closed behavior.
9. Complete operator review with decision `PASS`.
10. Finalize and validate the record:

```text
python tools/validate_broker_coverage_evidence.py artifacts/broker-agnostic-coverage.json --finalize
python tools/validate_broker_coverage_evidence.py artifacts/broker-agnostic-coverage.json
```

11. Copy the evidence ID/digest and class certification summary into `release_evidence.json`.
12. Set `gates.broker_coverage=true` only after the validator passes.
13. Run the aggregate release validator and final review validator.
14. Generate the MT5 release preset with `tools/export_mt5_release_inputs.py`; do not manually turn class flags on.

# Automatic NO-GO conditions

Broker coverage is NO-GO for the exact release candidate if any of the following occurs:

- full broker catalogue cannot be enumerated;
- Market Watch is the only proven discovery source while `ALL` is claimed;
- an unselected instrument is permanently rejected using unavailable pre-selection metadata;
- ambiguous alias maps to a materially different instrument;
- a stock/ETF/future/bond is reclassified from a descriptive underlying word;
- a non-crypto ticker is classified as crypto from an arbitrary substring;
- service collateral reaches executable scanning;
- class metadata disagrees with broker calculation/currency metadata and remains unresolved;
- required history/ticks cannot become synchronized;
- tick/contract/volume/stop geometry cannot be validated;
- broker margin or `OrderCheck()` fails;
- class macro/calendar mapping is absent or materially wrong;
- round-robin scanning starves part of the catalogue;
- an uncertified class can open REAL exposure;
- an OTHER/GEN symbol can inherit permission from another class;
- evidence candidate or broker identity differs from the deployment;
- evidence digest or validation output does not match;
- operator decision is not literal `PASS`.

# Relationship to the existing broker matrix

`BROKER_MATRIX_TESTS.md` remains the detailed runtime behavior matrix. This document adds the release-level acceptance contract and class-specific risk model.

The existing `broker_matrix` gate and the new `broker_coverage` gate are both required:

- **broker_matrix** proves broker execution behavior generally;
- **broker_coverage** proves full-catalogue discovery plus class-scoped authorization.

Neither gate substitutes for compile, MT5 validation, resilience, stop, API/news, soak, privacy, legal, customer acknowledgement or final review evidence.
