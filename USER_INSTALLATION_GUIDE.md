# GPT_EA — New User Installation & Setup Guide

This guide is for a new GPT_EA user installing the Expert Advisor on MetaTrader 5 for the first time.

Use these companion checklists during setup:

- `FIRST_RUN_CHECKLIST.md` — first-launch PASS/FAIL checklist.
- `API_KEY_TROUBLESHOOTING.md` — safe API/WebRequest troubleshooting without exposing the user's secret key.
- `TRADING_RISK_DISCLOSURE.md` — no-profit guarantee and trading-risk disclosure.
- `TERMS_AND_CONDITIONS.md` / `COMMERCIAL_LICENSE.md` — legal and license terms.
- `ANTI_PIRACY_LICENSE_ENFORCEMENT.md` — anti-copying/anti-circumvention policy.

## Important: every user uses their own OpenAI API account

GPT_EA is designed so that each user can enter their **own OpenAI API key** locally in MetaTrader 5.

The OpenAI API key itself is not purchased. The user creates a secret API key in the OpenAI API platform and funds the API account with billing/credits. ChatGPT subscriptions and OpenAI API billing are separate.

Official OpenAI references:

- API keys: https://help.openai.com/en/articles/4936850
- API billing: https://help.openai.com/en/articles/9039756
- Prepaid API billing: https://help.openai.com/en/articles/8264644
- OpenAI models: https://platform.openai.com/docs/models

Never send your OpenAI API key to the GPT_EA developer, broker, support agent, Telegram group, Discord server or another user.

## 1. What you need

Before installing GPT_EA, make sure you have:

- Windows PC or Windows VPS capable of running MetaTrader 5 continuously;
- MetaTrader 5 desktop terminal installed;
- an MT5 trading account from a supported broker;
- stable internet connection;
- GPT_EA release files;
- your own OpenAI API platform account;
- an active API billing balance/payment method;
- your own OpenAI secret API key.

A VPS is recommended for continuous operation, but it is not required for initial setup or demo testing.

## 2. Download/install MetaTrader 5

Install MetaTrader 5 from your broker or the official MetaTrader source.

Open MT5 and log in to your trading account.

For first installation, use a **demo account**. Do not begin with a real-money account.

Confirm that:

- the terminal shows a live connection;
- Market Watch is receiving prices;
- the chart is updating;
- Algo Trading is available in the terminal.

## 3. Install the GPT_EA files

In MetaTrader 5:

1. Click **File → Open Data Folder**.
2. Open `MQL5`.
3. Open `Experts`.
4. Create a folder named `GPT_EA` if one does not already exist.
5. Copy the GPT_EA files into that folder.

### If you received a compiled release

Copy `GPT_EA.ex5` and any required release files supplied with it into the GPT_EA folder.

You do not need the `.mq5` source code to run a valid compiled `.ex5` release.

### If you received the source package

Keep `GPT_EA.mq5` and all required `.mqh` files together exactly as supplied.

Open `GPT_EA.mq5` in MetaEditor and press **F7 / Compile**.

A production build should compile with:

- 0 errors;
- no unresolved production warnings.

Do not use a partially compiled or modified source tree for live trading.

After copying/compiling, return to MetaTrader 5 and refresh the Navigator or restart MT5 if GPT_EA does not appear.

## 4. Create and fund your OpenAI API account

Open the OpenAI API platform using your own account.

Important: a ChatGPT Free, Go, Plus, Pro, Business or other ChatGPT subscription is separate from API billing. API use must be enabled/funded separately.

For prepaid API billing:

1. Open the API billing section.
2. Add payment details.
3. Purchase API credits or configure the billing option available on your account.
4. Optionally configure auto-recharge and spending controls.
5. Confirm that the API account has an available balance before testing GPT_EA.

OpenAI currently documents prepaid API billing for new API accounts and a minimum initial credit purchase of USD 5, subject to account/country availability and future OpenAI changes.

## 5. Create your personal OpenAI API key

In the OpenAI API platform:

1. Open the API Keys page for the project you want GPT_EA to use.
2. Select **Create new secret key**.
3. Give the key a recognizable name such as `GPT_EA_MT5`.
4. Create the key.
5. Copy the full secret immediately and store it securely.

OpenAI only shows the full secret when it is created. If it is lost, create a new key instead of trying to recover the old secret.

