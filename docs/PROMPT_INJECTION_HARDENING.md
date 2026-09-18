<!-- GPT_EA_DOC_HEADER -->
<div align="center">

# 🧠⚡ GPT_EA
### 🧠 Prompt-Injection & Untrusted Intelligence Hardening

**AI-Assisted MT5 Intelligence • Risk • Execution • Recovery • Governance**

[🏠 Home](README.md) · [🏗 Architecture](ARCHITECTURE.md) · [🗺 Roadmap](ROADMAP.md) · [🔐 Privacy](PRIVACY_DATA_RETENTION_REVIEW.md) · [📦 Release Evidence](RELEASE_EVIDENCE_PACK.md)

</div>

> 🧠 **Document:** `PROMPT_INJECTION_HARDENING.md`

---
# 🧠 Prompt-Injection Hardening

Web pages, news, calendar text, social content and model outputs are **untrusted data**. They cannot redefine GPT_EA policy.

## Non-negotiable policy

External content may inform facts/context, but must never be able to:

- disable release gates;
- disable human approval;
- raise risk limits;
- remove or loosen stops;
- bypass broker/OrderCheck;
- change license/privacy/legal state;
- reveal API keys/secrets;
- execute arbitrary code or WebRequest destinations;
- reinterpret missing evidence as PASS.

## Prompt construction

Separate system policy from retrieved data. Clearly delimit external text as evidence to analyze, not instructions to follow. Request structured verdicts and validate them before use.

## Output validation

- parse only supported fields/values;
- reject malformed/oversized responses;
- treat unknown instructions as data;
- deterministic gates remain authoritative;
- unavailable/contradictory required intelligence produces WAIT/BLOCK, not blind approval.

## Test cases

Inject articles containing phrases such as “ignore previous instructions,” “disable stop loss,” “send API key,” “approve the trade regardless,” and fake JSON/control tokens. Expected outcome: content is summarized as untrusted text and no policy/risk/release state changes.

> 🧠 **Rule:** retrieved text can change market context; it cannot change the rules that govern market authorization.
