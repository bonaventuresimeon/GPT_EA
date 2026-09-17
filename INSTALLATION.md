# GPT_EA Installation — Start Here

New users should follow the complete step-by-step guide in:

**`USER_INSTALLATION_GUIDE.md`**

Also use:

- **`FIRST_RUN_CHECKLIST.md`** — first-launch PASS/FAIL checklist.
- **`API_KEY_TROUBLESHOOTING.md`** — safe API/WebRequest troubleshooting without sharing secrets.
- **`TRADING_RISK_DISCLOSURE.md`** — trading-loss and no-profit-guarantee disclosure.
- **`TERMS_AND_CONDITIONS.md`** and **`COMMERCIAL_LICENSE.md`** — customer legal/license terms.

The standard customer setup is:

```text
MetaTrader 5
→ GPT_EA
→ user's own funded OpenAI API account
→ user's own OpenAI API key
→ https://api.openai.com/v1/responses
```

## Quick installation checklist

1. Install MetaTrader 5 and log in to a **demo** trading account.
2. Copy the GPT_EA release into the MT5 `MQL5/Experts/GPT_EA` folder.
3. If using source, compile `GPT_EA.mq5` in MetaEditor and resolve all compile errors before continuing.
4. Create/fund your own OpenAI API account.
5. Create your own OpenAI secret API key.
6. In MT5 open **Tools → Options → Expert Advisors**.
7. Enable **Allow WebRequest for listed URL**.
8. Add:

```text
https://api.openai.com
```

9. Attach one GPT_EA instance to a chart.
10. Turn MT5 **Algo Trading** ON.
11. In EA Inputs set:

```text
InpUseOpenAI = true
InpAPITransportMode = GPT_API_DIRECT_OPENAI
InpOpenAIAPIKey = <YOUR OWN SECRET API KEY>
InpOpenAIEndpoint = https://api.openai.com/v1/responses
InpOpenAIModel = gpt-5.6-luna   # or gpt-5.6-terra / gpt-5.6-sol / gpt-6-astra
InpRequireApproval = true
```

12. Keep the release-recommended risk settings.
13. Confirm broker symbols, D1/H4/H1/M30/M15/M5 data, recovery and safety initialization in Experts/Journal.
14. Test the OpenAI connection on demo. WebRequest does not run in Strategy Tester.
15. Test APPROVE/DENY, broker validation, stop management and restart/recovery on demo.
16. Use real-account mode only after the required release/deployment evidence and live-arm requirements for the exact build are satisfied.

## OpenAI billing note

A ChatGPT subscription does **not** automatically include OpenAI API billing. Each GPT_EA user should use their own OpenAI API platform account, enable/fund API billing, and create their own secret key.

The key itself is not purchased; API usage is billed to the user's API account.

## Recommended ChatGPT companion plan

For users who want the strongest manual ChatGPT experience alongside GPT_EA, **ChatGPT Pro 20X is the recommended premium companion plan when available**.

This recommendation is for manual work such as deeper chart analysis, reviewing GPT_EA logs, strategy research, troubleshooting and working through complex market questions.

ChatGPT Pro 20X does **not** replace the user's separately funded OpenAI API account and does not automatically add API credits, API quota or extra performance to the API key used by GPT_EA.

As of September 2026, OpenAI has temporarily paused new sign-ups/upgrades to the ChatGPT Pro $200 Pro 20X tier. Existing Pro 20X subscribers can continue using it. New users should use the best currently available plan and may move to Pro 20X if/when OpenAI reopens enrollment.

See **`OPENAI_ACCOUNT_RECOMMENDATION.md`** for the full recommendation and distinction between ChatGPT subscriptions and API usage.

## Security

Never send your API key to the GPT_EA developer/support team.

Do not share an MT5 `.set` preset after saving your API key in it. Vendor/release presets should always contain a blank API-key field; the user should enter the secret locally after loading the preset.

For troubleshooting, share only redacted Journal/Experts output, HTTP status/error, request ID, MT5 build, broker/server and symbol names.

## Full guide

Read **`USER_INSTALLATION_GUIDE.md`**, **`FIRST_RUN_CHECKLIST.md`**, and **`API_KEY_TROUBLESHOOTING.md`** before first live use. The full guide covers:

- OpenAI account/billing setup;
- API key creation and security;
- MT5 WebRequest permission;
- model selection;
- broker symbol configuration;
- demo startup checks;
- API troubleshooting;
- release-block messages;
- real-account activation.

## Real-account legal acknowledgement

Before a REAL account can clear the R9 customer-risk/legal gate, the customer must read the commercial terms and trading-risk disclosure and enter the acknowledgement personally. Distributed presets must leave these fields unaccepted/blank.

    InpAcceptGPTCommercialTerms = true
    InpAcceptGPTTradingRisk = true
    InpGPTTermsAcceptancePhrase = I ACCEPT GPT_EA TERMS AND TRADING RISK
    InpCustomerLicenseReference = <LICENSE REFERENCE ISSUED TO CUSTOMER>
    InpAcknowledgeNoProfitGuarantee = true
    InpAcknowledgePossibleTotalLoss = true
    InpAcknowledgeAILimitations = true
    InpAcknowledgeBrokerThirdPartyRisk = true
    InpAcknowledgePersonalResponsibility = true
    InpAcknowledgeDemoFirst = true
    InpCustomerJurisdiction = <JURISDICTION CODE>
    InpAcceptedGPTTermsVersion = GPT_EA_TERMS_20260917_V1
    InpAcceptedGPTRiskAckVersion = GPT_EA_RISK_ACK_V1

This acknowledgement does not guarantee profitability and does not waive rights or liabilities that applicable law does not allow to be waived.
