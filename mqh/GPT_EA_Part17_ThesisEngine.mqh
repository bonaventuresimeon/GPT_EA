// ============================================================================
// GPT_EA Part 17 - Mandatory 25-point trade thesis and GPT critique engine
// ============================================================================

string MultiTFAlignmentText(const string sym,bool bull)
{
   ENUM_TIMEFRAMES tf[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M30,PERIOD_M15,PERIOD_M5};
   string nm[6]={"D1","H4","H1","M30","M15","M5"};
   string out="";
   for(int i=0;i<6;i++)
   {
      int v=TrendVote(sym,tf[i],bull);
      if(i>0) out+=" | ";
      out+=nm[i]+":"+(v>0?"ALIGNED":v<0?"OPPOSED":"NEUTRAL");
   }
   return out;
}

string PriceInvalidationText(const TradeSetup &s)
{
   return StringFormat("Immediate price invalidation: %.*f plus the stated structural close/acceptance failure. %s",
      DigitsFor(s.symbol),s.sl,s.invalidation);
}

string TargetLogicText(const TradeSetup &s,const StrategySnapshot &x)
{
   return StringFormat("TP1 %.*f, TP2 %.*f, TP3 %.*f. Objectives are checked against prior/session liquidity %.5f/%.5f, prior-day %.5f/%.5f and current range %.5f/%.5f rather than arbitrary pip distances.",
      DigitsFor(s.symbol),s.tp1,DigitsFor(s.symbol),s.tp2,DigitsFor(s.symbol),s.tp3,
      x.asianHigh,x.asianLow,x.previousDayHigh,x.previousDayLow,x.priorHigh,x.priorLow);
}

string LiquidityFakeoutText(const StrategySnapshot &x)
{
   return StringFormat("Bull sweep %s | Bear sweep %s | False break up/down %s/%s | Asian H/L %.5f/%.5f | Previous-day H/L %.5f/%.5f. Thin/opening volatility risk rises when OR is %.2fx ATR.",
      x.bullishSweep?"YES":"NO",x.bearishSweep?"YES":"NO",x.falseBreakUp?"YES":"NO",x.falseBreakDown?"YES":"NO",
      x.asianHigh,x.asianLow,x.previousDayHigh,x.previousDayLow,x.openingRangeRatio);
}

string VolatilityThesisText(const StrategySnapshot &x)
{
   return StringFormat("M15 ATR %.5f versus trailing ATR %.5f = %.2fx; opening range %.2fx ATR; regime %s. High volatility requires wider structural tolerance and faster invalidation; compression requires smaller target expectations until expansion confirms.",
      x.atr,x.atrAverage,x.atrRatio,x.openingRangeRatio,x.baseRegime);
}

