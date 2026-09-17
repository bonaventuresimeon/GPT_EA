// ============================================================================
// GPT_EA Part 36 - Machine-observed R5 demo-soak evidence
// ============================================================================
// This module does not certify a release by itself. It produces durable,
// reviewable evidence that can be reconciled with Part28 and the archived
// release-evidence JSON before an operator attests the R5 soak gate.

input bool   InpEnableDemoSoakEvidence              = false;
input string InpDemoSoakEvidenceId                  = "";
input string InpDemoSoakEvidenceFile                = "GPT_EA_DemoSoakEvidence.csv";
input int    InpDemoSoakObservationSeconds          = 60;
input int    InpDemoSoakSummaryMinutes              = 15;
input int    InpDemoSoakFreshQuoteSeconds           = 60;
input bool   InpDemoSoakCountWeekendTradingDays     = false;
input int    InpDemoSoakRolloverStartHourUTC        = 20;
input int    InpDemoSoakRolloverEndHourUTC          = 23;
input double InpDemoSoakRolloverSpreadATRFrac       = 0.12;

enum LifecycleWaitReasonClass
{
   LIFECYCLE_WAIT_UNSPECIFIED=0,
   LIFECYCLE_WAIT_MARKET_CONFIRMATION=1,
   LIFECYCLE_WAIT_HUMAN_APPROVAL=2
};

string DemoSoakKey(const string suffix){ return SysKey("SOAK_"+suffix); }

bool DemoSoakEligible()
{
   if(!InpEnableDemoSoakEvidence || (bool)MQLInfoInteger(MQL_TESTER)) return false;
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return false;
   return StringLen(InpDemoSoakEvidenceId)>=4;
}

int DemoSoakDateCode(datetime tm)
{
   MqlDateTime t={}; TimeToStruct(tm,t);
   return t.year*10000+t.mon*100+t.day;
}

datetime DemoSoakDayStart(datetime tm)
{
   MqlDateTime t={}; TimeToStruct(tm,t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

bool DemoSoakTradingDay(datetime tm)
{
   if(InpDemoSoakCountWeekendTradingDays) return true;
   MqlDateTime t={}; TimeToStruct(tm,t);
   return (t.day_of_week>=1 && t.day_of_week<=5);
}

bool DemoSoakConsecutiveTradingDay(datetime prevDay,datetime curDay)
{
   if(prevDay<=0 || curDay<=prevDay) return false;
   int gap=(int)((curDay-prevDay)/86400);
   if(InpDemoSoakCountWeekendTradingDays) return gap==1;
   MqlDateTime p={},c={}; TimeToStruct(prevDay,p); TimeToStruct(curDay,c);
   if(gap==1) return true;
   if(p.day_of_week==5 && c.day_of_week==1 && gap==3) return true; // Fri -> Mon
   return false;
}

bool DemoSoakHasFreshQuote(string &observedSymbol)
{
   observedSymbol="";
   datetime now=TimeTradeServer();
   int maxAge=MathMax(5,InpDemoSoakFreshQuoteSeconds);
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      MqlTick t={}; if(!GetTickSafe(sym,t) || t.bid<=0 || t.ask<=0 || t.time<=0) continue;
      if(MathAbs((long)(now-t.time))<=maxAge){ observedSymbol=sym; return true; }
   }
   return false;
}

bool DemoSoakHasOpenPosition(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

bool DemoSoakPendingApprovalActive(const string sym)
{
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && g_pending[i].setup.symbol==sym) return true;
   return false;
}

void EnsureDemoSoakEvidenceHeader()
{
   if(!DemoSoakEligible()) return;
   bool exists=FileIsExist(InpDemoSoakEvidenceFile,FILE_COMMON);
   int h=FileOpen(InpDemoSoakEvidenceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE){ Print("Demo-soak evidence file open failed: ",GetLastError()); return; }
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","run_id","event","symbol","detail",
         "consecutive_days","max_consecutive_days","london_days","ny_days","overlap_days","high_impact_news_days",
         "rollover_window","rollover_spread_expansion","restart_count","reconnect_count","manual_scan_observed","scheduled_scan_observed",
         "zero_tolerance_failures","unresolved_critical_states","coverage_ready","broker","server");
   FileClose(h);
}

