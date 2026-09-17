# GPT_EA OpenAI Intelligence Policy

This policy applies only to the standalone `GPT_EA` repository.

## Separation of responsibilities

GPT_EA uses two logically separate OpenAI roles:

1. **Live web/news intelligence** — frequent, current-information search used to identify scheduled or unexpected market risks capable of invalidating a technical setup. This path uses the configured `InpOpenAIModel` and the structured web-search contract in Parts 16/22.
2. **Deep adversarial trade validation** — a final reasoning pass that attempts to disprove an otherwise high-quality candidate. Part26 defaults this role to `gpt-5.6-sol` with `high` reasoning effort and maps the scanner's final `CallOpenAI()` review through `CallOpenAIDeep()`.

The two roles are deliberately separated so live news can remain responsive/cost-aware while the final validation receives greater reasoning depth.

## Live web/news contract

When enabled, the hardened web path requests current information through OpenAI web search and validates a strict structured result with:

- `verdict`: `CLEAR`, `WATCH` or `BLOCK`
- `risk_score`: 0–100
- scheduled `events`
- `breaking_news`
- `invalidation_channel`
- `intermarket` explanation
- `sources`
- `as_of_utc`

Source attribution is required by default. A malformed or missing structured result is not silently treated as `CLEAR`.

A compatibility free-text fallback is allowed, but it is explicitly downgraded to `WATCH`. If both structured and fallback calls fail, `InpFailClosedHighConfidenceNews=true` blocks a high-confidence authorization rather than silently executing without current-news intelligence.

Repeated failures expose a web-intelligence circuit-breaker condition. The circuit breaker does not alter existing position protection; it prevents new authorization from pretending that the news layer is healthy.

## Fresh intermarket requirement

The web prompt and final execution gate use the freshness-filtered intermarket layer. Stale broker bars are excluded. If too few fresh relevant reference instruments exist, the result is neutral/N/A rather than fabricated confirmation.

## Deep adversarial review

Part26 defaults:

- model: `gpt-5.6-sol`
- reasoning effort: `high`
- maximum output tokens: 1200

The adversarial prompt must try to invalidate the setup and explicitly review:

- classification/regime;
- MTF alignment;
- retracement versus reversal;
- counter-trend status;
- entry confirmation;
- stop logic;
- target logic;
- realistic R:R;
- liquidity/fakeout risk;
- volatility;
- news;
- intermarket evidence;
- counterargument;
- time invalidation;
- price invalidation;
- execution warning.

The GPT layer can veto/downgrade a trade when enabled. It cannot bypass deterministic calendar, yield, spread, risk, broker, release-safety, stop-protection, historical-research, structure or `OrderCheck()` gates.

## MT5 configuration

For live OpenAI requests, the terminal must permit WebRequest access to:

`https://api.openai.com`

The API key is entered locally through EA inputs. The repository default remains blank and no key may be committed.

## Failure policy

- Strategy Tester: WebRequest is unavailable; test deterministic logic and inject representative news/failure scenarios separately.
- Missing API key: explicit unavailable state; high-confidence live behavior follows fail-closed configuration.
- HTTP/API error: explicit error; no invented response.
- Structured parse error: fallback/downgrade or block according to policy.
- Stale cached intelligence: refresh is required after the configured maximum age.
- Fresh BLOCK verdict or risk score above the block threshold: no new execution.
- Fresh WATCH verdict: setup remains conditional and must still pass all deterministic gates.

## Release gate

Do not treat the OpenAI layer as live-ready until all applicable cases in `INTELLIGENCE_HARDENING_TESTS.md` have been exercised in an MT5 demo environment with real WebRequest access. MetaEditor compilation and demo-soak behavior remain mandatory hard release gates.
