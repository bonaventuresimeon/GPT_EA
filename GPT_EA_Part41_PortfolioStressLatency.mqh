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
input bool   InpUseMacroScenarioStress            = true;
input double InpStressUSDStrengthPct              = 1.00;
input double InpStressYieldShockBps               = 20.0;
input double InpStressYieldIndexEffectPct         = 1.50;
input double InpStressYieldGoldEffectPct          = 1.00;
input double InpStressYieldCryptoEffectPct        = 2.00;
input double InpStressEquityRiskOffPct            = 2.00;
input double InpStressVolatilityIndexDropPct      = 3.00;
input double InpStressCorrelatedGapMultiplier     = 1.50;
input bool   InpUseGapRiskSizingGate             = true;
input double InpMaxGapLossMultipleOfPlannedRisk  = 2.00;
input bool   InpUseMarginStressGate              = true;
input double InpMinimumStressedMarginLevelPct    = 250.0;
input bool   InpUseDecisionHalfLife              = true;
input bool   InpUseExecutionLatencyBudget        = true;
input double InpMaxLatencyBudgetFraction         = 0.35;


enum PortfolioStressScenario
{
   PORT_STRESS_USD_UP=0,
   PORT_STRESS_YIELDS_UP=1,
   PORT_STRESS_EQUITY_RISK_OFF=2,
   PORT_STRESS_GOLD_UP=3,
   PORT_STRESS_GOLD_DOWN=4,
   PORT_STRESS_OIL_UP=5,
   PORT_STRESS_OIL_DOWN=6,
   PORT_STRESS_VOLATILITY_SPIKE=7,
   PORT_STRESS_CORRELATED_GAP_DOWN=8,
   PORT_STRESS_CORRELATED_GAP_UP=9
};

string PortfolioStressScenarioName(int scenario)
{
   switch(scenario)
   {
      case PORT_STRESS_USD_UP: return StringFormat("USD +%.2f%%",InpStressUSDStrengthPct);
      case PORT_STRESS_YIELDS_UP: return StringFormat("YIELDS +%.0f bps",InpStressYieldShockBps);
      case PORT_STRESS_EQUITY_RISK_OFF: return StringFormat("EQUITY INDICES -%.2f%%",InpStressEquityRiskOffPct);
      case PORT_STRESS_GOLD_UP: return StringFormat("GOLD +%.2f%%",InpStressMetalShockPct);
      case PORT_STRESS_GOLD_DOWN: return StringFormat("GOLD -%.2f%%",InpStressMetalShockPct);
      case PORT_STRESS_OIL_UP: return StringFormat("OIL +%.2f%%",InpStressEnergyShockPct);
      case PORT_STRESS_OIL_DOWN: return StringFormat("OIL -%.2f%%",InpStressEnergyShockPct);
      case PORT_STRESS_VOLATILITY_SPIKE: return "VOLATILITY SPIKE";
      case PORT_STRESS_CORRELATED_GAP_DOWN: return "CORRELATED GAP RISK-OFF";
      case PORT_STRESS_CORRELATED_GAP_UP: return "CORRELATED GAP RISK-ON";
   }
   return "UNKNOWN";
}

double FXUSDScenarioShockPct(const string sym,double usdStrengthPct)
{
   string key=CanonicalInstrumentKey(sym,SymbolInfoString(sym,SYMBOL_DESCRIPTION),SymbolInfoString(sym,SYMBOL_PATH));
   if(StringFind(key,"FX:")!=0 || StringLen(key)<12) return 0.0;
   string pair=StringSubstr(key,3,6);
   string base=StringSubstr(pair,0,3),quote=StringSubstr(pair,3,3);
   if(base=="USD") return usdStrengthPct;
   if(quote=="USD") return -usdStrengthPct;
   return 0.0;
}