void WriteDemoSoakEvidenceEvent(const string eventName,const string symbol,const string detail)
{
   if(!DemoSoakEligible()) return;
   EnsureDemoSoakEvidenceHeader();
   int h=FileOpen(InpDemoSoakEvidenceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   bool ready=(GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0)>=5 &&
               GVRead(DemoSoakKey("LONDON_DAYS"),0)>=3 && GVRead(DemoSoakKey("NY_DAYS"),0)>=3 &&
               GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>=1 && GVRead(DemoSoakKey("NEWS_DAYS"),0)>=1 &&
               GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5 && GVRead(DemoSoakKey("RESTARTS"),0)>=1 &&
               GVRead(DemoSoakKey("RECONNECTS"),0)>=1 && GVRead(DemoSoakKey("MANUAL_SCAN"),0)>0.5 &&
               GVRead(DemoSoakKey("SCHEDULED_SCAN"),0)>0.5 && GVRead(DemoSoakKey("ZERO_TOL"),0)==0 &&
               GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0)==0);
   FileWrite(h,"demo_soak_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),InpDemoSoakEvidenceId,eventName,symbol,detail,
      GVRead(DemoSoakKey("CONSEC_DAYS"),0),GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),
      GVRead(DemoSoakKey("LONDON_DAYS"),0),GVRead(DemoSoakKey("NY_DAYS"),0),GVRead(DemoSoakKey("OVERLAP_DAYS"),0),
      GVRead(DemoSoakKey("NEWS_DAYS"),0),GVRead(DemoSoakKey("ROLLOVER_WINDOW"),0),GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0),
      GVRead(DemoSoakKey("RESTARTS"),0),GVRead(DemoSoakKey("RECONNECTS"),0),GVRead(DemoSoakKey("MANUAL_SCAN"),0),
      GVRead(DemoSoakKey("SCHEDULED_SCAN"),0),GVRead(DemoSoakKey("ZERO_TOL"),0),GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),
      ready?"1":"0",AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER));
   FileFlush(h); FileClose(h);
}

void ResetDemoSoakRunState()
{
   string keys[]={"START_TIME","LAST_INIT","LAST_OBSERVE","LAST_SUMMARY","LAST_DAY","CONSEC_DAYS","MAX_CONSEC_DAYS","TOTAL_DAYS",
      "LAST_LONDON_DAY","LONDON_DAYS","LAST_NY_DAY","NY_DAYS","LAST_OVERLAP_DAY","OVERLAP_DAYS","LAST_NEWS_DAY","NEWS_DAYS",
      "ROLLOVER_WINDOW","ROLLOVER_SPREAD","RESTARTS","RECONNECTS","CONNECTED_PREV","SAW_DISCONNECT","MANUAL_SCAN","SCHEDULED_SCAN",
      "LAST_MANUAL_SCAN","LAST_SCHEDULED_SCAN","ZERO_TOL","INCIDENTS","UNRESOLVED_CURRENT","CRITICAL_LATCH"};
   for(int i=0;i<ArraySize(keys);i++) GVWrite(DemoSoakKey(keys[i]),0);
   GVWrite(DemoSoakKey("RUN_HASH"),TextChecksum(InpDemoSoakEvidenceId));
   GVWrite(DemoSoakKey("START_TIME"),(double)TimeTradeServer());
   GlobalVariablesFlush();
}

bool EnsureDemoSoakRun()
{
   if(!DemoSoakEligible()) return false;
   int hash=TextChecksum(InpDemoSoakEvidenceId);
   int stored=(int)GVRead(DemoSoakKey("RUN_HASH"),0);
   if(stored!=hash) ResetDemoSoakRunState();
   return true;
}

