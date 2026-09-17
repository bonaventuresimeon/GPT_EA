// ============================================================================
// GPT_EA Part 13 - Advanced position manager
// ============================================================================

bool RestoreMissingProtectiveStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return false;
   double currentSL=PositionGetDouble(POSITION_SL);
   if(currentSL>0) return true;

   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   if(initSL<=0)
   {
      Print(sym,": CRITICAL - open GPT_EA position has no SL and no recoverable original SL.");
      return false;
   }

   string why="";
   if(!StopBrokerSafe(sym,bull,NormalizePriceToTick(sym,initSL),why))
   {
      Print(sym,": cannot restore missing protective SL yet - ",why);
      return false;
   }
   double tp=PositionGetDouble(POSITION_TP);
   if(!trade.PositionModify(ticket,NormalizePriceToTick(sym,initSL),tp))
   {
      Print(sym,": failed to restore missing protective SL - ",trade.ResultRetcodeDescription());
      return false;
   }
   Print(sym,": CRITICAL recovery action - protective SL restored from durable state/history.");
   SafeUniversalCheckpointNow();
   return true;
}

ulong RefreshTicketFromPositionId(ulong pid,ulong fallback)
{
   ulong current=FindOpenTicketByIdentifier(pid);
   return current>0?current:fallback;
}

bool PositionFlag(ulong pid,ulong ticket,const string field)
{
   return (GVRead(PosKey(pid,field),LegacyTicketRead(ticket,field,0))>0.5);
}

void WritePositionFlag(ulong pid,ulong ticket,const string field,double value)
{
   GVWrite(PosKey(pid,field),value);
   LegacyTicketWrite(ticket,field,value);
}

bool HandleTP1State(ulong &ticket,double px,double tp1,bool bull)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool reached=(bull?px>=tp1:px<=tp1);
   if(!reached) return PositionFlag(pid,ticket,"TP1DONE");

   bool partialDone=PositionFlag(pid,ticket,"TP1PARTIAL");
   if(!partialDone)
   {
      bool partialOK=true;
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(InpPartialAtTP1Percent>0 && InpPartialAtTP1Percent<100.0)
      {
         double closeVol=vol*InpPartialAtTP1Percent/100.0;
         partialOK=ReducePosition(ticket,closeVol);
      }
      else if(InpPartialAtTP1Percent>=100.0)
      {
         partialOK=trade.PositionClose(ticket,InpMaxSlippagePoints);
         if(partialOK) return true;
      }
      if(!partialOK)
      {
         Print(sym,": TP1 reached but partial close failed; state remains retryable - ",trade.ResultRetcodeDescription());
         return false;
      }
      ticket=RefreshTicketFromPositionId(pid,ticket);
      if(!PositionSelectByTicket(ticket)) return true;
      WritePositionFlag(pid,ticket,"TP1PARTIAL",1);
      double now=(double)TimeTradeServer();
      GVWrite(PosKey(pid,"TP1_TIME"),now);
      LegacyTicketWrite(ticket,"TP1_TIME",now);
      SafeUniversalCheckpointNow();
   }

   double rNow=0,R=0,entry=0,livePx=0; bool liveBull=true;
   if(!CurrentPositionR(ticket,rNow,R,entry,livePx,liveBull)) return false;
   bool protectionReady=!InpMoveSLToBEAfterTP1;
   if(InpMoveSLToBEAfterTP1)
   {
      if(PositionProtectedAtOrBeyondBE(ticket)) protectionReady=true;
      else
      {
         EnsureBreakEvenProtection(ticket,rNow,R,entry,liveBull);
         protectionReady=PositionProtectedAtOrBeyondBE(ticket);
      }
   }

   if(protectionReady)
   {
      WritePositionFlag(pid,ticket,"TP1DONE",1);
      if(GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(ticket,"TP1_TIME",0))<=0)
      {
         double now=(double)TimeTradeServer();
         GVWrite(PosKey(pid,"TP1_TIME"),now);
         LegacyTicketWrite(ticket,"TP1_TIME",now);
      }
      SafeUniversalCheckpointNow();
      return true;
   }

   Print(sym,": TP1 partial completed, but BE protection is waiting for a broker-valid modification distance; will retry.");
   return false;
}

