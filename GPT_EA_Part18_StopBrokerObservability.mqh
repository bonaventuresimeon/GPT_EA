// ============================================================================
// GPT_EA Part 18 - Broker-specific stop failure handling and observability
// ============================================================================

input bool   InpWriteStopFailureObservability      = true;
input string InpStopFailureObservabilityFile       = "GPT_EA_StopFailures.csv";
input bool   InpStopObservabilityFlushEachEvent    = true;
input bool   InpBlockNewEntriesOnPartialProtection = true;
input bool   InpBlockOnCriticalStopState           = true;
input bool   InpBlockOnOperatorStopState           = true;
input int    InpPartialProtectionMaxSeconds        = 45;
input int    InpMarketClosedStopRetrySeconds       = 60;
input int    InpConnectionStopRetrySeconds         = 30;
input int    InpFreezeStopRetrySeconds             = 10;
input int    InpRequoteStopRetrySeconds            = 3;
input int    InpRateLimitStopRetrySeconds          = 30;
input int    InpStopRateLimitMaxBackoffSeconds     = 180;

enum StopFailureClassCode
{
   STOP_CLASS_NONE=0,
   STOP_CLASS_INVALID_STOPS=1,
   STOP_CLASS_FROZEN=2,
   STOP_CLASS_MARKET_CLOSED=3,
   STOP_CLASS_REQUOTE_PRICE_CHANGED=4,
   STOP_CLASS_NO_QUOTES=5,
   STOP_CLASS_CONNECTION=6,
   STOP_CLASS_RATE_LIMIT=7,
   STOP_CLASS_TRADING_DISABLED=8,
   STOP_CLASS_INVALID_VOLUME=9,
   STOP_CLASS_INVALID_PRICE=10,
   STOP_CLASS_INVALID_FILL=11,
   STOP_CLASS_STOP_LEVEL_DISTANCE=12,
   STOP_CLASS_NO_CHANGES=13,
   STOP_CLASS_POSITION_CLOSED=14,
   STOP_CLASS_PROTECTION_MISSING=15,
   STOP_CLASS_PARTIAL_PROTECTION=16,
   STOP_CLASS_TRADE_CONTEXT_LOCKED=17,
   STOP_CLASS_OTHER=99
};

enum StopFailureActionCode
{
   STOP_ACTION_NONE=0,
   STOP_ACTION_RETRY_FRESH_PRICE=1,
   STOP_ACTION_WAIT_DISTANCE_CLEAR=2,
   STOP_ACTION_WAIT_MARKET_OPEN=3,
   STOP_ACTION_WAIT_CONNECTION_OR_QUOTE=4,
   STOP_ACTION_BACKOFF=5,
   STOP_ACTION_OPERATOR_OR_BROKER_CHANGE=6,
   STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE=7,
   STOP_ACTION_NOOP=8,
   STOP_ACTION_STOP_POSITION_MANAGEMENT=9
};

string StopFailureClassText(int code)
{
   switch(code)
   {
      case STOP_CLASS_INVALID_STOPS: return "INVALID_STOPS";
      case STOP_CLASS_FROZEN: return "FROZEN";
      case STOP_CLASS_MARKET_CLOSED: return "MARKET_CLOSED";
      case STOP_CLASS_REQUOTE_PRICE_CHANGED: return "REQUOTE_PRICE_CHANGED";
      case STOP_CLASS_NO_QUOTES: return "NO_QUOTES";
      case STOP_CLASS_CONNECTION: return "CONNECTION";
      case STOP_CLASS_RATE_LIMIT: return "RATE_LIMIT";
      case STOP_CLASS_TRADING_DISABLED: return "TRADING_DISABLED";
      case STOP_CLASS_INVALID_VOLUME: return "INVALID_VOLUME";
      case STOP_CLASS_INVALID_PRICE: return "INVALID_PRICE";
      case STOP_CLASS_INVALID_FILL: return "INVALID_FILL";
      case STOP_CLASS_STOP_LEVEL_DISTANCE: return "STOP_LEVEL_DISTANCE";
      case STOP_CLASS_NO_CHANGES: return "NO_CHANGES";
      case STOP_CLASS_POSITION_CLOSED: return "POSITION_CLOSED";
      case STOP_CLASS_PROTECTION_MISSING: return "PROTECTION_MISSING";
      case STOP_CLASS_PARTIAL_PROTECTION: return "PARTIAL_PROTECTION";
      case STOP_CLASS_TRADE_CONTEXT_LOCKED: return "TRADE_CONTEXT_LOCKED";
      case STOP_CLASS_NONE: return "NONE";
      default: return "OTHER_TRANSIENT_OR_BROKER_REJECTION";
   }
}