void RecordDemoSoakIncident(const string code,const string detail,bool zeroTolerance)
{
   if(!EnsureDemoSoakRun()) return;
   GVWrite(DemoSoakKey("INCIDENTS"),GVRead(DemoSoakKey("INCIDENTS"),0)+1);
   if(zeroTolerance) GVWrite(DemoSoakKey("ZERO_TOL"),GVRead(DemoSoakKey("ZERO_TOL"),0)+1);
   WriteDemoSoakEvidenceEvent(zeroTolerance?"ZERO_TOLERANCE_INCIDENT":"INCIDENT","",code+" | "+detail);
   GlobalVariablesFlush();
}

void DemoSoakMarkUniqueDay(const string lastKey,const string countKey,datetime day,const string eventName)
{
   datetime last=(datetime)GVRead(DemoSoakKey(lastKey),0);
   if(last==day) return;
   GVWrite(DemoSoakKey(lastKey),(double)day);
   GVWrite(DemoSoakKey(countKey),GVRead(DemoSoakKey(countKey),0)+1);
   WriteDemoSoakEvidenceEvent(eventName,"",TimeToString(day,TIME_DATE));
}

void ObserveDemoSoakTradingDay(datetime now)
{
   if(!DemoSoakTradingDay(now)) return;
   string sym=""; if(!DemoSoakHasFreshQuote(sym)) return;
   datetime day=DemoSoakDayStart(now);
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_DAY"),0);
   if(last==day) return;
   int consecutive=1;
   if(last>0 && DemoSoakConsecutiveTradingDay(last,day)) consecutive=(int)GVRead(DemoSoakKey("CONSEC_DAYS"),0)+1;
   GVWrite(DemoSoakKey("LAST_DAY"),(double)day);
   GVWrite(DemoSoakKey("CONSEC_DAYS"),consecutive);
   GVWrite(DemoSoakKey("MAX_CONSEC_DAYS"),MathMax(GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),(double)consecutive));
   GVWrite(DemoSoakKey("TOTAL_DAYS"),GVRead(DemoSoakKey("TOTAL_DAYS"),0)+1);
   WriteDemoSoakEvidenceEvent("TRADING_DAY_OBSERVED",sym,StringFormat("day %s | consecutive %d",TimeToString(day,TIME_DATE),consecutive));
}

void ObserveDemoSoakSessions(datetime now)
{
   string sym=""; if(!DemoSoakHasFreshQuote(sym)) return;
   datetime day=DemoSoakDayStart(now);
   string ses=AccurateSessionBucket();
   if(ses=="LONDON") DemoSoakMarkUniqueDay("LAST_LONDON_DAY","LONDON_DAYS",day,"LONDON_SESSION_OBSERVED");
   else if(ses=="NEW_YORK_OPEN") DemoSoakMarkUniqueDay("LAST_NY_DAY","NY_DAYS",day,"NEW_YORK_SESSION_OBSERVED");
   else if(ses=="LONDON_NY_OVERLAP")
   {
      DemoSoakMarkUniqueDay("LAST_OVERLAP_DAY","OVERLAP_DAYS",day,"LONDON_NY_OVERLAP_OBSERVED");
      DemoSoakMarkUniqueDay("LAST_LONDON_DAY","LONDON_DAYS",day,"LONDON_SESSION_OBSERVED_VIA_OVERLAP");
      DemoSoakMarkUniqueDay("LAST_NY_DAY","NY_DAYS",day,"NEW_YORK_SESSION_OBSERVED_VIA_OVERLAP");
   }
}

void ObserveDemoSoakNews(datetime now)
{
   datetime day=DemoSoakDayStart(now);
   if((datetime)GVRead(DemoSoakKey("LAST_NEWS_DAY"),0)==day) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      if(HighImpactEventWithin(sym,MathMax(30,InpStrategyNewsContextMinutes)))
      {
         GVWrite(DemoSoakKey("LAST_NEWS_DAY"),(double)day);
         GVWrite(DemoSoakKey("NEWS_DAYS"),GVRead(DemoSoakKey("NEWS_DAYS"),0)+1);
         WriteDemoSoakEvidenceEvent("HIGH_IMPACT_NEWS_DAY_OBSERVED",sym,UpcomingEventSummary(sym));
         return;
      }
   }
}