double MacroScenarioShockPct(const string sym,int scenario)
{
   string cls=StressAssetClass(sym);
   string key=CanonicalInstrumentKey(sym,SymbolInfoString(sym,SYMBOL_DESCRIPTION),SymbolInfoString(sym,SYMBOL_PATH));
   double gap=MathMax(1.0,InpStressCorrelatedGapMultiplier);

   if(scenario==PORT_STRESS_USD_UP)
   {
      if(cls=="FX") return FXUSDScenarioShockPct(sym,InpStressUSDStrengthPct);
      if(cls=="METAL") return -0.75*InpStressUSDStrengthPct;
      if(cls=="CRYPTO") return -1.50*InpStressUSDStrengthPct;
      return 0.0;
   }

   if(scenario==PORT_STRESS_YIELDS_UP)
   {
      double scale=MathMax(0.10,InpStressYieldShockBps/20.0);
      if(cls=="INDEX") return -InpStressYieldIndexEffectPct*scale;
      if(cls=="METAL") return -InpStressYieldGoldEffectPct*scale;
      if(cls=="CRYPTO") return -InpStressYieldCryptoEffectPct*scale;
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.40*scale);
      if(cls=="ENERGY") return -0.40*scale;
      return 0.0;
   }

   if(scenario==PORT_STRESS_EQUITY_RISK_OFF)
   {
      if(cls=="INDEX") return -InpStressEquityRiskOffPct;
      if(cls=="CRYPTO") return -MathMax(InpStressCryptoShockPct,InpStressEquityRiskOffPct*1.75);
      if(cls=="ENERGY") return -MathMax(2.0,InpStressEquityRiskOffPct);
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?1.00:0.50);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.50);
      return 0.0;
   }

   if(scenario==PORT_STRESS_GOLD_UP)
      return (StringFind(key,"METAL:XAU")==0?MathAbs(InpStressMetalShockPct):0.0);
   if(scenario==PORT_STRESS_GOLD_DOWN)
      return (StringFind(key,"METAL:XAU")==0?-MathAbs(InpStressMetalShockPct):0.0);
   if(scenario==PORT_STRESS_OIL_UP)
      return (cls=="ENERGY"?MathAbs(InpStressEnergyShockPct):0.0);
   if(scenario==PORT_STRESS_OIL_DOWN)
      return (cls=="ENERGY"?-MathAbs(InpStressEnergyShockPct):0.0);

   if(scenario==PORT_STRESS_VOLATILITY_SPIKE)
   {
      string u=sym; StringToUpper(u);
      if(StringFind(u,"VIX")>=0 || StringFind(u,"VOLATILITY")>=0) return 40.0;
      if(cls=="INDEX") return -MathAbs(InpStressVolatilityIndexDropPct);
      if(cls=="CRYPTO") return -MathMax(5.0,InpStressCryptoShockPct);
      if(cls=="ENERGY") return -MathMax(3.0,InpStressEnergyShockPct*0.75);
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?1.50:0.75);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.75);
      return 0.0;
   }

   if(scenario==PORT_STRESS_CORRELATED_GAP_DOWN)
   {
      if(cls=="INDEX") return -InpStressIndexShockPct*gap;
      if(cls=="CRYPTO") return -InpStressCryptoShockPct*gap;
      if(cls=="ENERGY") return -InpStressEnergyShockPct*gap;
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?InpStressMetalShockPct:0.5*InpStressMetalShockPct);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,InpStressUSDStrengthPct*gap);
      return -InpStressOtherShockPct*gap;
   }

   if(scenario==PORT_STRESS_CORRELATED_GAP_UP)
   {
      if(cls=="INDEX") return InpStressIndexShockPct*gap;
      if(cls=="CRYPTO") return InpStressCryptoShockPct*gap;
      if(cls=="ENERGY") return InpStressEnergyShockPct*gap;
      if(cls=="METAL") return -InpStressMetalShockPct;
      if(cls=="FX") return FXUSDScenarioShockPct(sym,-InpStressUSDStrengthPct*gap);
      return InpStressOtherShockPct*gap;
   }
   return 0.0;
}