string StopFailureActionText(int code)
{
   switch(code)
   {
      case STOP_ACTION_RETRY_FRESH_PRICE: return "RETRY_FRESH_PRICE";
      case STOP_ACTION_WAIT_DISTANCE_CLEAR: return "WAIT_DISTANCE_CLEAR";
      case STOP_ACTION_WAIT_MARKET_OPEN: return "WAIT_MARKET_OPEN";
      case STOP_ACTION_WAIT_CONNECTION_OR_QUOTE: return "WAIT_CONNECTION_OR_QUOTE";
      case STOP_ACTION_BACKOFF: return "BACKOFF";
      case STOP_ACTION_OPERATOR_OR_BROKER_CHANGE: return "OPERATOR_OR_BROKER_CHANGE";
      case STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE: return "CRITICAL_PROTECT_OR_CLOSE";
      case STOP_ACTION_NOOP: return "NOOP";
      case STOP_ACTION_STOP_POSITION_MANAGEMENT: return "STOP_POSITION_MANAGEMENT";
      default: return "NONE";
   }
}

int StopFailureClassCodeFrom(uint retcode,const string description,const string reason)
{
   string u=description+" "+reason; StringToUpper(u);
   if(StringFind(u,"TP1 PARTIAL")>=0 || StringFind(u,"PARTIAL PROTECTION")>=0) return STOP_CLASS_PARTIAL_PROTECTION;
   if(StringFind(u,"PROTECTIVE SL MISSING")>=0 || StringFind(u,"NO PROTECTIVE SL")>=0 || StringFind(u,"SL=0")>=0) return STOP_CLASS_PROTECTION_MISSING;
   if(retcode==10025 || StringFind(u,"NO CHANGES")>=0) return STOP_CLASS_NO_CHANGES;
   if(retcode==10036 || StringFind(u,"POSITION CLOSED")>=0) return STOP_CLASS_POSITION_CLOSED;
   if(retcode==10029 || StringFind(u,"FROZEN")>=0 || StringFind(u,"FREEZE")>=0) return STOP_CLASS_FROZEN;
   if(retcode==10016 || StringFind(u,"INVALID STOPS")>=0) return STOP_CLASS_INVALID_STOPS;
   if(StringFind(u,"STOP LEVEL")>=0 || StringFind(u,"MINIMUM STOP")>=0 || StringFind(u,"STOP DISTANCE")>=0) return STOP_CLASS_STOP_LEVEL_DISTANCE;
   if(retcode==10018 || StringFind(u,"MARKET CLOSED")>=0 || StringFind(u,"SESSION CLOSED")>=0) return STOP_CLASS_MARKET_CLOSED;
   if(retcode==10004 || retcode==10020 || StringFind(u,"REQUOTE")>=0 || StringFind(u,"PRICE CHANGED")>=0) return STOP_CLASS_REQUOTE_PRICE_CHANGED;
   if(retcode==10021 || StringFind(u,"PRICE OFF")>=0 || StringFind(u,"NO QUOTE")>=0 || StringFind(u,"NO PRICES")>=0) return STOP_CLASS_NO_QUOTES;
   if(retcode==10031 || StringFind(u,"CONNECTION")>=0 || StringFind(u,"DISCONNECTED")>=0) return STOP_CLASS_CONNECTION;
   if(retcode==10024 || StringFind(u,"TOO MANY")>=0 || StringFind(u,"RATE LIMIT")>=0 || StringFind(u,"FREQUENT REQUEST")>=0) return STOP_CLASS_RATE_LIMIT;
   if(retcode==10028 || StringFind(u,"LOCKED")>=0 || StringFind(u,"TRADE CONTEXT")>=0) return STOP_CLASS_TRADE_CONTEXT_LOCKED;
   if(retcode==10017 || retcode==10026 || retcode==10027 || StringFind(u,"TRADE DISABLED")>=0 || StringFind(u,"AUTOTRADING DISABLED")>=0) return STOP_CLASS_TRADING_DISABLED;
   if(retcode==10014 || StringFind(u,"INVALID VOLUME")>=0) return STOP_CLASS_INVALID_VOLUME;
   if(retcode==10015 || StringFind(u,"INVALID PRICE")>=0) return STOP_CLASS_INVALID_PRICE;
   if(retcode==10030 || StringFind(u,"INVALID FILL")>=0 || StringFind(u,"FILLING")>=0) return STOP_CLASS_INVALID_FILL;
   return STOP_CLASS_OTHER;
}

