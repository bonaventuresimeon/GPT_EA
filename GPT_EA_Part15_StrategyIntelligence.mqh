// ============================================================================
// GPT_EA Part 15 - Full regime-driven strategy intelligence
// ============================================================================

input bool   InpUseFullStrategyIntelligence      = true;
input int    InpMinStrategyScore                 = 72;
input int    InpMinCounterTrendScore             = 82;
input double InpDeepRetracementATR               = 0.85;
input double InpExhaustionATR                    = 2.00;
input double InpRangeBoundaryFraction            = 0.22;
input bool   InpAllowCounterTrendScalp            = true;
input bool   InpAllowCounterTrendSwing            = true;
input bool   InpAllowRangeTrades                  = true;
input bool   InpAllowMeanReversion                = true;
input bool   InpUseHistoricalStrategyEvidence     = true;
input int    InpStrategyEvidenceMinTrades         = 15;
input double InpStrategyEvidenceMinProfitFactor   = 1.05;
input double InpStrategyEvidenceMinAverageR       = 0.05;
input bool   InpBlockNegativeStrategyEvidence     = true;
input bool   InpRequireEvidenceSampleForLive      = false;
input int    InpStrategyHistoryLookbackDays       = 45;

// Display classifications requested by the strategy contract.
enum StrategyClass
{
   STRATEGY_NO_TRADE=0,
   STRATEGY_TREND_CONTINUATION=1,
   STRATEGY_RETRACEMENT_ENTRY=2,
   STRATEGY_COUNTER_TREND_SCALP=3,
   STRATEGY_COUNTER_TREND_SWING=4,
   STRATEGY_POTENTIAL_REVERSAL=5,
   STRATEGY_BREAKOUT=6,
   STRATEGY_BREAKOUT_RETEST=7,
   STRATEGY_RANGE_TRADE=8,
   STRATEGY_MEAN_REVERSION=9
};

enum MarketStateClass
{
   STATE_UNKNOWN=0,
   STATE_TREND_CONTINUATION=1,
   STATE_HEALTHY_RETRACEMENT=2,
   STATE_DEEP_RETRACEMENT=3,
   STATE_CORRECTION=4,
   STATE_COUNTER_TREND_MOVE=5,
   STATE_TREND_FAILURE=6,
   STATE_REVERSAL=7,
   STATE_BREAKOUT=8,
   STATE_BREAKOUT_RETEST=9,
   STATE_FALSE_BREAKOUT=10,
   STATE_LIQUIDITY_SWEEP=11,
   STATE_RANGE_EXPANSION=12,
   STATE_RANGE_REVERSAL=13,
   STATE_MEAN_REVERSION=14,
   STATE_MOMENTUM_CONTINUATION=15,
   STATE_EXHAUSTION=16,
   STATE_ACCUMULATION=17,
   STATE_DISTRIBUTION=18,
   STATE_CONSOLIDATION=19
};

enum StrategyAction
{
   STRATEGY_ACTION_NO_TRADE=0,
   STRATEGY_ACTION_WAIT=1,
   STRATEGY_ACTION_HIGH_CONFIDENCE=2
};

struct StrategySnapshot
{
   string symbol;
   bool dominantBull;
   bool htfStrong;
   int bullVotes;
   int bearVotes;
   double adx;
   double plusDI;
   double minusDI;
   double atr;
   double atrAverage;
   double atrRatio;
   double openingRangeRatio;
   double rsi15;
   double rsi5;
   double ema20;
   double ema50;
   double mid;
   double priorHigh;
   double priorLow;
   double previousDayHigh;
   double previousDayLow;
   double asianHigh;
   double asianLow;
   double rangePosition;
   double overextensionATR;
   double volumeRatio;
   bool m15BullStructure;
   bool m15BearStructure;
   bool ltfBullBreak;
   bool ltfBearBreak;
   bool bullishSweep;
   bool bearishSweep;
   bool bullishDivergence;
   bool bearishDivergence;
   bool doubleBottom;
   bool doubleTop;
   bool breakoutUp;
   bool breakoutDown;
   bool falseBreakUp;
   bool falseBreakDown;
   bool compression;
   bool expansion;
   bool exhaustion;
   bool possibleAccumulation;
   bool possibleDistribution;
   bool trendFailure;
   bool chochAgainstTrend;
   string baseRegime;
   string session;
   MarketStateClass state;
};

struct StrategyDecision
{
   TradeSetup setup;
   StrategyClass strategy;
   MarketStateClass state;
   StrategyAction action;
   bool counterTrend;
   int score;
   int counterTrendScore;
   string strategyName;
   string regime;
   string stateText;
   string rationale;
   string confirmation;
   string counterargument;
   string librarySummary;
   string evidence;
   string session;
};

string StrategyClassName(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION: return "TREND CONTINUATION";
      case STRATEGY_RETRACEMENT_ENTRY: return "RETRACEMENT ENTRY";
      case STRATEGY_COUNTER_TREND_SCALP: return "COUNTER-TREND SCALP";
      case STRATEGY_COUNTER_TREND_SWING: return "COUNTER-TREND SWING";
      case STRATEGY_POTENTIAL_REVERSAL: return "POTENTIAL REVERSAL";
      case STRATEGY_BREAKOUT: return "BREAKOUT";
      case STRATEGY_BREAKOUT_RETEST: return "BREAKOUT-RETEST";
      case STRATEGY_RANGE_TRADE: return "RANGE TRADE";
      case STRATEGY_MEAN_REVERSION: return "MEAN-REVERSION SETUP";
      default: return "NO TRADE";
   }
}

