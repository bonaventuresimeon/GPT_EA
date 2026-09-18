// ============================================================================
// GPT_EA Part 30 - Adaptive portfolio risk, correlation and independent supervisor
// ============================================================================
// This module is deliberately deterministic. GPT can never override these gates.

input bool   InpUseAdaptivePortfolioEngine          = true;
input bool   InpUseRollingCorrelationRisk           = true;
input int    InpCorrelationLookbackM15              = 96;
input double InpCorrelationRiskThreshold            = 0.70;
input double InpMaxCorrelationWeightedRiskPercent   = 2.25;
input double InpMaxMacroFactorRiskPercent           = 2.25;

input bool   InpUsePerStrategyRiskBudgets           = true;
input double InpTrendDailyRiskBudgetPct              = 2.00;
input double InpTrendWeeklyRiskBudgetPct             = 5.00;
input double InpRetracementDailyRiskBudgetPct        = 2.00;
input double InpRetracementWeeklyRiskBudgetPct       = 5.00;
input double InpCounterScalpDailyRiskBudgetPct       = 0.75;
input double InpCounterScalpWeeklyRiskBudgetPct      = 2.00;
input double InpCounterSwingDailyRiskBudgetPct       = 1.00;
input double InpCounterSwingWeeklyRiskBudgetPct      = 2.50;
input double InpReversalDailyRiskBudgetPct           = 1.00;
input double InpReversalWeeklyRiskBudgetPct          = 2.50;
input double InpBreakoutDailyRiskBudgetPct           = 1.50;
input double InpBreakoutWeeklyRiskBudgetPct          = 4.00;
input double InpBreakoutRetestDailyRiskBudgetPct     = 2.00;
input double InpBreakoutRetestWeeklyRiskBudgetPct    = 5.00;
input double InpRangeDailyRiskBudgetPct              = 1.00;
input double InpRangeWeeklyRiskBudgetPct             = 3.00;
input double InpMeanReversionDailyRiskBudgetPct      = 1.00;
input double InpMeanReversionWeeklyRiskBudgetPct     = 3.00;

input bool   InpUseDynamicQualitySizing              = true;
input double InpMinAdaptiveRiskMultiplier            = 0.25;
input double InpMaxAdaptiveRiskMultiplier            = 1.00;
input double InpDrawdownRiskReductionStartPct        = 3.00;
input double InpDrawdownRiskMinimumAtPct             = 7.00;

input bool   InpUseMarketConditionKillSwitch         = true;
input int    InpAbnormalMarketKillScore              = 3;
input double InpKillSpreadATRFrac                    = 0.20;
input double InpKillM1RangeM15ATRFrac                = 0.60;
input double InpKillATRRatio                         = 2.25;
input double InpKillOpeningRangeRatio                = 2.75;
input int    InpKillQuoteAgeSeconds                  = 10;

input bool   InpUseBrokerHealthGate                  = true;
input double InpBrokerHealthMinimum                  = 55.0;
input bool   InpUseIndependentRiskSupervisor         = true;
input double InpDrawdownAccelerationBlockPct         = 2.00;
input int    InpDrawdownAccelerationWindowMinutes    = 60;

// Strategy health modes written by Part31 and enforced here.
enum AdaptiveStrategyMode
{
   ADAPTIVE_MODE_ACTIVE=0,
   ADAPTIVE_MODE_REDUCED_RISK=1,
   ADAPTIVE_MODE_SHADOW=2,
   ADAPTIVE_MODE_DISABLED=3
};

string AdaptiveStrategyModeName(int mode)
{
   if(mode==ADAPTIVE_MODE_REDUCED_RISK) return "REDUCED_RISK";
   if(mode==ADAPTIVE_MODE_SHADOW) return "SHADOW";
   if(mode==ADAPTIVE_MODE_DISABLED) return "DISABLED";
   return "ACTIVE";
}