### Security rule

Do not:

- publish the key;
- commit it to GitHub;
- send it by email/chat to support;
- put it in screenshots;
- paste it into public logs;
- share a `.set` file after saving the key inside it.

If you believe the key was exposed, revoke/delete it in the OpenAI API platform and create a replacement.

## 6. Allow OpenAI WebRequest in MT5

GPT_EA uses MQL5 `WebRequest()` to call the OpenAI Responses API.

MetaTrader blocks web requests unless the user explicitly allow-lists the destination.

In MT5:

1. Click **Tools → Options**.
2. Open the **Expert Advisors** tab.
3. Tick **Allow WebRequest for listed URL**.
4. Add exactly:

```text
https://api.openai.com
```

5. Click **OK**.

Do not add random third-party URLs for DIRECT_OPENAI mode.

Official MQL5 WebRequest reference:

https://www.mql5.com/en/docs/network/webrequest

Note: MQL5 WebRequest does not execute in the Strategy Tester. Actual API connectivity must therefore be tested by attaching GPT_EA to a demo chart.

## 7. Attach GPT_EA to a chart

In MT5:

1. Open the **Navigator** panel.
2. Find **Expert Advisors → GPT_EA**.
3. Drag GPT_EA onto one liquid chart.
4. Allow algorithmic trading for the EA when prompted.
5. Turn the MT5 **Algo Trading** toolbar button ON.

GPT_EA is multi-symbol. Unless your release documentation specifically says otherwise, use **one GPT_EA instance per trading account/magic configuration** rather than attaching copies to many charts.

## 8. Enter your OpenAI settings

Open the EA **Inputs** tab and configure:

```text
InpUseOpenAI = true
InpAPITransportMode = GPT_API_DIRECT_OPENAI
InpOpenAIAPIKey = <YOUR OWN SECRET API KEY>
InpOpenAIEndpoint = https://api.openai.com/v1/responses
```

The default model is:

```text
InpOpenAIModel = gpt-5.6-luna
```

Current OpenAI model choices documented for the Responses API include:

- `gpt-5.6-luna` — lower-cost/high-volume option;
- `gpt-5.6-terra` — balanced intelligence/cost;
- `gpt-5.6-sol` — highest-quality GPT-5.6 option for complex reasoning.
- `gpt-6-astra` — OpenAI's current flagship and **maximum-intelligence option** for the hardest end-to-end analysis; use when the higher API cost/latency is acceptable.

Model availability, pricing and limits can change. Check the current OpenAI model/pricing documentation before changing the default.

Using your own API key gives your installation its own API billing, quota and usage limits. The key itself does not make the model smarter; model choice, prompt/context quality, available tools and account limits determine API behavior/performance.

## 9. Recommended first-run trading settings

For a new user, keep the safety controls conservative:

```text
InpRequireApproval = true
InpEnableApprovedExecution = true
InpUseOpenAI = true
InpAPITransportMode = GPT_API_DIRECT_OPENAI
InpAPIRequireProxyOnReal = false
```

Start with the release's recommended risk preset. Do not increase risk because a setup is labelled high confidence.

Do not disable release, stop, recovery, risk or broker-safety gates simply to make an order execute.

## 10. Configure symbols for your broker

GPT_EA supports broker symbol resolution, but broker naming still needs to be verified.

The default symbol input may include logical/common names such as:

```text
XAUUSD,US100.cash,GER40.cash
```

Your broker may instead use names such as:

- XAUUSDm;
- XAUUSD.a;
- NAS100;
- USTEC;
- US100;
- DE40;
- GER40;
- DAX40.

Before trading:

1. open Market Watch;
2. confirm the relevant broker symbols exist and receive live ticks;
3. make sure GPT_EA resolves the intended instruments;
4. review the broker-symbol profile printed by the EA;
5. do not assume two brokers use identical contract sizes, tick values, stops/freeze levels or margin rules.

## 11. First demo startup checklist

After attaching GPT_EA to a demo chart, check the **Experts** and **Journal** tabs.

A healthy first run should show no unresolved critical startup error and should confirm that the EA can:

