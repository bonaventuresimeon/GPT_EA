# GPT_EA Intelligence Release Test Matrix

This matrix is release-blocking for the new strategy/news intelligence engine. Tests must be run on demo/Strategy Tester as applicable before live arming.

| ID | Area | Scenario | Expected result |
|---|---|---|---|
| INT-001 | MTF | D1/H4/H1 bullish, M15/M5 pullback | classify trend context + healthy/deep retracement, not reversal |
| INT-002 | MTF | D1/H4/H1 bearish, M15/M5 rally | classify bearish trend with corrective retracement unless structure fails |
| INT-003 | Retracement | shallow pullback above structural support | `HEALTHY RETRACEMENT` / Retracement Entry or WAIT |
| INT-004 | Retracement | deeper move toward EMA50/support | `DEEP RETRACEMENT`, tighter validation, no automatic reversal label |
| INT-005 | Trend failure | HTF thesis structural level fails + LTF opposite structure | `TREND FAILURE` or Potential Reversal |
| INT-006 | Reversal | failure + sweep + CHOCH/BOS + divergence | Potential Reversal candidate |
| INT-007 | Counter trend | strong HTF trend without exhaustion | counter-trend score below threshold; NO TRADE/WAIT |
| INT-008 | Counter trend | sweep + exhaustion + divergence + BOS | Counter-Trend Scalp/Swing with stricter trigger |
| INT-009 | Counter trend | candidate loses swept level before entry | cancel setup |
| INT-010 | Trend | HH/HL + ADX + aligned EMA | Trend Continuation candidate |
| INT-011 | Momentum | trend + expansion + volume impulse | Momentum Continuation framework |
| INT-012 | Breakout | resistance break with displacement | Breakout classification but no chase if retest execution is absent |
| INT-013 | Breakout-retest | completed break + controlled retest | Breakout-Retest candidate |
| INT-014 | Fakeout | wick/close returns inside prior range | False Breakout state, breakout authorization blocked |
| INT-015 | Liquidity | prior low sweep + reclaim | Liquidity Sweep state / possible bullish reversal/retracement framework |
| INT-016 | Range | low ADX, boundary rejection | Range Trade candidate |
| INT-017 | Range | price in range middle | NO TRADE / WAIT; no boundary trade |
| INT-018 | Mean reversion | range + overextension toward boundary | Mean-Reversion Setup toward equilibrium/VWAP |
| INT-019 | Consolidation | low ATR + low ADX | Consolidation state; oversized target expectations rejected |
| INT-020 | Expansion | ATR/opening range expands sharply | Range Expansion / breakout framework and shorter expiry |
| INT-021 | Exhaustion | > configured ATR overextension + divergence | Exhaustion state; continuation chase downgraded |
| INT-022 | Accumulation | range low + divergence + volume | Possible Accumulation label only, not guaranteed accumulation |
| INT-023 | Distribution | range high + divergence + volume | Possible Distribution label only |
| INT-024 | Fibonacci | retracement enters 38.2-61.8% swing zone | retracement thesis records Fibonacci/value context |
| INT-025 | Supply/demand | entry near structural demand/supply proxy | thesis identifies zone and structure invalidation |
| INT-026 | Double bottom | two lows + structure confirmation | reversal framework may use Double Bottom |
| INT-027 | Double top | two highs + structure confirmation | reversal framework may use Double Top |
| INT-028 | Divergence | lower low / higher RSI or higher high / lower RSI | divergence contributes only with structure, never alone |
| INT-029 | Previous day | breakout near PDH/PDL | previous-day breakout/retest framework selected |
| INT-030 | Asian range | London break of Asian H/L | London/Asian-range breakout framework |
| INT-031 | London sweep | London sweeps session liquidity then CHOCH | London Liquidity Sweep Reversal framework |
| INT-032 | NY open | U.S. cash opening-range break/retest | New York/U.S. cash opening-range framework |
| INT-033 | Session | end-session weak liquidity | confidence/target expectations downgraded where applicable |
| INT-034 | Volatility | ATR > 1.5x average | wider structural expectations and faster expiry |
| INT-035 | Volatility | ATR < 0.7x average | slower expiry and smaller expansion expectations |
| INT-036 | R:R | spread/slippage widens | effective R:R drops; authorization blocked below floor |
| INT-037 | Calendar | high-impact event inside block window | setup blocked |
| INT-038 | Calendar | event outside block window | event displayed but not automatically blocked |
| INT-039 | Web news | current unexpected headline materially threatens setup | web verdict BLOCK can prevent approval |
| INT-040 | Web news | relevant headline exists but not setup-threatening | WATCH/CLEAR, no forced block |
| INT-041 | Web news | API/web unavailable, fail-open configured | deterministic layers continue with explicit unavailable status |
| INT-042 | Web news | API/web unavailable, fail-closed configured | approval blocked |
| INT-043 | Intermarket | gold long + DXY/yields strongly opposite | severe conflict blocks/downgrades |
| INT-044 | Intermarket | US100 long + yields down/VIX down | supportive intermarket score |
| INT-045 | Intermarket | required symbol unavailable | no fabricated confirmation; report N/A |
| INT-046 | Yield | configured US10Y shock threshold exceeded | block |
| INT-047 | Historical | strategy sample below minimum | evidence marked developing, not proof |
| INT-048 | Historical | sufficient positive expectancy/PF | evidence gate passes |
| INT-049 | Historical | sufficient negative expectancy/PF | strategy blocked when configured |
| INT-050 | Context stats | long and short trades | separate direction buckets update |
| INT-051 | Context stats | high/normal/low volatility | volatility buckets update |
| INT-052 | Context stats | Asian/London/NY sessions | session buckets update |
| INT-053 | Context stats | near high-impact event | news-context bucket updates |
| INT-054 | Context stats | current M15 setup / M5 execution | timeframe context persists |
| INT-055 | Thesis | any candidate | all 25 thesis sections present |
| INT-056 | Counterargument | strong opposing evidence | GPT/deterministic counterargument identifies failure case |
| INT-057 | Quality | weak contradictory setup | NO TRADE |
| INT-058 | Quality | promising but trigger incomplete | WAIT FOR CONFIRMATION |
| INT-059 | Quality | all gates and trigger aligned | HIGH-CONFIDENCE TRADE SETUP |
| INT-060 | Revalidation | strategy class changes before click | stale approval cancelled / REANALYZE |
| INT-061 | Revalidation | direction flips before click | execution blocked |
| INT-062 | Revalidation | price leaves zone | execution blocked |
| INT-063 | Revalidation | web headline changes to BLOCK | execution blocked |
| INT-064 | Revalidation | intermarket becomes severe conflict | execution blocked |
| INT-065 | Revalidation | spread/R:R deteriorates | execution blocked |
| INT-066 | Revalidation | calendar/yield shock appears | execution blocked |
| INT-067 | Revalidation | historical evidence gate changes | execution blocked |
| INT-068 | Approval | NO TRADE/WAIT state | no APPROVE prompt |
| INT-069 | Approval | high-confidence but release gate fails | no executable approval |
| INT-070 | Approval | high-confidence but partial-protection hazard active | new authorization blocked |
| INT-071 | Restart | pending strategy approval restart | class/state revalidated before execution |
| INT-072 | Restart | open strategy trade restart | strategy metadata reattached by position identifier |
| INT-073 | Analytics | finalized strategy trade | class/state/direction/volatility statistics update once |
| INT-074 | Analytics | finalized session/news trade | contextual buckets update once |
| INT-075 | GPT | secondary review says WAIT | AI veto blocks when enabled |
| INT-076 | GPT | GPT invents unsupported fact in test harness | deterministic broker/calendar/news gates remain authoritative |
| INT-077 | News prompt | equity symbol | company/sector/macro risk requested |
| INT-078 | News prompt | oil symbol | OPEC/inventory/supply-demand risk requested |
| INT-079 | News prompt | FX symbol | relevant central-bank/macro/currency risk requested |
| INT-080 | News prompt | gold symbol | USD/yields/inflation/safe-haven risk requested |

## Release rule

All applicable HIGH-risk behavior represented above must be validated before live arming. Failures in classification, stale-approval cancellation, news/intermarket blocking, counter-trend strictness, or NO-TRADE/WAIT behavior are release blockers.