string StrategyCode(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION: return "TC";
      case STRATEGY_RETRACEMENT_ENTRY: return "RE";
      case STRATEGY_COUNTER_TREND_SCALP: return "CTS";
      case STRATEGY_COUNTER_TREND_SWING: return "CTW";
      case STRATEGY_POTENTIAL_REVERSAL: return "REV";
      case STRATEGY_BREAKOUT: return "BO";
      case STRATEGY_BREAKOUT_RETEST: return "BRT";
      case STRATEGY_RANGE_TRADE: return "RNG";
      case STRATEGY_MEAN_REVERSION: return "MR";
      default: return "NT";
   }
}

string MarketStateName(MarketStateClass s)
{
   switch(s)
   {
      case STATE_TREND_CONTINUATION: return "TREND CONTINUATION";
      case STATE_HEALTHY_RETRACEMENT: return "HEALTHY RETRACEMENT";
      case STATE_DEEP_RETRACEMENT: return "DEEP RETRACEMENT";
      case STATE_CORRECTION: return "CORRECTION";
      case STATE_COUNTER_TREND_MOVE: return "COUNTER-TREND MOVEMENT";
      case STATE_TREND_FAILURE: return "TREND FAILURE";
      case STATE_REVERSAL: return "REVERSAL";
      case STATE_BREAKOUT: return "BREAKOUT";
      case STATE_BREAKOUT_RETEST: return "BREAKOUT-RETEST";
      case STATE_FALSE_BREAKOUT: return "FALSE BREAKOUT";
      case STATE_LIQUIDITY_SWEEP: return "LIQUIDITY SWEEP";
      case STATE_RANGE_EXPANSION: return "RANGE EXPANSION";
      case STATE_RANGE_REVERSAL: return "RANGE REVERSAL";
      case STATE_MEAN_REVERSION: return "MEAN REVERSION";
      case STATE_MOMENTUM_CONTINUATION: return "MOMENTUM CONTINUATION";
      case STATE_EXHAUSTION: return "EXHAUSTION";
      case STATE_ACCUMULATION: return "POSSIBLE ACCUMULATION";
      case STATE_DISTRIBUTION: return "POSSIBLE DISTRIBUTION";
      case STATE_CONSOLIDATION: return "CONSOLIDATION";
      default: return "UNCLASSIFIED";
   }
}

string CurrentSessionBucket()
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);
   if(l.hour>=7 && l.hour<9) return "LONDON_PREOPEN";
   if(l.hour>=9 && l.hour<12) return "LONDON";
   if(n.hour>=8 && n.hour<9) return "NEW_YORK_PREOPEN";
   if(n.hour>=9 && n.hour<12) return "NEW_YORK_OPEN";
   if(l.hour>=13 && n.hour<12) return "LONDON_NY_OVERLAP";
   if(l.hour>=0 && l.hour<7) return "ASIAN";
   return "OTHER";
}

bool PreviousDayHighLow(const string sym,double &hi,double &lo)
{
   hi=iHigh(sym,PERIOD_D1,1); lo=iLow(sym,PERIOD_D1,1);
   return (hi>0 && lo>0 && hi>lo);
}

bool AsianRange(const string sym,double &hi,double &lo)
{
   hi=-1.0e100; lo=1.0e100;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,PERIOD_M15,0,160,r);
   if(n<=0) return false;
   int chosenDate=-1,found=0;
   for(int i=0;i<n;i++)
   {
      datetime utc=ServerToUTC(r[i].time);
      MqlDateTime t={}; TimeToStruct(utc,t);
      int d=t.year*10000+t.mon*100+t.day;
      if(t.hour>=0 && t.hour<6)
      {
         if(chosenDate<0) chosenDate=d;
         if(d!=chosenDate) continue;
         hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low); found++;
      }
   }
   return (found>=8 && hi>lo);
}

bool RSIDivergenceSignal(const string sym,bool bullish)
{
   double h1=0,l1=0,h2=0,l2=0;
   if(!RecentHighLow(sym,PERIOD_M15,1,5,h1,l1) || !RecentHighLow(sym,PERIOD_M15,7,5,h2,l2)) return false;
   double r2=50,r8=50;
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,2,r2);
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,8,r8);
   if(bullish) return (l1<l2 && r2>r8+2.0);
   return (h1>h2 && r2<r8-2.0);
}

bool DoubleTopBottomSignal(const string sym,bool bottom)
{
   double h1=0,l1=0,h2=0,l2=0,atr=0;
   if(!RecentHighLow(sym,PERIOD_M15,1,6,h1,l1) || !RecentHighLow(sym,PERIOD_M15,8,6,h2,l2) ||
      !ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return false;
   double tol=0.25*atr;
   return bottom ? (MathAbs(l1-l2)<=tol) : (MathAbs(h1-h2)<=tol);
}

bool LowerTimeframeStructureBreak(const string sym,bool bullishBreak)
{
   double h1=0,l1=0,h2=0,l2=0;
   if(!RecentHighLow(sym,PERIOD_M5,1,5,h1,l1) || !RecentHighLow(sym,PERIOD_M5,7,5,h2,l2)) return false;
   return bullishBreak ? (h1>h2 && l1>l2) : (h1<h2 && l1<l2);
}

bool FalseBreakSignal(const string sym,bool upside)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,16,r)<14) return false;
   double ph=-1.0e100,pl=1.0e100;
   for(int i=2;i<=12;i++){ ph=MathMax(ph,r[i].high); pl=MathMin(pl,r[i].low); }
   if(upside) return (r[0].high>ph && r[0].close<ph);
   return (r[0].low<pl && r[0].close>pl);
}

bool ConfirmedBreakoutSignal(const string sym,bool upside,double atr)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,16,r)<14 || atr<=0) return false;
   double ph=-1.0e100,pl=1.0e100;
   for(int i=1;i<=12;i++){ ph=MathMax(ph,r[i].high); pl=MathMin(pl,r[i].low); }
   double body=MathAbs(r[0].close-r[0].open);
   if(upside) return (r[0].close>ph && body>=0.45*atr);
   return (r[0].close<pl && body>=0.45*atr);
}

