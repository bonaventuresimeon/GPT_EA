// ============================================================================
// GPT_EA Part 41 - Portfolio scenario stress, gap/margin risk and decision age
// ============================================================================

input bool   InpUsePortfolioScenarioStress       = true;
input double InpMaxScenarioStressLossPctEquity   = 4.00;
input double InpStressIndexShockPct              = 2.00;
input double InpStressFXShockPct                 = 1.00;
input double InpStressMetalShockPct              = 2.00;
input double InpStressEnergyShockPct             = 4.00;
input double InpStressCryptoShockPct             = 5.00;
input double InpStressOtherShockPct              = 1.50;
input bool   InpUseGapRiskSizingGate             = true;
input double InpMaxGapLossMultipleOfPlannedRisk  = 2.00;
input bool   InpUseMarginStressGate              = true;
input double InpMinimumStressedMarginLevelPct    = 250.0;
input bool   InpUseDecisionHalfLife              = true;
input bool   InpUseExecutionLatencyBudget        = true;
input double InpMaxLatencyBudgetFraction         = 0.35;

string StressAssetClass(const string sym)
{
   string u=sym+" "+SymbolInfoString(sym,SYMBOL_DESCRIPTION)+" "+SymbolInfoString(sym,SYMBOL_PATH);
   StringToUpper(u);
   if(StringFind(u,"XAU")>=0 || StringFind(u,"GOLD")>=0 || StringFind(u,"XAG")>=0 || StringFind(u,"SILVER")>=0) return "METAL";
   if(StringFind(u,"WTI")>=0 || StringFind(u,"BRENT")>=0 || StringFind(u,"OIL")>=0 || StringFind(u,"USOIL")>=0 || StringFind(u,"UKOIL")>=0) return "ENERGY";
   if(StringFind(u,"BTC")>=0 || StringFind(u,"ETH")>=0 || StringFind(u,"CRYPTO")>=0) return "CRYPTO";
   if(StringFind(u,"US100")>=0 || StringFind(u,"NASDAQ")>=0 || StringFind(u,"NAS100")>=0 ||
      StringFind(u,"US500")>=0 || StringFind(u,"SP500")>=0 || StringFind(u,"S&P")>=0 ||
      StringFind(u,"US30")>=0 || StringFind(u,"DOW")>=0 || StringFind(u,"GER40")>=0 ||
      StringFind(u,"DAX")>=0 || StringFind(u,"UK100")>=0 || StringFind(u,"FTSE")>=0 ||
      StringFind(u,"JP225")>=0 || StringFind(u,"NIKKEI")>=0) return "INDEX";
   string ccys=RelatedCurrencies(sym);
   if(ccys!="") return "FX";
   return "OTHER";
}

double StressShockPct(const string sym)
{
   string cls=StressAssetClass(sym);
   if(cls=="INDEX") return InpStressIndexShockPct;
   if(cls=="FX") return InpStressFXShockPct;
   if(cls=="METAL") return InpStressMetalShockPct;
   if(cls=="ENERGY") return InpStressEnergyShockPct;
   if(cls=="CRYPTO") return InpStressCryptoShockPct;
   return InpStressOtherShockPct;
}

StrategyClass StressCandidateStrategyForSymbol(const string sym)
{
   int c=(int)GVRead(SymKey(sym,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   if(c<=0) c=(int)GVRead(SymKey(sym,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   return (StrategyClass)c;
}

int StrategyDecisionHalfLifeSeconds(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_BREAKOUT: return 120;
      case STRATEGY_BREAKOUT_RETEST: return 300;
      case STRATEGY_COUNTER_TREND_SCALP: return 180;
      case STRATEGY_COUNTER_TREND_SWING: return 480;
      case STRATEGY_POTENTIAL_REVERSAL: return 600;
      case STRATEGY_RETRACEMENT_ENTRY: return 900;
      case STRATEGY_RANGE_TRADE: return 600;
      case STRATEGY_MEAN_REVERSION: return 600;
      case STRATEGY_TREND_CONTINUATION: return 1200;
      default: return 300;
   }
}

double PositionStressLossMoney(ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return 0;
   string sym=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double shock=MathMax(0.10,StressShockPct(sym))/100.0;
   double stressed=(type==POSITION_TYPE_BUY?entry*(1.0-shock):entry*(1.0+shock));
   double pnl=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,vol,entry,stressed,pnl)) return 0;
   return MathMax(0.0,-pnl);
}

double ProposedStressLossMoney(const TradeSetup &s,double lots)
{
   double shock=MathMax(0.10,StressShockPct(s.symbol))/100.0;
   double entry=s.preferred;
   double stressed=(s.bullish?entry*(1.0-shock):entry*(1.0+shock));
   double pnl=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,s.symbol,lots,entry,stressed,pnl)) return 0;
   return MathMax(0.0,-pnl);
}

