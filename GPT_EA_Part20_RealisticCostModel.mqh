// ============================================================================
// GPT_EA Part 20 - Realistic execution-cost and partial-profit R:R model
// ============================================================================

input bool   InpUseHistoricalCommissionEstimate = true;
input double InpFallbackCommissionPerLotRoundTurn = 0.0; // account currency per 1.0 lot round turn
input int    InpCommissionHistoryDays = 30;
input int    InpCommissionMinDeals    = 6;

struct RealisticRRReport
{
   double grossRiskMoney;
   double modeledSpreadSlipMoney;
   double commissionMoney;
   double totalRiskMoney;
   double weightedRewardMoney;
   double rr;
   string detail;
};

double EstimateCommissionPerLotRoundTurn(const string sym)
{
   if(!InpUseHistoricalCommissionEstimate) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   datetime now=TimeTradeServer(),from=now-MathMax(1,InpCommissionHistoryDays)*86400;
   if(!HistorySelect(from,now)) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   double commission=0,volume=0; int deals=0;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-1000);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=sym) continue;
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      double v=HistoryDealGetDouble(d,DEAL_VOLUME); if(v<=0) continue;
      double c=MathAbs(HistoryDealGetDouble(d,DEAL_COMMISSION));
      if(c<=0) continue;
      commission+=c; volume+=v; deals++;
   }
   if(deals<InpCommissionMinDeals || volume<=0) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   // History usually records commission per side/deal. Double the per-side average to estimate round turn.
   return 2.0*commission/volume;
}

double OneLotProfitBetween(const string sym,bool bull,double from,double to)
{
   double p=0; ENUM_ORDER_TYPE ot=(bull?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,1.0,from,to,p)) return 0;
   return p;
}

RealisticRRReport RealisticRiskReward(const TradeSetup &s)
{
   RealisticRRReport r; ZeroMemory(r); r.detail="";
   MqlTick t={}; if(!GetTickSafe(s.symbol,t)){ r.detail="No live tick."; return r; }
   double pt=PointFor(s.symbol); if(pt<=0){ r.detail="No point size."; return r; }

   double entry=s.preferred;
   double spread=MathMax(0.0,t.ask-t.bid);
   double slip=DynamicSlippagePoints(s.symbol)*pt;
   // Adverse entry deviation model: long fills higher, short fills lower.
   double modeledEntry=(s.bullish?entry+spread+slip:entry-spread-slip);
   double riskPnl=OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.sl);
   r.grossRiskMoney=MathAbs(riskPnl);

   double rawRiskPnl=OneLotProfitBetween(s.symbol,s.bullish,entry,s.sl);
   r.modeledSpreadSlipMoney=MathMax(0.0,r.grossRiskMoney-MathAbs(rawRiskPnl));
   r.commissionMoney=EstimateCommissionPerLotRoundTurn(s.symbol);
   r.totalRiskMoney=r.grossRiskMoney+r.commissionMoney;

   double f1=MathMax(0.0,MathMin(1.0,InpPartialAtTP1Percent/100.0));
   double remain1=1.0-f1;
   double f2=MathMax(0.0,MathMin(1.0,InpPartialAtTP2Percent/100.0))*remain1;
   double f3=MathMax(0.0,1.0-f1-f2);

   double p1=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp1));
   double p2=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp2));
   double p3=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp3));
   r.weightedRewardMoney=f1*p1+f2*p2+f3*p3-r.commissionMoney;
   if(r.weightedRewardMoney<0) r.weightedRewardMoney=0;
   r.rr=(r.totalRiskMoney>0?r.weightedRewardMoney/r.totalRiskMoney:0);
   r.detail=StringFormat("Realistic weighted R:R %.2f | 1-lot modeled risk %.2f | spread/slippage cost %.2f | commission %.2f | weighted reward %.2f | partial weights TP1 %.0f%% / TP2 %.0f%% / runner %.0f%%",
      r.rr,r.totalRiskMoney,r.modeledSpreadSlipMoney,r.commissionMoney,r.weightedRewardMoney,f1*100.0,f2*100.0,f3*100.0);
   return r;
}

bool RealisticRRGate(const TradeSetup &s,double floor,string &why)
{
   RealisticRRReport r=RealisticRiskReward(s);
   why=r.detail;
   return r.rr>=floor;
}