StrategyClass CandidateStrategyForSymbol(const string sym)
{
   int c=(int)GVRead(SymKey(sym,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   if(c<=0) c=(int)GVRead(SymKey(sym,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   return (StrategyClass)c;
}

void StrategyRiskBudgetCaps(StrategyClass c,double &daily,double &weekly)
{
   daily=InpTrendDailyRiskBudgetPct; weekly=InpTrendWeeklyRiskBudgetPct;
   switch(c)
   {
      case STRATEGY_RETRACEMENT_ENTRY: daily=InpRetracementDailyRiskBudgetPct; weekly=InpRetracementWeeklyRiskBudgetPct; break;
      case STRATEGY_COUNTER_TREND_SCALP: daily=InpCounterScalpDailyRiskBudgetPct; weekly=InpCounterScalpWeeklyRiskBudgetPct; break;
      case STRATEGY_COUNTER_TREND_SWING: daily=InpCounterSwingDailyRiskBudgetPct; weekly=InpCounterSwingWeeklyRiskBudgetPct; break;
      case STRATEGY_POTENTIAL_REVERSAL: daily=InpReversalDailyRiskBudgetPct; weekly=InpReversalWeeklyRiskBudgetPct; break;
      case STRATEGY_BREAKOUT: daily=InpBreakoutDailyRiskBudgetPct; weekly=InpBreakoutWeeklyRiskBudgetPct; break;
      case STRATEGY_BREAKOUT_RETEST: daily=InpBreakoutRetestDailyRiskBudgetPct; weekly=InpBreakoutRetestWeeklyRiskBudgetPct; break;
      case STRATEGY_RANGE_TRADE: daily=InpRangeDailyRiskBudgetPct; weekly=InpRangeWeeklyRiskBudgetPct; break;
      case STRATEGY_MEAN_REVERSION: daily=InpMeanReversionDailyRiskBudgetPct; weekly=InpMeanReversionWeeklyRiskBudgetPct; break;
      default: break;
   }
}

datetime StartOfTradingDay()
{
   MqlDateTime t={}; TimeToStruct(TimeTradeServer(),t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

datetime StartOfTradingWeek()
{
   datetime d=StartOfTradingDay();
   MqlDateTime t={}; TimeToStruct(d,t);
   int back=(t.day_of_week==0?6:t.day_of_week-1); // Monday start
   return d-back*86400;
}

double StrategyOpenRiskMoney(StrategyClass c)
{
   double sum=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      double r=PositionRiskMoney(tk);
      if(r>1.0e90) return r;
      sum+=r;
   }
   return sum;
}

double StrategyRealizedLossMoneySince(StrategyClass c,datetime from)
{
   datetime now=TimeTradeServer();
   if(from<=0 || !HistorySelect(from,now)) return 0;
   double loss=0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if((long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP);
      if(p<0) loss+=-p;
   }
   return loss;
}

double StrategyBudgetAvailableMoney(StrategyClass c,bool weekly,string &detail)
{
   detail="";
   if(!InpUsePerStrategyRiskBudgets || c==STRATEGY_NO_TRADE) return 1.0e100;
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   if(capital<=0) return 0;
   double dailyCap=0,weeklyCap=0; StrategyRiskBudgetCaps(c,dailyCap,weeklyCap);
   double pct=(weekly?weeklyCap:dailyCap);
   if(pct<=0) return 0;
   datetime from=(weekly?StartOfTradingWeek():StartOfTradingDay());
   double consumed=StrategyOpenRiskMoney(c)+StrategyRealizedLossMoneySince(c,from);
   double capMoney=capital*pct/100.0;
   double avail=MathMax(0.0,capMoney-consumed);
   detail=StringFormat("%s %s budget %.2f%% | consumed %.2f | available %.2f",
      StrategyClassName(c),weekly?"weekly":"daily",pct,consumed,avail);
   return avail;
}

bool StrategyRiskBudgetAllows(StrategyClass c,double proposedMoney,string &why)
{
   why="Strategy risk budgets disabled.";
   if(!InpUsePerStrategyRiskBudgets || c==STRATEGY_NO_TRADE) return true;
   string d="",w="";
   double da=StrategyBudgetAvailableMoney(c,false,d);
   double wa=StrategyBudgetAvailableMoney(c,true,w);
   double avail=MathMin(da,wa);
   why=d+" | "+w+StringFormat(" | proposed %.2f",proposedMoney);
   return proposedMoney<=avail+0.01;
}

bool ReturnSeriesM15(const string sym,int lookback,double &r[])
{
   int bars=MathMax(24,lookback)+1;
   double c[]; ArraySetAsSeries(c,true);
   int n=CopyClose(sym,PERIOD_M15,1,bars,c);
   if(n<25) return false;
   int m=n-1; ArrayResize(r,m);
   for(int i=0;i<m;i++) r[i]=(c[i+1]!=0?(c[i]-c[i+1])/c[i+1]:0);
   return true;
}

double RollingM15Correlation(const string a,const string b)
{
   if(a==b) return 1.0;
   double x[],y[];
   if(!ReturnSeriesM15(a,InpCorrelationLookbackM15,x) || !ReturnSeriesM15(b,InpCorrelationLookbackM15,y)) return 0;
   int n=MathMin(ArraySize(x),ArraySize(y)); if(n<20) return 0;
   double sx=0,sy=0; for(int i=0;i<n;i++){ sx+=x[i]; sy+=y[i]; }
   double mx=sx/n,my=sy/n,num=0,dx=0,dy=0;
   for(int i=0;i<n;i++)
   {
      double ax=x[i]-mx,ay=y[i]-my;
      num+=ax*ay; dx+=ax*ax; dy+=ay*ay;
   }
   if(dx<=0 || dy<=0) return 0;
   return MathMax(-1.0,MathMin(1.0,num/MathSqrt(dx*dy)));
}

double DirectionSign(bool bull){ return bull?1.0:-1.0; }

double CorrelationWeightedOpenRiskMoney(const TradeSetup &s)
{
   if(!InpUseRollingCorrelationRisk) return 0;
   double sum=0,psign=DirectionSign(s.bullish);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string os=PositionGetString(POSITION_SYMBOL);
      bool obull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double corr=RollingM15Correlation(s.symbol,os);
      double aligned=corr*psign*DirectionSign(obull);
      if(aligned<InpCorrelationRiskThreshold) continue;
      double r=PositionRiskMoney(tk); if(r>1.0e90) return r;
      sum+=r*MathMax(0.0,MathMin(1.0,aligned));
   }
   return sum;
}

void MacroFactorBetas(const string sym,bool bull,double &usd,double &riskOn)
{
   usd=0; riskOn=0;
   string u=sym; StringToUpper(u);
   double dir=DirectionSign(bull);
   if(StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0){ usd=-0.75*dir; riskOn=-0.20*dir; return; }
   if(StringFind(u,"US100")>=0 || StringFind(u,"NAS")>=0 || StringFind(u,"USTEC")>=0 ||
      StringFind(u,"US500")>=0 || StringFind(u,"SPX")>=0 || StringFind(u,"US30")>=0 ||
      StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX")>=0)
   { riskOn=1.0*dir; usd=-0.15*dir; return; }
   if(StringFind(u,"BTC")>=0 || StringFind(u,"ETH")>=0){ riskOn=0.80*dir; usd=-0.30*dir; return; }
   if(StringFind(u,"WTI")>=0 || StringFind(u,"BRENT")>=0 || StringFind(u,"USOIL")>=0 || StringFind(u,"UKOIL")>=0)
   { riskOn=0.45*dir; usd=-0.25*dir; return; }

   // Major FX USD leg approximation. Suffixes are allowed because we search the canonical six-letter sequence.
   string majors[7]={"EURUSD","GBPUSD","AUDUSD","NZDUSD","USDJPY","USDCHF","USDCAD"};
   for(int i=0;i<7;i++) if(StringFind(u,majors[i])>=0)
   {
      bool usdBase=(StringFind(majors[i],"USD")==0);
      usd=(usdBase?1.0:-1.0)*dir;
      riskOn=(majors[i]=="AUDUSD" || majors[i]=="NZDUSD"?0.35*dir:0.0);
      return;
   }
}

void CurrentMacroFactorRisk(double &usdMoney,double &riskMoney)
{
   usdMoney=0; riskMoney=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      double pr=PositionRiskMoney(tk); if(pr<=0 || pr>1.0e90) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double u=0,r=0; MacroFactorBetas(sym,bull,u,r);
      usdMoney+=u*pr; riskMoney+=r*pr;
   }
}

bool AdvancedPortfolioRiskAllows(const TradeSetup &s,double lots,string &why)
{
   string base="";
   if(!PortfolioRiskAllows(s,lots,base)){ why=base; return false; }
   if(!InpUseAdaptivePortfolioEngine){ why=base+" | adaptive portfolio layer disabled."; return true; }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0){ why="Account equity unavailable."; return false; }
   double proposed=ProposedRiskMoney(s,lots);

   double weighted=CorrelationWeightedOpenRiskMoney(s);
   if(weighted>1.0e90){ why="Correlation layer found unprotected position."; return false; }
   double weightedPct=(weighted+proposed)/eq*100.0;
   if(InpUseRollingCorrelationRisk && InpMaxCorrelationWeightedRiskPercent>0 && weightedPct>InpMaxCorrelationWeightedRiskPercent)
   {
      why=StringFormat("Correlation-weighted risk %.2f%% > %.2f%% cap. | %s",weightedPct,InpMaxCorrelationWeightedRiskPercent,base);
      return false;
   }

   double usd=0,risk=0,pu=0,pr=0; CurrentMacroFactorRisk(usd,risk); MacroFactorBetas(s.symbol,s.bullish,pu,pr);
   double usdPct=MathAbs(usd+pu*proposed)/eq*100.0;
   double riskPct=MathAbs(risk+pr*proposed)/eq*100.0;
   if(InpMaxMacroFactorRiskPercent>0 && MathMax(usdPct,riskPct)>InpMaxMacroFactorRiskPercent)
   {
      why=StringFormat("Macro factor concentration %.2f%% (USD %.2f%% / risk-on %.2f%%) > %.2f%% cap.",
                       MathMax(usdPct,riskPct),usdPct,riskPct,InpMaxMacroFactorRiskPercent);
      return false;
   }
   why=StringFormat("%s | correlation-weighted %.2f%% | macro USD %.2f%% risk-on %.2f%%",base,weightedPct,usdPct,riskPct);
   return true;
}

int AbnormalMarketConditionScore(const string sym,string &detail)
{
   int score=0; string d="";
   MqlTick t={}; double atr5=0,atr15=0;
   if(GetTickSafe(sym,t) && ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr5) && atr5>0)
   {
      double spread=(t.ask-t.bid)/atr5;
      if(spread>=InpKillSpreadATRFrac){ score++; d+="spread/ATR; "; }
   }
   ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr15);
   MqlRates m1[]; ArraySetAsSeries(m1,true);
   if(atr15>0 && CopyRates(sym,PERIOD_M1,1,2,m1)>=1)
   {
      double r=m1[0].high-m1[0].low;
      if(r/atr15>=InpKillM1RangeM15ATRFrac){ score++; d+="violent-M1; "; }
   }
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   if(x.atrRatio>=InpKillATRRatio){ score++; d+="ATR-regime; "; }
   if(x.openingRangeRatio>=InpKillOpeningRangeRatio){ score++; d+="opening-range; "; }
   if(StopQuoteAgeSeconds(sym)>InpKillQuoteAgeSeconds){ score++; d+="stale-quote; "; }
   string y=""; if(InpUseYieldShockFilter && YieldShock(y)){ score++; d+="yield-shock; "; }
   detail=StringFormat("abnormal-market score %d/%d [%s]",score,InpAbnormalMarketKillScore,d);
   return score;
}

double BrokerHealthScore(const string sym,string &detail)
{
   double score=100.0;
   int age=StopQuoteAgeSeconds(sym);
   if(age>InpKillQuoteAgeSeconds) score-=25;
   double atr=0; MqlTick t={};
   if(GetTickSafe(sym,t) && ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) && atr>0)
   {
      double sf=(t.ask-t.bid)/atr;
      if(sf>InpMaxSpreadATRFrac) score-=MathMin(25.0,100.0*(sf-InpMaxSpreadATRFrac));
   }
   double attempts=GVRead(SymKey(sym,"EXEC_ATTEMPTS"),0),fails=GVRead(SymKey(sym,"EXEC_FAILS"),0);
   if(attempts>=5) score-=MathMin(25.0,(fails/attempts)*50.0);
   double slip=GVRead(SymKey(sym,"EXEC_SLIP_EWMA_PTS"),0);
   double spreadPts=0,pt=PointFor(sym); if(pt>0 && t.ask>t.bid) spreadPts=(t.ask-t.bid)/pt;
   if(spreadPts>0 && slip>2.0*spreadPts) score-=15;
   int activeStopFails=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=sym) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      activeStopFails+=StopFailureCount(pid);
   }
   score-=MathMin(20.0,activeStopFails*3.0);
   score=MathMax(0.0,MathMin(100.0,score));
   detail=StringFormat("broker health %.1f/100 | quote %ds | attempts %.0f fails %.0f | slipEWMA %.1f pts | active stop failures %d",
                       score,age,attempts,fails,slip,activeStopFails);
   return score;
}

