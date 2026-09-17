// ============================================================================
// GPT_EA Part 31B - History-safe adaptive execution finalization
// ============================================================================

double AdaptivePositionCommission(const ulong pid)
{
   double commission=0;
   if(!HistorySelectByPosition(pid)) return 0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      commission+=MathAbs(HistoryDealGetDouble(d,DEAL_COMMISSION));
   }
   return commission;
}

void FinalizeAdaptiveLearningHistoryR5()
{
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;

   ulong pids[];
   string syms[];
   int total=HistoryDealsTotal();
   for(int i=MathMax(0,total-1200);i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(pid==0 || PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"ADAPT_FINAL"),0)>0.5 || GVRead(PosKey(pid,"ADAPT_META"),0)<0.5) continue;
      bool duplicate=false;
      for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ duplicate=true; break; }
      if(duplicate) continue;
      int n=ArraySize(pids); ArrayResize(pids,n+1); ArrayResize(syms,n+1);
      pids[n]=pid; syms[n]=HistoryDealGetString(d,DEAL_SYMBOL);
   }

   for(int i=0;i<ArraySize(pids);i++)
   {
      ulong pid=pids[i];
      int cls=(int)GVRead(PosKey(pid,"STRATEGY"),0); if(cls<=0) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double pnl=StrategyPositionRealized(pid),R=pnl/risk;
      int raw=(int)GVRead(PosKey(pid,"RAW_CONF"),0);
      int ev=(int)GVRead(PosKey(pid,"EVENT_CLASS"),0);
      double tp1=GVRead(PosKey(pid,"TP1_M15"),0);

      if(raw>0) UpdateConfidenceCalibrationBucket(raw,R);
      if(ev>0) UpdateStrategyBucket(SysKey(StringFormat("EVENT_%d_STRAT_%d",ev,cls)),R);
      if(tp1>0) UpdateExpiryHistogram((StrategyClass)cls,tp1);

      string maeKey=SysKey(StringFormat("MAE_MFE_%d",cls));
      GVWrite(maeKey+"_N",GVRead(maeKey+"_N",0)+1);
      GVWrite(maeKey+"_MAE",GVRead(maeKey+"_MAE",0)+GVRead(PosKey(pid,"MAE_R"),0));
      GVWrite(maeKey+"_MFE",GVRead(maeKey+"_MFE",0)+GVRead(PosKey(pid,"MFE_R"),0));

      double commission=AdaptivePositionCommission(pid);
      GVWrite(PosKey(pid,"ACTUAL_COMMISSION"),commission);
      WriteExecutionLearningRow("CLOSED",syms[i],pid,"history-safe post-trade learning finalized",R);
      GVWrite(PosKey(pid,"ADAPT_FINAL"),1);
   }
   GlobalVariablesFlush();
}

void ExecutionLearningInitR5()
{
   EnsureExecutionLearningHeader();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
   FinalizeAdaptiveLearningHistoryR5();
   Print("GPT_EA R5 execution-quality learning initialized.");
}

void ExecutionLearningTimerR5()
{
   UpdateOpenMAEMFE();
   FinalizeAdaptiveLearningHistoryR5();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
}
