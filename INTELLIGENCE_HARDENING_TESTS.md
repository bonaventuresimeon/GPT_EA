# GPT_EA Intelligence Hardening Release Tests

These tests extend `INTELLIGENCE_TEST_MATRIX.md`. All applicable **BLOCKING** cases must pass before live arming. A green static GitHub Action is necessary but not sufficient; MetaEditor compile, Strategy Tester, broker/recovery/stop tests and demo soak remain mandatory.

| ID | Severity | Area | Scenario | Expected result |
|---|---|---|---|---|
| HARD-001 | BLOCKING | Structured news | Web search returns schema-conformant CLEAR result with sources | Parse succeeds; risk score and source text are retained; no block unless deterministic layers block |
| HARD-002 | BLOCKING | Structured news | Web response is malformed / missing a required field | Structured parse fails; fallback is explicitly downgraded; no silent high-confidence trust |
| HARD-003 | BLOCKING | Structured news | Result has no source attribution while source requirement is enabled | Treat structured result as invalid; apply fallback/fail-closed policy |
| HARD-004 | BLOCKING | News availability | OpenAI key/WebRequest unavailable on a high-confidence candidate | With `InpFailClosedHighConfidenceNews=true`, authorization is blocked |
| HARD-005 | HIGH | News availability | Low-quality candidate below strategy threshold | Web search may be deferred; candidate cannot become executable high-confidence merely because news was skipped |
| HARD-006 | BLOCKING | News cache | Cached web intelligence exceeds configured maximum age | Fresh request required before execution; stale cache cannot authorize |
| HARD-007 | HIGH | News circuit breaker | Repeated structured/fallback failures reach threshold | Circuit-breaker status is visible; high-confidence fail-closed policy remains enforceable |
| HARD-008 | BLOCKING | Intermarket freshness | DXY/yield/VIX reference bars are stale | Stale components are excluded; no severe confirmation/contradiction is fabricated |
| HARD-009 | BLOCKING | Intermarket freshness | At least minimum fresh relevant components exist | Score uses only fresh components and can block on severe contradiction |
| HARD-010 | BLOCKING | News/intermarket consistency | Web-news prompt is built while raw broker references are stale | Prompt receives freshness-filtered intermarket report through Part22 bridge |
| HARD-011 | BLOCKING | Walk-forward | Strategy has adequate sample; recent OOS avg R/PF below thresholds | Research gate returns NO TRADE when negative walk-forward blocking is enabled |
| HARD-012 | HIGH | Walk-forward | Strategy sample below minimum | Evidence is marked developing/neutral; never described as proven edge |
| HARD-013 | HIGH | Drift | Training segment positive but recent segment degrades below zero/PF 1 | Drift is reported explicitly and recent gate controls authorization |
| HARD-014 | BLOCKING | Context evidence | Current session bucket has adequate negative sample | Current strategy is blocked even if aggregate strategy history is positive |
| HARD-015 | BLOCKING | Context evidence | Current direction bucket (LONG/SHORT) is negative with adequate sample | Direction-specific evidence can block |
| HARD-016 | BLOCKING | Context evidence | High/low volatility bucket is negative with adequate sample | Volatility-context evidence can block |
| HARD-017 | BLOCKING | Context evidence | Near-news context bucket is negative with adequate sample | News-proximity evidence can block |
| HARD-018 | HIGH | Context evidence | M15/M5 timeframe bucket is developing | Report developing sample; do not call it reliable proof |
| HARD-019 | BLOCKING | Retracement | HTF trend intact; three-bar counter move is non-impulsive | Classify as corrective/retracement pressure rather than automatic reversal |
| HARD-020 | BLOCKING | Retracement | Counter move exceeds impulse thresholds with volume | Flag impulsive / possible trend-failure pressure and demand structural confirmation |
| HARD-021 | HIGH | Retracement target | EMA/VWAP/Fibonacci/previous-session levels are available | Output a likely retracement destination based on nearest valid value/structure level |
| HARD-022 | BLOCKING | Chase | Trend/momentum setup is overextended beyond chase ATR threshold | Downgrade executable trend/breakout candidate to WAIT for retracement/retest |
| HARD-023 | BLOCKING | Reversal | HTF swing level plus opposite M15/M5 structure has not failed | Do not label full reversal solely from counter movement |
| HARD-024 | BLOCKING | Extreme regime | ATR ratio above extreme-high or below extreme-low threshold | NO TRADE / out-of-distribution block |
| HARD-025 | BLOCKING | Extreme regime | Opening range exceeds extreme threshold | NO TRADE / reanalyze instead of reusing normal stop/target assumptions |
| HARD-026 | BLOCKING | Session | London/New York overlap conditions are present | `LONDON_NY_OVERLAP` takes precedence over generic London/NY bucket |
| HARD-027 | HIGH | Session | London/NY closing-liquidity transition | Score is penalized; fast setup is downgraded to WAIT when configured |
| HARD-028 | BLOCKING | Expiry | Breakout candidate | Base candle expiry is faster than retracement candidate, then ATR/OR adaptation is applied |
| HARD-029 | BLOCKING | Expiry | Counter-trend scalp | Uses short follow-through window; stale scalp invalidates quickly |
| HARD-030 | HIGH | Expiry | Swing retracement | Receives longer base follow-through window than breakout/scalp, within AdaptiveExpiry bounds |
| HARD-031 | BLOCKING | Pullback vs BRT R:R | Spread/slippage/commission increase materially | Thesis displays separate realistic weighted R:R for pullback and breakout-retest |
| HARD-032 | BLOCKING | Partial exits | TP1/TP2 partial percentages change | Realistic weighted reward and R:R change accordingly |
| HARD-033 | BLOCKING | Disproof | Opposing evidence / false break / exhaustion exists | Deterministic disproof checklist surfaces it before authorization |
| HARD-034 | BLOCKING | Revalidation | Research evidence changes to BLOCK after user sees approval prompt | Fresh strict revalidation cancels execution |
| HARD-035 | BLOCKING | Revalidation | Intermarket data becomes stale/severely contradictory before click | Execution is cancelled or contradiction is neutralized if stale |
| HARD-036 | BLOCKING | Revalidation | Live news changes CLEAR/WATCH to BLOCK | No order is sent |
| HARD-037 | HIGH | Observability | Any full scan completes | `GPT_EA_Intelligence.csv` records time, asset, classification, state, strategy decision, final decision and card |
| HARD-038 | HIGH | Observability | EA restarts | Last decision timestamp/status is recoverable through symbol Global Variables; new scan still revalidates |
| HARD-039 | BLOCKING | Security | Repository scan | No real OpenAI API key is committed; input default remains blank |
| HARD-040 | BLOCKING | Static architecture | Required hardening module or macro wiring is removed | GitHub static release workflow fails |
| HARD-041 | BLOCKING | Compile | MetaEditor compile of `GPT_EA.mq5` | 0 errors; warnings reviewed and accepted/fixed |
| HARD-042 | BLOCKING | Strategy Tester | Representative symbols/regimes | No runtime array/history/order errors; NO TRADE/WAIT/HIGH-CONFIDENCE behavior matches fixtures |
| HARD-043 | BLOCKING | Demo soak | Live/demo calendar + web + broker feed | No stale authorization, duplicate execution, unprotected position, or silent intelligence failure |

## Required release sequence

1. GitHub static release gate PASS.
2. MetaEditor compile: 0 errors; warnings reviewed.
3. Strategy Tester across trend, retracement, reversal, range, breakout, news-proxy and extreme-volatility cases.
4. Broker matrix + recovery invariants + stop-management HIGH-priority matrix.
5. `INTELLIGENCE_TEST_MATRIX.md` and this hardening matrix completed for applicable cases.
6. Controlled OpenAI/WebRequest failure injection and structured-output validation.
7. Demo soak with economic calendar, live web intelligence and correlated symbols enabled.
8. Real-account arming only after the existing release-safety gates pass.