void BuildStrategySnapshot(const string sym,StrategySnapshot &x)
{
   ZeroMemory(x);
   x.symbol=sym;
   x.baseRegime=DetectMarketRegime(sym);
   x.session=CurrentSessionBucket();
   x.bullVotes=0; x.bearVotes=0;
   ENUM_TIMEFRAMES htf[3]={PERIOD_D1,PERIOD_H4,PERIOD_H1};
   for(int i=0;i<3;i++)
   {
      if(TrendVote(sym,htf[i],true)>0) x.bullVotes++;
      if(TrendVote(sym,htf[i],false)>0) x.bearVotes++;
   }
   x.dominantBull=(x.bullVotes>=x.bearVotes);
   x.htfStrong=(MathMax(x.bullVotes,x.bearVotes)>=2 && MathMin(x.bullVotes,x.bearVotes)==0);
   ADXSnapshot(sym,PERIOD_M15,InpADXPeriod,x.adx,x.plusDI,x.minusDI);
   ATRValue(sym,PERIOD_M15,InpATRPeriod,1,x.atr);
   x.atrAverage=AverageATR(sym,PERIOD_M15,InpATRPeriod,50);
   x.atrRatio=(x.atrAverage>0?x.atr/x.atrAverage:1.0);
   x.openingRangeRatio=OpeningRangeRatio(sym);
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,1,x.rsi15);
   RSIValue(sym,PERIOD_M5,InpRSIPeriod,1,x.rsi5);
   EMAValue(sym,PERIOD_M15,InpFastEMA,1,x.ema20);
   EMAValue(sym,PERIOD_M15,InpSlowEMA,1,x.ema50);
   MqlTick t={}; GetTickSafe(sym,t); x.mid=(t.ask+t.bid)*0.5;
   RecentHighLow(sym,PERIOD_M15,2,InpSwingBars,x.priorHigh,x.priorLow);
   PreviousDayHighLow(sym,x.previousDayHigh,x.previousDayLow);
   AsianRange(sym,x.asianHigh,x.asianLow);
   double width=x.priorHigh-x.priorLow;
   x.rangePosition=(width>0?(x.mid-x.priorLow)/width:0.5);
   x.overextensionATR=(x.atr>0?(x.mid-x.ema20)/x.atr:0);
   x.volumeRatio=M5VolumeRatio(sym);
   x.m15BullStructure=StructureAligned(sym,true);
   x.m15BearStructure=StructureAligned(sym,false);
   x.ltfBullBreak=LowerTimeframeStructureBreak(sym,true);
   x.ltfBearBreak=LowerTimeframeStructureBreak(sym,false);
   x.bullishSweep=LiquiditySweepAligned(sym,true);
   x.bearishSweep=LiquiditySweepAligned(sym,false);
   x.bullishDivergence=RSIDivergenceSignal(sym,true);
   x.bearishDivergence=RSIDivergenceSignal(sym,false);
   x.doubleBottom=DoubleTopBottomSignal(sym,true);
   x.doubleTop=DoubleTopBottomSignal(sym,false);
   x.breakoutUp=ConfirmedBreakoutSignal(sym,true,x.atr);
   x.breakoutDown=ConfirmedBreakoutSignal(sym,false,x.atr);
   x.falseBreakUp=FalseBreakSignal(sym,true);
   x.falseBreakDown=FalseBreakSignal(sym,false);
   x.compression=(x.baseRegime=="COMPRESSION" || (x.atrRatio<0.75 && x.adx<18));
   x.expansion=(x.baseRegime=="HIGH_VOL_EXPANSION" || x.atrRatio>1.40 || x.openingRangeRatio>1.75);
   x.exhaustion=(MathAbs(x.overextensionATR)>=InpExhaustionATR &&
                 ((x.overextensionATR>0 && (x.bearishDivergence || x.rsi15>=70)) ||
                  (x.overextensionATR<0 && (x.bullishDivergence || x.rsi15<=30))));
   bool against=(x.dominantBull?x.ltfBearBreak:x.ltfBullBreak);
   x.chochAgainstTrend=against;
   x.trendFailure=(x.htfStrong && against &&
                   (x.dominantBull?x.m15BearStructure:x.m15BullStructure));
   x.possibleAccumulation=(x.baseRegime=="RANGING" && x.rangePosition<0.40 && x.bullishDivergence && x.volumeRatio>=0.9);
   x.possibleDistribution=(x.baseRegime=="RANGING" && x.rangePosition>0.60 && x.bearishDivergence && x.volumeRatio>=0.9);

   // State precedence: structural failure/reversal > breakout/fakeout > retracement > range/compression > trend.
   if(x.trendFailure && ((x.dominantBull && x.bearishSweep) || (!x.dominantBull && x.bullishSweep))) x.state=STATE_REVERSAL;
   else if(x.trendFailure) x.state=STATE_TREND_FAILURE;
   else if(x.falseBreakUp || x.falseBreakDown) x.state=STATE_FALSE_BREAKOUT;
   else if(x.breakoutUp || x.breakoutDown) x.state=(x.expansion?STATE_RANGE_EXPANSION:STATE_BREAKOUT);
   else if(x.bullishSweep || x.bearishSweep) x.state=STATE_LIQUIDITY_SWEEP;
   else if(x.exhaustion) x.state=STATE_EXHAUSTION;
   else if(x.possibleAccumulation) x.state=STATE_ACCUMULATION;
   else if(x.possibleDistribution) x.state=STATE_DISTRIBUTION;
   else if(x.compression) x.state=STATE_CONSOLIDATION;
   else if(x.baseRegime=="RANGING")
   {
      if(x.rangePosition<=InpRangeBoundaryFraction || x.rangePosition>=1.0-InpRangeBoundaryFraction) x.state=STATE_RANGE_REVERSAL;
      else x.state=STATE_MEAN_REVERSION;
   }
   else if(x.htfStrong)
   {
      bool againstEMA=(x.dominantBull?x.mid<x.ema20:x.mid>x.ema20);
      bool deep=(x.dominantBull?x.mid<=x.ema50:x.mid>=x.ema50) || MathAbs(x.mid-x.ema20)>=InpDeepRetracementATR*x.atr;
      if(againstEMA && deep) x.state=STATE_DEEP_RETRACEMENT;
      else if(againstEMA) x.state=STATE_HEALTHY_RETRACEMENT;
      else if(x.expansion && x.volumeRatio>=1.15) x.state=STATE_MOMENTUM_CONTINUATION;
      else x.state=STATE_TREND_CONTINUATION;
   }
   else x.state=STATE_CORRECTION;
}

