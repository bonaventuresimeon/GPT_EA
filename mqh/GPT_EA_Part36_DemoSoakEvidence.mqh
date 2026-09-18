// ============================================================================
// GPT_EA Part 36 - Machine-observed R6 demo-soak evidence
// ============================================================================
// This module does NOT self-certify a release. It records durable observations
// and writes an exportable demo_soak JSON object. The operator must reconcile
// the machine evidence with terminal logs, complete the report, finalize the
// SHA-256 digest offline and pass the R6 release-evidence validators.

input bool   InpEnableDemoSoakEvidence              = false;
input string InpDemoSoakEvidenceId                  = ""; // >= 8 chars; unique per candidate soak
input string InpDemoSoakEvidenceFile                = "GPT_EA_DemoSoakEvidence.csv";
input string InpDemoSoakSnapshotJsonFile            = "GPT_EA_DemoSoakSnapshot.json";
input string InpDemoSoakReportReference             = "artifacts/demo-soak-report.md";
input int    InpDemoSoakObservationSeconds          = 60;
input int    InpDemoSoakSummaryMinutes              = 15;
input int    InpDemoSoakFreshQuoteSeconds           = 60;
input bool   InpDemoSoakCountWeekendTradingDays     = false;
input int    InpDemoSoakRolloverStartHourUTC        = 20;
input int    InpDemoSoakRolloverEndHourUTC          = 23;
input double InpDemoSoakRolloverSpreadATRFrac       = 0.12;

const string GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA="demo_soak_evidence_v1";

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
   return StringLen(InpDemoSoakEvidenceId)>=8;
}

string DemoSoakIso(datetime tm)
{
   MqlDateTime t={}; TimeToStruct(tm,t);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d",t.year,t.mon,t.day,t.hour,t.min,t.sec);
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
      if(MathAbs((double)(now-t.time))<=maxAge){ observedSymbol=sym; return true; }
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

bool DemoSoakAnyPendingApproval()
{
   for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) return true;
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
         "trading_days","current_consecutive_days","london_sessions","ny_sessions","overlap_observed","news_day_observed","rollover_observed",
         "restart_observed","reconnect_observed","scheduled_scans","continuous_scans","manual_scans","checkpoint_updates","backup_checkpoint_updates",
         "zero_tolerance_failures","unresolved_critical_states","duplicate_orders","duplicate_partials","sl_regressions","unprotected_new_authorizations",
         "release_gate_bypasses","analytics_duplicate_finalizations","stop_failure_join_failures","dashboard_gate_mismatches","runtime_critical_errors",
         "secrets_exposed","execution_log_present","stop_log_present","release_evidence_log_present","machine_coverage_ready","broker","server");
   FileClose(h);
}

bool DemoSoakLogPresent(const string fileName)
{
   if(fileName=="") return false;
   return FileIsExist(fileName,FILE_COMMON);
}

void RefreshDemoSoakLogPresence()
{
   GVWrite(DemoSoakKey("EXEC_LOG"),DemoSoakLogPresent(InpExecutionJournalFile)?1:0);
   GVWrite(DemoSoakKey("STOP_LOG"),DemoSoakLogPresent(InpStopFailureObservabilityFile)?1:0);
   GVWrite(DemoSoakKey("RELEASE_LOG"),DemoSoakLogPresent(InpReleaseEvidenceSnapshotFile)?1:0);
}

bool DemoSoakFailureCountersClear()
{
   string keys[]={"ZERO_TOL","UNRESOLVED_CURRENT","DUP_ORDERS","DUP_PARTIALS","SL_REGRESSIONS","UNPROTECTED_AUTH",
                  "RELEASE_BYPASS","ANALYTICS_DUP_FINAL","STOP_JOIN_FAIL","DASH_MISMATCH","RUNTIME_CRITICAL","SECRETS"};
   for(int i=0;i<ArraySize(keys);i++) if(GVRead(DemoSoakKey(keys[i]),0)!=0) return false;
   return true;
}

bool DemoSoakCoverageReady()
{
   if(!DemoSoakEligible()) return false;
   RefreshDemoSoakLogPresence();
   return (GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0)>=5 &&
           GVRead(DemoSoakKey("LONDON_DAYS"),0)>=3 && GVRead(DemoSoakKey("NY_DAYS"),0)>=3 &&
           GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>=1 && GVRead(DemoSoakKey("NEWS_DAYS"),0)>=1 &&
           GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5 && GVRead(DemoSoakKey("RESTARTS"),0)>=1 &&
           GVRead(DemoSoakKey("RECONNECTS"),0)>=1 && GVRead(DemoSoakKey("SCHEDULED_SCANS"),0)>=1 &&
           GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0)>=1 && GVRead(DemoSoakKey("MANUAL_SCANS"),0)>=1 &&
           GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0)>=1 && GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0)>=1 &&
           DemoSoakFailureCountersClear() && GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5 &&
           GVRead(DemoSoakKey("STOP_LOG"),0)>0.5 && GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5);
}