void RefreshDrawdownAccelerationBaseline()
{
   datetime now=TimeTradeServer();
   datetime saved=(datetime)GVRead(SysKey("DD_ACCEL_TIME"),0);
   double current=EquityDrawdownPercent();
   int window=MathMax(5,InpDrawdownAccelerationWindowMinutes)*60;
   if(saved<=0 || now-saved>=window)
   {
      GVWrite(SysKey("DD_ACCEL_TIME"),(double)now);
      GVWrite(SysKey("DD_ACCEL_BASE"),current);
   }
}

bool DrawdownAccelerationBlocked(string &why)
{
   RefreshDrawdownAccelerationBaseline();
   double base=GVRead(SysKey("DD_ACCEL_BASE"),EquityDrawdownPercent());
   double now=EquityDrawdownPercent();
   double delta=now-base;
   if(InpDrawdownAccelerationBlockPct>0 && delta>=InpDrawdownAccelerationBlockPct)
   {
      why=StringFormat("Drawdown accelerated %.2f percentage points within supervisor window (%.2f -> %.2f).",delta,base,now);
      return true;
   }
   why=StringFormat("Drawdown acceleration %.2fpp within supervisor window.",delta);
   return false;
}

int StrategyHealthMode(StrategyClass c)
{
   if(c==STRATEGY_NO_TRADE) return ADAPTIVE_MODE_DISABLED;
   return (int)GVRead(SysKey(StringFormat("HEALTH_MODE_%d",(int)c)),ADAPTIVE_MODE_ACTIVE);
}

