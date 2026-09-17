// ============================================================================
// GPT_EA Part 11 - Server preflight and netting recovery safety guard
// ============================================================================

input bool   InpUseOrderCheckPreflight       = true;
input double InpMinPostTradeMarginLevelPct   = 150.0;
input bool   InpPauseOnNettingReversal       = true;
input bool   InpPauseOnRecoveryInconsistency = true;

bool BrokerFillingMode(const string sym,ENUM_ORDER_TYPE_FILLING &out,string &why)
{
   long exec=SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE);
   long flags=SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);

   // RETURN is allowed for Request/Instant/Exchange but prohibited for Market Execution.
   if(exec!=SYMBOL_TRADE_EXECUTION_MARKET)
   {
      out=ORDER_FILLING_RETURN;
      why="RETURN";
      return true;
   }
   if((flags & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
   {
      out=ORDER_FILLING_FOK;
      why="FOK";
      return true;
   }
   if((flags & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
   {
      out=ORDER_FILLING_IOC;
      why="IOC";
      return true;
   }
   why="No broker-supported filling policy found for Market Execution.";
   return false;
}

bool ServerOrderCheckAllows(const TradeSetup &s,double lots,int deviationPts,string &why)
{
   if(!InpUseOrderCheckPreflight){ why="OrderCheck preflight disabled."; return true; }
   MqlTick tick;
   if(!GetTickSafe(s.symbol,tick)){ why="No live tick for OrderCheck."; return false; }

   ENUM_ORDER_TYPE_FILLING fill;
   string fillText="";
   if(!BrokerFillingMode(s.symbol,fill,fillText)){ why=fillText; return false; }

   MqlTradeRequest req={};
   MqlTradeCheckResult chk={};
   req.action=TRADE_ACTION_DEAL;
   req.magic=(ulong)InpMagic;
   req.symbol=s.symbol;
   req.volume=lots;
   req.type=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   req.price=(s.bullish?tick.ask:tick.bid);
   req.sl=NormalizePriceToTick(s.symbol,s.sl);
   req.tp=NormalizePriceToTick(s.symbol,s.tp3);
   req.deviation=(ulong)MathMax(0,deviationPts);
   req.type_filling=fill;
   req.type_time=ORDER_TIME_GTC;
   req.comment=(s.kind==SETUP_BREAKOUT_RETEST?"GPT-BR-CHECK":"GPT-PB-CHECK");

   ResetLastError();
   bool ok=OrderCheck(req,chk);
   if(!ok)
   {
      why=StringFormat("OrderCheck failed: terminal error %d, retcode %u, %s",GetLastError(),chk.retcode,chk.comment);
      return false;
   }
   if(chk.retcode!=0)
   {
      why=StringFormat("OrderCheck rejected request: retcode %u, %s",chk.retcode,chk.comment);
      return false;
   }
   if(chk.margin_free<0)
   {
      why=StringFormat("OrderCheck projects negative free margin %.2f.",chk.margin_free);
      return false;
   }
   if(InpMinPostTradeMarginLevelPct>0 && chk.margin>0 && chk.margin_level>0 && chk.margin_level<InpMinPostTradeMarginLevelPct)
   {
      why=StringFormat("Projected margin level %.1f%% below %.1f%% floor.",chk.margin_level,InpMinPostTradeMarginLevelPct);
      return false;
   }

   why=StringFormat("OrderCheck OK | fill %s | projected free margin %.2f | margin level %.1f%% | %s",
      fillText,chk.margin_free,chk.margin_level,chk.comment);
   return true;
}

bool FirstPositionDirectionFromHistory(ulong pid,bool &firstBull)
{
   firstBull=true;
   if(!HistorySelectByPosition(pid)) return false;
   int n=HistoryDealsTotal();
   long earliest=LONG_MAX;
   bool found=false;
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      ENUM_DEAL_TYPE t=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
      if(e!=DEAL_ENTRY_IN && e!=DEAL_ENTRY_INOUT) continue;
      if(t!=DEAL_TYPE_BUY && t!=DEAL_TYPE_SELL) continue;
      long tm=HistoryDealGetInteger(d,DEAL_TIME_MSC);
      if(!found || tm<earliest)
      {
         earliest=tm;
         firstBull=(t==DEAL_TYPE_BUY);
         found=true;
      }
   }
   return found;
}

bool RecoveryNettingReversalDetected(string &detail)
{
   detail="No netting reversal inconsistency detected.";
   long mm=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool firstBull=true;
      if(!FirstPositionDirectionFromHistory(pid,firstBull)) continue;
      bool currentBull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(firstBull!=currentBull)
      {
         detail=StringFormat("Netting reversal detected on %s position_id=%I64u: original %s, current %s. POSITION_IDENTIFIER was preserved by MT5.",
            PositionGetString(POSITION_SYMBOL),pid,firstBull?"BUY":"SELL",currentBull?"BUY":"SELL");
         return true;
      }
   }
   return false;
}

bool RecoveryStateConsistencyCheck(string &detail)
{
   detail="Recovery state consistent.";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0));
      int kind=(int)GVRead(PosKey(pid,"KIND"),0);
      if(entry<=0)
      {
         detail="Recovered GPT_EA position has no valid entry price: "+sym;
         return false;
      }
      if(initSL<=0)
      {
         detail="Recovered GPT_EA position has no recoverable original stop: "+sym;
         return false;
      }
      if(kind!=SETUP_PULLBACK && kind!=SETUP_BREAKOUT_RETEST)
      {
         detail="Recovered GPT_EA position has unknown setup type: "+sym;
         return false;
      }
   }
   return true;
}

void RecoverySafetyAudit()
{
   string rev="";
   if(InpPauseOnNettingReversal && RecoveryNettingReversalDetected(rev))
   {
      GVWrite(SysKey("PAUSED"),1);
      g_manualPaused=true;
      Print("GPT_EA RECOVERY SAFETY PAUSE: ",rev);
      if(InpEnableAlerts) Alert("GPT_EA paused: "+rev);
   }

   string consistency="";
   if(InpPauseOnRecoveryInconsistency && !RecoveryStateConsistencyCheck(consistency))
   {
      GVWrite(SysKey("PAUSED"),1);
      g_manualPaused=true;
      Print("GPT_EA RECOVERY SAFETY PAUSE: ",consistency);
      if(InpEnableAlerts) Alert("GPT_EA paused: "+consistency);
   }
   GlobalVariablesFlush();
}