string StopFailureClassName(uint retcode,const string description,const string reason)
{
   return StopFailureClassText(StopFailureClassCodeFrom(retcode,description,reason));
}

int StopFailureActionForClass(int cls)
{
   if(cls==STOP_CLASS_INVALID_STOPS || cls==STOP_CLASS_FROZEN || cls==STOP_CLASS_STOP_LEVEL_DISTANCE) return STOP_ACTION_WAIT_DISTANCE_CLEAR;
   if(cls==STOP_CLASS_MARKET_CLOSED) return STOP_ACTION_WAIT_MARKET_OPEN;
   if(cls==STOP_CLASS_CONNECTION || cls==STOP_CLASS_NO_QUOTES) return STOP_ACTION_WAIT_CONNECTION_OR_QUOTE;
   if(cls==STOP_CLASS_REQUOTE_PRICE_CHANGED || cls==STOP_CLASS_INVALID_PRICE) return STOP_ACTION_RETRY_FRESH_PRICE;
   if(cls==STOP_CLASS_RATE_LIMIT || cls==STOP_CLASS_TRADE_CONTEXT_LOCKED) return STOP_ACTION_BACKOFF;
   if(cls==STOP_CLASS_TRADING_DISABLED || cls==STOP_CLASS_INVALID_FILL || cls==STOP_CLASS_INVALID_VOLUME) return STOP_ACTION_OPERATOR_OR_BROKER_CHANGE;
   if(cls==STOP_CLASS_PROTECTION_MISSING || cls==STOP_CLASS_PARTIAL_PROTECTION) return STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE;
   if(cls==STOP_CLASS_NO_CHANGES) return STOP_ACTION_NOOP;
   if(cls==STOP_CLASS_POSITION_CLOSED) return STOP_ACTION_STOP_POSITION_MANAGEMENT;
   return STOP_ACTION_RETRY_FRESH_PRICE;
}

int StopFailureRetrySecondsForClassCode(int cls,int failureCount=1)
{
   if(cls==STOP_CLASS_MARKET_CLOSED) return MathMax(10,InpMarketClosedStopRetrySeconds);
   if(cls==STOP_CLASS_CONNECTION || cls==STOP_CLASS_NO_QUOTES) return MathMax(5,InpConnectionStopRetrySeconds);
   if(cls==STOP_CLASS_FROZEN || cls==STOP_CLASS_INVALID_STOPS || cls==STOP_CLASS_STOP_LEVEL_DISTANCE) return MathMax(3,InpFreezeStopRetrySeconds);
   if(cls==STOP_CLASS_REQUOTE_PRICE_CHANGED || cls==STOP_CLASS_INVALID_PRICE) return MathMax(1,InpRequoteStopRetrySeconds);
   if(cls==STOP_CLASS_RATE_LIMIT || cls==STOP_CLASS_TRADE_CONTEXT_LOCKED)
   {
      int multiplier=(int)MathMax(1,MathMin(6,failureCount));
      return MathMin(MathMax(5,InpStopRateLimitMaxBackoffSeconds),MathMax(5,InpRateLimitStopRetrySeconds)*multiplier);
   }
   if(cls==STOP_CLASS_TRADING_DISABLED || cls==STOP_CLASS_INVALID_FILL || cls==STOP_CLASS_INVALID_VOLUME) return MathMax(30,InpMarketClosedStopRetrySeconds);
   if(cls==STOP_CLASS_PROTECTION_MISSING || cls==STOP_CLASS_PARTIAL_PROTECTION) return MathMax(1,InpStopUpdateRetrySeconds);
   if(cls==STOP_CLASS_NO_CHANGES || cls==STOP_CLASS_POSITION_CLOSED) return 0;
   return MathMax(1,InpStopUpdateRetrySeconds);
}

