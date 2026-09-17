// ============================================================================
// GPT_EA Part 12 - Release safety gates, recovery invariants and advanced stops
// ============================================================================

input bool   InpUseReleaseSafetyGate           = true;
input bool   InpBlockRealUnlessExplicitlyArmed = true;
input string InpLiveArmPhrase                  = "";
input bool   InpRequireApprovalOnRealAccount   = true;
input bool   InpRequireTerminalConnected       = true;
input bool   InpRequireSeriesSynchronized      = true;
input int    InpMinBarsPerRequiredTF           = 120;
input int    InpMaxQuoteAgeSeconds             = 30;
input bool   InpBlockOnRecoveryInvariantFail   = true;
input bool   InpRequireMarketAndSLOrderModes   = true;

input bool   InpUseAdvancedStopManagement = true;
input double InpBETriggerR                = 1.00;
input double InpBELockMinR                = 0.00;
input double InpProfitLockTriggerR        = 1.50;
input double InpProfitLockR               = 0.50;
input double InpStrongLockTriggerR        = 2.00;
input double InpStrongLockR               = 1.00;
input bool   InpUseATRTrailing            = true;
input double InpTrailStartR               = 2.00;
input double InpTrailATRMultiplier        = 1.25;
input int    InpTrailStructureBarsM5      = 8;
input double InpTrailStructureBufferATR   = 0.15;
input double InpTrailMinStepR             = 0.15;
input double InpPartialAtTP2Percent       = 50.0;
input bool   InpKeepTP3WhileTrailing      = true;

bool g_releaseBlocked=false;
string g_releaseBlockReason="Not evaluated";

bool AdvancedManagementConfigSafe(string &why)
{
   why="";
   if(!InpUseAdvancedStopManagement) return true;
   if(InpBETriggerR<=0){ why="InpBETriggerR must be > 0."; return false; }
   if(InpBELockMinR<0){ why="InpBELockMinR cannot be negative."; return false; }
   if(InpProfitLockTriggerR<InpBETriggerR){ why="Profit-lock trigger must be >= BE trigger."; return false; }
   if(InpProfitLockR<0 || InpProfitLockR>=InpProfitLockTriggerR){ why="Profit-lock R must be >=0 and below its trigger R."; return false; }
   if(InpStrongLockTriggerR<InpProfitLockTriggerR){ why="Strong-lock trigger must be >= profit-lock trigger."; return false; }
   if(InpStrongLockR<InpProfitLockR || InpStrongLockR>=InpStrongLockTriggerR){ why="Strong-lock R must be >= profit-lock R and below strong-lock trigger R."; return false; }
   if(InpTrailStartR<InpStrongLockTriggerR){ why="Trail start must be >= strong-lock trigger."; return false; }
   if(InpTrailATRMultiplier<=0){ why="Trail ATR multiplier must be > 0."; return false; }
   if(InpTrailStructureBarsM5<3){ why="Trail structure lookback must be >= 3 bars."; return false; }
   if(InpTrailStructureBufferATR<0 || InpTrailMinStepR<0){ why="Trail buffers/steps cannot be negative."; return false; }
   if(InpPartialAtTP1Percent<0 || InpPartialAtTP1Percent>100){ why="TP1 partial percent must be 0..100."; return false; }
   if(InpPartialAtTP2Percent<0 || InpPartialAtTP2Percent>100){ why="TP2 partial percent must be 0..100."; return false; }
   return true;
}

bool RequiredSeriesReady(const string sym,string &why)
{
   why="";
   if(!InpRequireSeriesSynchronized) return true;
   ENUM_TIMEFRAMES tfs[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M30,PERIOD_M15,PERIOD_M5};
   string names[6]={"D1","H4","H1","M30","M15","M5"};
   for(int i=0;i<6;i++)
   {
      if(!(bool)SeriesInfoInteger(sym,tfs[i],SERIES_SYNCHRONIZED))
      {
         why=sym+" "+names[i]+" series is not synchronized.";
         return false;
      }
      long bars=SeriesInfoInteger(sym,tfs[i],SERIES_BARS_COUNT);
      if(InpMinBarsPerRequiredTF>0 && bars<InpMinBarsPerRequiredTF)
      {
         why=StringFormat("%s %s has only %I64d bars; minimum is %d.",sym,names[i],bars,InpMinBarsPerRequiredTF);
         return false;
      }
   }
   return true;
}