bool DemoSoakRolloverHourUTC(int h)
{
   int a=MathMax(0,MathMin(23,InpDemoSoakRolloverStartHourUTC));
   int b=MathMax(0,MathMin(23,InpDemoSoakRolloverEndHourUTC));
   if(a<=b) return (h>=a && h<=b);
   return (h>=a || h<=b);
}

void ObserveDemoSoakRollover()
{
   MqlDateTime u={}; TimeToStruct(TimeGMT(),u);
   if(!DemoSoakRolloverHourUTC(u.hour)) return;
   if(GVRead(DemoSoakKey("ROLLOVER_WINDOW"),0)<0.5)
   {
      GVWrite(DemoSoakKey("ROLLOVER_WINDOW"),1);
      WriteDemoSoakEvidenceEvent("ROLLOVER_WINDOW_OBSERVED","",StringFormat("UTC hour %d",u.hour));
   }
   if(GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      MqlTick t={}; double atr=0;
      if(!GetTickSafe(sym,t) || !ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) || atr<=0) continue;
      double ratio=(t.ask-t.bid)/atr;
      if(ratio>=MathMax(0.01,InpDemoSoakRolloverSpreadATRFrac))
      {
         GVWrite(DemoSoakKey("ROLLOVER_SPREAD"),1);
         WriteDemoSoakEvidenceEvent("ROLLOVER_SPREAD_EXPANSION_OBSERVED",sym,StringFormat("spread/M5 ATR %.3f",ratio));
         return;
      }
   }
}

void ObserveDemoSoakConnection()
{
   bool connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool prev=GVRead(DemoSoakKey("CONNECTED_PREV"),connected?1:0)>0.5;
   if(!connected)
   {
      if(prev) WriteDemoSoakEvidenceEvent("DISCONNECT_OBSERVED","","terminal connection transitioned to disconnected");
      GVWrite(DemoSoakKey("SAW_DISCONNECT"),1);
   }
   else if(!prev && GVRead(DemoSoakKey("SAW_DISCONNECT"),0)>0.5)
   {
      GVWrite(DemoSoakKey("RECONNECTS"),GVRead(DemoSoakKey("RECONNECTS"),0)+1);
      WriteDemoSoakEvidenceEvent("RECONNECT_OBSERVED","","terminal connection recovered after observed disconnect");
   }
   GVWrite(DemoSoakKey("CONNECTED_PREV"),connected?1:0);
}

int DemoSoakCurrentCriticalStates(string &detail)
{
   int count=0; detail="";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetDouble(POSITION_SL)<=0){ count++; detail+="unprotected position "+PositionGetString(POSITION_SYMBOL)+"; "; }
   }
   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   {
      string u=stopWhy; StringToUpper(u);
      if(StringFind(u,"CRITICAL")>=0 || StringFind(u,"UNPROTECTED")>=0 || StringFind(u,"OPERATOR")>=0)
      { count++; detail+="stop observability: "+stopWhy+"; "; }
   }
   return count;
}

void ReconcileStaleApprovalWaitStates()
{
   if(!InpUseLifecycleStateMachine) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="" || DemoSoakHasOpenPosition(sym)) continue;
      int state=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
      int kind=(int)GVRead(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
      if(state!=LIFE_WAIT_CONFIRMATION || kind!=LIFECYCLE_WAIT_HUMAN_APPROVAL) continue;
      if(DemoSoakPendingApprovalActive(sym)) continue;
      string reason="human-approval WAIT state had no active pending approval; reconciled after approval/revalidation path ended without a fill";
      if(SetSymbolLifecycle(sym,LIFE_INVALIDATED,reason))
      {
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
         if(DemoSoakEligible()) WriteDemoSoakEvidenceEvent("STALE_APPROVAL_LIFECYCLE_RECONCILED",sym,reason);
      }
   }
}

