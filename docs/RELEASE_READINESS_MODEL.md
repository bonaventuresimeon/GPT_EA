<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🚦 Release Readiness Model

**Code readiness is not evidence readiness**

[🏠 Home](README.md) · [🚀 Release](RELEASE_CERTIFICATION.md) · [🧪 MT5 Proof](MT5_MINIMUM_PROOF_SET.md)

</div>

> 🚦 **Document:** `RELEASE_READINESS_MODEL.md`

---

# Release Readiness Model

GPT_EA reports two independent readiness axes.

## 1. Code readiness

`CODE_STATIC_READY` means the exact candidate source SHA has passed the repository aggregate static suite, either from:

- an executed local `tools/run_release_checks.py` result bound to the same Git SHA; or
- the validated GitHub CI bundle for the same SHA.

It does **not** mean MetaEditor compiled the EA and does **not** authorize REAL trading.

`CODE_STATIC_HOLD` means static proof is absent, failed, stale or belongs to another SHA.

## 2. Evidence readiness

`EVIDENCE_HOLD` means one or more release-blocking evidence gates remain incomplete.

`EVIDENCE_READY_FOR_FINAL_REVIEW` means every non-operator release gate is true for the frozen candidate, but the final human GO review/operator gate is not yet complete.

`PRODUCTION_GO` is reported only when the existing authoritative release-evidence validator and final-review validator both pass and the final decision is literal `GO`.

The readiness artifact never overrides Part28/R10 runtime safety and never creates an attestation.

## Overall state

- `HOLD` whenever evidence readiness is not `PRODUCTION_GO`.
- `GO` only when evidence readiness is `PRODUCTION_GO`.

A source may therefore correctly report:

`CODE_STATIC_READY + EVIDENCE_HOLD → HOLD`

This is the normal state while GitHub runner execution, MetaEditor/MT5 proof, five-day soak or operator review is still pending.

## Current monolithic source

The active candidate source is `GPT_EA.mq5`. Archived `mqh/` files are reference/release-contract material after the monolithic merge; static tooling must bind the exact Git SHA and current monolithic source rather than treating archived modules as separately compiled units.

## Machine status

Use:

```text
python tools/build_release_readiness_status.py \
  --release-evidence artifacts/release-evidence.json \
  --static-check static-check.txt \
  --final-review artifacts/final-release-review.json
```

Then validate:

```text
python tools/validate_release_readiness_status.py artifacts/release-readiness-status.json
```

The status is diagnostic/operational metadata. The authoritative release decision remains the existing release-evidence and final-review chain.
