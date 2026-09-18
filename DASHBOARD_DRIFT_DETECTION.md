<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚦 Release-Truth Dashboard Drift Detection

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🚦 **Document:** `DASHBOARD_DRIFT_DETECTION.md`

---

# 🚦 Dashboard Drift Detection

The release-truth dashboard is a **derived view** of machine-readable release evidence. It must never be edited into a greener state than the underlying evidence.

## 🎯 Drift definition

Dashboard drift exists when any deterministic dashboard marker no longer matches the evidence file used to generate it:

- release-truth schema;
- canonical evidence SHA-256;
- semantic truth fingerprint;
- overall PASS / HOLD / NO-GO state.

Cosmetic fields such as the generation timestamp are not used as the primary drift signal.

## 🔏 Deterministic markers

Generated dashboards contain:

```text
<!-- RELEASE_TRUTH_SCHEMA: gpt_ea_release_truth_v1 -->
<!-- RELEASE_TRUTH_EVIDENCE_SHA256: <64-char sha256> -->
<!-- RELEASE_TRUTH_FINGERPRINT: <64-char sha256> -->
<!-- RELEASE_TRUTH_OVERALL: <status> -->
```

The evidence digest is calculated from canonical JSON.

The truth fingerprint is calculated from the semantic dashboard state:

- release validation ID;
- candidate Git SHA;
- overall status;
- truth rows;
- explicit blockers.

## 🧪 Drift check

Repository baseline:

```text
python tools/check_release_truth_drift.py RELEASE_EVIDENCE_TEMPLATE.json
```

Candidate release:

```text
python tools/check_release_truth_drift.py release_evidence.json \
  --dashboard RELEASE_TRUTH_DASHBOARD.md \
  --output release-truth-drift-validation.txt
```

A mismatch is **FAILED** and must block final release packaging until the dashboard is regenerated from the exact evidence.

## 🔄 Correct recovery

If drift is detected:

1. do **not** hand-edit the status to match expectation;
2. establish which evidence file is authoritative;
3. correct/validate the machine-readable evidence if necessary;
4. regenerate the dashboard using `tools/generate_release_truth_dashboard.py`;
5. rerun the drift detector;
6. archive the PASS drift-validation output with the release pack.

## ⛔ Automatic drift failure examples

- evidence changed after dashboard generation;
- a gate changed PASS ↔ HOLD ↔ NO-GO;
- candidate Git SHA changed;
- an explicit blocker appeared/disappeared;
- dashboard marker was manually edited;
- dashboard belongs to another release evidence file;
- deterministic fingerprint is missing.

## 📦 Release pack requirement

A production evidence pack should contain:

```text
RELEASE_TRUTH_DASHBOARD.md
release-truth-drift-validation.txt
release_evidence.json
```

The dashboard and drift output must correspond to the same exact evidence JSON.

## 🛡️ Authority hierarchy

1. exact source/artifact identity;
2. machine-readable release evidence;
3. dedicated validators;
4. final GO/NO-GO review;
5. dashboard as a derived summary.

The dashboard cannot override failed evidence.

---

> 🚦 **Truth rule:** regenerate from evidence; never edit the dashboard into compliance.
