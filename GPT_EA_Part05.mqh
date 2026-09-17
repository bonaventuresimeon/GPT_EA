string SetupSummaryLine(const TradeSetup &s)
{
   return StringFormat("%s: zone %.*f–%.*f | preferred %.*f | SL %.*f | TP1 %.*f | conf %d%% | eff R:R %.2f",
      s.name,DigitsFor(s.symbol),s.zoneLow,DigitsFor(s.symbol),s.zoneHigh,
      DigitsFor(s.symbol),s.preferred,DigitsFor(s.symbol),s.sl,DigitsFor(s.symbol),s.tp1,s.confidence,s.effectiveRR1);
}

string BuildCard(TradeSetup &primary,TradeSetup &pullback,TradeSetup &breakout,const string scanReason,bool newsBlock,const string news,string spreadText,bool spreadOK,bool yieldBlock,const string yieldText,bool sessionBlock,const string sessionText)
{
   string s="━━━━━━━━━━━━━━━━━━━━\n";
   string icon=(primary.bullish?"🟢":"🔴");
   s+=StringFormat("%s %s %s — PRIMARY SETUP\n",icon,primary.symbol,Arrow(primary.bullish));
   s+="━━━━━━━━━━━━━━━━━━━━\n\n";
   s+="Asset: "+primary.symbol+"\n";
   s+="TF: D1 / H4 / H1 / M30 / M15 / M5\n";
   s+="Bias: "+DirText(primary.bullish)+" — "+primary.name+"\n";
   s+="Scan: "+scanReason+"\n\n";
   s+="Analysis:\n"+primary.reason+"\n\n";
   s+="Confirmation:\n";
   s+="✅ Multi-timeframe trend alignment\n";
   s+=StringFormat("%s Setup rule satisfied\n",primary.valid?"✅":"⚠️");
   s+=StringFormat("%s %s\n",spreadOK?"✅":"❌",spreadText);
   s+=StringFormat("%s %s\n",newsBlock?"❌":"✅",news);
   s+=StringFormat("%s %s\n",yieldBlock?"❌":"✅",yieldText);
   s+=StringFormat("%s %s\n",sessionBlock?"❌":"✅",sessionText);

   int d=DigitsFor(primary.symbol);
   s+=StringFormat("\nEntry: %.*f – %.*f\nPreferred Entry: %.*f\nSL: %.*f\nTP1: %.*f\nTP2: %.*f\nTP3: %.*f\n",
      d,primary.zoneLow,d,primary.zoneHigh,d,primary.preferred,d,primary.sl,d,primary.tp1,d,primary.tp2,d,primary.tp3);
   s+=StringFormat("R:R: TP1 = 1R, TP2 = 2R, TP3 = 3R; effective R:R to TP2 after spread/slippage ≈ 1:%.2f\n",primary.effectiveRR1);
   s+=StringFormat("Confidence: %d%%\n",primary.confidence);
   s+=StringFormat("Time invalidation: TP1 should be reached within %d M15 candles after entry (ATR/opening-range adjusted).\n",primary.expiryM15);
   s+="Invalidation: "+primary.invalidation+"\n";
   s+="Failure pattern: "+primary.failurePattern+"\n\n";

   s+="Pullback vs Breakout-Retest:\n"+SetupSummaryLine(pullback)+"\n"+SetupSummaryLine(breakout)+"\n";
   s+="Pullback usually fails by acceptance through the support/resistance zone; breakout-retest usually fails by a false break and close back inside the old range.\n";
   s+="Spread/slippage penalize the tighter setup more: if effective R:R falls below the configured minimum, skip the entry.\n\n";

   s+="Position management:\n";
   s+=StringFormat("• Lot size = %.2f%% of %s using OrderCalcProfit().\n",InpRiskPercent,(InpUseEquity?"equity":"balance"));
   s+=StringFormat("• At TP1: take %.0f%% partial; %s.\n",InpPartialAtTP1Percent,(InpMoveSLToBEAfterTP1?"move SL to BE + cost buffer":"keep original SL"));
   s+=StringFormat("• After TP1: if price stalls near the next M15 resistance/support for %d M5 candles, keep only while H1/M15 momentum remains aligned; otherwise close remainder.\n",InpPostTP1StallM5);
   s+="• A high-impact event, yield shock, excessive opening range, stale price displacement, spread blowout, portfolio-risk breach, cooldown or effective R:R deterioration invalidates entry before execution.\n\n";

   bool tradable=(primary.valid && !newsBlock && !yieldBlock && !sessionBlock && spreadOK && primary.effectiveRR1>=InpMinEffectiveRR);
   s+="Preferred Trade: "+(tradable?"✅ HIGH-CONFIDENCE SETUP VALID":"⏳ WAIT — CONDITIONS NOT FULLY VALID")+"\n";
   s+="Execution rule: "+primary.executionRule+"\n";
   s+="Risk note: execution costs and fast markets can make realized loss larger than the modelled stop risk.\n";
   return s;
}

