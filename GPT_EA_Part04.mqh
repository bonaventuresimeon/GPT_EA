   if(risk<=0 || reward<=0) return 0;
   return reward/risk;
}

bool SpreadOK(const string sym,string &detail)
{
   MqlTick t; if(!GetTickSafe(sym,t)) { detail="No live tick."; return false; }
   double atr=0; if(!ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) || atr<=0){ detail="No M5 ATR."; return false; }
   double spread=t.ask-t.bid;
   double ratio=spread/atr;
   detail=StringFormat("Spread %.1f pts = %.2f%% of M5 ATR",spread/PointFor(sym),ratio*100.0);
   return ratio<=InpMaxSpreadATRFrac;
}

// -------------------------- Setup building ------------------------
void InitSetup(TradeSetup &s,const string sym,SetupKind k,bool bull)
{
   s.valid=false; s.bullish=bull; s.kind=k; s.symbol=sym;
   s.name=(k==SETUP_PULLBACK?"PULLBACK":"BREAKOUT-RETEST");
   s.zoneLow=s.zoneHigh=s.preferred=s.sl=s.tp1=s.tp2=s.tp3=0;
   s.nominalRR1=s.effectiveRR1=0; s.confidence=0; s.expiryM15=0;
   s.reason=s.invalidation=s.failurePattern=s.eventRisk=s.yieldRisk=s.executionRule="";
}

void TargetsFromRisk(TradeSetup &s)
{
   double r=MathAbs(s.preferred-s.sl);
   if(r<=0) return;
   if(s.bullish){ s.tp1=s.preferred+r; s.tp2=s.preferred+2*r; s.tp3=s.preferred+3*r; }
   else { s.tp1=s.preferred-r; s.tp2=s.preferred-2*r; s.tp3=s.preferred-3*r; }
   s.tp1=NormPrice(s.symbol,s.tp1); s.tp2=NormPrice(s.symbol,s.tp2); s.tp3=NormPrice(s.symbol,s.tp3);
   s.nominalRR1=1.0;
   s.effectiveRR1=EffectiveRR(s.symbol,s.bullish,s.preferred,s.sl,s.tp2);
}

TradeSetup BuildPullback(const string sym,bool bull,int baseConfidence,const string trendDetail)
{
   TradeSetup s; InitSetup(s,sym,SETUP_PULLBACK,bull);
   double atr=0,ema=0,hi=0,lo=0;
   if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || !EMAValue(sym,PERIOD_M15,InpFastEMA,1,ema) ||
      !RecentHighLow(sym,PERIOD_M15,1,InpSwingBars,hi,lo) || atr<=0) return s;

   s.zoneLow = NormPrice(sym,ema-InpPullbackLowATR*atr);
   s.zoneHigh= NormPrice(sym,ema+InpPullbackHighATR*atr);
   s.preferred=NormPrice(sym,ema);
   if(bull) s.sl=NormPrice(sym,MathMin(lo,ema-InpStopATR*atr));
   else     s.sl=NormPrice(sym,MathMax(hi,ema+InpStopATR*atr));
   TargetsFromRisk(s);

   MqlTick t; if(!GetTickSafe(sym,t)) return s;
   double mid=(t.ask+t.bid)*0.5;
   bool notBroken=(bull ? mid>s.sl : mid<s.sl);
   bool notTooFar=(MathAbs(mid-s.preferred)<=2.25*atr);
   s.confidence=MathMin(95,baseConfidence+(notTooFar?5:-10));
   s.expiryM15=AdaptiveExpiry(sym,InpPullbackExpiryM15);
   s.valid=(notBroken && s.confidence>=InpMinConfidence && s.effectiveRR1>=InpMinEffectiveRR);
   s.reason=trendDetail+StringFormat(" | Pullback to M15 EMA%d; ATR %.5f.",InpFastEMA,atr);
   s.invalidation=(bull?"M15 close below pullback swing/SL or multi-TF bullish alignment breaks.":"M15 close above pullback swing/SL or multi-TF bearish alignment breaks.");
   s.failurePattern=(bull?"Failure: entry zone is accepted below, lower-high/lower-low sequence forms, or support fails before expansion.":"Failure: entry zone is accepted above, higher-low/higher-high sequence forms, or resistance fails before expansion.");
   s.executionRule="Enter only inside the zone after an M5 rejection/higher-low (long) or rejection/lower-high (short). Do not chase.";
   return s;
}