int StopFailureRetrySecondsForClass(const string cls)
{
   int code=STOP_CLASS_OTHER;
   if(cls=="MARKET_CLOSED") code=STOP_CLASS_MARKET_CLOSED;
   else if(cls=="CONNECTION") code=STOP_CLASS_CONNECTION;
   else if(cls=="NO_QUOTES") code=STOP_CLASS_NO_QUOTES;
   else if(cls=="FROZEN") code=STOP_CLASS_FROZEN;
   else if(cls=="INVALID_STOPS") code=STOP_CLASS_INVALID_STOPS;
   else if(cls=="STOP_LEVEL_DISTANCE") code=STOP_CLASS_STOP_LEVEL_DISTANCE;
   else if(cls=="REQUOTE_PRICE_CHANGED") code=STOP_CLASS_REQUOTE_PRICE_CHANGED;
   else if(cls=="INVALID_PRICE") code=STOP_CLASS_INVALID_PRICE;
   else if(cls=="RATE_LIMIT") code=STOP_CLASS_RATE_LIMIT;
   else if(cls=="TRADE_CONTEXT_LOCKED") code=STOP_CLASS_TRADE_CONTEXT_LOCKED;
   else if(cls=="TRADING_DISABLED") code=STOP_CLASS_TRADING_DISABLED;
   else if(cls=="INVALID_FILL") code=STOP_CLASS_INVALID_FILL;
   else if(cls=="INVALID_VOLUME") code=STOP_CLASS_INVALID_VOLUME;
   else if(cls=="PROTECTION_MISSING") code=STOP_CLASS_PROTECTION_MISSING;
   else if(cls=="PARTIAL_PROTECTION") code=STOP_CLASS_PARTIAL_PROTECTION;
   else if(cls=="NO_CHANGES") code=STOP_CLASS_NO_CHANGES;
   else if(cls=="POSITION_CLOSED") code=STOP_CLASS_POSITION_CLOSED;
   return StopFailureRetrySecondsForClassCode(code,1);
}

bool StopFailureClassIsPermanentUntilOperatorOrSessionChange(const string cls)
{
   return (cls=="TRADING_DISABLED" || cls=="INVALID_FILL" || cls=="INVALID_VOLUME");
}

bool StopFailureActionRequiresOperator(int action)
{
   return (action==STOP_ACTION_OPERATOR_OR_BROKER_CHANGE);
}

int StopQuoteAgeSeconds(const string sym)
{
   MqlTick t={}; if(!SymbolInfoTick(sym,t) || t.time<=0) return 999999;
   datetime now=TimeTradeServer();
   return (int)MathMax(0,now-(datetime)t.time);
}

void EnsureStopFailureObservabilityHeader()
{
   if(!InpWriteStopFailureObservability) return;
   bool exists=FileIsExist(InpStopFailureObservabilityFile,FILE_COMMON);
   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","broker","server","login","account_mode","leverage","symbol","canonical","position_id","ticket","side","context","class_code","class","action_code","action","retcode","retcode_text","failure_count","critical","current_sl","requested_or_reference_sl","entry","r_now","spread_pts","quote_age_sec","stops_level_pts","freeze_level_pts","trade_mode","execution_mode","terminal_connected","tp1_partial","tp1_done","tp2_partial","protection_stage","retry_seconds","next_retry_time","reason");
   if(InpStopObservabilityFlushEachEvent) FileFlush(h);
   FileClose(h);
}