void ObserveDemoSoakCriticalStates()
{
   string detail=""; int n=DemoSoakCurrentCriticalStates(detail);
   GVWrite(DemoSoakKey("UNRESOLVED_CURRENT"),n);
   bool latched=GVRead(DemoSoakKey("CRITICAL_LATCH"),0)>0.5;
   if(n>0 && !latched)
   {
      GVWrite(DemoSoakKey("CRITICAL_LATCH"),1);
      RecordDemoSoakIncident("CRITICAL_PROTECTION_STATE",detail,true);
   }
   else if(n==0 && latched)
   {
      GVWrite(DemoSoakKey("CRITICAL_LATCH"),0);
      WriteDemoSoakEvidenceEvent("CRITICAL_STATE_CLEARED","","all machine-observed critical protection states cleared");
   }
}

void ObserveDemoSoakScanCard(const string card)
{
   if(!EnsureDemoSoakRun()) return;
   datetime now=TimeTradeServer();
   if(StringFind(card,"Scan: Manual SCAN NOW")>=0)
   {
      datetime last=(datetime)GVRead(DemoSoakKey("LAST_MANUAL_SCAN"),0);
      if(last<=0 || now-last>5)
      {
         GVWrite(DemoSoakKey("LAST_MANUAL_SCAN"),(double)now);
         GVWrite(DemoSoakKey("MANUAL_SCAN"),1);
         WriteDemoSoakEvidenceEvent("MANUAL_SCAN_OBSERVED","","manual SCAN NOW produced a complete decision card");
      }
      return;
   }
   int p=StringFind(card,"Scan:");
   if(p<0 || StringFind(card,"EA startup / restart recovery")>=0) return;
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_SCHEDULED_SCAN"),0);
   if(last<=0 || now-last>10)
   {
      GVWrite(DemoSoakKey("LAST_SCHEDULED_SCAN"),(double)now);
      GVWrite(DemoSoakKey("SCHEDULED_SCAN"),1);
      WriteDemoSoakEvidenceEvent("SCHEDULED_OR_CONTINUOUS_SCAN_OBSERVED","","non-manual scheduled/continuous scan produced a complete decision card");
   }
}

bool DemoSoakCoverageReady()
{
   if(!DemoSoakEligible()) return false;
   return (GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0)>=5 && GVRead(DemoSoakKey("LONDON_DAYS"),0)>=3 &&
           GVRead(DemoSoakKey("NY_DAYS"),0)>=3 && GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>=1 &&
           GVRead(DemoSoakKey("NEWS_DAYS"),0)>=1 && GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5 &&
           GVRead(DemoSoakKey("RESTARTS"),0)>=1 && GVRead(DemoSoakKey("RECONNECTS"),0)>=1 &&
           GVRead(DemoSoakKey("MANUAL_SCAN"),0)>0.5 && GVRead(DemoSoakKey("SCHEDULED_SCAN"),0)>0.5 &&
           GVRead(DemoSoakKey("ZERO_TOL"),0)==0 && GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0)==0);
}

