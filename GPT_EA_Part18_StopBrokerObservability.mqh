// ============================================================================
// GPT_EA Part 18 - Broker-specific stop failure handling and observability
// ============================================================================

input bool   InpWriteStopFailureObservability   = true;
input string InpStopFailureObservabilityFile    = "GPT_EA_StopFailures.csv";
input bool   InpBlockNewEntriesOnPartialProtection = true;
input int    InpPartialProtectionMaxSeconds     = 45;
input int    InpMarketClosedStopRetrySeconds    = 60;
input int    InpConnectionStopRetrySeconds      = 30;
input int    InpFreezeStopRetrySeconds          = 10;
input int    InpRequoteStopRetrySeconds         = 3;
input int    InpRateLimitStopRetrySeconds       = 30;

string StopFailureClassName(uint retcode,const string description,const string reason)
{
   string u=description+" "+reason; StringToUpper(u);
   if(retcode==10016 || StringFind(u,"INVALID STOPS")>=0 || StringFind(u,"STOPS")>=0) return "INVALID_STOPS";
   if(retcode==10029 || StringFind(u,"FROZEN")>=0 || StringFind(u,"FREEZE")>=0) return "FROZEN";
   if(retcode==10018 || StringFind(u,"MARKET CLOSED")>=0) return "MARKET_CLOSED";
   if(retcode==10004 || retcode==10020 || StringFind(u,"REQUOTE")>=0 || StringFind(u,"PRICE CHANGED")>=0) return "REQUOTE_PRICE_CHANGED";
   if(retcode==10021 || StringFind(u,"PRICE OFF")>=0 || StringFind(u,"NO QUOTE")>=0) return "NO_QUOTES";
   if(retcode==10031 || StringFind(u,"CONNECTION")>=0) return "CONNECTION";
   if(retcode==10024 || StringFind(u,"TOO MANY")>=0) return "RATE_LIMIT";
   if(retcode==10017 || retcode==10026 || retcode==10027 || StringFind(u,"TRADE DISABLED")>=0) return "TRADING_DISABLED";
   if(retcode==10014 || StringFind(u,"INVALID VOLUME")>=0) return "INVALID_VOLUME";
   if(retcode==10015 || StringFind(u,"INVALID PRICE")>=0) return "INVALID_PRICE";
   if(retcode==10030 || StringFind(u,"INVALID FILL")>=0) return "INVALID_FILL";
   if(StringFind(u,"STOP LEVEL")>=0) return "STOP_LEVEL_DISTANCE";
   return "OTHER_TRANSIENT_OR_BROKER_REJECTION";
}

int StopFailureRetrySecondsForClass(const string cls)
{
   if(cls=="MARKET_CLOSED") return MathMax(10,InpMarketClosedStopRetrySeconds);
   if(cls=="CONNECTION" || cls=="NO_QUOTES") return MathMax(5,InpConnectionStopRetrySeconds);
   if(cls=="FROZEN" || cls=="INVALID_STOPS" || cls=="STOP_LEVEL_DISTANCE") return MathMax(3,InpFreezeStopRetrySeconds);
   if(cls=="REQUOTE_PRICE_CHANGED" || cls=="INVALID_PRICE") return MathMax(1,InpRequoteStopRetrySeconds);
   if(cls=="RATE_LIMIT") return MathMax(5,InpRateLimitStopRetrySeconds);
   if(cls=="TRADING_DISABLED" || cls=="INVALID_FILL" || cls=="INVALID_VOLUME") return MathMax(30,InpMarketClosedStopRetrySeconds);
   return MathMax(1,InpStopUpdateRetrySeconds);
}

bool StopFailureClassIsPermanentUntilOperatorOrSessionChange(const string cls)
{
   return (cls=="TRADING_DISABLED" || cls=="INVALID_FILL" || cls=="INVALID_VOLUME");
}

void EnsureStopFailureObservabilityHeader()
{
   if(!InpWriteStopFailureObservability) return;
   bool exists=FileIsExist(InpStopFailureObservabilityFile,FILE_COMMON);
   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"time","broker","server","account_mode","symbol","position_id","ticket","side","context","class","retcode","retcode_text","failure_count","critical","current_sl","requested_or_reference_sl","entry","r_now","spread_pts","stops_level_pts","freeze_level_pts","execution_mode","tp1_partial","tp1_done","tp2_partial","protection_stage","retry_seconds","reason");
   FileClose(h);
}

void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL=0,double rNow=0)
{
   if(!InpWriteStopFailureObservability || !PositionSelectByTicket(ticket)) return;
   EnsureStopFailureObservabilityHeader();
   string sym=PositionGetString(POSITION_SYMBOL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   uint ret=(uint)trade.ResultRetcode();
   string desc=trade.ResultRetcodeDescription();
   string cls=StopFailureClassName(ret,desc,reason);
   int retry=StopFailureRetrySecondsForClass(cls);
   GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),retry);
   GVWrite(PosKey(pid,"STOP_FAIL_CLASS_HASH"),StringLen(cls));
   double pt=PointFor(sym); MqlTick t={}; GetTickSafe(sym,t);
   double spread=(pt>0?(t.ask-t.bid)/pt:0);
   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),
      (string)AccountInfoInteger(ACCOUNT_MARGIN_MODE),sym,(string)pid,(string)ticket,bull?"BUY":"SELL",context,cls,(string)ret,desc,
      (string)StopFailureCount(pid),critical?"1":"0",DoubleToString(PositionGetDouble(POSITION_SL),DigitsFor(sym)),
      DoubleToString(requestedSL,DigitsFor(sym)),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),DigitsFor(sym)),DoubleToString(rNow,3),
      DoubleToString(spread,1),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),
      (string)SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE),PositionFlag(pid,ticket,"TP1PARTIAL")?"1":"0",PositionFlag(pid,ticket,"TP1DONE")?"1":"0",
      PositionFlag(pid,ticket,"TP2PARTIAL")?"1":"0",(string)ActualProtectionStage(ticket),(string)retry,reason);
   FileClose(h);

   if(StopFailureClassIsPermanentUntilOperatorOrSessionChange(cls))
      StopFailurePauseNewEntries(sym+": broker stop failure class "+cls+" requires operator/broker condition change.");
}

bool PartialProtectionHazardActive(string &why)
{
   why="No partial-protection hazard.";
   datetime now=TimeTradeServer();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      if(!partial || done) continue;
      datetime tp1=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(tk,"TP1_TIME",0));
      int elapsed=(tp1>0?(int)(now-tp1):0);
      if(elapsed>=MathMax(1,InpPartialProtectionMaxSeconds))
      {
         why=StringFormat("%s has TP1 partial completed but breakeven protection remains incomplete for %d sec.",PositionGetString(POSITION_SYMBOL),elapsed);
         return true;
      }
   }
   return false;
}

bool StopObservabilityAllowsNewEntries(string &why)
{
   if(!InpBlockNewEntriesOnPartialProtection){ why="Partial-protection release gate disabled."; return true; }
   if(PartialProtectionHazardActive(why)) return false;
   why="Stop observability/release gate clear.";
   return true;
}

void ObservePartialProtectionState()
{
   string why="";
   if(PartialProtectionHazardActive(why))
   {
      if(InpBlockNewEntriesOnPartialProtection) StopFailurePauseNewEntries(why);
      Print("GPT_EA PARTIAL PROTECTION HAZARD: ",why);
   }
}

void StopFailureObservabilityInit()
{
   EnsureStopFailureObservabilityHeader();
   ObservePartialProtectionState();
}

void StopFailureObservabilityTimer()
{
   ObservePartialProtectionState();
}