void RecordStopObservationEvent(ulong ticket,const string eventName,const string context,const string reason,bool critical,double requestedSL=0,double rNow=0)
{
   if(!InpWriteStopFailureObservability || !PositionSelectByTicket(ticket)) return;
   EnsureStopFailureObservabilityHeader();

   string sym=PositionGetString(POSITION_SYMBOL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   uint ret=(uint)trade.ResultRetcode();
   string desc=trade.ResultRetcodeDescription();

   bool recoveryEvent=(eventName=="STOP_PROTECTION_RECOVERED");
   int cls=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_CLASS_CODE"),STOP_CLASS_NONE):StopFailureClassCodeFrom(ret,desc,reason));
   int action=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE):StopFailureActionForClass(cls));
   int count=StopFailureCount(pid);
   int retry=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_RETRY_SEC"),0):StopFailureRetrySecondsForClassCode(cls,MathMax(1,count)));
   datetime next=(recoveryEvent?(datetime)GVRead(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0):(retry>0?TimeTradeServer()+retry:0));

   if(!recoveryEvent)
   {
      GVWrite(PosKey(pid,"STOP_FAIL_CLASS_CODE"),cls);
      GVWrite(PosKey(pid,"STOP_FAIL_ACTION_CODE"),action);
      GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),retry);
      GVWrite(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),(double)next);
   }

   double pt=PointFor(sym); MqlTick t={}; GetTickSafe(sym,t);
   double spread=(pt>0?(t.ask-t.bid)/pt:0);
   string canonical=CanonicalInstrumentKey(sym,SymbolInfoString(sym,SYMBOL_DESCRIPTION),SymbolInfoString(sym,SYMBOL_PATH));

   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"stop_failure_observability_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,
      AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),(string)AccountInfoInteger(ACCOUNT_LOGIN),
      (string)AccountInfoInteger(ACCOUNT_MARGIN_MODE),(string)AccountInfoInteger(ACCOUNT_LEVERAGE),sym,canonical,
      (string)pid,(string)ticket,bull?"BUY":"SELL",context,(string)cls,StopFailureClassText(cls),(string)action,StopFailureActionText(action),
      (string)ret,desc,(string)count,critical?"1":"0",DoubleToString(PositionGetDouble(POSITION_SL),DigitsFor(sym)),
      DoubleToString(requestedSL,DigitsFor(sym)),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),DigitsFor(sym)),DoubleToString(rNow,3),
      DoubleToString(spread,1),(string)StopQuoteAgeSeconds(sym),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
      (string)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_MODE),
      (string)SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE),TerminalInfoInteger(TERMINAL_CONNECTED)?"1":"0",
      PositionFlag(pid,ticket,"TP1PARTIAL")?"1":"0",PositionFlag(pid,ticket,"TP1DONE")?"1":"0",
      PositionFlag(pid,ticket,"TP2PARTIAL")?"1":"0",(string)ActualProtectionStage(ticket),(string)retry,
      (next>0?TimeToString(next,TIME_DATE|TIME_SECONDS):""),reason);
   if(InpStopObservabilityFlushEachEvent) FileFlush(h);
   FileClose(h);

   if(!recoveryEvent && StopFailureActionRequiresOperator(action) && InpBlockOnOperatorStopState)
      StopFailurePauseNewEntries(sym+": broker stop state "+StopFailureClassText(cls)+" requires operator/broker condition change.");
}

void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL=0,double rNow=0)
{
   RecordStopObservationEvent(ticket,critical?"CRITICAL_FAILURE":"STOP_UPDATE_FAILURE",context,reason,critical,requestedSL,rNow);
}

