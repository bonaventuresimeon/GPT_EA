# GPT_EA Customer-Facing Risk Acknowledgement Flow

This flow must be completed before GPT_EA is authorized for REAL-account new entries.

The purpose is informed acknowledgement, not hidden fine print.

## Stage 1 — Present the documents

Before live acknowledgement, the customer must receive access to:

1. COMMERCIAL_LICENSE.md
2. TERMS_AND_CONDITIONS.md
3. TRADING_RISK_DISCLOSURE.md
4. DISCLAIMER.md
5. ANTI_PIRACY_LICENSE_ENFORCEMENT.md

No vendor preset may pre-accept the legal inputs.

## Stage 2 — Plain-language summary

Present prominently:

> GPT_EA does not guarantee profit, wealth, income, winning trades or capital preservation. Trading can result in substantial loss, including loss of all capital allocated to trading. AI, market data, brokers, APIs and software can fail or be wrong. You remain responsible for your broker, capital, leverage, settings, approvals and decision to trade.

This summary does not replace the full legal documents.

## Stage 3 — Explicit acknowledgements

The customer must affirm each item separately:

- I understand GPT_EA does not guarantee profit or wealth.
- I understand trading can result in substantial or total loss of allocated trading capital.
- I understand AI/automated analysis can be wrong, stale, incomplete or unavailable.
- I understand broker execution, slippage, spread, gaps and third-party failures can increase losses.
- I understand I remain responsible for funding, leverage, broker choice, settings and trade approvals.
- I confirm I have tested the installation on demo before attempting live use.
- I accept the current Commercial License and Terms.
- I accept the current Trading Risk Disclosure.

No acknowledgement should be pre-selected.

## Stage 4 — Jurisdiction and terms binding

Record:

    Customer jurisdiction code:
    Customer license reference:
    Terms version:
    Risk acknowledgement version:

The jurisdiction field is for contract/evidence routing. It is not proof that distribution is lawful there. The seller must separately complete JURISDICTION_LEGAL_REVIEW_CHECKLIST.md.

## Stage 5 — Typed acceptance phrase

The customer types exactly:

    I ACCEPT GPT_EA TERMS AND TRADING RISK

The customer must personally perform the acceptance.

## Stage 6 — MT5 live acknowledgement inputs

REAL-account configuration requires:

    InpAcceptGPTCommercialTerms = true
    InpAcceptGPTTradingRisk = true
    InpAcknowledgeNoProfitGuarantee = true
    InpAcknowledgePossibleTotalLoss = true
    InpAcknowledgeAILimitations = true
    InpAcknowledgeBrokerThirdPartyRisk = true
    InpAcknowledgePersonalResponsibility = true
    InpAcknowledgeDemoFirst = true
    InpCustomerJurisdiction = <JURISDICTION CODE>
    InpGPTTermsAcceptancePhrase = I ACCEPT GPT_EA TERMS AND TRADING RISK
    InpCustomerLicenseReference = <ISSUED LICENSE REFERENCE>

The EA must reject REAL-account new authorization when a required acknowledgement is absent.

## Stage 7 — Evidence record

On REAL accounts, GPT_EA records a non-secret local acknowledgement event containing only minimum useful evidence:

- timestamp;
- terms version;
- acknowledgement schema version;
- jurisdiction code;
- masked license reference;
- broker company/server;
- PASS/FAIL state.

The record must never contain OpenAI API keys, MT5 passwords, proxy tokens, card data or authentication secrets.

## Stage 8 — What acceptance does and does not mean

Acceptance means the customer confirms receipt and understanding of the stated terms/risk disclosures.

Acceptance does not guarantee profitability, convert a losing trade into a software defect, waive mandatory legal rights, prevent lawful complaints, guarantee the owner will never face litigation/regulatory proceedings, or override mandatory law.

## Stage 9 — Re-acknowledgement

Require fresh acknowledgement after material changes to the Terms, Commercial License, Trading Risk Disclosure, customer license scope, product classification/use model, governing-law/dispute terms, or any other change designated by legal counsel.

## Stage 10 — Failure behavior

If acknowledgement is incomplete or stale:

- block new REAL-account authorization;
- explain the missing item;
- never silently auto-accept;
- do not remove SL/TP;
- do not close or open punishment trades;
- continue safe management of existing GPT_EA positions.

## Stage 11 — Support script

Support may say:

> Your live authorization is blocked because the current risk/legal acknowledgement is incomplete or does not match the required terms version. Please review the current license, terms and risk disclosure, then complete the acknowledgement yourself. Do not send us your API key or MT5 password.

Support must not accept the customer's terms on their behalf.

## Stage 12 — Audit and retention

The seller should establish a jurisdiction-appropriate retention policy and keep only what is reasonably required to prove versioned acceptance and license scope.