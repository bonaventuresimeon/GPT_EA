// ============================================================================
// GPT_EA Part 15B - Named strategy framework library
// ============================================================================

string SelectedStrategyFramework(const StrategySnapshot &x,StrategyClass c)
{
   bool nearPDH=(x.previousDayHigh>0 && x.atr>0 && MathAbs(x.mid-x.previousDayHigh)<=0.35*x.atr);
   bool nearPDL=(x.previousDayLow>0 && x.atr>0 && MathAbs(x.mid-x.previousDayLow)<=0.35*x.atr);
   bool nearAsianH=(x.asianHigh>-1.0e90 && x.atr>0 && MathAbs(x.mid-x.asianHigh)<=0.35*x.atr);
   bool nearAsianL=(x.asianLow<1.0e90 && x.atr>0 && MathAbs(x.mid-x.asianLow)<=0.35*x.atr);
   bool london=(x.session=="LONDON" || x.session=="LONDON_PREOPEN" || x.session=="LONDON_NY_OVERLAP");
   bool ny=(x.session=="NEW_YORK_OPEN" || x.session=="NEW_YORK_PREOPEN" || x.session=="LONDON_NY_OVERLAP");

   if(c==STRATEGY_TREND_CONTINUATION)
   {
      if(x.state==STATE_MOMENTUM_CONTINUATION) return "Momentum Continuation / Volatility Expansion";
      if(x.dominantBull?x.m15BullStructure:x.m15BearStructure) return "Higher-High/Higher-Low or Lower-High/Lower-Low Continuation";
      return "Multi-Timeframe Trend Alignment / Dynamic EMA Support-Resistance";
   }
   if(c==STRATEGY_RETRACEMENT_ENTRY)
   {
      if((x.bullishSweep||x.bearishSweep)) return "Liquidity-Sweep Retracement into Structure";
      if(nearPDH||nearPDL) return "Previous-Day Structure Retracement";
      if(MathAbs(x.mid-x.ema20)<=0.35*x.atr || MathAbs(x.mid-x.ema50)<=0.35*x.atr) return "Moving-Average / Dynamic-Support Retracement";
      return "Fibonacci 38.2-61.8% + Previous Breakout Structure Retracement";
   }
   if(c==STRATEGY_BREAKOUT || c==STRATEGY_BREAKOUT_RETEST)
   {
      if(london && (nearAsianH||nearAsianL)) return (c==STRATEGY_BREAKOUT?"London Open / Asian-Range Breakout":"London Open / Asian-Range Breakout-Retest");
      if(london && (x.bullishSweep||x.bearishSweep)) return "London Liquidity Sweep then Breakout-Retest";
      if(ny && x.openingRangeRatio>0.5) return (c==STRATEGY_BREAKOUT?"New York / U.S. Cash Opening-Range Breakout":"U.S. Cash Opening-Range Breakout-Retest");
      if(nearPDH||nearPDL) return "Previous-Day High/Low Breakout-Retest";
      if(x.expansion) return "Consolidation / Volatility-Expansion Breakout";
      return "Support/Resistance Breakout and Retest";
   }
   if(c==STRATEGY_COUNTER_TREND_SCALP || c==STRATEGY_COUNTER_TREND_SWING || c==STRATEGY_POTENTIAL_REVERSAL)
   {
      if(x.falseBreakUp||x.falseBreakDown) return "Failed Breakout / Liquidity Sweep Reversal";
      if(x.doubleTop||x.doubleBottom) return "Double Top/Bottom + Structural Confirmation";
      if(x.exhaustion && (x.bullishDivergence||x.bearishDivergence)) return "Exhaustion + Momentum Divergence + CHOCH";
      if(london && (x.bullishSweep||x.bearishSweep)) return "London Liquidity Sweep Reversal";
      if(ny && (x.bullishSweep||x.bearishSweep)) return "U.S. Cash-Session Sweep/Reversal";
      return "Major Support/Resistance Rejection + Change of Character / Break of Structure";
   }
   if(c==STRATEGY_RANGE_TRADE)
   {
      if(x.falseBreakUp||x.falseBreakDown) return "Failed Range Breakout / Range Reversal";
      if(london||ny) return "Session-Range Boundary Reversal";
      return "Range Support Buy / Range Resistance Sell";
   }
   if(c==STRATEGY_MEAN_REVERSION)
      return "Mean Reversion Toward Range Equilibrium / VWAP";
   return "No executable framework";
}

void EnrichStrategyDecision(const string sym,StrategyDecision &d)
{
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string framework=SelectedStrategyFramework(x,d.strategy);
   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      d.strategyName=StrategyClassName(d.strategy)+" — "+framework;
      d.rationale+=" | Framework: "+framework+".";
      if(StringFind(framework,"Fibonacci")>=0) d.confirmation+=" Confirm price is reacting within the measured 38.2-61.8% retracement/value zone.";
      if(StringFind(framework,"Opening-Range")>=0) d.confirmation+=" Require a completed opening-range break and controlled hold/retest; opening volatility alone is not confirmation.";
      if(StringFind(framework,"Liquidity Sweep")>=0) d.confirmation+=" Require the swept level to be reclaimed/rejected before entry.";
      if(StringFind(framework,"Previous-Day")>=0) d.confirmation+=" Treat the previous-day high/low as a liquidity level and require acceptance/rejection appropriate to the strategy.";
   }
}

void SelectDynamicStrategyEnriched(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategy(sym,pb,br,d);
   EnrichStrategyDecision(sym,d);
   PersistStrategyCandidate(sym,d);
}