void WriteDemoSoakEvidenceEvent(const string eventName,const string symbol,const string detail)
{
   if(!DemoSoakEligible()) return;
   EnsureDemoSoakEvidenceHeader();
   RefreshDemoSoakLogPresence();
   int h=FileOpen(InpDemoSoakEvidenceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),InpDemoSoakEvidenceId,eventName,symbol,detail,
      (int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),(int)GVRead(DemoSoakKey("CONSEC_DAYS"),0),
      (int)GVRead(DemoSoakKey("LONDON_DAYS"),0),(int)GVRead(DemoSoakKey("NY_DAYS"),0),
      GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?1:0,GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?1:0,GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?1:0,
      GVRead(DemoSoakKey("RESTARTS"),0)>0?1:0,GVRead(DemoSoakKey("RECONNECTS"),0)>0?1:0,
      (int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0),(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0),(int)GVRead(DemoSoakKey("MANUAL_SCANS"),0),
      (int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0),(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0),
      (int)GVRead(DemoSoakKey("ZERO_TOL"),0),(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),(int)GVRead(DemoSoakKey("DUP_ORDERS"),0),
      (int)GVRead(DemoSoakKey("DUP_PARTIALS"),0),(int)GVRead(DemoSoakKey("SL_REGRESSIONS"),0),(int)GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0),
      (int)GVRead(DemoSoakKey("RELEASE_BYPASS"),0),(int)GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0),(int)GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0),
      (int)GVRead(DemoSoakKey("DASH_MISMATCH"),0),(int)GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0),(int)GVRead(DemoSoakKey("SECRETS"),0),
      GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?1:0,GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?1:0,GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?1:0,
      DemoSoakCoverageReady()?1:0,AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER));
   FileFlush(h); FileClose(h);
}

void ResetDemoSoakRunState()
{
   string keys[]={"START_TIME","LAST_INIT","LAST_OBSERVE","LAST_SUMMARY","LAST_DAY","CONSEC_DAYS","MAX_CONSEC_DAYS","TOTAL_DAYS",
      "LAST_LONDON_DAY","LONDON_DAYS","LAST_NY_DAY","NY_DAYS","LAST_OVERLAP_DAY","OVERLAP_DAYS","LAST_NEWS_DAY","NEWS_DAYS",
      "ROLLOVER_WINDOW","ROLLOVER_SPREAD","RESTARTS","RECONNECTS","CONNECTED_PREV","SAW_DISCONNECT",
      "MANUAL_SCANS","SCHEDULED_SCANS","CONTINUOUS_SCANS","LAST_SCAN_TIME","LAST_SCAN_HASH",
      "CHECKPOINT_UPDATES","BACKUP_CHECKPOINT_UPDATES","LAST_CHECKPOINT_TIME",
      "ZERO_TOL","INCIDENTS","UNRESOLVED_CURRENT","CRITICAL_LATCH","UNPROTECTED_AUTH_LATCH","DASH_MISMATCH_LATCH",
      "DUP_ORDERS","DUP_PARTIALS","SL_REGRESSIONS","UNPROTECTED_AUTH","RELEASE_BYPASS","ANALYTICS_DUP_FINAL","STOP_JOIN_FAIL",
      "DASH_MISMATCH","RUNTIME_CRITICAL","SECRETS","EXEC_LOG","STOP_LOG","RELEASE_LOG"};
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

void IncrementDemoSoakFailureMetric(const string code)
{
   string u=code; StringToUpper(u);
   if(u=="DUPLICATE_ORDER") GVWrite(DemoSoakKey("DUP_ORDERS"),GVRead(DemoSoakKey("DUP_ORDERS"),0)+1);
   else if(u=="DUPLICATE_PARTIAL") GVWrite(DemoSoakKey("DUP_PARTIALS"),GVRead(DemoSoakKey("DUP_PARTIALS"),0)+1);
   else if(u=="SL_REGRESSION") GVWrite(DemoSoakKey("SL_REGRESSIONS"),GVRead(DemoSoakKey("SL_REGRESSIONS"),0)+1);
   else if(u=="UNPROTECTED_NEW_AUTHORIZATION") GVWrite(DemoSoakKey("UNPROTECTED_AUTH"),GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0)+1);
   else if(u=="RELEASE_GATE_BYPASS") GVWrite(DemoSoakKey("RELEASE_BYPASS"),GVRead(DemoSoakKey("RELEASE_BYPASS"),0)+1);
   else if(u=="ANALYTICS_DUPLICATE_FINALIZATION") GVWrite(DemoSoakKey("ANALYTICS_DUP_FINAL"),GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0)+1);
   else if(u=="STOP_FAILURE_JOIN_FAILURE") GVWrite(DemoSoakKey("STOP_JOIN_FAIL"),GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0)+1);
   else if(u=="DASHBOARD_GATE_MISMATCH") GVWrite(DemoSoakKey("DASH_MISMATCH"),GVRead(DemoSoakKey("DASH_MISMATCH"),0)+1);
   else if(u=="RUNTIME_CRITICAL_ERROR" || u=="CRITICAL_PROTECTION_STATE") GVWrite(DemoSoakKey("RUNTIME_CRITICAL"),GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0)+1);
   else if(u=="SECRET_EXPOSED") GVWrite(DemoSoakKey("SECRETS"),GVRead(DemoSoakKey("SECRETS"),0)+1);
}

