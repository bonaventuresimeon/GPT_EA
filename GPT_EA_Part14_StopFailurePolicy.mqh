// ============================================================================
// GPT_EA Part 14 - Stop update failure policy and escalation
// ============================================================================

input int  InpStopUpdateRetrySeconds          = 10;
input int  InpStopFailureWarnAfter            = 3;
input int  InpStopFailurePauseAfter           = 8;
input bool InpPauseNewEntriesOnStopFailure    = true;
input int  InpUnprotectedEmergencySeconds     = 30;
input bool InpEmergencyCloseUnprotected       = true;
input bool InpAlertOnStopFailureEscalation    = true;

int StopFailureCount(ulong pid)
{
   return (int)GVRead(PosKey(pid,"STOP_FAIL_COUNT"),0);
}

datetime StopFailureFirstTime(ulong pid)
{
   return (datetime)GVRead(PosKey(pid,"STOP_FAIL_FIRST"),0);
}

datetime StopFailureLastTime(ulong pid)
{
   return (datetime)GVRead(PosKey(pid,"STOP_FAIL_LAST"),0);
}

bool StopUpdateRetryDue(ulong pid)
{
   datetime last=StopFailureLastTime(pid);
   if(last<=0) return true;
   return (TimeTradeServer()-last>=MathMax(1,InpStopUpdateRetrySeconds));
}

int ActualProtectionStage(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return -1;
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(sl<=0 || R<=0) return -1;
   double locked=(bull?sl-entry:entry-sl)/R;
   if(locked>=InpStrongLockR-0.05) return 3;
   if(locked>=InpProfitLockR-0.05) return 2;
   if(locked>=-0.02) return 1;
   return 0;
}

int ExpectedProtectionStage(double rNow)
{
   if(!InpUseAdvancedStopManagement) return 0;
   if(rNow>=InpStrongLockTriggerR) return 3;
   if(rNow>=InpProfitLockTriggerR) return 2;
   if(rNow>=InpBETriggerR) return 1;
   return 0;
}

void StopFailurePauseNewEntries(const string reason)
{
   if(!InpPauseNewEntriesOnStopFailure) return;
   GVWrite(SysKey("PAUSED"),1);
   g_manualPaused=true;
   GlobalVariablesFlush();
   Print("GPT_EA STOP SAFETY PAUSE: ",reason);
}

void RegisterStopUpdateFailure(ulong ticket,const string reason,bool critical=false)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   datetime now=TimeTradeServer();

   int count=StopFailureCount(pid)+1;
   datetime first=StopFailureFirstTime(pid);
   if(first<=0) first=now;
   GVWrite(PosKey(pid,"STOP_FAIL_COUNT"),count);
   GVWrite(PosKey(pid,"STOP_FAIL_FIRST"),(double)first);
   GVWrite(PosKey(pid,"STOP_FAIL_LAST"),(double)now);
   GVWrite(PosKey(pid,"STOP_FAIL_CRITICAL"),critical?1:0);

   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   if(count==1 || count==InpStopFailureWarnAfter || count==InpStopFailurePauseAfter || critical)
   {
      AppendJournal(critical?"STOP_FAIL_CRITICAL":"STOP_UPDATE_FAIL",sym,kind,0,pid,entry,sl,0,0,
                    GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),reason);
   }

   PrintFormat("%s: stop-update failure #%d | critical=%s | %s",sym,count,critical?"YES":"NO",reason);

   bool warn=(critical || (InpStopFailureWarnAfter>0 && count==InpStopFailureWarnAfter));
   if(warn && InpAlertOnStopFailureEscalation)
   {
      string msg=StringFormat("GPT_EA %s stop protection issue: %s",sym,reason);
      if(InpEnableAlerts) Alert(msg);
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(StringSubstr(msg,0,(int)MathMin(250,StringLen(msg))));
   }

   if(critical || (InpStopFailurePauseAfter>0 && count>=InpStopFailurePauseAfter))
      StopFailurePauseNewEntries(sym+": "+reason);

   SafeUniversalCheckpointNow();
}

void ClearStopFailureState(ulong ticket,const string note="protection recovered")
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int oldCount=StopFailureCount(pid);
   if(oldCount<=0) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);

   GVWrite(PosKey(pid,"STOP_FAIL_COUNT"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_FIRST"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_LAST"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_CRITICAL"),0);
   AppendJournal("STOP_UPDATE_RECOVERED",sym,kind,0,pid,entry,sl,0,0,
                 GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),note);
   PrintFormat("%s: stop protection recovered after %d failed update(s).",sym,oldCount);
   SafeUniversalCheckpointNow();
}

void AuditStopUpdateAttempt(ulong ticket,double rNow,const string context)
{
   if(!PositionSelectByTicket(ticket)) return;
   int expected=ExpectedProtectionStage(rNow);
   if(expected<=0) return;
   int actual=ActualProtectionStage(ticket);
   if(actual>=expected)
   {
      ClearStopFailureState(ticket,context+" satisfied");
      return;
   }

   string sym=PositionGetString(POSITION_SYMBOL);
   double sl=PositionGetDouble(POSITION_SL);
   bool critical=(sl<=0);
   string why=StringFormat("%s expected stage %d but actual stage is %d at %.2fR",context,expected,actual,rNow);
   RegisterStopUpdateFailure(ticket,why,critical);
}

bool HandleUnprotectedStopFailure(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return true;
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return true;
   double sl=PositionGetDouble(POSITION_SL);
   if(sl>0)
   {
      ClearStopFailureState(ticket,"protective SL restored");
      return true;
   }

   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   if(StopUpdateRetryDue(pid)) RegisterStopUpdateFailure(ticket,reason,true);

   datetime first=StopFailureFirstTime(pid);
   datetime now=TimeTradeServer();
   int elapsed=(first>0?(int)(now-first):0);
   if(!InpEmergencyCloseUnprotected || elapsed<MathMax(1,InpUnprotectedEmergencySeconds)) return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(DynamicSlippagePoints(sym));
   if(trade.PositionClose(ticket,DynamicSlippagePoints(sym)))
   {
      int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
      AppendJournal("EMERGENCY_CLOSE_UNPROTECTED",sym,kind,0,pid,
                    PositionGetDouble(POSITION_PRICE_OPEN),0,0,0,
                    GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),reason);
      PrintFormat("%s: emergency close sent after %d sec without a protective SL.",sym,elapsed);
      SafeUniversalCheckpointNow();
      return true;
   }

   Print(sym,": emergency close of unprotected position failed - ",trade.ResultRetcodeDescription());
   return false;
}

string StopFailurePolicySummary()
{
   return StringFormat("retry %ds | warn %d | pause %d | unprotected emergency %ds | emergency close %s",
      InpStopUpdateRetrySeconds,InpStopFailureWarnAfter,InpStopFailurePauseAfter,
      InpUnprotectedEmergencySeconds,InpEmergencyCloseUnprotected?"ON":"OFF");
}