void NotifyCard(const string card)
{
   Print("\n",card);
   g_lastCard=card;
   Comment(card);
   if(InpEnableAlerts) Alert(StringSubstr(card,0,(int)MathMin(240,StringLen(card))));
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(StringSubstr(card,0,(int)MathMin(250,StringLen(card))));
}

// ------------------------- Optional execution ---------------------
string GVKey(ulong ticket,string suffix){ return StringFormat("CGPT_%I64u_%s",ticket,suffix); }
void GVSet(ulong ticket,string suffix,double v){ GlobalVariableSet(GVKey(ticket,suffix),v); }
double GVGet(ulong ticket,string suffix,double def=0){ string k=GVKey(ticket,suffix); return GlobalVariableCheck(k)?GlobalVariableGet(k):def; }

int CountPositions(const string sym)
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==sym && PositionGetInteger(POSITION_MAGIC)==InpMagic) n++;
   }
   return n;
}

bool PriceInsideZone(const TradeSetup &s)
{
   MqlTick t; if(!GetTickSafe(s.symbol,t)) return false;
   double p=(s.bullish?t.ask:t.bid);
   return (p>=s.zoneLow && p<=s.zoneHigh);
}

bool M5Trigger(const TradeSetup &s)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(s.symbol,PERIOD_M5,1,3,r)<3) return false;
   if(s.bullish)
      return (r[0].close>r[0].open && r[0].low>=r[1].low && r[0].close>r[1].close);
   return (r[0].close<r[0].open && r[0].high<=r[1].high && r[0].close<r[1].close);
}

bool ApprovedPlaceTrade(const TradeSetup &s)
{
   // Approval is authorization only. Every risk, broker and market condition is revalidated here.
   if(!InpEnableApprovedExecution || !s.valid) return false;

   TradeSetup x=s;
   x.sl=NormalizePriceToTick(x.symbol,x.sl);
   x.tp1=NormalizePriceToTick(x.symbol,x.tp1);
   x.tp2=NormalizePriceToTick(x.symbol,x.tp2);
   x.tp3=NormalizePriceToTick(x.symbol,x.tp3);

   if(!PriceInsideZone(x) || !M5Trigger(x)) return false;
   if(CountPositions(x.symbol)>=InpMaxPositionsPerSymbol) return false;

   string kill=""; if(RiskKillSwitchActive(kill)){ Print(x.symbol,": execution blocked - ",kill); return false; }
   string cd=""; if(CooldownActive(x.symbol,cd)){ Print(x.symbol,": execution blocked - ",cd); return false; }
   string sp; if(!SpreadOK(x.symbol,sp)) return false;
   string news; if(CalendarBlock(x.symbol,news)) return false;
   string y; if(YieldShock(y)) return false;

   double liveRR=EffectiveRRDynamic(x);
   if(liveRR<InpMinEffectiveRR)
   {
      PrintFormat("%s: dynamic execution R:R %.2f below %.2f minimum.",x.symbol,liveRR,InpMinEffectiveRR);
      return false;
   }

   double riskMoney=0,oneLot=0;
   double lots=LotSizeForRisk(x,riskMoney,oneLot);
   if(lots<=0){ Print(x.symbol,": lot calculation returned 0."); return false; }

   string portfolioWhy="";
   if(!PortfolioRiskAllows(x,lots,portfolioWhy))
   {
      Print(x.symbol,": portfolio risk blocked execution - ",portfolioWhy);
      return false;
   }

   string brokerWhy="";
   if(!BrokerExecutionAllows(x,lots,brokerWhy))
   {
      Print(x.symbol,": broker execution gate blocked order - ",brokerWhy);
      return false;
   }

   int slipPts=DynamicSlippagePoints(x.symbol);
   RegisterPlannedExecution(x,lots,riskMoney);
   UniversalCheckpointNow();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(slipPts);
   trade.SetTypeFillingBySymbol(x.symbol);
   string comment=(x.kind==SETUP_PULLBACK?"GPT-PB-OK":"GPT-BR-OK");
   bool ok=(x.bullish?trade.Buy(lots,x.symbol,0,x.sl,x.tp3,comment):trade.Sell(lots,x.symbol,0,x.sl,x.tp3,comment));
   if(!ok){ Print("Approved trade failed: ",trade.ResultRetcodeDescription()," | ",brokerWhy); return false; }

   ulong newest=0; datetime newestTime=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=x.symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      datetime pt=(datetime)PositionGetInteger(POSITION_TIME);
      if(pt>=newestTime){ newestTime=pt; newest=tk; }
   }
   if(newest>0)
   {
      GVSet(newest,"INITSL",x.sl); GVSet(newest,"TP1",x.tp1); GVSet(newest,"TP2",x.tp2);
      GVSet(newest,"TP3",x.tp3); GVSet(newest,"EXP",x.expiryM15); GVSet(newest,"TP1DONE",0);
   }
   UniversalCheckpointNow();
   PrintFormat("%s APPROVED: %s opened %.2f lots; planned risk %.2f; dynamic slippage ceiling %d pts; live R:R %.2f | %s",
               x.symbol,Arrow(x.bullish),lots,riskMoney,slipPts,liveRR,brokerWhy);
   return true;
}
