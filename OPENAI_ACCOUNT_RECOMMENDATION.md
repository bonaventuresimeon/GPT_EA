# GPT_EA OpenAI Account Recommendation

## Recommended premium companion plan

For users who also want to use ChatGPT manually alongside GPT_EA for deeper chart review, troubleshooting, trade-journal analysis, prompt refinement and research, the premium recommendation is **ChatGPT Pro 20X when available**.

ChatGPT Pro 20X is recommended as a companion product because it is intended for heavier, more advanced ChatGPT usage and access to premium ChatGPT capabilities.

### Important distinction

ChatGPT Pro 20X and the OpenAI API are separate products.

Buying or subscribing to ChatGPT Pro 20X does **not**:

- add API credits to GPT_EA;
- increase the balance of the user's API account;
- automatically increase GPT_EA API rate limits;
- make an API key itself more powerful;
- replace the need for a funded OpenAI API account.

GPT_EA still requires each user to:

1. create/use their own OpenAI API platform account;
2. enable/fund API billing separately;
3. create their own secret API key;
4. select an appropriate API model;
5. configure the key locally in MT5.

## Recommended setup for maximum overall experience

For users who want the strongest overall GPT_EA + ChatGPT workflow:

```text
ChatGPT Pro 20X (when available)
+
separately funded OpenAI API account
+
user's own OpenAI API key
+
high-quality API model supported by GPT_EA
+
GPT_EA running on MT5/VPS
```

The ChatGPT subscription helps the user outside the EA—for manual analysis, research, reviewing logs, investigating rejected setups, comparing strategies and working with supporting documents.

The API account powers the automated GPT calls made by GPT_EA.

## Recommended API model ladder

For the API model used by GPT_EA:

- `gpt-5.6-luna` — lower-cost/high-volume default.
- `gpt-5.6-terra` — stronger intelligence/cost balance.
- `gpt-5.6-sol` — stronger complex professional reasoning.
- `gpt-6-astra` — **maximum-intelligence recommendation** for the hardest end-to-end analysis when the additional API cost/latency is acceptable.

OpenAI currently identifies GPT-6 Astra as its most capable model and supports `gpt-6-astra` on the Responses API. ChatGPT Pro 20X and `gpt-6-astra` are separate choices: Pro 20X affects the user's ChatGPT experience, while the API model configured in `InpOpenAIModel` affects GPT_EA's automated calls.

## Current availability note

As of September 2026, OpenAI has temporarily paused new sign-ups/upgrades to the ChatGPT Pro $200 **Pro 20X** tier. Existing Pro 20X subscribers can continue using it. New users should choose the best currently available ChatGPT plan for their needs and may move to Pro 20X if/when OpenAI reopens enrollment.

This availability note can change, so users should check current OpenAI plan information before subscribing.

## Performance note

For GPT_EA itself, API performance depends primarily on:

- the API model selected in `InpOpenAIModel`;
- OpenAI API availability;
- the user's API project rate/usage limits;
- available API billing/credits;
- request size/context;
- network/VPS latency;
- GPT_EA's timeout/backoff configuration.

Therefore, ChatGPT Pro 20X is a **recommended premium companion subscription**, not a technical requirement for GPT_EA operation.

For users seeking the strongest overall setup, the premium recommendation is **Pro 20X for manual ChatGPT work plus `gpt-6-astra` for GPT_EA API calls**, provided the user accepts the higher API cost and the model is available to their API project.
