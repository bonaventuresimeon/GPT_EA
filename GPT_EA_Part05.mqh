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
   s+="✅ Multi-timeframe context evaluated\n";
   s+=StringFormat("%s Setup rule satisfied\n",primary.valid?"✅":"⚠️");
   s+=StringFormat("%s %s\n",spreadOK?"✅":"❌",spreadText);
   s+=StringFormat("%s %s\n",newsBlock?"❌":"✅",news);
   s+=StringFormat("%s %s\n",yieldBlock?"❌":"✅",yieldText);
   s+=StringFormat("%s %s\n",sessionBlock?"❌":"✅",sessionText);

   int d=DigitsFor(primary.symbol);
   s+=StringFormat("\nEntry: %.*f – %.*f\nPreferred Entry: %.*f\nSL: %.*f\nTP1: %.*f\nTP2: %.*f\nTP3: %.*f\n",
      d,primary.zoneLow,d,primary.zoneHigh,d,primary.preferred,d,primary.sl,d,primary.tp1,d,primary.tp2,d,primary.tp3);
   s+=StringFormat("R:R: nominal TP1 family %.2fR; effective R:R to TP2 after spread/slippage ≈ 1:%.2f\n",primary.nominalRR1,primary.effectiveRR1);
   s+=StringFormat("Confidence: %d%%\n",primary.confidence);
   s+=StringFormat("Time invalidation: TP1 should be reached within %d M15 candles after entry (ATR/opening-range/strategy adjusted).\n",primary.expiryM15);
   s+="Invalidation: "+primary.invalidation+"\n";
   s+="Failure pattern: "+primary.failurePattern+"\n\n";

   s+="Pullback vs Breakout-Retest:\n"+SetupSummaryLine(pullback)+"\n"+SetupSummaryLine(breakout)+"\n";
   s+="Pullback usually fails by acceptance through support/resistance/value; breakout-retest usually fails by a false break and close back inside the old range.\n";
   s+="Spread/slippage penalize tighter setups more; effective R:R below the configured threshold invalidates authorization.\n\n";

   s+="Position management:\n";
   s+=StringFormat("• Lot size = %.2f%% of %s using broker-aware OrderCalcProfit().\n",InpRiskPercent,(InpUseEquity?"equity":"balance"));
   s+=StringFormat("• TP1: take %.0f%% partial; cost-aware BE protection is retried until broker-valid.\n",InpPartialAtTP1Percent);
   s+=StringFormat("• Profit lock: at %.2fR lock %.2fR; at %.2fR lock %.2fR.\n",
                   InpProfitLockTriggerR,InpProfitLockR,InpStrongLockTriggerR,InpStrongLockR);
   s+=StringFormat("• Trail: from %.2fR use ATR + M5 structure; minimum stop improvement %.2fR; stops never loosen.\n",
                   InpTrailStartR,InpTrailMinStepR);
   s+=StringFormat("• TP2: optionally close %.0f%% of the remaining volume, then manage the runner toward TP3/trailing exit.\n",InpPartialAtTP2Percent);
   s+=StringFormat("• After TP1: if price stalls near the next M15 resistance/support for %d M5 candles and momentum deteriorates, close the remainder.\n",InpPostTP1StallM5);
   s+="• News/intermarket, economic/yield/session, spread, release-safety, partial-protection, portfolio-risk, cooldown, broker/OrderCheck and R:R deterioration can invalidate entry before execution.\n\n";

   bool tradable=(primary.valid && !newsBlock && !yieldBlock && !sessionBlock && spreadOK && primary.effectiveRR1>=InpMinEffectiveRR);
   s+="Preferred Trade: "+(tradable?"✅ HIGH-CONFIDENCE SETUP VALID":"⏳ WAIT — CONDITIONS NOT FULLY VALID")+"\n";
   s+="Execution rule: "+primary.executionRule+"\n";
   s+="Risk note: execution costs, gaps and fast markets can make realized loss larger than modelled stop risk.\n";
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
   // Approval is authorization only. Every strategy, news, release, risk, broker and market condition is revalidated here.
   if(!InpEnableApprovedExecution || !s.valid) return false;

   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   {
      Print(s.symbol,": RELEASE SAFETY BLOCK - ",releaseWhy);
      return false;
   }

   string stopPolicyWhy="";
   if(!StopFailurePolicyConfigSafe(stopPolicyWhy))
   {
      StopFailurePauseNewEntries("invalid stop failure policy: "+stopPolicyWhy);
      Print(s.symbol,": STOP FAILURE POLICY BLOCK - ",stopPolicyWhy);
      return false;
   }

   string stopObsWhy="";
   if(!StopObservabilityAllowsNewEntries(stopObsWhy))
   {
      Print(s.symbol,": PARTIAL PROTECTION/STOP OBSERVABILITY BLOCK - ",stopObsWhy);
      return false;
   }

   TradeSetup x=s;
   x.sl=NormalizePriceToTick(x.symbol,x.sl);
   x.tp1=NormalizePriceToTick(x.symbol,x.tp1);
   x.tp2=NormalizePriceToTick(x.symbol,x.tp2);
   x.tp3=NormalizePriceToTick(x.symbol,x.tp3);

   string intelWhy="";
   if(!PreEntryIntelligenceRevalidation(x,intelWhy))
   {
      Print(x.symbol,": STRATEGY/NEWS/INTERMARKET REVALIDATION BLOCK - ",intelWhy);
      return false;
   }

   if(!PriceInsideZone(x)) return false;
   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(x.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(!StrategyExecutionTrigger(x,cls)) return false;
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
   string serverWhy="";
   if(!ServerOrderCheckAllows(x,lots,slipPts,serverWhy))
   {
      Print(x.symbol,": OrderCheck preflight blocked order - ",serverWhy);
      return false;
   }

   PersistStrategyPlanForExecution(x);
   RegisterPlannedExecution(x,lots,riskMoney);
   SafeUniversalCheckpointNow();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(slipPts);
   trade.SetTypeFillingBySymbol(x.symbol);
   cls=(StrategyClass)(int)GVRead(SymKey(x.symbol,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   string comment="GPT-"+StrategyCode(cls)+"-OK";
   bool ok=(x.bullish?trade.Buy(lots,x.symbol,0,x.sl,x.tp3,comment):trade.Sell(lots,x.symbol,0,x.sl,x.tp3,comment));
   if(!ok){ Print("Approved trade failed: ",trade.ResultRetcodeDescription()," | ",brokerWhy," | ",serverWhy); return false; }

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
      LegacyTicketWrite(newest,"TP1PARTIAL",0); LegacyTicketWrite(newest,"TP2PARTIAL",0);
   }
   AttachStrategyMetadataToOpenPositions();
   SafeUniversalCheckpointNow();
   PrintFormat("%s APPROVED: %s %s opened %.2f lots; planned risk %.2f; dynamic slippage ceiling %d pts; live R:R %.2f | intelligence PASS | release PASS | %s | %s",
               x.symbol,StrategyClassName(cls),Arrow(x.bullish),lots,riskMoney,slipPts,liveRR,brokerWhy,serverWhy);
   return true;
}