double StrategyHealthRiskMultiplier(StrategyClass c)
{
   int mode=StrategyHealthMode(c);
   if(mode==ADAPTIVE_MODE_REDUCED_RISK) return 0.50;
   if(mode==ADAPTIVE_MODE_SHADOW || mode==ADAPTIVE_MODE_DISABLED) return 0.0;
   return MathMax(0.25,MathMin(1.0,GVRead(SysKey(StringFormat("HEALTH_RISK_MULT_%d",(int)c)),1.0)));
}

bool IndependentRiskSupervisorAllows(const TradeSetup &s,string &why)
{
   if(!InpUseIndependentRiskSupervisor){ why="Independent risk supervisor disabled."; return true; }
   string base=""; if(RiskKillSwitchActive(base)){ why="Account kill switch: "+base; return false; }
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   int mode=StrategyHealthMode(c);
   if(mode==ADAPTIVE_MODE_SHADOW || mode==ADAPTIVE_MODE_DISABLED)
   { why=StrategyClassName(c)+" is "+AdaptiveStrategyModeName(mode)+"; live exposure prohibited."; return false; }

   if(InpUseMarketConditionKillSwitch)
   {
      string abnormal=""; int score=AbnormalMarketConditionScore(s.symbol,abnormal);
      if(score>=MathMax(1,InpAbnormalMarketKillScore)){ why="Market-condition kill switch: "+abnormal; return false; }
   }
   if(InpUseBrokerHealthGate)
   {
      string bh=""; double h=BrokerHealthScore(s.symbol,bh);
      if(h<InpBrokerHealthMinimum){ why="Broker-health gate: "+bh; return false; }
   }
   string dd=""; if(DrawdownAccelerationBlocked(dd)){ why="Independent supervisor: "+dd; return false; }
   why="Independent supervisor PASS.";
   return true;
}

