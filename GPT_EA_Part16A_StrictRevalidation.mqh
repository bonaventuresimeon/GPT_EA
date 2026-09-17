// ============================================================================
// GPT_EA Part 16A - Strict pre-entry strategy identity revalidation
// ============================================================================

bool PreEntryIntelligenceRevalidationStrict(const TradeSetup &s,string &why)
{
   StrategyClass expected=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   MarketStateClass expectedState=(MarketStateClass)(int)GVRead(SymKey(s.symbol,"CAND_STATE"),STATE_UNKNOWN);
   if(expected==STRATEGY_NO_TRADE)
   { why="No stored executable strategy classification exists."; return false; }

   TradeSetup pb=BuildPullback(s.symbol,s.bullish,s.confidence,"");
   TradeSetup br=BuildBreakoutRetest(s.symbol,s.bullish,s.confidence,"");
   StrategyDecision d; SelectDynamicStrategy(s.symbol,pb,br,d);

   if(d.strategy==STRATEGY_NO_TRADE || d.action==STRATEGY_ACTION_NO_TRADE)
   {
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Fresh strategy engine now returns NO TRADE.";
      return false;
   }
   if(d.setup.bullish!=s.bullish)
   {
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Fresh strategy direction differs from the approved direction.";
      return false;
   }
   if(d.strategy!=expected)
   {
      string change=StrategyClassName(expected)+" -> "+StrategyClassName(d.strategy);
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Strategy classification changed during approval: "+change+". Reanalyze instead of executing stale authorization.";
      return false;
   }

   IntermarketReport im=AssessIntermarket(s.symbol,s.bullish);
   if(im.severeConflict)
   { why="Severe intermarket contradiction: "+im.detail; return false; }

   string web="",err=""; bool block=false,watch=false;
   bool webOK=GetLiveWebIntel(s.symbol,s,d,true,web,block,watch,err);
   if(!webOK || (InpBlockOnWebIntelVerdictBLOCK && block))
   { why="Live news/web intelligence invalidated execution: "+web; return false; }

   string cal=""; if(CalendarBlock(s.symbol,cal)){ why="Economic calendar now blocks execution: "+cal; return false; }
   string yield=""; if(YieldShock(yield)){ why="Treasury-yield shock now blocks execution: "+yield; return false; }

   string ev="";
   if(!StrategyEvidenceAllows(expected,ev)){ why="Historical strategy evidence gate changed to BLOCK: "+ev; return false; }

   // Keep the original approved class, but refresh time/state only after identity is proven stable.
   GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
   GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)d.state);
   GVWrite(SymKey(s.symbol,"CAND_SCORE"),(double)d.score);
   GVWrite(SymKey(s.symbol,"CAND_TIME"),(double)TimeTradeServer());
   why="Strict pre-entry intelligence PASS | "+StrategyClassName(expected)+" remains valid | "+MarketStateName(d.state)+" | "+im.detail+(watch?" | web WATCH":" | web CLEAR");
   return true;
}
