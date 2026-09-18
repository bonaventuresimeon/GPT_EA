<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 📦 Reproducible Customer Release Packaging

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 📦 **Document:** `REPRODUCIBLE_RELEASE_PACKAGING.md`

---
# 📦 Reproducible Release Packaging

Customer packaging must be derived from a certified candidate, not assembled manually from “latest” files.

## Package contents

- exact certified `GPT_EA.ex5`;
- certified blank-secret `.set` or explicit NONE;
- package manifest with hashes;
- release-truth dashboard and drift PASS;
- installation/first-run/API troubleshooting docs;
- license, terms, risk disclosure and disclaimer;
- customer-visible release notes;
- optional externally produced manifest signature.

## Packaging preconditions

- feature freeze active;
- R10 release evidence validator PASS;
- final release review PASS/GO;
- release-truth `--require-pass` PASS;
- dashboard drift PASS;
- EX5/SET hashes match compile evidence;
- secret scan clean.

## Refusal rules

Packaging must fail on HOLD/NO-GO, hash mismatch, secret detection, missing legal/customer docs, missing compile evidence, missing final review, or candidate SHA mismatch.

## Output

```text
GPT_EA_<release>/
  GPT_EA.ex5
  certified.set             # if used; blank customer secrets
  PACKAGE_MANIFEST.json
  PACKAGE_MANIFEST.sha256
  RELEASE_TRUTH_DASHBOARD.md
  INSTALLATION.md
  USER_INSTALLATION_GUIDE.md
  FIRST_RUN_CHECKLIST.md
  API_KEY_TROUBLESHOOTING.md
  COMMERCIAL_LICENSE.md
  TERMS_AND_CONDITIONS.md
  TRADING_RISK_DISCLOSURE.md
  DISCLAIMER.md
```

Use `tools/build_customer_release_package.py` after all authoritative validators pass.

> 📦 **Rule:** no PASS evidence, no customer release package.
