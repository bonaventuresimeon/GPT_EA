bool ReducePosition(ulong ticket,double closeVolume)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double vol=PositionGetDouble(POSITION_VOLUME);
   closeVolume=NormalizeVolumeDown(sym,MathMin(closeVolume,vol));
   if(closeVolume<=0 || closeVolume>=vol) return trade.PositionClose(ticket,InpMaxSlippagePoints);

   long marginMode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(marginMode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return trade.PositionClosePartial(ticket,closeVolume,InpMaxSlippagePoints);

   // Netting/exchange: reduce by opposite market deal.
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(InpMaxSlippagePoints); trade.SetTypeFillingBySymbol(sym);
   if(type==POSITION_TYPE_BUY) return trade.Sell(closeVolume,sym,0,0,0,"CGPT-partial");
   return trade.Buy(closeVolume,sym,0,0,0,"CGPT-partial");
}

int BarsSince(const string sym,ENUM_TIMEFRAMES tf,datetime from)
{
   int n=Bars(sym,tf,from,TimeTradeServer());
   return MathMax(0,n-1);
}

bool MomentumStillAligned(const string sym,bool bull)
{
   double e20h1,e50h1,r15;
   if(!EMAValue(sym,PERIOD_H1,InpFastEMA,1,e20h1) || !EMAValue(sym,PERIOD_H1,InpSlowEMA,1,e50h1) || !RSIValue(sym,PERIOD_M15,InpRSIPeriod,1,r15)) return false;
   return bull ? (e20h1>e50h1 && r15>=50.0) : (e20h1<e50h1 && r15<=50.0);
}

bool NearNextBarrier(const string sym,bool bull,double &barrier)
{
   double hi,lo,atr;
   if(!RecentHighLow(sym,PERIOD_M15,1,InpSwingBars,hi,lo) || !ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr)) return false;
   barrier=(bull?hi:lo);
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   double p=(bull?t.bid:t.ask);
   return MathAbs(p-barrier)<=0.25*atr;
}

bool M5ReversalAgainst(const string sym,bool bull)
{
   double rsi,e20,c;
   if(!RSIValue(sym,PERIOD_M5,InpRSIPeriod,1,rsi) || !EMAValue(sym,PERIOD_M5,InpFastEMA,1,e20) || !CloseValue(sym,PERIOD_M5,1,c)) return false;
   return bull ? (rsi<48.0 && c<e20) : (rsi>52.0 && c>e20);
}

void ManagePositions()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(InpMaxSlippagePoints);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i); if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      bool bull=(type==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      MqlTick t; if(!GetTickSafe(sym,t)) continue;
      double px=(bull?t.bid:t.ask);

      double initSL=GVGet(ticket,"INITSL",sl);
      double tp1=GVGet(ticket,"TP1",0);
      double tp2=GVGet(ticket,"TP2",0);
      int expiry=(int)GVGet(ticket,"EXP",InpPullbackExpiryM15);
      bool tp1done=(GVGet(ticket,"TP1DONE",0)>0.5);
      if(tp1<=0)
      {
         double R=MathAbs(entry-initSL); tp1=(bull?entry+R:entry-R); tp2=(bull?entry+2*R:entry-2*R);
         GVSet(ticket,"TP1",tp1); GVSet(ticket,"TP2",tp2); GVSet(ticket,"EXP",expiry);
      }

      bool reached=(bull?px>=tp1:px<=tp1);
      if(reached && !tp1done)
      {
         double closeVol=vol*InpPartialAtTP1Percent/100.0;
         if(InpPartialAtTP1Percent>0 && InpPartialAtTP1Percent<100) ReducePosition(ticket,closeVol);
         if(PositionSelectByTicket(ticket) && InpMoveSLToBEAfterTP1)
         {
            double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
            double be=(bull?entry+InpBECostATRFrac*atr:entry-InpBECostATRFrac*atr);
            double currentTP=PositionGetDouble(POSITION_TP);
            ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
            double expectedSL=NormPrice(sym,be);
            GVWrite(PosKey(pid,"EA_EXPECT_SL"),expectedSL);
            GVWrite(PosKey(pid,"EA_EXPECT_TP"),currentTP);
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),(double)(TimeTradeServer()+10));
            if(!trade.PositionModify(ticket,expectedSL,currentTP))
               GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         }
         GVSet(ticket,"TP1DONE",1);
         tp1done=true;
      }

      // Time-based invalidation: before TP1, no result after adaptive candle budget => exit.
      if(!tp1done && BarsSince(sym,PERIOD_M15,opened)>=expiry)
      {
         Print(sym,": time invalidation — TP1 not reached within ",expiry," M15 candles.");
         trade.PositionClose(ticket,InpMaxSlippagePoints);
         continue;
      }

      // After TP1, stale near next barrier + momentum failure => close remainder.
      if(tp1done)
      {
         double barrier=0;
         bool near=NearNextBarrier(sym,bull,barrier);
         bool stalled=(BarsSince(sym,PERIOD_M5,opened)>=InpPostTP1StallM5);
         if(near && stalled && (!MomentumStillAligned(sym,bull) || M5ReversalAgainst(sym,bull)))
         {
            PrintFormat("%s: closing remainder after TP1; stall near %.5f with momentum deterioration.",sym,barrier);
            trade.PositionClose(ticket,InpMaxSlippagePoints);
            continue;
         }
      }
   }
}

