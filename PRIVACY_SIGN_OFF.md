<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🔐 Privacy, Governance & Release Sign-Off

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🔐 **Document:** `PRIVACY_SIGN_OFF.md`

---

# 🔐 Privacy Release Sign-Off

This document defines the release-level privacy approval required before a REAL-account deployment can clear the R10 privacy gate.

It is a governance/evidence control, not a substitute for jurisdiction-specific legal advice.

## 🎯 Purpose

The privacy sign-off confirms that the exact customer jurisdiction and release have been reviewed for:

- data inventory;
- retention/deletion;
- customer notice/transparency;
- secret-handling;
- cross-border processing;
- incident response;
- telemetry status;
- unresolved privacy findings.

## 🧾 Required R10 inputs

A REAL-account deployment requires:

```text
InpReleasePrivacySignoffPassed = true
InpReleasePrivacySignoffSchemaVersion = gpt_ea_privacy_signoff_v1
InpReleasePrivacySignoffId = <EVIDENCE ID>
InpReleasePrivacySignoffDigest = <64-CHAR SHA256>
InpReleasePrivacyReviewer = <REVIEWER>
InpReleasePrivacyReviewerRole = <ROLE>
InpReleasePrivacySignedAt = <TIMESTAMP>
InpReleasePrivacyJurisdiction = <MATCH CUSTOMER JURISDICTION>

InpReleasePrivacyDataInventoryApproved = true
InpReleasePrivacyRetentionApproved = true
InpReleasePrivacyCustomerNoticeApproved = true
InpReleasePrivacySecretHandlingApproved = true
InpReleasePrivacyCrossBorderApproved = true
InpReleasePrivacyDeletionWorkflowApproved = true
InpReleasePrivacyIncidentResponseApproved = true
InpReleasePrivacyTelemetryState = DISABLED | APPROVED
InpReleasePrivacyUnresolvedCriticalFindings = 0
```

## 🛡️ Fail-closed behavior

If privacy sign-off is missing, stale, mismatched or has unresolved critical findings:

- new REAL-account entries remain blocked;
- the exact privacy block reason is surfaced;
- existing GPT_EA positions continue normal safety/stop/recovery management;
- the EA must not remove protection or create punitive trades.

## 🌍 Jurisdiction binding

`InpReleasePrivacyJurisdiction` must match `InpCustomerJurisdiction`.

This prevents a privacy approval for one jurisdiction being reused for another without review.

Use `JURISDICTION_LEGAL_REVIEW_CHECKLIST.md` to document the wider market-specific legal review.

## 📊 Telemetry state

Only two release states are accepted:

- `DISABLED` — centralized/customer telemetry is not enabled for the release.
- `APPROVED` — telemetry has been specifically reviewed and approved under the privacy program.

Anything else blocks the R10 gate.

## 🔐 Secret-handling rule

Privacy sign-off must confirm that the product/support/release process does not intentionally collect:

- customer OpenAI API keys;
- MT5 passwords;
- card/payment authentication data;
- proxy secrets;
- private signing keys;
- secret-bearing presets/logs.

## 🧪 Evidence workflow

1. Complete `PRIVACY_DATA_RETENTION_REVIEW.md`.
2. Complete the jurisdiction review.
3. Fill `PRIVACY_SIGN_OFF_TEMPLATE.json`.
4. Compute the canonical SHA-256 excluding `evidence_digest`.
5. Run:

```text
python tools/validate_privacy_signoff.py privacy-signoff.json
```

6. Archive the PASS output in the release-evidence pack.
7. Copy the approved R10 fields into the certified MT5 preset/input record.
8. Re-run final GO/NO-GO review.

## 🚦 Decision semantics

- **APPROVED** — all mandatory privacy controls pass, jurisdiction matches, zero critical findings.
- **HOLD** — review/evidence is incomplete or ambiguous.
- **NO-GO** — critical privacy issue, secret exposure, unapproved telemetry, jurisdiction mismatch, or material unresolved legal/privacy requirement.

There is no conditional live GO with unresolved critical privacy findings.

---

> 🔐 **Release principle:** privacy approval must be evidence-bound, jurisdiction-specific, secret-safe and revalidated after material processing changes.