double ScenarioPositionPnLMoney(ulong ticket,int scenario)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return 0.0;
   string sym=PositionGetString(POSITION_SYMBOL);
   double shock=MacroScenarioShockPct(sym,scenario);
   if(MathAbs(shock)<0.000001) return 0.0;
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double stressed=entry*(1.0+shock/100.0);
   double pnl=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,vol,entry,stressed,pnl)) return 0.0;
   return pnl;
}

double ScenarioProposedPnLMoney(const TradeSetup &s,double lots,int scenario)
{
   double shock=MacroScenarioShockPct(s.symbol,scenario);
   if(MathAbs(shock)<0.000001) return 0.0;
   double stressed=s.preferred*(1.0+shock/100.0);
   double pnl=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,s.symbol,lots,s.preferred,stressed,pnl)) return 0.0;
   return pnl;
}

double WorstMacroScenarioPortfolioLoss(const TradeSetup &s,double lots,string &worstName)
{
   worstName="none";
   if(!InpUseMacroScenarioStress) return 0.0;
   double worst=0.0;
   for(int scenario=PORT_STRESS_USD_UP;scenario<=PORT_STRESS_CORRELATED_GAP_UP;scenario++)
   {
      double pnl=ScenarioProposedPnLMoney(s,lots,scenario);
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         pnl+=ScenarioPositionPnLMoney(tk,scenario);
      }
      double loss=MathMax(0.0,-pnl);
      if(loss>worst)
      {
         worst=loss;
         worstName=PortfolioStressScenarioName(scenario);
      }
   }
   return worst;
}

double WorstMacroScenarioProposedLoss(const TradeSetup &s,double lots,string &worstName)
{
   worstName="none";
   if(!InpUseMacroScenarioStress) return 0.0;
   double worst=0.0;
   for(int scenario=PORT_STRESS_USD_UP;scenario<=PORT_STRESS_CORRELATED_GAP_UP;scenario++)
   {
      double loss=MathMax(0.0,-ScenarioProposedPnLMoney(s,lots,scenario));
      if(loss>worst){ worst=loss; worstName=PortfolioStressScenarioName(scenario); }
   }
   return worst;
}

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
   string macroName="";
   double macro=WorstMacroScenarioProposedLoss(s,lots,macroName);
   if(macro>gap) gap=macro;
   double multiple=gap/planned;
   why=StringFormat("gap/scenario loss %.2f vs planned %.2f = %.2fx | worst macro %s %.2f",
                    gap,planned,multiple,macroName,macro);
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
   double assetClassStress=CurrentPortfolioScenarioStressLoss()+proposedStress;
   string worstMacro="";
   double macroStress=WorstMacroScenarioPortfolioLoss(s,lots,worstMacro);
   double total=MathMax(assetClassStress,macroStress);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double pct=(equity>0?total/equity*100.0:999.0);
   if(InpUsePortfolioScenarioStress && pct>InpMaxScenarioStressLossPctEquity)
   {
      why=StringFormat("scenario-stress BLOCK %.2f%% equity > %.2f%% | asset adverse %.2f | worst macro %s %.2f | %s",
                       pct,InpMaxScenarioStressLossPctEquity,assetClassStress,worstMacro,macroStress,age);
      return false;
   }

   string gap="";
   if(!GapRiskAllows(s,lots,gap)){ why="gap risk BLOCK: "+gap+" | "+age; return false; }
   string margin="";
   double proposedForMargin=MathMax(proposedStress,MathMax(0.0,macroStress-CurrentPortfolioScenarioStressLoss()));
   if(!MarginStressAllows(s,lots,proposedForMargin,margin)){ why="margin stress BLOCK: "+margin+" | "+age; return false; }

   why=StringFormat("scenario stress %.2f%% equity PASS | asset adverse %.2f | worst macro %s %.2f | %s | %s | %s",
                    pct,assetClassStress,worstMacro,macroStress,gap,margin,age);
   return true;
}