string FibRetracementText(const StrategySnapshot &x)
{
   double w=x.priorHigh-x.priorLow;
   if(w<=0) return "Fibonacci: unavailable.";
   double f382=(x.dominantBull?x.priorHigh-0.382*w:x.priorLow+0.382*w);
   double f618=(x.dominantBull?x.priorHigh-0.618*w:x.priorLow+0.618*w);
   double lo=MathMin(f382,f618),hi=MathMax(f382,f618);
   bool inside=(x.mid>=lo && x.mid<=hi);
   return StringFormat("Fibonacci 38.2-61.8%% retracement zone %.5f-%.5f; price %s.",lo,hi,inside?"inside":"outside");
}

string SupplyDemandText(const StrategySnapshot &x)
{
   if(x.atr<=0) return "Supply/demand: unavailable.";
   double demandLo=x.priorLow,demandHi=x.priorLow+0.35*x.atr;
   double supplyLo=x.priorHigh-0.35*x.atr,supplyHi=x.priorHigh;
   return StringFormat("Demand %.5f-%.5f | Supply %.5f-%.5f",demandLo,demandHi,supplyLo,supplyHi);
}

int CounterTrendScore(const StrategySnapshot &x,bool counterBull)
{
   int s=0;
   if(x.exhaustion) s+=18;
   if(counterBull?x.bullishSweep:x.bearishSweep) s+=16;
   if(counterBull?x.bullishDivergence:x.bearishDivergence) s+=14;
   if(counterBull?x.doubleBottom:x.doubleTop) s+=8;
   if(counterBull?x.ltfBullBreak:x.ltfBearBreak) s+=18;
   if(x.chochAgainstTrend) s+=10;
   bool major=(counterBull?(x.rangePosition<=0.20 || (x.previousDayLow>0 && x.mid<=x.previousDayLow+0.25*x.atr)):
                           (x.rangePosition>=0.80 || (x.previousDayHigh>0 && x.mid>=x.previousDayHigh-0.25*x.atr)));
   if(major) s+=10;
   if(x.adx>=32 && x.htfStrong) s-=12; // fighting a powerful trend requires exceptional evidence.
   if(x.expansion && !x.exhaustion) s-=8;
   return MathMax(0,MathMin(100,s));
}

void SetConservativeTargets(TradeSetup &s,double r1,double r2,double r3)
{
   double R=MathAbs(s.preferred-s.sl); if(R<=0) return;
   if(s.bullish){ s.tp1=s.preferred+r1*R; s.tp2=s.preferred+r2*R; s.tp3=s.preferred+r3*R; }
   else { s.tp1=s.preferred-r1*R; s.tp2=s.preferred-r2*R; s.tp3=s.preferred-r3*R; }
   s.tp1=NormPrice(s.symbol,s.tp1); s.tp2=NormPrice(s.symbol,s.tp2); s.tp3=NormPrice(s.symbol,s.tp3);
   s.nominalRR1=r1;
   s.effectiveRR1=EffectiveRRDynamic(s);
}

TradeSetup BuildCounterTrendCandidate(const StrategySnapshot &x,bool bull,int score,bool swing)
{
   TradeSetup s; InitSetup(s,x.symbol,SETUP_PULLBACK,bull);
   double atr=x.atr; if(atr<=0) return s;
   double extreme=(bull?x.priorLow:x.priorHigh);
   s.name=(swing?"COUNTER-TREND SWING":"COUNTER-TREND SCALP");
   s.zoneLow=NormPrice(x.symbol,extreme-0.12*atr);
   s.zoneHigh=NormPrice(x.symbol,extreme+0.12*atr);
   s.preferred=NormPrice(x.symbol,extreme);
   s.sl=NormPrice(x.symbol,bull?extreme-0.45*atr:extreme+0.45*atr);
   SetConservativeTargets(s,swing?0.90:0.70,swing?1.60:1.15,swing?2.30:1.70);
   s.confidence=MathMin(94,score);
   s.expiryM15=AdaptiveExpiry(x.symbol,swing?4:2);
   s.valid=(score>=InpMinCounterTrendScore && s.effectiveRR1>=MathMax(1.05,InpMinEffectiveRR-0.35));
   s.reason=StringFormat("COUNTER-TREND TRADE | HTF %s but exhaustion/structure evidence supports a %s counter move. Score %d/100.",
                         x.dominantBull?"bullish":"bearish",bull?"bullish":"bearish",score);
   s.invalidation=(bull?"M15 acceptance below the swept/major support extreme invalidates the counter-trend thesis.":
                        "M15 acceptance above the swept/major resistance extreme invalidates the counter-trend thesis.");
   s.failurePattern="Failure: dominant higher-timeframe trend re-accelerates before lower-timeframe reversal structure develops.";
   s.executionRule="Counter-trend entry requires liquidity rejection plus M5 change-of-character/break-of-structure and a confirming rejection. No blind fading.";
   return s;
}

