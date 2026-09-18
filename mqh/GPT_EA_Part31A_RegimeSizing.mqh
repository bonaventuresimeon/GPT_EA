// ============================================================================
// GPT_EA Part 31A - Final adaptive sizing with regime-transition caution
// ============================================================================

double AdaptiveLotSizeForRiskFinal(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   riskMoney=0; oneLotLoss=0;
   double baseRisk=0,baseOneLot=0;
   double baseLots=AdaptiveLotSizeForRisk(s,baseRisk,baseOneLot);
   if(baseLots<=0 || baseOneLot<=0) return 0;

   double transition=MathMax(0.25,MathMin(1.0,GVRead(SymKey(s.symbol,"REGIME_RISK_MULT"),1.0)));
   double lots=NormalizeVolumeDown(s.symbol,baseLots*transition);
   if(lots<=0) return 0;
   oneLotLoss=baseOneLot;
   riskMoney=lots*oneLotLoss;
   return lots;
}

string FinalAdaptiveSizingText(const TradeSetup &s)
{
   string q="";
   double base=AdaptiveRiskMultiplier(s,q);
   double transition=MathMax(0.25,MathMin(1.0,GVRead(SymKey(s.symbol,"REGIME_RISK_MULT"),1.0)));
   return StringFormat("final adaptive sizing x%.2f = quality x%.2f * regime-transition x%.2f",base*transition,base,transition);
}