bool HandleTP2Partial(ulong &ticket,double px,double tp2,bool bull,double rNow)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(PositionFlag(pid,ticket,"TP2PARTIAL")) return true;
   bool reached=(bull?px>=tp2:px<=tp2) || rNow>=2.0;
   if(!reached) return false;

   string sym=PositionGetString(POSITION_SYMBOL);
   double vol=PositionGetDouble(POSITION_VOLUME);
   bool ok=true;
   if(InpPartialAtTP2Percent>0 && InpPartialAtTP2Percent<100.0)
      ok=ReducePosition(ticket,vol*InpPartialAtTP2Percent/100.0);
   else if(InpPartialAtTP2Percent>=100.0)
      ok=trade.PositionClose(ticket,InpMaxSlippagePoints);

   if(!ok)
   {
      Print(sym,": TP2 partial failed; state remains retryable - ",trade.ResultRetcodeDescription());
      return false;
   }

   ticket=RefreshTicketFromPositionId(pid,ticket);
   if(PositionSelectByTicket(ticket))
   {
      WritePositionFlag(pid,ticket,"TP2PARTIAL",1);
      double now=(double)TimeTradeServer();
      GVWrite(PosKey(pid,"TP2_TIME"),now);
      LegacyTicketWrite(ticket,"TP2_TIME",now);
      SafeUniversalCheckpointNow();
   }
   return true;
}

void ManagePositionsAdvanced()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;

      string sym=PositionGetString(POSITION_SYMBOL);
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);

      // Open positions are always managed even when release gates block new entries.
      if(!RestoreMissingProtectiveStop(ticket))
      {
         if(InpPauseOnRecoveryInconsistency)
         {
            GVWrite(SysKey("PAUSED"),1);
            g_manualPaused=true;
         }
         continue;
      }
      if(!PositionSelectByTicket(ticket)) continue;

      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",PositionGetDouble(POSITION_SL)));
      if(initSL<=0) initSL=HistoricalInitialSL(pid);
      double R=MathAbs(entry-initSL);
      if(R<=0) continue;

      double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
      double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
      double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
      int expiry=(int)LegacyTicketRead(ticket,"EXP",InpPullbackExpiryM15);
      LegacyTicketWrite(ticket,"TP1",tp1);
      LegacyTicketWrite(ticket,"TP2",tp2);
      LegacyTicketWrite(ticket,"TP3",tp3);
      LegacyTicketWrite(ticket,"EXP",expiry);

      MqlTick tick; if(!GetTickSafe(sym,tick)) continue;
      double px=(bull?tick.bid:tick.ask);

      bool tp1done=HandleTP1State(ticket,px,tp1,bull);
      ticket=RefreshTicketFromPositionId(pid,ticket);
      if(!PositionSelectByTicket(ticket)) continue;

      if(!tp1done && BarsSince(sym,PERIOD_M15,opened)>=expiry)
      {
         Print(sym,": time invalidation — TP1 not reached within ",expiry," M15 candles.");
         trade.PositionClose(ticket,InpMaxSlippagePoints);
         continue;
      }

      double rNow=0,liveR=0,liveEntry=0,livePx=0; bool liveBull=true;
      if(!CurrentPositionR(ticket,rNow,liveR,liveEntry,livePx,liveBull)) continue;

      if(tp1done)
      {
         AdvanceProfitProtection(ticket,rNow,liveR,liveEntry,livePx,liveBull);
         ticket=RefreshTicketFromPositionId(pid,ticket);
         if(!PositionSelectByTicket(ticket)) continue;

         HandleTP2Partial(ticket,livePx,tp2,liveBull,rNow);
         ticket=RefreshTicketFromPositionId(pid,ticket);
         if(!PositionSelectByTicket(ticket)) continue;

         datetime tp1Time=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(ticket,"TP1_TIME",0));
         if(tp1Time<=0) tp1Time=TimeTradeServer();
         double barrier=0;
         bool near=NearNextBarrier(sym,liveBull,barrier);
         bool stalled=(BarsSince(sym,PERIOD_M5,tp1Time)>=InpPostTP1StallM5);
         if(near && stalled && (!MomentumStillAligned(sym,liveBull) || M5ReversalAgainst(sym,liveBull)))
         {
            PrintFormat("%s: closing managed remainder; post-TP1 stall near %.5f with momentum deterioration.",sym,barrier);
            trade.PositionClose(ticket,InpMaxSlippagePoints);
            continue;
         }
      }
   }
}