TradeSetup BuildRangeCandidate(const StrategySnapshot &x,bool meanReversion)
{
   bool bull=(x.rangePosition<=0.50);
   TradeSetup s; InitSetup(s,x.symbol,SETUP_PULLBACK,bull);
   if(x.atr<=0 || x.priorHigh<=x.priorLow) return s;
   double boundary=(bull?x.priorLow:x.priorHigh);
   s.name=(meanReversion?"MEAN-REVERSION SETUP":"RANGE TRADE");
   s.zoneLow=NormPrice(x.symbol,boundary-0.12*x.atr);
   s.zoneHigh=NormPrice(x.symbol,boundary+0.12*x.atr);
   s.preferred=NormPrice(x.symbol,boundary);
   s.sl=NormPrice(x.symbol,bull?boundary-0.45*x.atr:boundary+0.45*x.atr);
   double eq=(x.priorHigh+x.priorLow)*0.5;
   double R=MathAbs(s.preferred-s.sl);
   s.tp1=NormPrice(x.symbol,eq);
   s.tp2=NormPrice(x.symbol,bull?x.priorHigh-0.15*x.atr:x.priorLow+0.15*x.atr);
   s.tp3=NormPrice(x.symbol,bull?x.priorHigh:x.priorLow);
   s.nominalRR1=(R>0?MathAbs(s.tp1-s.preferred)/R:0);
   s.effectiveRR1=EffectiveRRDynamic(s);
   int boundaryScore=(x.rangePosition<=InpRangeBoundaryFraction || x.rangePosition>=1.0-InpRangeBoundaryFraction?82:64);
   if(bull && (x.bullishSweep || x.doubleBottom)) boundaryScore+=8;
   if(!bull && (x.bearishSweep || x.doubleTop)) boundaryScore+=8;
   s.confidence=MathMin(94,boundaryScore);
   s.expiryM15=AdaptiveExpiry(x.symbol,5);
   s.valid=(InpAllowRangeTrades && boundaryScore>=InpMinStrategyScore && s.effectiveRR1>=1.05);
   s.reason=StringFormat("%s at range boundary %.5f-%.5f; equilibrium %.5f.",s.name,x.priorLow,x.priorHigh,eq);
   s.invalidation="A decisive M15 close outside the range boundary in the adverse direction invalidates the range/mean-reversion thesis.";
   s.failurePattern="Failure: range transitions into directional expansion and boundary rejection does not hold.";
   s.executionRule="Enter only at a range boundary after rejection/reclaim; never initiate a range trade in the middle of the range.";
   return s;
}

int StrategyBaseScore(const StrategySnapshot &x,StrategyClass c)
{
   int s=45;
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION:
         s+=(x.htfStrong?18:5)+(x.adx>=25?12:4)+((x.dominantBull?x.m15BullStructure:x.m15BearStructure)?12:0)+(x.volumeRatio>=1.0?6:0);
         break;
      case STRATEGY_RETRACEMENT_ENTRY:
         s+=(x.htfStrong?20:5)+((x.state==STATE_HEALTHY_RETRACEMENT)?16:(x.state==STATE_DEEP_RETRACEMENT?10:0))+(MathAbs(x.overextensionATR)<1.5?8:0);
         break;
      case STRATEGY_BREAKOUT:
         s+=(x.breakoutUp||x.breakoutDown?20:0)+(x.expansion?15:0)+(x.volumeRatio>=1.15?10:0)+(x.adx>=23?8:0);
         break;
      case STRATEGY_BREAKOUT_RETEST:
         s+=(x.expansion?10:0)+(x.adx>=20?8:0)+(x.volumeRatio>=0.95?6:0);
         break;
      case STRATEGY_POTENTIAL_REVERSAL:
         s+=(x.trendFailure?20:0)+(x.chochAgainstTrend?15:0)+(x.exhaustion?10:0)+((x.bullishDivergence||x.bearishDivergence)?8:0);
         break;
      case STRATEGY_RANGE_TRADE:
         s+=(x.baseRegime=="RANGING"?20:0)+((x.rangePosition<=0.22||x.rangePosition>=0.78)?18:0)+((x.bullishSweep||x.bearishSweep)?8:0);
         break;
      case STRATEGY_MEAN_REVERSION:
         s+=(x.baseRegime=="RANGING"?18:0)+(MathAbs(x.overextensionATR)>=1.0?15:0)+(x.exhaustion?8:0);
         break;
      default: break;
   }
   return MathMax(0,MathMin(100,s));
}

string StrategyStatsKey(StrategyClass c,const string suffix)
{
   return SysKey(StringFormat("STRAT_%d_%s",(int)c,suffix));
}

void UpdateStrategyBucket(const string prefix,double R)
{
   double n=GVRead(prefix+"_N",0)+1;
   double wins=GVRead(prefix+"_WIN",0)+(R>0?1:0);
   double sum=GVRead(prefix+"_SUMR",0)+R;
   double pos=GVRead(prefix+"_POSR",0)+(R>0?R:0);
   double neg=GVRead(prefix+"_NEGR",0)+(R<0?-R:0);
   double curve=GVRead(prefix+"_CURVE",0)+R;
   double peak=MathMax(GVRead(prefix+"_PEAK",0),curve);
   double dd=MathMax(GVRead(prefix+"_MAXDD",0),peak-curve);
   double run=(R<0?GVRead(prefix+"_LOSSRUN",0)+1:0);
   double maxRun=MathMax(GVRead(prefix+"_MAXLOSSRUN",0),run);
   GVWrite(prefix+"_N",n); GVWrite(prefix+"_WIN",wins); GVWrite(prefix+"_SUMR",sum);
   GVWrite(prefix+"_POSR",pos); GVWrite(prefix+"_NEGR",neg); GVWrite(prefix+"_CURVE",curve);
   GVWrite(prefix+"_PEAK",peak); GVWrite(prefix+"_MAXDD",dd); GVWrite(prefix+"_LOSSRUN",run); GVWrite(prefix+"_MAXLOSSRUN",maxRun);
}

