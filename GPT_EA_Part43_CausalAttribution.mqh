// ============================================================================
// GPT_EA Part 43 - Post-trade causal attribution
// ============================================================================

input bool   InpUsePostTradeCausalAttribution = true;
input string InpCausalAttributionFile         = "GPT_EA_CausalAttribution.csv";
input double InpCausalHighSlippageR           = 0.15;
input double InpCausalGivebackMFER             = 1.00;

void EnsureCausalAttributionHeader()
{
   if(!InpUsePostTradeCausalAttribution) return;
   bool exists=FileIsExist(InpCausalAttributionFile,FILE_COMMON);
   int h=FileOpen(InpCausalAttributionFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","position_id","symbol","strategy","strategy_config","release_id",
         "config_fingerprint","model_policy","realized_r","mae_r","mfe_r","slippage_pts","latency_ms","event_class",
         "stored_market_state","current_market_state","cause","detail","quarantined");
   FileClose(h);
}

string CausalAttributionForPosition(ulong pid,const string sym,double realizedR,string &detail)
{
   detail="";
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
   double mae=GVRead(PosKey(pid,"MAE_R"),0);
   double mfe=GVRead(PosKey(pid,"MFE_R"),0);
   double slipPts=MathMax(0.0,GVRead(PosKey(pid,"EXEC_SLIP_PTS"),0));
   double latency=GVRead(PosKey(pid,"EXEC_LATENCY_MS"),0);
   int ev=(int)GVRead(PosKey(pid,"EVENT_CLASS"),0);
   int storedState=(int)GVRead(PosKey(pid,"MARKET_STATE"),STATE_UNKNOWN);

   if(GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)>0.5)
   { detail="trade path was changed from outside the EA"; return "MANUAL_INTERVENTION"; }
   if(GVRead(PosKey(pid,"STORAGE_ANOMALY"),0)>0.5 || GVRead(PosKey(pid,"BROKER_ANOMALY"),0)>0.5 ||
      GVRead(PosKey(pid,"CONNECTION_ANOMALY"),0)>0.5 || GVRead(PosKey(pid,"CHAOS_SAMPLE"),0)>0.5)
   { detail="operational/broker/storage/fault-injection anomaly present"; return "OPERATIONAL_ERROR"; }

   double riskMoney=GVRead(PosKey(pid,"RISK"),0);
   double onePointMoney=0;
   if(riskMoney>0)
   {
      double lots=GVRead(PosKey(pid,"EXEC_LOTS"),0);
      double pt=PointFor(sym);
      if(lots>0 && pt>0)
      {
         double pnl=0,entry=GVRead(PosKey(pid,"EXEC_FILL"),GVRead(PosKey(pid,"EXEC_EXPECTED"),0));
         if(entry>0 && OrderCalcProfit(ORDER_TYPE_BUY,sym,lots,entry,entry+pt,pnl))
            onePointMoney=MathAbs(pnl);
      }
   }
   double slipR=(riskMoney>0?slipPts*onePointMoney/riskMoney:0);
   if(realizedR<=0 && slipR>=InpCausalHighSlippageR)
   { detail=StringFormat("slippage cost estimated %.2fR",slipR); return "EXECUTION_COST"; }

   int halfLife=StrategyDecisionHalfLifeSeconds(c);
   double budgetMs=halfLife*1000.0*MathMax(0.05,MathMin(0.90,InpMaxLatencyBudgetFraction));
   if(realizedR<=0 && latency>budgetMs && latency>0)
   { detail=StringFormat("execution latency %.0f ms exceeded %.0f ms budget",latency,budgetMs); return "DELAYED_ENTRY"; }

   if(realizedR<=0 && ev!=EVENT_NONE)
   { detail="loss occurred in event-specific context "+AdaptiveEventName(ev); return "NEWS_OR_EVENT_SHOCK"; }

   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   if(realizedR<=0 && storedState!=STATE_UNKNOWN && (int)x.state!=storedState)
   {
      detail="market state transitioned from "+MarketStateName((MarketStateClass)storedState)+" to "+MarketStateName(x.state);
      return "REGIME_TRANSITION";
   }

   if(realizedR<=0 && mfe>=MathMax(0.5,InpCausalGivebackMFER))
   {
      detail=StringFormat("trade reached %.2fR favorable excursion before closing at %.2fR",mfe,realizedR);
      return "PROFIT_GIVEBACK_OR_EXIT_TIMING";
   }
   if(realizedR<0 && mae>=0.90 && mfe<0.35)
   {
      detail=StringFormat("adverse excursion %.2fR with only %.2fR favorable excursion",mae,mfe);
      return "THESIS_OR_ENTRY_FAILURE";
   }
   if(realizedR<0)
   {
      detail=StringFormat("negative outcome %.2fR without dominant operational attribution",realizedR);
      return "STRATEGY_THESIS_FAILURE";
   }
   if(realizedR>0 && mfe>realizedR+0.75)
   {
      detail=StringFormat("realized %.2fR from %.2fR MFE; runner/exit efficiency review",realizedR,mfe);
      return "PROFITABLE_WITH_EXIT_OPPORTUNITY";
   }
   detail=StringFormat("positive outcome %.2fR with no dominant failure attribution",realizedR);
   return "SUCCESSFUL_STRATEGY_EXECUTION";
}

