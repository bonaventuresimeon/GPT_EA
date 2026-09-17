// ============================================================================
// GPT_EA Part 24 - Session accuracy, late-session risk and strategy expiry
// ============================================================================

input bool InpDowngradeLateSessionLiquidity = true;
input int  InpLateSessionScorePenalty       = 8;

string AccurateSessionBucket()
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);

   // Overlap must be evaluated before generic London/NY buckets.
   if(l.hour>=13 && l.hour<17 && n.hour>=8 && n.hour<12) return "LONDON_NY_OVERLAP";
   if(l.hour>=7 && l.hour<9) return "LONDON_PREOPEN";
   if(l.hour>=9 && l.hour<13) return "LONDON";
   if(n.hour>=8 && n.hour<9) return "NEW_YORK_PREOPEN";
   if(n.hour>=9 && n.hour<12) return "NEW_YORK_OPEN";
   if(l.hour>=0 && l.hour<7) return "ASIAN";
   if(l.hour>=16 && l.hour<18) return "LONDON_CLOSE";
   if(n.hour>=15 && n.hour<17) return "NEW_YORK_CLOSE";
   return "OTHER";
}

bool LateSessionLiquidityRisk(string &why)
{
   why="";
   if(!InpDowngradeLateSessionLiquidity) return false;
   string s=AccurateSessionBucket();
   if(s=="LONDON_CLOSE" || s=="NEW_YORK_CLOSE")
   {
      why=s+" liquidity/flow transition can increase fakeouts, spread instability and poor follow-through.";
      return true;
   }
   return false;
}

int StrategyAdaptiveExpiry(const string sym,StrategyClass c)
{
   int base=5;
   switch(c)
   {
      case STRATEGY_BREAKOUT:            base=2; break;
      case STRATEGY_BREAKOUT_RETEST:     base=3; break;
      case STRATEGY_COUNTER_TREND_SCALP: base=2; break;
      case STRATEGY_COUNTER_TREND_SWING: base=4; break;
      case STRATEGY_POTENTIAL_REVERSAL:  base=4; break;
      case STRATEGY_RANGE_TRADE:         base=4; break;
      case STRATEGY_MEAN_REVERSION:      base=4; break;
      case STRATEGY_TREND_CONTINUATION:  base=5; break;
      case STRATEGY_RETRACEMENT_ENTRY:   base=6; break;
      default:                           base=4; break;
   }
   return AdaptiveExpiry(sym,base);
}

void RefreshFrameworkForAccurateSession(const string sym,StrategyDecision &d)
{
   if(d.strategy==STRATEGY_NO_TRADE) return;
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   x.session=AccurateSessionBucket();
   string framework=SelectedStrategyFramework(x,d.strategy);
   d.session=x.session;
   d.strategyName=StrategyClassName(d.strategy)+" — "+framework;
   d.rationale+=" | Accurate session context: "+x.session+"; framework refreshed to "+framework+".";
}

bool AccurateSessionEvidenceAllows(const string sym,StrategyClass c,string &detail)
{
   detail="Accurate-session evidence: not applicable.";
   if(c==STRATEGY_NO_TRADE) return true;
   string session=AccurateSessionBucket();
   int code=StrategySessionCode(session);
   return ContextBucketAllows(SysKey(StringFormat("STRAT_%d_SESSION_%d",(int)c,code)),
                              "ACCURATE SESSION "+session,detail);
}

void PersistStrategyPlanForExecutionAccurate(const TradeSetup &s)
{
   PersistStrategyPlanForExecutionFull(s);
   string session=AccurateSessionBucket();
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_CODE"),StrategySessionCode(session));
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_HASH"),(double)StringLen(session));
}

void SelectDynamicStrategyFinal(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyResearch(sym,pb,br,d);
   RefreshFrameworkForAccurateSession(sym,d);

   if(d.strategy!=STRATEGY_NO_TRADE)
      d.setup.expiryM15=StrategyAdaptiveExpiry(sym,d.strategy);

   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      string sessionEvidence="";
      bool sessionEvidenceOK=AccurateSessionEvidenceAllows(sym,d.strategy,sessionEvidence);
      d.evidence+=" | "+sessionEvidence;
      if(!sessionEvidenceOK)
      {
         d.action=STRATEGY_ACTION_NO_TRADE;
         d.setup.valid=false;
         d.rationale+=" | Corrected-session evidence gate BLOCKED the strategy in the current session segment.";
      }
   }

   string lateWhy="";
   if(LateSessionLiquidityRisk(lateWhy) && d.strategy!=STRATEGY_NO_TRADE && d.action!=STRATEGY_ACTION_NO_TRADE)
   {
      int penalty=(InpLateSessionScorePenalty>0?InpLateSessionScorePenalty:0);
      d.score=(d.score>penalty?d.score-penalty:0);
      d.rationale+=" | Late-session liquidity warning: "+lateWhy;
      bool fastSetup=(d.strategy==STRATEGY_BREAKOUT || d.strategy==STRATEGY_BREAKOUT_RETEST ||
                      d.strategy==STRATEGY_COUNTER_TREND_SCALP || d.strategy==STRATEGY_MEAN_REVERSION);
      if(fastSetup && d.action==STRATEGY_ACTION_HIGH_CONFIDENCE)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=" | Fast setup downgraded to WAIT because end-session liquidity can invalidate normal follow-through assumptions.";
      }
      else if(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE && d.score<InpMinStrategyScore)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
      }
   }
   PersistStrategyCandidate(sym,d);
}