void RecordDemoSoakIncident(const string code,const string detail,bool zeroTolerance)
{
   if(!EnsureDemoSoakRun()) return;
   GVWrite(DemoSoakKey("INCIDENTS"),GVRead(DemoSoakKey("INCIDENTS"),0)+1);
   if(zeroTolerance)
   {
      GVWrite(DemoSoakKey("ZERO_TOL"),GVRead(DemoSoakKey("ZERO_TOL"),0)+1);
      IncrementDemoSoakFailureMetric(code);
   }
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

void ObserveDemoSoakRecoveryCheckpoints()
{
   datetime cp=g_lastUniversalCheckpoint;
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_CHECKPOINT_TIME"),0);
   if(cp<=0 || cp==last) return;
   GVWrite(DemoSoakKey("LAST_CHECKPOINT_TIME"),(double)cp);
   GVWrite(DemoSoakKey("CHECKPOINT_UPDATES"),GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0)+1);
   bool backupOK=(InpKeepRecoveryBackup && RecoveryCheckpointHeaderValid(RecoveryBackupFileName()));
   if(backupOK) GVWrite(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0)+1);
   WriteDemoSoakEvidenceEvent("RECOVERY_CHECKPOINT_OBSERVED","",backupOK?"primary + validated backup present":"primary checkpoint update observed; validated backup not yet observed");
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
      string reason="human-approval WAIT state has no active pending approval; approval/revalidation path ended without a fill";
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

   bool unprotected=(n>0);
   bool auth=DemoSoakAnyPendingApproval();
   bool authLatched=GVRead(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),0)>0.5;
   if(unprotected && auth && !authLatched)
   {
      GVWrite(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),1);
      RecordDemoSoakIncident("UNPROTECTED_NEW_AUTHORIZATION","pending approval existed while a machine-observed critical/unprotected state was active",true);
   }
   else if((!unprotected || !auth) && authLatched) GVWrite(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),0);
}

void ObserveDemoSoakReleaseDashboardConsistency()
{
   string summary=ReleaseGateSummary();
   bool reportedPass=(StringFind(summary,"PASS") == 0);
   bool actualPass=!g_releaseBlocked;
   bool mismatch=(reportedPass!=actualPass);
   bool latched=GVRead(DemoSoakKey("DASH_MISMATCH_LATCH"),0)>0.5;
   if(mismatch && !latched)
   {
      GVWrite(DemoSoakKey("DASH_MISMATCH_LATCH"),1);
      RecordDemoSoakIncident("DASHBOARD_GATE_MISMATCH","release summary and runtime g_releaseBlocked disagree: "+summary,true);
   }
   else if(!mismatch && latched) GVWrite(DemoSoakKey("DASH_MISMATCH_LATCH"),0);
}

string DemoSoakCardLine(const string card,const string prefix)
{
   int p=StringFind(card,prefix); if(p<0) return "";
   p+=StringLen(prefix);
   int e=StringFind(card,"\n",p); if(e<0) e=StringLen(card);
   string out=StringSubstr(card,p,e-p); StringTrimLeft(out); StringTrimRight(out); return out;
}