bool QuoteFreshEnough(const string sym,string &why)
{
   why="";
   if(InpMaxQuoteAgeSeconds<=0) return true;
   MqlTick t;
   if(!GetTickSafe(sym,t)){ why=sym+" has no current tick."; return false; }
   datetime now=TimeTradeServer();
   if(now<=0 || t.time<=0){ why=sym+" quote/server timestamp unavailable."; return false; }
   long age=(long)(now-t.time);
   if(age>InpMaxQuoteAgeSeconds)
   {
      why=StringFormat("%s quote age %I64d sec exceeds %d sec limit.",sym,age,InpMaxQuoteAgeSeconds);
      return false;
   }
   return true;
}

bool SymbolOrderModesSafe(const string sym,string &why)
{
   why="";
   if(!InpRequireMarketAndSLOrderModes) return true;
   long mode=SymbolInfoInteger(sym,SYMBOL_ORDER_MODE);
   if((mode & SYMBOL_ORDER_MARKET)!=(long)SYMBOL_ORDER_MARKET){ why=sym+" does not permit market orders."; return false; }
   if((mode & SYMBOL_ORDER_SL)!=(long)SYMBOL_ORDER_SL){ why=sym+" does not permit protective Stop Loss orders."; return false; }
   return true;
}

bool PositionRecoveryInvariant(ulong ticket,string &why)
{
   why="";
   if(!PositionSelectByTicket(ticket)){ why="Position selection failed."; return false; }
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return true;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double currentSL=PositionGetDouble(POSITION_SL);
   if(pid==0){ why=sym+" has zero POSITION_IDENTIFIER."; return false; }
   if(entry<=0 || vol<=0){ why=sym+" has invalid entry/volume."; return false; }
   if(currentSL<=0){ why=sym+" open GPT_EA position is unprotected (SL=0)."; return false; }
   if(GVRead(PosKey(pid,"FINAL"),0)>0.5){ why=sym+" is open but analytics FINAL flag is already set."; return false; }
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   if(initSL<=0){ why=sym+" original stop cannot be recovered."; return false; }
   if(bull && initSL>=entry){ why=sym+" BUY original SL is not below entry."; return false; }
   if(!bull && initSL<=entry){ why=sym+" SELL original SL is not above entry."; return false; }
   double R=MathAbs(entry-initSL);
   if(R<=PointFor(sym)){ why=sym+" recovered initial risk distance is invalid."; return false; }
   double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
   double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
   double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
   if(bull && !(tp1>entry && tp2>tp1 && tp3>tp2)){ why=sym+" BUY target geometry is inconsistent."; return false; }
   if(!bull && !(tp1<entry && tp2<tp1 && tp3<tp2)){ why=sym+" SELL target geometry is inconsistent."; return false; }
   return true;
}

bool PendingRecoveryInvariant(string &why)
{
   why="";
   for(int i=0;i<ArraySize(g_pending);i++)
   {
      if(!g_pending[i].active) continue;
      TradeSetup s=g_pending[i].setup;
      if(s.symbol=="" || !EnsureSymbol(s.symbol)){ why="Pending approval has unavailable symbol."; return false; }
      if(g_pending[i].expiresAt<=g_pending[i].createdAt){ why=s.symbol+" pending approval has invalid timestamps."; return false; }
      if(!s.valid){ why=s.symbol+" active pending setup is not marked valid."; return false; }
      if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1 && s.tp3>s.tp2)){ why=s.symbol+" pending BUY geometry is inconsistent."; return false; }
      if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1 && s.tp3<s.tp2)){ why=s.symbol+" pending SELL geometry is inconsistent."; return false; }
      for(int j=i+1;j<ArraySize(g_pending);j++)
         if(g_pending[j].active && g_pending[j].setup.symbol==s.symbol){ why=s.symbol+" has duplicate active pending approvals."; return false; }
   }
   return true;
}

bool RecoveryInvariantsPass(string &why)
{
   why="";
   string configWhy="";
   if(!AdvancedManagementConfigSafe(configWhy)){ why="Management configuration invalid: "+configWhy; return false; }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(!PositionSelectByTicket(tk) || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string pwhy="";
      if(!PositionRecoveryInvariant(tk,pwhy)){ why=pwhy; return false; }
   }
   string pendingWhy="";
   if(!PendingRecoveryInvariant(pendingWhy)){ why=pendingWhy; return false; }
   if(g_dayStartEquity<=0 || g_equityPeak<=0){ why="Risk-session equity state is invalid."; return false; }
   return true;
}