- see the configured/resolved symbols;
- receive synchronized D1/H4/H1/M30/M15/M5 data;
- receive fresh quotes;
- initialize recovery/checkpoint state;
- initialize strategy intelligence;
- initialize the release/safety gate;
- access the OpenAI endpoint when a GPT request is actually required;
- keep the account under manual approval control.

If OpenAI is required for a candidate but the API cannot be reached, GPT_EA should follow its configured WAIT/NO-TRADE/fail-closed policy rather than blindly authorizing a trade.

## 12. Test the OpenAI connection on demo

Because WebRequest is unavailable in Strategy Tester, perform the real API connection test on a demo account.

Verify:

1. `https://api.openai.com` is still in the MT5 WebRequest allow-list.
2. `InpUseOpenAI=true`.
3. `InpAPITransportMode=GPT_API_DIRECT_OPENAI`.
4. `InpOpenAIAPIKey` contains your personal key.
5. The API account has usable billing/credits.
6. The configured model is available to your API project.
7. The computer/VPS has working internet and HTTPS/TLS access.
8. Trigger/allow a GPT_EA scan and inspect Experts/Journal output.

Possible responses:

- HTTP 2xx: API request reached OpenAI successfully;
- 401/403: key/authentication/permission problem;
- 429: rate limit, usage/spend limit or billing/credit issue depending on the returned OpenAI error;
- 5xx: upstream service problem;
- synthetic 599: MT5/network/DNS/TLS/WebRequest failure;
- synthetic 598: GPT_EA transport backoff/circuit block is active.

## 13. API cost and performance choices

Each user pays for their own API usage.

Recommended approach:

- begin with `gpt-5.6-luna` while setting up and demo testing;
- use `gpt-5.6-terra` for a stronger intelligence/cost balance;
- use `gpt-5.6-sol` for stronger complex professional reasoning;
- consider `gpt-6-astra` for the **highest available reasoning capability** when the additional API cost/latency is acceptable and the model is available to your project.

Do not judge performance from one trade. Validate API reliability and trading behavior over a meaningful demo period.

## 14. Approval workflow

GPT_EA is designed around human authorization.

Typical flow:

```text
Market scan
→ multi-timeframe analysis
→ strategy classification
→ technical/confluence validation
→ live news/intermarket checks
→ GPT adversarial review
→ risk/release/broker checks
→ HIGH-CONFIDENCE / WAIT / NO TRADE
→ APPROVE or DENY
→ fresh pre-entry revalidation
→ OrderCheck
→ execution
```

If a setup changes before you approve it, the EA may reject the stale approval.

## 15. Demo before real trading

A new installation should remain on demo until the required release/test process for that exact build and deployment is complete.

Do not use a real account simply because:

- GPT requests work;
- the dashboard looks correct;
- one Strategy Tester run passed;
- one demo trade won;
- another user has already tested a different broker/account.

Real-account arming is intentionally stricter than demo operation.

## 16. Real-account activation

Before live arming, read the legal package and `CUSTOMER_RISK_ACKNOWLEDGEMENT_FLOW.md`. The R9 customer-risk gate requires the customer to personally acknowledge each material risk item and the exact current terms/risk versions; a vendor preset must never pre-accept these fields.

Required live acknowledgement inputs:

    InpAcceptGPTCommercialTerms = true
    InpAcceptGPTTradingRisk = true
    InpAcknowledgeNoProfitGuarantee = true
    InpAcknowledgePossibleTotalLoss = true
    InpAcknowledgeAILimitations = true
    InpAcknowledgeBrokerThirdPartyRisk = true
    InpAcknowledgePersonalResponsibility = true
    InpAcknowledgeDemoFirst = true
    InpCustomerJurisdiction = <JURISDICTION CODE>
    InpAcceptedGPTTermsVersion = GPT_EA_TERMS_20260917_V1
    InpAcceptedGPTRiskAckVersion = GPT_EA_RISK_ACK_V1
    InpGPTTermsAcceptancePhrase = I ACCEPT GPT_EA TERMS AND TRADING RISK
    InpCustomerLicenseReference = <YOUR ISSUED LICENSE REFERENCE>

A customer must not set these merely to bypass a block without actually reading/accepting the terms.


GPT_EA contains explicit real-account release gates.

A certified live deployment may require:

- the current release validation ID;
- MetaEditor compile evidence;
- artifact identity/hash evidence;
- Strategy Tester/matrix results;
- broker/deployment validation;
- recovery and stop-management validation;
- API transport validation;
- demo-soak evidence;
- final GO/NO-GO review;
- live arm phrase;
- human approval enabled for the initial deployment.

Use the certified release package/preset supplied for the intended broker/deployment. Do not manually set evidence flags to `true` merely to bypass a blocked release.

Because every user enters their own API key locally, do not distribute a production `.set` file containing an actual user key. Secret-bearing inputs must be entered by the user after loading the non-secret certified settings.

## 17. Do not save/share your API key in presets

MT5 input presets (`.set`) can store input values.

If you save a preset after entering your OpenAI API key, the key may be stored in that preset.

Therefore:

- use a clean vendor/release preset with the API key field blank;
- enter your API key manually after loading the preset;
- do not upload/share/export a preset containing your secret;
- if you accidentally share one, revoke that OpenAI key and create a new one.

## 18. Common problems

### GPT_EA does not appear in Navigator

- confirm files are under the correct MT5 Data Folder;
- refresh Expert Advisors;
- restart MT5;
- if using source, compile `GPT_EA.mq5` in MetaEditor.

### Algo Trading is disabled

- enable the terminal Algo Trading toolbar button;
- check Tools → Options → Expert Advisors;
- confirm the EA properties allow algorithmic trading;
- confirm the trading account permits Expert Advisors.

### `WebRequest` or OpenAI API fails

For the complete safe procedure, use **`API_KEY_TROUBLESHOOTING.md`**. Never send your API key to support.

- add `https://api.openai.com` to the allowed URL list;
- confirm internet/TLS connectivity;
- confirm DIRECT_OPENAI is selected;
- confirm the endpoint is `https://api.openai.com/v1/responses`;
- remember WebRequest will not work in Strategy Tester.

### 401 or 403 from OpenAI

- check that the API key was copied correctly;
- make sure it has not been revoked;
- verify project/key permissions;
- create a new key if necessary.

### 429 / quota / billing error

- read the exact OpenAI error code;
- check API billing/credits;
- check project/organization spend limits;
- check API rate limits;
- wait for GPT_EA's configured backoff when the error is a temporary rate limit.

### Symbols unavailable

- open Market Watch and show the broker symbols;
- confirm broker suffix/prefix naming;
- check whether the broker offers the requested asset;
- inspect GPT_EA symbol-resolution logs.

### EA says release blocked

Read the exact release reason in Experts/Journal/dashboard.

Do not turn off the gate blindly. Resolve the missing condition: compile/evidence, deployment identity, API transport, data synchronization, quote freshness, recovery invariant, broker rule, safety condition or live-arm requirement.

### No trade is opening

A working GPT_EA is allowed to return **WAIT** or **NO TRADE**. Successful installation does not mean it should always produce an entry.

## 19. Recommended new-user sequence

Use this order:

```text
1. Install MT5
2. Login to a DEMO trading account
3. Install GPT_EA
4. Create/fund your OpenAI API account
5. Create your personal API key
6. Add https://api.openai.com to MT5 WebRequest allow-list
7. Attach one GPT_EA instance
8. Enter your personal API key
9. Keep DIRECT_OPENAI selected
10. Keep APPROVAL required
11. Confirm symbols/data/recovery initialize correctly
12. Test a real OpenAI request on demo
13. Test APPROVE/DENY behavior
14. Observe stop/recovery/risk behavior on demo
15. Complete the required release/demo validation
16. Use only the certified live preset/build for real-account activation
```

## 20. Support information to provide — without secrets

If you need installation support, provide:

- MT5 build number;
- broker/company name;
- trade server name;
- demo or real account type — never account password;
- symbol names shown in Market Watch;
- GPT_EA version/release ID;
- exact Experts/Journal error text;
- HTTP status or synthetic transport status;
- OpenAI request ID if shown;
- screenshot with all API keys, tokens, account numbers and private data redacted.

Never provide:

- OpenAI API key;
- proxy token;
- MT5 master/investor password;
- payment-card information;
- unredacted secret-bearing `.set` files.

## 21. Final rule

A successful GPT_EA installation means the EA is correctly loaded, connected, receiving valid market data, permitted to use OpenAI WebRequest, using the user's own funded API account, and passing its safety/release checks.

It does **not** guarantee that a trade will be generated or profitable.
