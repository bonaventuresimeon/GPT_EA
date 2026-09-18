<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧪 Validation & Quality Assurance

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧪 **Document:** `RELEASE_CERTIFICATION_TESTS.md`

---

# GPT_EA Release Certification Gate Tests

These tests validate `GPT_EA_Part28_ReleaseCertification.mqh`. They are release-blocking for real-account arming behavior.

## RC-001 — defaults are fail-closed on real

- Use a real-account test environment with all release-attestation inputs at defaults.
- Even if normal trading permissions are available, `ReleaseEvidenceAllows()` must return BLOCK.
- The blocking reason must identify the first missing release requirement.
- No new approval/execution may bypass the certified release gate.
- Existing GPT_EA positions must continue to be managed.

## RC-002 — live-arm phrase alone is insufficient

- Set `InpLiveArmPhrase=GPT_EA_LIVE_ARMED`.
- Leave one or more release-attestation flags false.
- Real-account execution must remain blocked.

## RC-003 — attestation alone is insufficient

- Set every release-attestation flag true and enter the correct release validation ID.
- Leave the normal live-arm phrase unset when the base release gate requires it.
- Real-account execution must remain blocked by the base release gate.

## RC-004 — wrong release validation ID

- Set every release-attestation flag true.
- Enter a stale or incorrect `InpReleaseValidationId`.
- Real-account execution must remain blocked.

## RC-005 — each individual evidence flag is mandatory

Repeat with exactly one of the following false while all others are true:

- MetaEditor compile;
- Strategy Tester;
- broker matrix;
- recovery tests;
- stop-management matrix;
- partial-protection test;
- WebRequest/OpenAI failure injection;
- demo soak;
- operator review.

Each case must block and identify the missing evidence class.

## RC-006 — complete certified state

- Use the current required release validation ID.
- Set all evidence flags true only after the archived evidence exists.
- Set the normal live-arm phrase if required.
- Confirm all other release, risk, stop, broker, news and strategy gates still apply.
- Certification must not create an execution bypass.

## RC-007 — Strategy Tester remains usable

- Run in Strategy Tester with default false attestations.
- Certification attestation must not block test execution paths.
- Other Strategy Tester limitations still apply normally.

## RC-008 — demo remains usable for validation

- Run on demo/contest with default false attestations.
- Release-evidence attestation must be informational only.
- Demo failure-injection and soak testing must remain possible.

## RC-009 — evidence snapshot

- Initialize on demo and real test environments.
- Confirm `GPT_EA_ReleaseEvidence.csv` records required/entered release IDs, broker/server, all evidence flags, gate result and reason.
- Confirm no API key or other secret is written.

## RC-010 — restart

- Restart MT5/EA with a certified real-account input set.
- Verify the certification gate is re-evaluated at startup.
- Verify the evidence snapshot is appended.
- Verify no stale in-memory PASS bypass exists if an input is changed back to false.

## RC-011 — source/release ID rollover

- Change a release-sensitive code path for a future release.
- Bump `GPT_EA_REQUIRED_RELEASE_VALIDATION_ID` before certification.
- Confirm the previous validation ID no longer arms real execution.

## RC-012 — certification cannot clear safety pauses

- Trigger a stop-failure or operator-required safety pause.
- Keep release certification valid.
- Verify the certification gate does not clear or bypass the safety pause.

## Pass rule

A live candidate fails release if any RC test permits real-account new exposure without both:

1. all ordinary release/risk/broker/stop/intelligence conditions; and
2. complete release evidence attestation for the current validation ID.