void RecordStopRecoveryObservation(ulong ticket,const string context,const string note)
{
   if(!PositionSelectByTicket(ticket)) return;
   RecordStopObservationEvent(ticket,"STOP_PROTECTION_RECOVERED",context,note,false,PositionGetDouble(POSITION_SL),0);
}

void RecordPartialProtectionObservation(ulong ticket,const string eventName,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   RecordStopObservationEvent(ticket,eventName,"PARTIAL_PROTECTION",reason,eventName=="PARTIAL_PROTECTION_HAZARD",PositionGetDouble(POSITION_SL),0);

   if((eventName=="PARTIAL_PROTECTION_COMPLETED" || eventName=="PARTIAL_PROTECTION_RECOVERED") &&
      StopFailureCount(pid)<=0 && GVRead(PosKey(pid,"STOP_FAIL_CRITICAL"),0)<=0.5)
   {
      GVWrite(PosKey(pid,"STOP_FAIL_CLASS_CODE"),STOP_CLASS_NONE);
      GVWrite(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE);
      GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),0);
      GVWrite(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0);
   }
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

bool StopPortfolioProtectionHazardActive(string &why)
{
   why="Stop portfolio protection state clear.";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL);
      if(sl<=0)
      {
         why=sym+": open GPT_EA position has no protective SL.";
         return true;
      }
      if(InpBlockOnCriticalStopState && GVRead(PosKey(pid,"STOP_FAIL_CRITICAL"),0)>0.5)
      {
         why=sym+": critical stop failure state remains active.";
         return true;
      }
      int action=(int)GVRead(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE);
      if(InpBlockOnOperatorStopState && StopFailureActionRequiresOperator(action))
      {
         why=sym+": stop failure requires operator/broker condition change.";
         return true;
      }
      if(InpStopFailurePauseAfter>0 && StopFailureCount(pid)>=InpStopFailurePauseAfter)
      {
         why=StringFormat("%s: repeated stop failures reached pause threshold (%d).",sym,StopFailureCount(pid));
         return true;
      }
   }
   return false;
}

bool StopObservabilityAllowsNewEntries(string &why)
{
   string portfolioWhy="";
   if(StopPortfolioProtectionHazardActive(portfolioWhy)){ why=portfolioWhy; return false; }
   if(InpBlockNewEntriesOnPartialProtection && PartialProtectionHazardActive(why)) return false;
   why="Stop observability/release gate clear.";
   return true;
}

void ObservePartialProtectionState()
{
   datetime now=TimeTradeServer();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      bool logged=(GVRead(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),0)>0.5);

      if(partial && !done)
      {
         datetime tp1=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(tk,"TP1_TIME",0));
         int elapsed=(tp1>0?(int)(now-tp1):0);
         if(elapsed>=MathMax(1,InpPartialProtectionMaxSeconds))
         {
            string why=StringFormat("TP1 partial completed but required breakeven protection has remained incomplete for %d sec.",elapsed);
            if(!logged)
            {
               GVWrite(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),1);
               RecordPartialProtectionObservation(tk,"PARTIAL_PROTECTION_HAZARD",why);
               Print("GPT_EA PARTIAL PROTECTION HAZARD: ",PositionGetString(POSITION_SYMBOL)," - ",why);
            }
            if(InpBlockNewEntriesOnPartialProtection) StopFailurePauseNewEntries(PositionGetString(POSITION_SYMBOL)+": "+why);
         }
      }
      else if(done && logged)
      {
         RecordPartialProtectionObservation(tk,"PARTIAL_PROTECTION_RECOVERED","TP1 partial and required protection are now complete.");
         GVWrite(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),0);
      }
   }
}

string StopObservabilityHealthSummary()
{
   string why="";
   if(!StopObservabilityAllowsNewEntries(why)) return "BLOCKED: "+why;
   return "CLEAR";
}

void StopFailureObservabilityInit()
{
   EnsureStopFailureObservabilityHeader();
   ObservePartialProtectionState();
   Print("GPT_EA stop observability: ",StopObservabilityHealthSummary());
}

void StopFailureObservabilityTimer()
{
   ObservePartialProtectionState();
}
