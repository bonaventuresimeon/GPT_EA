// ============================================================================
// GPT_EA Part 15C - Strategy context analytics (session/timeframe/news)
// ============================================================================

input int InpStrategyNewsContextMinutes = 120;

int StrategySessionCode(const string s)
{
   if(s=="ASIAN") return 1;
   if(s=="LONDON_PREOPEN") return 2;
   if(s=="LONDON") return 3;
   if(s=="LONDON_NY_OVERLAP") return 4;
   if(s=="NEW_YORK_PREOPEN") return 5;
   if(s=="NEW_YORK_OPEN") return 6;
   return 7;
}

bool HighImpactEventWithin(const string sym,int minutes)
{
   if(!InpUseEconomicCalendar || (bool)MQLInfoInteger(MQL_TESTER)) return false;
   string ccy=RelatedCurrencies(sym); if(ccy=="") return false;
   string arr[]; int nc=StringSplit(ccy,',',arr);
   datetime now=TimeTradeServer(),from=now-MathMax(1,minutes)*60,to=now+MathMax(1,minutes)*60;
   for(int c=0;c<nc;c++)
   {
      MqlCalendarValue vals[]; int n=CalendarValueHistory(vals,from,to,NULL,arr[c]);
      if(n<=0) continue;
      for(int i=0;i<n;i++)
      {
         MqlCalendarEvent ev={};
         if(CalendarEventById(vals[i].event_id,ev) && ev.importance==CALENDAR_IMPORTANCE_HIGH) return true;
      }
   }
   return false;
}

void PersistStrategyPlanForExecutionFull(const TradeSetup &s)
{
   PersistStrategyPlanForExecution(s);
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_CODE"),StrategySessionCode(x.session));
   GVWrite(SymKey(s.symbol,"PLAN_SETUP_TF"),15);  // current strategy construction timeframe
   GVWrite(SymKey(s.symbol,"PLAN_EXEC_TF"),5);    // current execution confirmation timeframe
   GVWrite(SymKey(s.symbol,"PLAN_NEWS_CONTEXT"),HighImpactEventWithin(s.symbol,InpStrategyNewsContextMinutes)?1:0);
}

void AttachStrategyContextMetadata()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      datetime pt=(datetime)GVRead(SymKey(sym,"PLAN_STRAT_TIME"),0);
      if(pt<=0 || MathAbs((long)PositionGetInteger(POSITION_TIME)-(long)pt)>1200) continue;
      if(GVRead(PosKey(pid,"STRAT_SESSION_CODE"),0)<=0) GVWrite(PosKey(pid,"STRAT_SESSION_CODE"),GVRead(SymKey(sym,"PLAN_SESSION_CODE"),7));
      if(GVRead(PosKey(pid,"STRAT_SETUP_TF"),0)<=0) GVWrite(PosKey(pid,"STRAT_SETUP_TF"),GVRead(SymKey(sym,"PLAN_SETUP_TF"),15));
      if(GVRead(PosKey(pid,"STRAT_EXEC_TF"),0)<=0) GVWrite(PosKey(pid,"STRAT_EXEC_TF"),GVRead(SymKey(sym,"PLAN_EXEC_TF"),5));
      if(!GlobalVariableCheck(PosKey(pid,"STRAT_NEWS_CONTEXT"))) GVWrite(PosKey(pid,"STRAT_NEWS_CONTEXT"),GVRead(SymKey(sym,"PLAN_NEWS_CONTEXT"),0));
   }
}

void FinalizeStrategyContextHistory()
{
   datetime now=TimeTradeServer(),from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-400);i<n;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"STRAT_CONTEXT_FINAL"),0)>0.5) continue;
      int cls=(int)GVRead(PosKey(pid,"STRATEGY"),0); if(cls<=0) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double R=StrategyPositionRealized(pid)/risk;
      int ses=(int)GVRead(PosKey(pid,"STRAT_SESSION_CODE"),7);
      int stf=(int)GVRead(PosKey(pid,"STRAT_SETUP_TF"),15);
      int etf=(int)GVRead(PosKey(pid,"STRAT_EXEC_TF"),5);
      int news=(int)GVRead(PosKey(pid,"STRAT_NEWS_CONTEXT"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_SESSION_%d",cls,ses)),R);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_TF_%d_%d",cls,stf,etf)),R);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_NEWS_%d",cls,news)),R);
      GVWrite(PosKey(pid,"STRAT_CONTEXT_FINAL"),1);
   }
}

void StrategyIntelligenceInitFull()
{
   StrategyIntelligenceInit();
   AttachStrategyContextMetadata();
   FinalizeStrategyContextHistory();
}

void StrategyIntelligenceTimerFull()
{
   StrategyIntelligenceTimer();
   AttachStrategyContextMetadata();
   FinalizeStrategyContextHistory();
}