void WriteCausalAttribution(ulong pid,const string sym,double realizedR,const string cause,const string detail)
{
   EnsureCausalAttributionHeader();
   int h=FileOpen(InpCausalAttributionFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"causal_attribution_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),(string)pid,sym,
      StrategyClassName(c),StrategyConfigVersion(c),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,CurrentConfigFingerprint(),
      InpModelPolicyVersion,DoubleToString(realizedR,3),DoubleToString(GVRead(PosKey(pid,"MAE_R"),0),3),
      DoubleToString(GVRead(PosKey(pid,"MFE_R"),0),3),DoubleToString(GVRead(PosKey(pid,"EXEC_SLIP_PTS"),0),1),
      DoubleToString(GVRead(PosKey(pid,"EXEC_LATENCY_MS"),0),0),(int)GVRead(PosKey(pid,"EVENT_CLASS"),0),
      MarketStateName((MarketStateClass)(int)GVRead(PosKey(pid,"MARKET_STATE"),STATE_UNKNOWN)),
      MarketStateName(x.state),cause,detail,GVRead(PosKey(pid,"LEARN_QUARANTINE"),0)>0.5?"1":"0");
   FileFlush(h); FileClose(h);
}

void FinalizeCausalAttributionHistory()
{
   if(!InpUsePostTradeCausalAttribution) return;
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;

   ulong pids[]; string syms[];
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-1200);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(pid==0 || PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"CAUSE_FINAL"),0)>0.5) continue;
      if(GVRead(PosKey(pid,"STRATEGY"),0)<=0 || GVRead(PosKey(pid,"RISK"),0)<=0) continue;
      bool dup=false; for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ dup=true; break; }
      if(dup) continue;
      int at=ArraySize(pids); ArrayResize(pids,at+1); ArrayResize(syms,at+1);
      pids[at]=pid; syms[at]=HistoryDealGetString(d,DEAL_SYMBOL);
   }

   for(int i=0;i<ArraySize(pids);i++)
   {
      ulong pid=pids[i];
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double realized=StrategyPositionRealized(pid)/risk;
      string detail="";
      string cause=CausalAttributionForPosition(pid,syms[i],realized,detail);
      WriteCausalAttribution(pid,syms[i],realized,cause,detail);
      GVWrite(PosKey(pid,"CAUSE_FINAL"),1);
   }
   GlobalVariablesFlush();
}

void CausalAttributionInit()
{
   EnsureCausalAttributionHeader();
   FinalizeCausalAttributionHistory();
}

void CausalAttributionTimer()
{
   FinalizeCausalAttributionHistory();
}