string DemoSoakEvidenceSummary()
{
   if(!InpEnableDemoSoakEvidence) return "Demo soak evidence: disabled.";
   if(!DemoSoakEligible()) return "Demo soak evidence: inactive (requires non-real terminal, non-tester run and evidence ID >= 4 chars).";
   return StringFormat("Demo soak %s | consecutive %d/5 (max %d) | London %d/3 | NY %d/3 | overlap %d | news days %d | rollover spread %s | restarts %d | reconnects %d | manual/scheduled scan %s/%s | zero-tolerance %d | unresolved critical %d | coverage %s",
      InpDemoSoakEvidenceId,(int)GVRead(DemoSoakKey("CONSEC_DAYS"),0),(int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),
      (int)GVRead(DemoSoakKey("LONDON_DAYS"),0),(int)GVRead(DemoSoakKey("NY_DAYS"),0),(int)GVRead(DemoSoakKey("OVERLAP_DAYS"),0),
      (int)GVRead(DemoSoakKey("NEWS_DAYS"),0),GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?"YES":"NO",
      (int)GVRead(DemoSoakKey("RESTARTS"),0),(int)GVRead(DemoSoakKey("RECONNECTS"),0),
      GVRead(DemoSoakKey("MANUAL_SCAN"),0)>0.5?"YES":"NO",GVRead(DemoSoakKey("SCHEDULED_SCAN"),0)>0.5?"YES":"NO",
      (int)GVRead(DemoSoakKey("ZERO_TOL"),0),(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),DemoSoakCoverageReady()?"READY_FOR_HUMAN_REVIEW":"INCOMPLETE");
}

void DemoSoakEvidenceInit()
{
   if(!InpEnableDemoSoakEvidence) return;
   if((bool)MQLInfoInteger(MQL_TESTER)){ Print("Demo-soak evidence disabled in Strategy Tester; use a demo/contest terminal."); return; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){ Print("Demo-soak evidence capture refuses REAL-account mode."); return; }
   if(StringLen(InpDemoSoakEvidenceId)<4){ Print("Demo-soak evidence enabled but InpDemoSoakEvidenceId is missing/too short."); return; }
   bool existing=((int)GVRead(DemoSoakKey("RUN_HASH"),0)==TextChecksum(InpDemoSoakEvidenceId));
   datetime lastInit=(datetime)GVRead(DemoSoakKey("LAST_INIT"),0);
   EnsureDemoSoakRun(); EnsureDemoSoakEvidenceHeader();
   if(existing && lastInit>0)
   {
      GVWrite(DemoSoakKey("RESTARTS"),GVRead(DemoSoakKey("RESTARTS"),0)+1);
      WriteDemoSoakEvidenceEvent("EA_RESTART_OR_REINIT_OBSERVED","",StringFormat("previous init %s",TimeToString(lastInit,TIME_DATE|TIME_SECONDS)));
   }
   GVWrite(DemoSoakKey("LAST_INIT"),(double)TimeTradeServer());
   GVWrite(DemoSoakKey("CONNECTED_PREV"),(bool)TerminalInfoInteger(TERMINAL_CONNECTED)?1:0);
   WriteDemoSoakEvidenceEvent("SOAK_INIT","",DemoSoakEvidenceSummary());
   GlobalVariablesFlush();
}

void DemoSoakEvidenceTimer()
{
   ReconcileStaleApprovalWaitStates();
   if(!EnsureDemoSoakRun()) return;
   datetime now=TimeTradeServer();
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_OBSERVE"),0);
   if(last>0 && now-last<MathMax(10,InpDemoSoakObservationSeconds)) return;
   GVWrite(DemoSoakKey("LAST_OBSERVE"),(double)now);
   ObserveDemoSoakConnection();
   ObserveDemoSoakTradingDay(now);
   ObserveDemoSoakSessions(now);
   ObserveDemoSoakNews(now);
   ObserveDemoSoakRollover();
   ObserveDemoSoakCriticalStates();

   datetime lastSummary=(datetime)GVRead(DemoSoakKey("LAST_SUMMARY"),0);
   if(lastSummary<=0 || now-lastSummary>=MathMax(1,InpDemoSoakSummaryMinutes)*60)
   {
      GVWrite(DemoSoakKey("LAST_SUMMARY"),(double)now);
      WriteDemoSoakEvidenceEvent("SUMMARY","",DemoSoakEvidenceSummary());
   }
   GlobalVariablesFlush();
}

void DemoSoakEvidenceShutdown()
{
   if(!DemoSoakEligible()) return;
   ObserveDemoSoakCriticalStates();
   WriteDemoSoakEvidenceEvent("SOAK_SHUTDOWN","",DemoSoakEvidenceSummary());
   GlobalVariablesFlush();
}