void ObserveDemoSoakScanCard(const string card)
{
   if(!EnsureDemoSoakRun()) return;
   string reason=DemoSoakCardLine(card,"Scan:"); if(reason=="") return;
   if(StringFind(reason,"startup / restart recovery")>=0) return;
   datetime now=TimeTradeServer();
   int hash=TextChecksum(reason);
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_SCAN_TIME"),0);
   int oldHash=(int)GVRead(DemoSoakKey("LAST_SCAN_HASH"),0);
   if(last>0 && now-last<=15 && oldHash==hash) return; // same multi-symbol scan
   GVWrite(DemoSoakKey("LAST_SCAN_TIME"),(double)now); GVWrite(DemoSoakKey("LAST_SCAN_HASH"),hash);

   string u=reason; StringToUpper(u);
   if(StringFind(u,"MANUAL SCAN NOW")>=0)
   {
      GVWrite(DemoSoakKey("MANUAL_SCANS"),GVRead(DemoSoakKey("MANUAL_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("MANUAL_SCAN_OBSERVED","",reason);
   }
   else if(StringFind(u,"CONTINUOUS")>=0 || StringFind(u,"NEW-M5-BAR")>=0)
   {
      GVWrite(DemoSoakKey("CONTINUOUS_SCANS"),GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("CONTINUOUS_SCAN_OBSERVED","",reason);
   }
   else
   {
      GVWrite(DemoSoakKey("SCHEDULED_SCANS"),GVRead(DemoSoakKey("SCHEDULED_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("SCHEDULED_SCAN_OBSERVED","",reason);
   }
}

void WriteDemoSoakJsonSnapshot()
{
   if(!DemoSoakEligible()) return;
   RefreshDemoSoakLogPresence();
   int h=FileOpen(InpDemoSoakSnapshotJsonFile,FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("Demo-soak JSON snapshot open failed: ",GetLastError()); return; }
   datetime start=(datetime)GVRead(DemoSoakKey("START_TIME"),TimeTradeServer());
   datetime now=TimeTradeServer();
   string json="{\n";
   json+="  \"schema_version\": \""+GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA+"\",\n";
   json+="  \"evidence_id\": \""+JsonEscape(InpDemoSoakEvidenceId)+"\",\n";
   json+="  \"evidence_digest\": \"\",\n"; // finalized offline by validator/finalizer
   json+="  \"start\": \""+DemoSoakIso(start)+"\",\n";
   json+="  \"end\": \""+DemoSoakIso(now)+"\",\n";
   json+=StringFormat("  \"trading_days\": %d,\n",(int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0));
   json+=StringFormat("  \"london_sessions\": %d,\n",(int)GVRead(DemoSoakKey("LONDON_DAYS"),0));
   json+=StringFormat("  \"ny_sessions\": %d,\n",(int)GVRead(DemoSoakKey("NY_DAYS"),0));
   json+="  \"overlap_observed\": "+(GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?"true":"false")+",\n";
   json+="  \"news_day_observed\": "+(GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?"true":"false")+",\n";
   json+="  \"rollover_observed\": "+(GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?"true":"false")+",\n";
   json+="  \"restart_observed\": "+(GVRead(DemoSoakKey("RESTARTS"),0)>0?"true":"false")+",\n";
   json+="  \"reconnect_observed\": "+(GVRead(DemoSoakKey("RECONNECTS"),0)>0?"true":"false")+",\n";
   json+=StringFormat("  \"scheduled_scans\": %d,\n",(int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0));
   json+=StringFormat("  \"continuous_scans\": %d,\n",(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0));
   json+=StringFormat("  \"checkpoint_updates\": %d,\n",(int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0));
   json+=StringFormat("  \"backup_checkpoint_updates\": %d,\n",(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0));
   json+=StringFormat("  \"zero_tolerance_failures\": %d,\n",(int)GVRead(DemoSoakKey("ZERO_TOL"),0));
   json+=StringFormat("  \"unresolved_critical_states\": %d,\n",(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0));
   json+=StringFormat("  \"duplicate_orders\": %d,\n",(int)GVRead(DemoSoakKey("DUP_ORDERS"),0));
   json+=StringFormat("  \"duplicate_partials\": %d,\n",(int)GVRead(DemoSoakKey("DUP_PARTIALS"),0));
   json+=StringFormat("  \"sl_regressions\": %d,\n",(int)GVRead(DemoSoakKey("SL_REGRESSIONS"),0));
   json+=StringFormat("  \"unprotected_new_authorizations\": %d,\n",(int)GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0));
   json+=StringFormat("  \"release_gate_bypasses\": %d,\n",(int)GVRead(DemoSoakKey("RELEASE_BYPASS"),0));
   json+=StringFormat("  \"analytics_duplicate_finalizations\": %d,\n",(int)GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0));
   json+=StringFormat("  \"stop_failure_join_failures\": %d,\n",(int)GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0));
   json+=StringFormat("  \"dashboard_gate_mismatches\": %d,\n",(int)GVRead(DemoSoakKey("DASH_MISMATCH"),0));
   json+=StringFormat("  \"runtime_critical_errors\": %d,\n",(int)GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0));
   json+=StringFormat("  \"secrets_exposed\": %d,\n",(int)GVRead(DemoSoakKey("SECRETS"),0));
   json+="  \"execution_log_present\": "+(GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"stop_log_present\": "+(GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"release_evidence_log_present\": "+(GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"report_path\": \""+JsonEscape(InpDemoSoakReportReference)+"\"\n";
   json+="}\n";
   FileWriteString(h,json); FileFlush(h); FileClose(h);
}

string DemoSoakEvidenceSummary()
{
   if(!InpEnableDemoSoakEvidence) return "Demo soak evidence: disabled.";
   if(!DemoSoakEligible()) return "Demo soak evidence: inactive (requires demo/contest terminal, non-tester run and evidence ID >= 8 chars).";
   return StringFormat("Demo soak %s [%s] | consecutive %d/5 | London %d/3 | NY %d/3 | overlap/news/rollover %s/%s/%s | restart/reconnect %s/%s | scheduled/continuous/manual %d/%d/%d | checkpoint/backup %d/%d | zero-tolerance %d | unresolved critical %d | logs E/S/R %s/%s/%s | machine coverage %s",
      InpDemoSoakEvidenceId,GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA,(int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),
      (int)GVRead(DemoSoakKey("LONDON_DAYS"),0),(int)GVRead(DemoSoakKey("NY_DAYS"),0),
      GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?"Y":"N",GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?"Y":"N",GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?"Y":"N",
      GVRead(DemoSoakKey("RESTARTS"),0)>0?"Y":"N",GVRead(DemoSoakKey("RECONNECTS"),0)>0?"Y":"N",
      (int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0),(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0),(int)GVRead(DemoSoakKey("MANUAL_SCANS"),0),
      (int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0),(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0),
      (int)GVRead(DemoSoakKey("ZERO_TOL"),0),(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),
      GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?"Y":"N",GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?"Y":"N",GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?"Y":"N",
      DemoSoakCoverageReady()?"READY_FOR_HUMAN_RECONCILIATION":"INCOMPLETE");
}

void DemoSoakEvidenceInit()
{
   ReconcileStaleApprovalWaitStates();
   if(!InpEnableDemoSoakEvidence) return;
   if((bool)MQLInfoInteger(MQL_TESTER)){ Print("Demo-soak evidence disabled in Strategy Tester; use a demo/contest terminal."); return; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){ Print("Demo-soak evidence capture refuses REAL-account mode."); return; }
   if(StringLen(InpDemoSoakEvidenceId)<8){ Print("Demo-soak evidence enabled but InpDemoSoakEvidenceId must contain at least 8 characters."); return; }

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
   ObserveDemoSoakRecoveryCheckpoints();
   RefreshDemoSoakLogPresence();
   WriteDemoSoakEvidenceEvent("SOAK_INIT","",DemoSoakEvidenceSummary());
   WriteDemoSoakJsonSnapshot();
   GlobalVariablesFlush();
}

void DemoSoakEvidenceTimer()
{
   // Lifecycle stale-state reconciliation is always active, even when soak capture is disabled.
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
   ObserveDemoSoakRecoveryCheckpoints();
   ObserveDemoSoakCriticalStates();
   ObserveDemoSoakReleaseDashboardConsistency();
   RefreshDemoSoakLogPresence();

   datetime lastSummary=(datetime)GVRead(DemoSoakKey("LAST_SUMMARY"),0);
   if(lastSummary<=0 || now-lastSummary>=MathMax(1,InpDemoSoakSummaryMinutes)*60)
   {
      GVWrite(DemoSoakKey("LAST_SUMMARY"),(double)now);
      WriteDemoSoakEvidenceEvent("SUMMARY","",DemoSoakEvidenceSummary());
      WriteDemoSoakJsonSnapshot();
   }
   GlobalVariablesFlush();
}

void DemoSoakEvidenceShutdown()
{
   ReconcileStaleApprovalWaitStates();
   if(!DemoSoakEligible()) return;
   ObserveDemoSoakRecoveryCheckpoints();
   ObserveDemoSoakCriticalStates();
   ObserveDemoSoakReleaseDashboardConsistency();
   RefreshDemoSoakLogPresence();
   WriteDemoSoakEvidenceEvent("SOAK_SHUTDOWN","",DemoSoakEvidenceSummary());
   WriteDemoSoakJsonSnapshot();
   GlobalVariablesFlush();
}
