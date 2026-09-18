# GPT EA Premium Dashboard & Approval Cockpit

## Purpose

This UI layer gives the monolithic `GPT_EA.mq5` a premium MetaTrader cockpit while preserving the existing fail-closed execution architecture. The visual layer never authorizes a trade by itself. APPROVE only allows the EA to continue into fresh strategy, news, intermarket, release, recovery, risk, broker, OrderCheck, and execution validation.

## Visual system

- Dark luxury base: near-black navy panels with restrained blue, gold, emerald, crimson and violet accents.
- Candidate dashboard: Market Intelligence, Trade Approval / Level Ladder, Risk & Safety, and EA Action sections.
- Live dashboard: Market / Position Intelligence, Trade Ladder / Profit Protection, Risk & Safety, and EA Management sections.
- Approval hero: large timed APPROVE / DENY card with confidence, strategy, effective R:R, Entry, SL, projected B.E., TP1/TP2/TP3, trail start, countdown and progress bar.
- Native MT5 hover: chart mouse-move events lift/highlight the approval buttons.
- Native MT5 animation: tick/timer refresh produces restrained border/status pulsing and countdown progression.

## Lifecycle badges

Candidate states include ANALYZING / WAITING, FINAL EXECUTION CHECKS ACTIVE, APPROVAL PENDING and EXPIRING.

Decision feedback includes APPROVED, DENIED, EXPIRED, BLOCKED AFTER APPROVAL and ACTIVE / TRADE EXECUTED.

Live-position states include ACTIVE, TP1 HIT, B.E. ACTIVE, TP2 HIT / RUNNER and TRAILING.

## Chart ladder

Candidate chart levels:
- Entry = 0.00R
- Initial SL = -1.00R
- Projected B.E. protection
- TP1 = +1.00R
- TP2 = +2.00R
- TP3 / runner = +3.00R
- Trail-start level = configured `InpTrailStartR`

Live chart levels additionally show the current authoritative stop stage and locked R value. Existing trailing movement segments remain visible as the stop advances.

## Approval safety

1. No user response before `InpApprovalTimeoutSeconds` expires => the pending setup is deleted and marked EXPIRED.
2. DENY => pending setup is deleted and cooldown is applied.
3. APPROVE => the pending approval is consumed, then `FreshApprovalValidation()` reruns the complete execution checks.
4. If any fresh gate fails, the UI shows BLOCKED AFTER APPROVAL and no order is opened.
5. Visual effects cannot bypass release, recovery, stop-observability, news, intermarket, model-trust, risk, broker or OrderCheck gates.

## OpenAI integration

The EA keeps the API key local through `InpOpenAIAPIKey`; no real key is committed to GitHub.

The active endpoint is:

`https://api.openai.com/v1/responses`

The hardened review path uses `CallOpenAIDeep()`. Deep review defaults to `gpt-5.6-sol` with high reasoning effort, while the base configurable model remains available for lower-cost operation.

In MetaTrader 5, add `https://api.openai.com` to:

Tools > Options > Expert Advisors > Allow WebRequest for listed URL

The dashboard reports OpenAI as OFF, TESTER OFFLINE, KEY MISSING, or CONFIGURED. This is a configuration state, not a promise that every remote request will succeed.

## Main premium inputs

- `InpPremiumDashboard`
- `InpPremiumUIAnimations`
- `InpDashboardWidth`
- `InpDashboardHeight`
- `InpDashboardRefreshMs`
- `InpDashboardTitleFont`
- `InpDashboardBodyFont`
- `InpApprovalHeroX`
- `InpApprovalHeroY`
- `InpApprovalHeroWidth`
- `InpApprovalHeroHeight`
- `InpApprovalAnimationMs`
- `InpApprovalDangerSeconds`
- `InpApprovalFeedbackSeconds`
- `InpEnableApprovalHover`

## Object namespace

Approval:
- `GPT_EA_APPROVAL_PANEL`
- `GPT_EA_APPROVAL_ACCENT`
- `GPT_EA_APPROVAL_TITLE`
- `GPT_EA_APPROVAL_STATUS`
- `GPT_EA_APPROVAL_META`
- `GPT_EA_APPROVAL_LADDER`
- `GPT_EA_APPROVAL_TIMER`
- `GPT_EA_APPROVAL_PROGRESS_BG`
- `GPT_EA_APPROVAL_PROGRESS_FG`
- `GPT_EA_APPROVE_BTN`
- `GPT_EA_DENY_BTN`

Dashboard:
- `GPT_EA_DASH_MARKET_CARD`
- `GPT_EA_DASH_TRADE_CARD`
- `GPT_EA_DASH_RISK_CARD`
- `GPT_EA_DASH_ACTION_CARD`

Chart:
- `GPT_EA_LEVEL_ENTRY`
- `GPT_EA_LEVEL_SL`
- `GPT_EA_LEVEL_BE`
- `GPT_EA_LEVEL_TRAIL_START`
- `GPT_EA_LEVEL_TP1`
- `GPT_EA_LEVEL_TP2`
- `GPT_EA_LEVEL_TP3`
- `GPT_EA_LEVEL_LIVE_SL`

## Validation status

Repository-side structural checks confirm balanced braces, parentheses and brackets after the premium UI patch. A real MetaEditor compile is still required on a Windows/MT5 environment before release or live trading.