string StrategyEvidenceText(StrategyClass c)
{
   string p=SysKey(StringFormat("STRAT_%d",(int)c));
   double n=GVRead(p+"_N",0),win=GVRead(p+"_WIN",0),sum=GVRead(p+"_SUMR",0);
   double pos=GVRead(p+"_POSR",0),neg=GVRead(p+"_NEGR",0),dd=GVRead(p+"_MAXDD",0),maxL=GVRead(p+"_MAXLOSSRUN",0);
   double wr=(n>0?win/n*100.0:0),avg=(n>0?sum/n:0),pf=(neg>0?pos/neg:(pos>0?99.0:0));
   return StringFormat("%s evidence: N %.0f | win %.1f%% | avg %.2fR | PF %.2f | max DD %.2fR | max losses %.0f",
      StrategyClassName(c),n,wr,avg,pf,dd,maxL);
}

bool StrategyEvidenceAllows(StrategyClass c,string &detail)
{
   detail=StrategyEvidenceText(c);
   if(!InpUseHistoricalStrategyEvidence || c==STRATEGY_NO_TRADE) return true;
   string p=SysKey(StringFormat("STRAT_%d",(int)c));
   double n=GVRead(p+"_N",0),sum=GVRead(p+"_SUMR",0),pos=GVRead(p+"_POSR",0),neg=GVRead(p+"_NEGR",0);
   if(n<InpStrategyEvidenceMinTrades)
   {
      if(InpRequireEvidenceSampleForLive && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
      { detail+=" | BLOCK: minimum live evidence sample not reached."; return false; }
      detail+=" | evidence sample still developing; treated as neutral, not proof of edge.";
      return true;
   }
   double avg=sum/n,pf=(neg>0?pos/neg:(pos>0?99.0:0));
   if(InpBlockNegativeStrategyEvidence && (avg<InpStrategyEvidenceMinAverageR || pf<InpStrategyEvidenceMinProfitFactor))
   { detail+=StringFormat(" | BLOCK: evidence below thresholds avg %.2fR / PF %.2f.",InpStrategyEvidenceMinAverageR,InpStrategyEvidenceMinProfitFactor); return false; }
   detail+=" | historical/internal evidence gate PASS; past results are not a guarantee.";
   return true;
}

void PersistStrategyCandidate(const string sym,const StrategyDecision &d)
{
   GVWrite(SymKey(sym,"CAND_STRATEGY"),(double)d.strategy);
   GVWrite(SymKey(sym,"CAND_STATE"),(double)d.state);
   GVWrite(SymKey(sym,"CAND_SCORE"),(double)d.score);
   GVWrite(SymKey(sym,"CAND_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(sym,"CAND_SESSION"),(double)StringFind("ASIAN,LONDON_PREOPEN,LONDON,LONDON_NY_OVERLAP,NEW_YORK_PREOPEN,NEW_YORK_OPEN,OTHER",d.session));
}

void PersistStrategyPlanForExecution(const TradeSetup &s)
{
   datetime ct=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   int cls=(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   int state=(int)GVRead(SymKey(s.symbol,"CAND_STATE"),STATE_UNKNOWN);
   if(ct<=0 || TimeTradeServer()-ct>900) cls=STRATEGY_NO_TRADE;
   GVWrite(SymKey(s.symbol,"PLAN_STRATEGY"),cls);
   GVWrite(SymKey(s.symbol,"PLAN_STATE"),state);
   GVWrite(SymKey(s.symbol,"PLAN_STRAT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"PLAN_DIR"),s.bullish?1:0);
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   GVWrite(SymKey(s.symbol,"PLAN_VOL"),(x.atrRatio>=1.35?2:(x.atrRatio<=0.75?0:1)));
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_HASH"),(double)StringLen(x.session));
}

bool PositionIdStillOpenStrategy(ulong pid)
{
   return PositionIdentifierOpen(pid);
}

double StrategyPositionRealized(ulong pid)
{
   if(!HistorySelectByPosition(pid)) return 0;
   double pnl=0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT)
         pnl+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP);
   }
   return pnl;
}

void AttachStrategyMetadataToOpenPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(GVRead(PosKey(pid,"STRATEGY"),0)>0) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      datetime pt=(datetime)GVRead(SymKey(sym,"PLAN_STRAT_TIME"),0);
      if(pt<=0 || MathAbs((long)PositionGetInteger(POSITION_TIME)-(long)pt)>1200) continue;
      GVWrite(PosKey(pid,"STRATEGY"),GVRead(SymKey(sym,"PLAN_STRATEGY"),0));
      GVWrite(PosKey(pid,"MARKET_STATE"),GVRead(SymKey(sym,"PLAN_STATE"),0));
      GVWrite(PosKey(pid,"STRAT_DIR"),GVRead(SymKey(sym,"PLAN_DIR"),0));
      GVWrite(PosKey(pid,"STRAT_VOL"),GVRead(SymKey(sym,"PLAN_VOL"),1));
      GVWrite(PosKey(pid,"STRAT_SESSION"),GVRead(SymKey(sym,"PLAN_SESSION_HASH"),0));
   }
}

void FinalizeStrategyHistory()
{
   datetime now=TimeTradeServer();
   datetime from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-400);i<n;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(PositionIdStillOpenStrategy(pid) || GVRead(PosKey(pid,"STRAT_FINAL"),0)>0.5) continue;
      StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
      if(c==STRATEGY_NO_TRADE) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0);
      double realized=StrategyPositionRealized(pid);
      double R=(risk>0?realized/risk:0);
      string p=SysKey(StringFormat("STRAT_%d",(int)c));
      UpdateStrategyBucket(p,R);
      int state=(int)GVRead(PosKey(pid,"MARKET_STATE"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_STATE_%d",(int)c,state)),R);
      int dir=(int)GVRead(PosKey(pid,"STRAT_DIR"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_DIR_%d",(int)c,dir)),R);
      int vol=(int)GVRead(PosKey(pid,"STRAT_VOL"),1);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_VOL_%d",(int)c,vol)),R);
      GVWrite(PosKey(pid,"STRAT_FINAL"),1);
   }
}

bool StrategyExecutionTrigger(const TradeSetup &s,StrategyClass c)
{
   if(c==STRATEGY_COUNTER_TREND_SCALP || c==STRATEGY_COUNTER_TREND_SWING || c==STRATEGY_POTENTIAL_REVERSAL)
   {
      bool reject=M5RejectionAligned(s.symbol,s.bullish);
      bool bos=LowerTimeframeStructureBreak(s.symbol,s.bullish);
      bool sweep=LiquiditySweepAligned(s.symbol,s.bullish);
      return PriceInsideZone(s) && reject && bos && sweep;
   }
   if(c==STRATEGY_RANGE_TRADE || c==STRATEGY_MEAN_REVERSION)
      return PriceInsideZone(s) && M5RejectionAligned(s.symbol,s.bullish);
   if(c==STRATEGY_BREAKOUT)
   {
      // Direct breakout is a first-class execution path. It must never inherit
      // breakout-retest semantics from a legacy setup-kind value.
      if(s.kind!=SETUP_BREAKOUT) return false;
      return PriceInsideZone(s) && M5Trigger(s) && EMAImpulseAligned(s.symbol,s.bullish);
   }
   if(c==STRATEGY_BREAKOUT_RETEST)
   {
      if(s.kind!=SETUP_BREAKOUT_RETEST) return false;
      return PriceInsideZone(s) && M5Trigger(s);
   }
   return PriceInsideZone(s) && M5Trigger(s);
}

void SelectDynamicStrategy(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   ZeroMemory(d);
   d.strategy=STRATEGY_NO_TRADE; d.state=STATE_UNKNOWN; d.action=STRATEGY_ACTION_NO_TRADE;
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   d.state=x.state; d.regime=x.baseRegime; d.stateText=MarketStateName(x.state); d.session=x.session;

   int trendScore=StrategyBaseScore(x,STRATEGY_TREND_CONTINUATION);
   int retraceScore=StrategyBaseScore(x,STRATEGY_RETRACEMENT_ENTRY);
   int breakoutScore=StrategyBaseScore(x,STRATEGY_BREAKOUT);
   int brScore=StrategyBaseScore(x,STRATEGY_BREAKOUT_RETEST)+(br.valid?10:0);
   int reversalScore=StrategyBaseScore(x,STRATEGY_POTENTIAL_REVERSAL);
   int rangeScore=StrategyBaseScore(x,STRATEGY_RANGE_TRADE);
   int meanScore=StrategyBaseScore(x,STRATEGY_MEAN_REVERSION);
   bool counterBull=!x.dominantBull;
   int counterScore=CounterTrendScore(x,counterBull);
   d.counterTrendScore=counterScore;

   d.librarySummary=StringFormat("Library scores: trend %d | retracement %d | breakout %d | breakout-retest %d | reversal %d | range %d | mean-reversion %d | counter-trend %d",
                                  trendScore,retraceScore,breakoutScore,brScore,reversalScore,rangeScore,meanScore,counterScore);

   // Regime-driven selection. We intentionally do not force a setup when the regime and strategy disagree.
   if((x.state==STATE_REVERSAL || x.state==STATE_TREND_FAILURE) && reversalScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_POTENTIAL_REVERSAL; d.score=reversalScore; d.counterTrend=true;
      d.setup=BuildCounterTrendCandidate(x,counterBull,MathMax(reversalScore,counterScore),true);
   }
   else if((x.state==STATE_EXHAUSTION || x.state==STATE_FALSE_BREAKOUT || x.state==STATE_LIQUIDITY_SWEEP) &&
           InpAllowCounterTrendScalp && counterScore>=InpMinCounterTrendScore)
   {
      d.strategy=(InpAllowCounterTrendSwing && x.trendFailure?STRATEGY_COUNTER_TREND_SWING:STRATEGY_COUNTER_TREND_SCALP);
      d.score=counterScore; d.counterTrend=true;
      d.setup=BuildCounterTrendCandidate(x,counterBull,counterScore,d.strategy==STRATEGY_COUNTER_TREND_SWING);
   }
   else if((x.state==STATE_BREAKOUT || x.state==STATE_RANGE_EXPANSION || x.state==STATE_MOMENTUM_CONTINUATION) && breakoutScore>=InpMinStrategyScore)
   {
      d.strategy=(br.valid?STRATEGY_BREAKOUT_RETEST:STRATEGY_BREAKOUT); d.score=(br.valid?MathMax(brScore,breakoutScore):breakoutScore);
      d.setup=br;
      d.setup.name=StrategyClassName(d.strategy);
      if(d.strategy==STRATEGY_BREAKOUT && !br.valid)
      {
         d.setup.valid=false; // breakout identified, but do not chase it; wait for executable structure.
         d.setup.reason+=" | Breakout detected but entry is not authorized until a controlled retest/shallow execution structure appears.";
      }
   }
   else if((x.state==STATE_HEALTHY_RETRACEMENT || x.state==STATE_DEEP_RETRACEMENT || x.state==STATE_CORRECTION) && retraceScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_RETRACEMENT_ENTRY; d.score=retraceScore; d.setup=pb; d.setup.name=StrategyClassName(d.strategy);
   }
   else if((x.state==STATE_RANGE_REVERSAL || x.state==STATE_ACCUMULATION || x.state==STATE_DISTRIBUTION) && InpAllowRangeTrades && rangeScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_RANGE_TRADE; d.score=rangeScore; d.setup=BuildRangeCandidate(x,false);
   }
   else if((x.state==STATE_MEAN_REVERSION || x.state==STATE_CONSOLIDATION) && InpAllowMeanReversion && meanScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_MEAN_REVERSION; d.score=meanScore; d.setup=BuildRangeCandidate(x,true);
   }
   else if((x.state==STATE_TREND_CONTINUATION || x.state==STATE_MOMENTUM_CONTINUATION) && trendScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_TREND_CONTINUATION; d.score=trendScore; d.setup=(pb.valid?pb:br); d.setup.name=StrategyClassName(d.strategy);
   }
   else
   {
      d.strategy=STRATEGY_NO_TRADE; d.score=MathMax(MathMax(trendScore,retraceScore),MathMax(rangeScore,breakoutScore)); d.setup=(pb.confidence>=br.confidence?pb:br); d.setup.valid=false;
   }

   d.strategyName=StrategyClassName(d.strategy);
   d.counterTrend=(d.strategy==STRATEGY_COUNTER_TREND_SCALP || d.strategy==STRATEGY_COUNTER_TREND_SWING || d.strategy==STRATEGY_POTENTIAL_REVERSAL);
   d.rationale=StringFormat("State %s | regime %s | HTF bull %d/3 bear %d/3 | ADX %.1f | ATR %.2fx | OR %.2fx | overextension %.2f ATR | volume %.2fx. %s %s",
      d.stateText,x.baseRegime,x.bullVotes,x.bearVotes,x.adx,x.atrRatio,x.openingRangeRatio,x.overextensionATR,x.volumeRatio,
      FibRetracementText(x),SupplyDemandText(x));
   d.confirmation=(d.counterTrend?"Require liquidity rejection + M5 change of character/break of structure + rejection candle.":
                   (d.strategy==STRATEGY_RANGE_TRADE||d.strategy==STRATEGY_MEAN_REVERSION?"Require range-boundary rejection/reclaim; avoid mid-range entry.":
                    "Require price in zone plus strategy-aligned M5 confirmation; do not chase displacement."));
   d.counterargument=StringFormat("Opposing evidence: HTF opposite votes %d, trend strength ADX %.1f, false-break up/down %s/%s, exhaustion %s. Main risk is mistaking %s for a durable directional move.",
      x.dominantBull?x.bearVotes:x.bullVotes,x.adx,x.falseBreakUp?"YES":"NO",x.falseBreakDown?"YES":"NO",x.exhaustion?"YES":"NO",d.stateText);

   bool evidenceOK=StrategyEvidenceAllows(d.strategy,d.evidence);
   if(d.strategy==STRATEGY_NO_TRADE)
   {
      d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false;
   }
   else if(!evidenceOK)
   {
      d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false; d.rationale+=" | Historical/internal evidence gate rejected this strategy.";
   }
   else if(d.score<InpMinStrategyScore || !d.setup.valid)
   {
      d.action=STRATEGY_ACTION_WAIT;
   }
   else
   {
      d.action=STRATEGY_ACTION_HIGH_CONFIDENCE;
   }
   PersistStrategyCandidate(sym,d);
}

string StrategyDecisionHeader(const StrategyDecision &d)
{
   string action=(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE?"HIGH-CONFIDENCE TRADE SETUP":d.action==STRATEGY_ACTION_WAIT?"WAIT FOR CONFIRMATION":"NO TRADE");
   string ct=d.counterTrend?"\n⚠️ COUNTER-TREND TRADE — stricter confirmation and conservative targets apply.":"";
   return "━━━━━━━━━━━━━━━━━━━━\n🧠 STRATEGY INTELLIGENCE\n━━━━━━━━━━━━━━━━━━━━\n"
          "Classification: "+d.strategyName+"\n"
          "Market state: "+d.stateText+"\n"
          "Regime: "+d.regime+"\n"
          "Session: "+d.session+"\n"
          "Decision: "+action+ct+"\n"
          "Strategy score: "+IntegerToString(d.score)+"/100\n"
          "Counter-trend score: "+IntegerToString(d.counterTrendScore)+"/100\n"
          +d.librarySummary+"\n"+d.evidence+"\n";
}

bool RevalidateStrategyIdentity(const TradeSetup &stored,string &why)
{
   TradeSetup pb=BuildPullback(stored.symbol,stored.bullish,stored.confidence,"");
   TradeSetup br=BuildBreakoutRetest(stored.symbol,stored.bullish,stored.confidence,"");
   StrategyDecision d; SelectDynamicStrategy(stored.symbol,pb,br,d);
   StrategyClass expected=(StrategyClass)(int)GVRead(SymKey(stored.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(d.strategy==STRATEGY_NO_TRADE || d.action==STRATEGY_ACTION_NO_TRADE)
   { why="Strategy engine now classifies the market as NO TRADE."; return false; }
   if(d.setup.bullish!=stored.bullish)
   { why="Strategy engine direction changed during revalidation."; return false; }
   if(expected!=STRATEGY_NO_TRADE && d.strategy!=expected)
   { why="Strategy classification changed from "+StrategyClassName(expected)+" to "+StrategyClassName(d.strategy)+"."; return false; }
   why="Strategy identity remains valid: "+d.strategyName+" / "+d.stateText+".";
   return true;
}

void StrategyIntelligenceInit()
{
   AttachStrategyMetadataToOpenPositions();
   FinalizeStrategyHistory();
}

void StrategyIntelligenceTimer()
{
   AttachStrategyMetadataToOpenPositions();
   FinalizeStrategyHistory();
}