double AdaptiveRiskMultiplier(const TradeSetup &s,string &detail)
{
   if(!InpUseDynamicQualitySizing){ detail="Dynamic quality sizing disabled."; return 1.0; }
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   double conf=MathMax(0.0,MathMin(100.0,(double)s.confidence));
   double confF=MathMax(0.40,MathMin(1.0,0.40+(conf-50.0)*0.012));
   double healthF=StrategyHealthRiskMultiplier(c);
   string bh=""; double broker=BrokerHealthScore(s.symbol,bh);
   double brokerF=MathMax(0.50,MathMin(1.0,(broker-35.0)/65.0));
   double dd=EquityDrawdownPercent(),ddF=1.0;
   if(dd>InpDrawdownRiskReductionStartPct)
   {
      double den=MathMax(0.25,InpDrawdownRiskMinimumAtPct-InpDrawdownRiskReductionStartPct);
      ddF=1.0-0.65*MathMin(1.0,(dd-InpDrawdownRiskReductionStartPct)/den);
   }
   double histF=1.0;
   if(c!=STRATEGY_NO_TRADE)
   {
      double n=0,wr=0,avg=0,pf=0,maxdd=0,ml=0;
      StrategyBucketMetrics(SysKey(StringFormat("STRAT_%d",(int)c)),n,wr,avg,pf,maxdd,ml);
      if(n>=8 && (avg<0 || pf<1.0)) histF=0.65;
      else if(n>=15 && avg>=0.15 && pf>=1.25) histF=1.0;
      else if(n>=8) histF=0.85;
   }
   double eventF=HighImpactEventWithin(s.symbol,InpStrategyNewsContextMinutes)?0.60:1.0;
   double modelF=ModelTrustRiskMultiplier();
   double f=confF*healthF*brokerF*ddF*histF*eventF*modelF;
   f=MathMax(InpMinAdaptiveRiskMultiplier,MathMin(InpMaxAdaptiveRiskMultiplier,f));
   if(healthF<=0 || modelF<=0) f=0;
   detail=StringFormat("adaptive risk x%.2f | conf %.2f health %.2f broker %.2f DD %.2f history %.2f event %.2f model %.2f",
                       f,confF,healthF,brokerF,ddF,histF,eventF,modelF);
   return f;
}