// ---------------------- Approval workflow -------------------------
void DeleteApprovalObjects()
{
   ObjectDelete(0,BTN_APPROVE);
   ObjectDelete(0,BTN_DENY);
   ObjectDelete(0,LBL_PROMPT);
   ChartRedraw();
}

int FirstActivePending()
{
   for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) return i;
   return -1;
}

int ActivePendingForSymbol(const string sym)
{
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && g_pending[i].setup.symbol==sym) return i;
   return -1;
}

void RenderApprovalPrompt()
{
   int idx=FirstActivePending();
   g_displayPending=idx;
   if(idx<0){ DeleteApprovalObjects(); return; }

   int remain=(int)MathMax(0,(long)(g_pending[idx].expiresAt-TimeTradeServer()));
   TradeSetup s=g_pending[idx].setup;
   string kind=(s.kind==SETUP_PULLBACK?"PULLBACK":(s.kind==SETUP_BREAKOUT?"BREAKOUT":"BREAKOUT-RETEST"));
   string txt=StringFormat(
      "TRADE APPROVAL REQUIRED | %s %s | %s | Confidence %d%% | Expires in %ds\nEntry %.5f | SL %.5f | TP1 %.5f | TP2 %.5f | TP3 %.5f",
      s.symbol,Arrow(s.bullish),kind,s.confidence,remain,s.preferred,s.sl,s.tp1,s.tp2,s.tp3);

   if(ObjectFind(0,LBL_PROMPT)<0) ObjectCreate(0,LBL_PROMPT,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,LBL_PROMPT,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,LBL_PROMPT,OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,LBL_PROMPT,OBJPROP_YDISTANCE,25);
   ObjectSetInteger(0,LBL_PROMPT,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,LBL_PROMPT,OBJPROP_TEXT,txt);

   if(ObjectFind(0,BTN_APPROVE)<0) ObjectCreate(0,BTN_APPROVE,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_APPROVE,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,BTN_APPROVE,OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,BTN_APPROVE,OBJPROP_YDISTANCE,78);
   ObjectSetInteger(0,BTN_APPROVE,OBJPROP_XSIZE,125);
   ObjectSetInteger(0,BTN_APPROVE,OBJPROP_YSIZE,30);
   ObjectSetString(0,BTN_APPROVE,OBJPROP_TEXT,"APPROVE TRADE");

   if(ObjectFind(0,BTN_DENY)<0) ObjectCreate(0,BTN_DENY,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_DENY,OBJPROP_CORNER,CORNER_LEFT_UPPER);