void RebuildAdvancedProtectionState()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0));
      if(initSL<=0) initSL=HistoricalInitialSL(pid);
      double R=MathAbs(entry-initSL);
      if(R<=0) continue;
      int stage=0;
      if(sl>0)
      {
         double locked=(bull?sl-entry:entry-sl)/R;
         if(locked>=InpStrongLockR-0.05) stage=3;
         else if(locked>=InpProfitLockR-0.05) stage=2;
         else if(locked>=-0.05) stage=1;
      }
      double stored=GVRead(PosKey(pid,"SL_STAGE"),0);
      if(stage>(int)stored) GVWrite(PosKey(pid,"SL_STAGE"),stage);
      GVWrite(PosKey(pid,"LASTSL"),sl);
      if(LegacyTicketRead(tk,"TP1DONE",0)>0.5 || PositionHistoryHadExit(pid))
      {
         LegacyTicketWrite(tk,"TP1PARTIAL",1);
         GVWrite(PosKey(pid,"TP1PARTIAL"),1);
      }
   }
   GlobalVariablesFlush();
}

bool ReleaseSafetyAllows(const string sym,string &why)
{
   why="";
   if(!InpUseReleaseSafetyGate){ why="Release safety gate disabled."; return true; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ why="Strategy Tester environment."; return true; }
   string configWhy="";
   if(!AdvancedManagementConfigSafe(configWhy)){ why="Management configuration invalid: "+configWhy; return false; }
   if(InpRequireTerminalConnected && !(bool)TerminalInfoInteger(TERMINAL_CONNECTED)){ why="Terminal is not connected to trade server."; return false; }
   if(!(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why="Terminal automated trading is disabled."; return false; }
   if(!(bool)MQLInfoInteger(MQL_TRADE_ALLOWED)){ why="EA-level automated trading permission is disabled."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)){ why="Trading is disabled for this account."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT)){ why="EA trading is disabled by the trade server/account."; return false; }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode==ACCOUNT_TRADE_MODE_REAL)
   {
      if(InpBlockRealUnlessExplicitlyArmed && InpLiveArmPhrase!="GPT_EA_LIVE_ARMED"){ why="REAL account blocked: set local InpLiveArmPhrase to GPT_EA_LIVE_ARMED only after release validation."; return false; }
      if(InpRequireApprovalOnRealAccount && !InpRequireApproval){ why="REAL account blocked: human approval is required by release policy."; return false; }
   }
   if(InpBlockOnRecoveryInvariantFail)
   {
      string inv="";
      if(!RecoveryInvariantsPass(inv)){ why="Recovery invariant failed: "+inv; return false; }
   }
   if(sym!="")
   {
      string swhy="";
      if(!RequiredSeriesReady(sym,swhy)){ why=swhy; return false; }
      if(!QuoteFreshEnough(sym,swhy)){ why=swhy; return false; }
      if(!SymbolOrderModesSafe(sym,swhy)){ why=swhy; return false; }
   }
   return true;
}

void RefreshReleaseSafetyGate()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllows("",why);
   if(ok)
   {
      for(int i=0;i<ArraySize(g_symbols);i++)
      {
         if(g_symbols[i]=="") continue;
         if(!ReleaseSafetyAllows(g_symbols[i],why)){ ok=false; break; }
      }
   }
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All release-blocking safety gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason)) Print("GPT_EA RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked) Print("GPT_EA RELEASE GATE CLEARED: all release-blocking safety gates pass.");
}

string ReleaseGateSummary(){ return (g_releaseBlocked?"BLOCKED - "+g_releaseBlockReason:"PASS"); }

double BrokerModifyDistance(const string sym)
{
   double pt=PointFor(sym);
   int stops=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
   int freeze=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL);
   return ((double)MathMax(stops,freeze)+1.0)*pt;
}

bool StopImproves(bool bull,double currentSL,double candidate,double minStep)
{
   if(candidate<=0) return false;
   if(currentSL<=0) return true;
   return bull ? (candidate>currentSL+minStep) : (candidate<currentSL-minStep);
}

bool StopBrokerSafe(const string sym,bool bull,double candidate,string &why)
{
   why="";
   MqlTick t; if(!GetTickSafe(sym,t)){ why="No tick for stop validation."; return false; }
   double px=(bull?t.bid:t.ask);
   double dist=BrokerModifyDistance(sym);
   if(bull && candidate>=px-dist){ why="BUY stop is inside broker stop/freeze distance."; return false; }
   if(!bull && candidate<=px+dist){ why="SELL stop is inside broker stop/freeze distance."; return false; }
   return true;
}

string StopStageName(int stage)
{
   if(stage<=0) return "INITIAL";
   if(stage==1) return "BREAKEVEN";
   if(stage==2) return "PROFIT_LOCK";
   if(stage==3) return "STRONG_LOCK";
   return "TRAIL";
}