double AdaptiveLotSizeForRisk(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   riskMoney=0; oneLotLoss=0;
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   if(capital<=0) return 0;
   string q=""; double mult=AdaptiveRiskMultiplier(s,q);
   if(mult<=0) return 0;
   double desired=capital*InpRiskPercent/100.0*mult;
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   if(InpUsePerStrategyRiskBudgets && c!=STRATEGY_NO_TRADE)
   {
      string d="",w="";
      desired=MathMin(desired,MathMin(StrategyBudgetAvailableMoney(c,false,d),StrategyBudgetAvailableMoney(c,true,w)));
   }
   if(desired<=0) return 0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss=0;
   if(!OrderCalcProfit(ot,s.symbol,1.0,s.preferred,s.sl,loss)) return 0;
   oneLotLoss=MathAbs(loss); if(oneLotLoss<=0) return 0;
   double lots=NormalizeVolumeDown(s.symbol,desired/oneLotLoss);
   if(lots<=0) return 0;
   riskMoney=lots*oneLotLoss; // actual normalized risk, not pre-rounding target.
   return lots;
}

bool AdaptivePreEntryAllows(const TradeSetup &s,double lots,string &why)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string modelClock="";
   if(!ModelClockExecutionAllows(s,c,modelClock)){ why="Model/clock trust: "+modelClock; return false; }

   string sup=""; if(!IndependentRiskSupervisorAllows(s,sup)){ why=sup; return false; }
   double proposed=ProposedRiskMoney(s,lots);
   string budget=""; if(!StrategyRiskBudgetAllows(c,proposed,budget)){ why="Strategy budget: "+budget; return false; }
   string portfolio=""; if(!AdvancedPortfolioRiskAllows(s,lots,portfolio)){ why="Adaptive portfolio: "+portfolio; return false; }
   string stress=""; if(!PortfolioStressLatencyAllows(s,lots,stress)){ why="Scenario/latency supervisor: "+stress; return false; }
   why=modelClock+" | "+sup+" | "+budget+" | "+portfolio+" | "+stress;
   return true;
}

string AdaptiveRiskSummary(const TradeSetup &s)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string mult="",bh="",ab="",dd="";
   double f=AdaptiveRiskMultiplier(s,mult);
   double h=BrokerHealthScore(s.symbol,bh);
   int a=AbnormalMarketConditionScore(s.symbol,ab);
   bool ddb=DrawdownAccelerationBlocked(dd);
   double daily=0,weekly=0; string d="",w="";
   daily=StrategyBudgetAvailableMoney(c,false,d); weekly=StrategyBudgetAvailableMoney(c,true,w);
   return StringFormat("Adaptive risk: %s | mode %s | risk multiplier %.2f | broker health %.1f | abnormal score %d | DD acceleration %s | daily/weekly available %.2f/%.2f",
      StrategyClassName(c),AdaptiveStrategyModeName(StrategyHealthMode(c)),f,h,a,ddb?"BLOCK":"OK",daily,weekly);
}

void AdaptiveRiskSupervisorInit()
{
   RefreshDrawdownAccelerationBaseline();
   Print("GPT_EA adaptive portfolio/risk supervisor initialized.");
}

void AdaptiveRiskSupervisorTimer()
{
   RefreshDrawdownAccelerationBaseline();
}