string BuildMandatory25PointThesis(const string sym,TradeSetup &primary,TradeSetup &pb,TradeSetup &br,
                                   const StrategyDecision &d,const ConfluenceReport &c,
                                   const string calendarText,const string webText,const IntermarketReport &im,
                                   const string spreadText,const string sessionText)
{
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string s="\n━━━━━━━━━━━━━━━━━━━━\n📚 MANDATORY 25-POINT TRADE THESIS\n━━━━━━━━━━━━━━━━━━━━\n";
   s+="1. Multi-Timeframe Alignment: "+MultiTFAlignmentText(sym,primary.bullish)+". HTF context establishes bias; M15/M5 are execution layers.\n";
   s+="2. Market Regime: "+d.regime+" / "+d.stateText+". "+d.rationale+"\n";
   s+=StringFormat("3. Market Structure: M15 bullish/bearish structure %s/%s; LTF bullish/bearish break %s/%s; CHOCH against trend %s; compression %s; expansion %s.\n",
      x.m15BullStructure?"YES":"NO",x.m15BearStructure?"YES":"NO",x.ltfBullBreak?"YES":"NO",x.ltfBearBreak?"YES":"NO",x.chochAgainstTrend?"YES":"NO",x.compression?"YES":"NO",x.expansion?"YES":"NO");
   s+="4. Strategy Selection: "+d.strategyName+" selected from the regime-driven library. "+d.librarySummary+"\n";
   s+="5. Trend vs Retracement Assessment: current state is "+d.stateText+". HTF dominant direction is "+(x.dominantBull?"BULLISH":"BEARISH")+"; trend failure="+(x.trendFailure?"YES":"NO")+".\n";
   s+=StringFormat("6. Entry Logic: zone %.*f-%.*f around preferred %.*f. %s\n",DigitsFor(sym),primary.zoneLow,DigitsFor(sym),primary.zoneHigh,DigitsFor(sym),primary.preferred,primary.reason);
   s+="7. Confirmation Logic: "+d.confirmation+" Execution rule: "+primary.executionRule+"\n";
   s+=StringFormat("8. Stop-Loss Logic: SL %.*f sits beyond the structural thesis invalidation rather than using a fixed pip distance. %s\n",DigitsFor(sym),primary.sl,primary.invalidation);
   s+="9. Take-Profit Logic: "+TargetLogicText(primary,x)+"\n";
   s+=StringFormat("10. Risk-to-Reward Analysis: theoretical geometry %.2fR to TP1 family; realistic effective R:R to TP2 after spread/slippage %.2f. %s Partials at TP1/TP2 alter realized portfolio R and are tracked in analytics.\n",
      primary.nominalRR1,EffectiveRRDynamic(primary),spreadText);
   s+="11. Pullback vs Breakout-Retest Analysis: Pullback => "+SetupSummaryLine(pb)+"; Breakout-Retest => "+SetupSummaryLine(br)+". Pullback failure is acceptance through value/structure; breakout-retest failure is a false break and return inside the old range.\n";
   s+="12. Counter-Trend Assessment: "+(d.counterTrend?("COUNTER-TREND TRADE. Score "+IntegerToString(d.counterTrendScore)+"/100; strict sweep + CHOCH/BOS + rejection confirmation required, with more conservative targets."):"Trade is not classified as counter-trend against dominant HTF structure.")+"\n";
   s+="13. Liquidity & Fakeout Assessment: "+LiquidityFakeoutText(x)+"\n";
   s+="14. Volatility Analysis: "+VolatilityThesisText(x)+"\n";
   s+="15. News Risk Assessment: Scheduled calendar => "+calendarText+" | Live web intelligence => "+webText+"\n";
   s+="16. Treasury-Yield & Intermarket Analysis: "+im.detail+"; dedicated yield-shock filter is also checked independently before authorization.\n";
   s+="17. Session Analysis: "+d.session+". "+sessionText+" Session/previous-day/Asian highs-lows are treated as liquidity objectives and fakeout locations.\n";
   s+=StringFormat("18. Time-Based Invalidation: base setup expiry %d M15 candles; AdaptiveExpiry() shortens fast/high-ATR or oversized-opening-range setups and extends slow regimes within safety bounds. Breakouts demand faster follow-through than swing retracements.\n",primary.expiryM15);
   s+="19. Price-Based Invalidation: "+PriceInvalidationText(primary)+"\n";
   s+="20. Counterargument Analysis: "+d.counterargument+" Ask explicitly: could liquidity run the opposite side first, is this a retracement mistaken for reversal, is this breakout actually a sweep, is price overextended, and does effective R:R still survive costs?\n";
   s+="21. Setup Quality Filtering: strategy action is "+(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE?"HIGH-CONFIDENCE TRADE SETUP":d.action==STRATEGY_ACTION_WAIT?"WAIT FOR CONFIRMATION":"NO TRADE")+". Contradictory/marginal evidence is not forced into a signal.\n";
   s+=StringFormat("22. Confidence Validation: strategy %d/100 | advanced confluence %d/100 | HTF votes %d/3 | ADX %.1f | volume %.2fx | spread %s. Confidence is multi-factor, not a single-indicator label.\n",
      d.score,c.score,c.htfVotes,c.adx,c.volumeRatio,c.spreadOK?"OK":"BLOCK");
   s+="23. Historical Strategy Validation: "+d.evidence+" Contextual strategy stats are accumulated by strategy/state/direction/volatility. Historical/forward evidence is treated as evidence, never as a guarantee.\n";
   s+="24. Pre-Entry Revalidation: immediately before execution the EA re-checks strategy identity, D1/H4/H1/M30/M15/M5 data freshness, current zone/trigger, spread, ATR/opening range, calendar, live web news, Treasury yields, intermarket conflict, release/risk/broker gates and original invalidation. Changed conditions cancel the setup.\n";
   s+="25. Detailed Trade Thesis: The trade exists because "+d.strategyName+" matches "+d.stateText+" with the stated structure/confluence. Entry requires "+d.confirmation+" SL invalidates the thesis at structure, targets follow liquidity/structural objectives, failure channels are explicitly listed, and execution is authorized only if realistic reward still justifies total risk.\n";
   return s;
}

string BuildDeepGPTPrompt(const string sym,const string card,const string thesis,const string webIntel,const StrategyDecision &d)
{
   return "You are the secondary adversarial validation layer for a MetaTrader EA. The broker-derived technical data, strategy classification and live-news intelligence below are authoritative inputs. "
          "Do not invent prices, economic events, yields, headlines or statistics. Actively try to DISPROVE the proposed trade before validating it. "
          "Confirm that the classification distinguishes trend continuation, retracement/correction, counter-trend movement, reversal, breakout/retest/fakeout, sweep, range, mean reversion, momentum, exhaustion and consolidation correctly. "
          "If the trade is counter-trend, demand stronger evidence and conservative objectives. If evidence is insufficient say WAIT; if invalid say NO TRADE/INVALID; only say VALID when independent evidence genuinely aligns. "
          "Return compact lines: VERDICT: VALID|WAIT|INVALID; CLASSIFICATION: ...; STRATEGY: ...; MTF: ...; RETRACEMENT_OR_REVERSAL: ...; COUNTER_TREND: ...; ENTRY_CONFIRMATION: ...; "
          "SL_LOGIC: ...; TARGET_LOGIC: ...; RR_AFTER_COSTS: ...; LIQUIDITY_FAKEOUT: ...; VOLATILITY: ...; NEWS: ...; INTERMARKET: ...; COUNTERARGUMENT: ...; TIME_INVALIDATION: ...; PRICE_INVALIDATION: ...; EXECUTION_WARNING: ... .\n"
          "Symbol: "+sym+"\nSelected strategy: "+d.strategyName+"\nSignal card:\n"+card+"\nMandatory thesis:\n"+thesis+"\nLive web intelligence:\n"+webIntel;
}