double CurrentPortfolioScenarioStressLoss()
{
   double loss=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      loss+=PositionStressLossMoney(tk);
   }
   return loss;
}

bool GapRiskAllows(const TradeSetup &s,double lots,string &why)
{
   why="";
   if(!InpUseGapRiskSizingGate){ why="gap-risk gate disabled"; return true; }
   double planned=ProposedRiskMoney(s,lots);
   if(planned<=0){ why="planned stop risk unavailable"; return false; }
   double gap=ProposedStressLossMoney(s,lots);
   double multiple=gap/planned;
   why=StringFormat("gap/scenario loss %.2f vs planned %.2f = %.2fx",gap,planned,multiple);
   return multiple<=MathMax(1.0,InpMaxGapLossMultipleOfPlannedRisk);
}

bool MarginStressAllows(const TradeSetup &s,double lots,double proposedStress,string &why)
{
   why="";
   if(!InpUseMarginStressGate){ why="margin stress disabled"; return true; }
   MqlTick t={}; if(!GetTickSafe(s.symbol,t)){ why="no fresh tick for margin stress"; return false; }
   double px=(s.bullish?t.ask:t.bid),newMargin=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcMargin(ot,s.symbol,lots,px,newMargin)){ why="OrderCalcMargin failed in stress test"; return false; }
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   double portfolioStress=CurrentPortfolioScenarioStressLoss()+proposedStress;
   double stressedEquity=MathMax(0.0,equity-portfolioStress);
   double stressedMargin=margin+newMargin;
   double level=(stressedMargin>0?stressedEquity/stressedMargin*100.0:99999.0);
   why=StringFormat("stressed margin level %.1f%% | stress loss %.2f | projected margin %.2f",
                    level,portfolioStress,stressedMargin);
   return level>=MathMax(100.0,InpMinimumStressedMarginLevelPct);
}

bool DecisionAgeLatencyAllows(const TradeSetup &s,StrategyClass c,string &why)
{
   why="";
   int halfLife=StrategyDecisionHalfLifeSeconds(c);
   datetime candidate=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   datetime now=TimeTradeServer();
   int age=(candidate>0?(int)MathMax(0,(long)(now-candidate)):999999);
   if(InpUseDecisionHalfLife && (candidate<=0 || age>halfLife))
   {
      why=StringFormat("decision half-life expired: age %d sec > %d sec for %s",age,halfLife,StrategyClassName(c));
      return false;
   }
   double latency=GVRead(SymKey(s.symbol,"EXEC_LATENCY_EWMA_MS"),0);
   double budgetMs=halfLife*1000.0*MathMax(0.05,MathMin(0.90,InpMaxLatencyBudgetFraction));
   if(InpUseExecutionLatencyBudget && latency>0 && latency>budgetMs)
   {
      why=StringFormat("learned execution latency %.0f ms exceeds %.0f ms decision budget",latency,budgetMs);
      return false;
   }
   why=StringFormat("decision age %d/%d sec | learned latency %.0f/%.0f ms",age,halfLife,latency,budgetMs);
   return true;
}

bool PortfolioStressLatencyAllows(const TradeSetup &s,double lots,string &why)
{
   why="";
   StrategyClass c=StressCandidateStrategyForSymbol(s.symbol);
   string age="";
   if(!DecisionAgeLatencyAllows(s,c,age)){ why=age; return false; }

   double proposedStress=ProposedStressLossMoney(s,lots);
   double total=CurrentPortfolioScenarioStressLoss()+proposedStress;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double pct=(equity>0?total/equity*100.0:999.0);
   if(InpUsePortfolioScenarioStress && pct>InpMaxScenarioStressLossPctEquity)
   {
      why=StringFormat("scenario-stress BLOCK %.2f%% equity > %.2f%% | %s",pct,InpMaxScenarioStressLossPctEquity,age);
      return false;
   }

   string gap="";
   if(!GapRiskAllows(s,lots,gap)){ why="gap risk BLOCK: "+gap+" | "+age; return false; }
   string margin="";
   if(!MarginStressAllows(s,lots,proposedStress,margin)){ why="margin stress BLOCK: "+margin+" | "+age; return false; }

   why=StringFormat("scenario stress %.2f%% equity PASS | %s | %s | %s",pct,gap,margin,age);
   return true;
}