TradeSetup BuildBreakoutRetest(const string sym,bool bull,int baseConfidence,const string trendDetail)
{
   TradeSetup s; InitSetup(s,sym,SETUP_BREAKOUT_RETEST,bull);
   double atr=0,priorHi=0,priorLo=0,lastClose=0;
   if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0 ||
      !RecentHighLow(sym,PERIOD_M15,2,InpSwingBars,priorHi,priorLo) || !CloseValue(sym,PERIOD_M15,1,lastClose)) return s;

   double level=(bull?priorHi:priorLo);
   bool broke=(bull ? lastClose>level+InpBreakoutBufferATR*atr : lastClose<level-InpBreakoutBufferATR*atr);
   s.zoneLow=NormPrice(sym,level-InpRetestHalfWidthATR*atr);
   s.zoneHigh=NormPrice(sym,level+InpRetestHalfWidthATR*atr);
   s.preferred=NormPrice(sym,bull?level+0.03*atr:level-0.03*atr);
   if(bull) s.sl=NormPrice(sym,MathMin(priorLo,s.zoneLow-InpStopATR*atr));
   else     s.sl=NormPrice(sym,MathMax(priorHi,s.zoneHigh+InpStopATR*atr));
   TargetsFromRisk(s);

   MqlTick t; if(!GetTickSafe(sym,t)) return s;
   double mid=(t.ask+t.bid)*0.5;
   bool retestReasonable=(MathAbs(mid-level)<=1.50*atr);
   s.confidence=MathMin(97,baseConfidence+(broke?10:-18)+(retestReasonable?3:-8));
   s.expiryM15=AdaptiveExpiry(sym,InpBreakoutExpiryM15);
   s.valid=(broke && retestReasonable && s.confidence>=InpMinConfidence && s.effectiveRR1>=InpMinEffectiveRR);
   s.reason=trendDetail+StringFormat(" | Prior M15 level %.5f; breakout %s.",level,(broke?"CONFIRMED":"NOT confirmed"));
   s.invalidation=(bull?"M15 closes back below the broken resistance and cannot reclaim it on retest.":"M15 closes back above the broken support and cannot reject it on retest.");
   s.failurePattern=(bull?"Failure: false breakout—price closes back inside the old range, retest loses the level, then downside structure expands.":"Failure: false breakdown—price closes back inside the old range, retest loses the level, then upside structure expands.");
   s.executionRule="Require a completed M15 breakout first, then an M5/M15 retest that holds the broken level. No first-candle chasing.";
   return s;
}

int BaseConfidenceFromScore(int score,bool alignedBull,bool alignedBear,bool bull)
{
   double norm=MathMin(1.0,MathAbs(score)/42.0);
   int c=(int)MathRound(55+35*norm);
   bool aligned=(bull?alignedBull:alignedBear);
   if(aligned) c+=5; else c-=12;
   if(c<0)c=0; if(c>95)c=95; return c;
}

TradeSetup ChoosePrimary(TradeSetup &a,TradeSetup &b)
{
   if(a.valid && b.valid) return (b.confidence>a.confidence?b:a);
   if(a.valid) return a;
   if(b.valid) return b;
   return (a.confidence>=b.confidence?a:b);
}

// --------------------------- Lot sizing ---------------------------
double NormalizeVolumeDown(const string sym,double vol)
{
   double mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   if(st<=0) st=mn;
   vol=MathMin(vol,mx);
   vol=MathFloor(vol/st+1e-9)*st;
   if(vol<mn) return 0.0;
   int vd=2;
   if(st>=1.0) vd=0; else if(st>=0.1) vd=1; else if(st>=0.01) vd=2; else vd=3;
   return NormalizeDouble(vol,vd);
}

double LotSizeForRisk(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   riskMoney=capital*InpRiskPercent/100.0;
   oneLotLoss=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss=0;
   if(!OrderCalcProfit(ot,s.symbol,1.0,s.preferred,s.sl,loss)) return 0;
   oneLotLoss=MathAbs(loss);
   if(oneLotLoss<=0) return 0;
   return NormalizeVolumeDown(s.symbol,riskMoney/oneLotLoss);
}

// --------------------------- Signal card --------------------------
string DirText(bool bull){ return bull?"🟢 BULLISH — BUY":"🔴 BEARISH — SELL"; }
string Arrow(bool bull){ return bull?"LONG":"SHORT"; }