bool ApplyAdvancedStop(ulong ticket,double candidate,int stage,double rNow,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(R<=0) return false;
   double minStep=MathMax(PointFor(sym),InpTrailMinStepR*MathMax(R,PointFor(sym)));
   candidate=NormalizePriceToTick(sym,candidate);
   if(stage>=4)
   {
      if(!StopImproves(bull,currentSL,candidate,minStep)) return false;
   }
   else if(!StopImproves(bull,currentSL,candidate,PointFor(sym)*0.5)) return false;
   string safeWhy="";
   if(!StopBrokerSafe(sym,bull,candidate,safeWhy)) return false;
   double currentTP=PositionGetDouble(POSITION_TP);
   double tp=((stage>=4 && !InpKeepTP3WhileTrailing)?0:currentTP);
   if(!trade.PositionModify(ticket,candidate,tp))
   {
      Print(sym,": stop modification failed - ",trade.ResultRetcodeDescription());
      return false;
   }
   GVWrite(PosKey(pid,"SL_STAGE"),stage);
   GVWrite(PosKey(pid,"LASTSL"),candidate);
   LegacyTicketWrite(ticket,"ADV_STAGE",stage);
   SafeUniversalCheckpointNow();
   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   AppendJournal("STOP_"+StopStageName(stage),sym,kind,0,pid,entry,candidate,0,rNow,GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),reason);
   PrintFormat("%s: protective SL advanced to %.*f | stage %s | %.2fR | %s",sym,DigitsFor(sym),candidate,StopStageName(stage),rNow,reason);
   return true;
}

bool CurrentPositionR(ulong ticket,double &rNow,double &R,double &entry,double &px,bool &bull)
{
   rNow=0; R=0; entry=0; px=0; bull=true;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   entry=PositionGetDouble(POSITION_PRICE_OPEN);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   R=MathAbs(entry-initSL);
   if(R<=0) return false;
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   px=(bull?t.bid:t.ask);
   rNow=(bull?px-entry:entry-px)/R;
   return true;
}

bool EnsureBreakEvenProtection(ulong ticket,double rNow,double R,double entry,bool bull)
{
   if(!InpUseAdvancedStopManagement || rNow<InpBETriggerR) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
   double cost=MathMax(InpBECostATRFrac*atr,(t.ask-t.bid)+DynamicSlippagePoints(sym)*PointFor(sym));
   double minLock=InpBELockMinR*R;
   double buffer=MathMax(cost,minLock);
   double candidate=(bull?entry+buffer:entry-buffer);
   return ApplyAdvancedStop(ticket,candidate,1,rNow,"cost-aware breakeven");
}

bool AdvanceProfitProtection(ulong ticket,double rNow,double R,double entry,double px,bool bull)
{
   if(!InpUseAdvancedStopManagement) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),LegacyTicketRead(ticket,"ADV_STAGE",0));
   bool changed=false;
   if(rNow>=InpBETriggerR && stage<1)
   {
      if(EnsureBreakEvenProtection(ticket,rNow,R,entry,bull)){ stage=1; changed=true; }
   }
   if(rNow>=InpProfitLockTriggerR && stage<2)
   {
      double candidate=(bull?entry+InpProfitLockR*R:entry-InpProfitLockR*R);
      if(ApplyAdvancedStop(ticket,candidate,2,rNow,StringFormat("lock %.2fR after %.2fR",InpProfitLockR,InpProfitLockTriggerR))){ stage=2; changed=true; }
   }
   if(rNow>=InpStrongLockTriggerR && stage<3)
   {
      double candidate=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);
      if(ApplyAdvancedStop(ticket,candidate,3,rNow,StringFormat("lock %.2fR after %.2fR",InpStrongLockR,InpStrongLockTriggerR))){ stage=3; changed=true; }
   }
   if(InpUseATRTrailing && rNow>=InpTrailStartR)
   {
      double atr=0,hi=0,lo=0;
      int lookback=(int)MathMax(3,InpTrailStructureBarsM5);
      if(ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) && atr>0 && RecentHighLow(sym,PERIOD_M5,1,lookback,hi,lo))
      {
         double atrStop=(bull?px-InpTrailATRMultiplier*atr:px+InpTrailATRMultiplier*atr);
         double structureStop=(bull?lo-InpTrailStructureBufferATR*atr:hi+InpTrailStructureBufferATR*atr);
         double floorStop=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);
         double candidate=(bull?MathMax(floorStop,MathMin(atrStop,structureStop)):MathMin(floorStop,MathMax(atrStop,structureStop)));
         if(ApplyAdvancedStop(ticket,candidate,4,rNow,"ATR + M5 structure trailing")) changed=true;
      }
   }
   return changed;
}

bool PositionProtectedAtOrBeyondBE(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   return sl>0 && (bull?sl>=entry:sl<=entry);
}

void AdvancedSafetyInit()
{
   RebuildAdvancedProtectionState();
   RefreshReleaseSafetyGate();
}

void AdvancedSafetyTimer()
{
   RefreshReleaseSafetyGate();
}
