// ============================================================================
// GPT_EA Part 21 - Research validation, context evidence and retracement logic
// ============================================================================

input bool   InpUseContextualEvidenceGate       = true;
input int    InpContextEvidenceMinTrades        = 8;
input double InpContextEvidenceMinProfitFactor  = 0.90;
input double InpContextEvidenceMinAverageR      = -0.05;
input bool   InpUseWalkForwardValidation        = true;
input int    InpWalkForwardMinTrades            = 12;
input double InpWalkForwardRecentFraction       = 0.35;
input double InpWalkForwardMinRecentPF          = 0.90;
input double InpWalkForwardMinRecentAverageR    = -0.05;
input bool   InpBlockNegativeWalkForward        = true;
input double InpChaseOverextensionATR           = 1.25;
input bool   InpBlockExtremeRegimes             = true;
input double InpExtremeATRRatioHigh             = 2.50;
input double InpExtremeATRRatioLow              = 0.35;
input double InpExtremeOpeningRangeRatio        = 3.00;

void StrategyBucketMetrics(const string key,double &n,double &wr,double &avg,double &pf,double &dd,double &maxLosses)
{
   n=GVRead(key+"_N",0);
   double wins=GVRead(key+"_WIN",0),sum=GVRead(key+"_SUMR",0);
   double pos=GVRead(key+"_POSR",0),neg=GVRead(key+"_NEGR",0);
   dd=GVRead(key+"_MAXDD",0); maxLosses=GVRead(key+"_MAXLOSSRUN",0);
   wr=(n>0?wins/n*100.0:0.0);
   avg=(n>0?sum/n:0.0);
   pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
}

bool ContextBucketAllows(const string key,const string label,string &line)
{
   double n=0,wr=0,avg=0,pf=0,dd=0,ml=0;
   StrategyBucketMetrics(key,n,wr,avg,pf,dd,ml);
   line=StringFormat("%s N %.0f | win %.1f%% | avg %.2fR | PF %.2f | DD %.2fR | maxL %.0f",label,n,wr,avg,pf,dd,ml);
   if(!InpUseContextualEvidenceGate || n<InpContextEvidenceMinTrades)
   {
      line+=(n<InpContextEvidenceMinTrades?" | developing sample":" | informational only");
      return true;
   }
   bool ok=(avg>=InpContextEvidenceMinAverageR && pf>=InpContextEvidenceMinProfitFactor);
   line+=(ok?" | PASS":" | BLOCK: negative current-context evidence");
   return ok;
}

string CurrentStrategyContextEvidence(const string sym,StrategyClass c,bool directionBull,bool &allows)
{
   allows=true;
   if(c==STRATEGY_NO_TRADE) return "Context evidence: no executable strategy.";
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   int cls=(int)c;
   int dir=(directionBull?1:0);
   int vol=(x.atrRatio>=1.35?2:(x.atrRatio<=0.75?0:1));
   int ses=StrategySessionCode(x.session);
   int news=(HighImpactEventWithin(sym,InpStrategyNewsContextMinutes)?1:0);
   string a="",b="",d="",e="",f="";
   bool okDir=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_DIR_%d",cls,dir)),directionBull?"LONG":"SHORT",a);
   bool okVol=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_VOL_%d",cls,vol)),vol==2?"HIGH-VOL":vol==0?"LOW-VOL":"NORMAL-VOL",b);
   bool okSes=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_SESSION_%d",cls,ses)),"SESSION "+x.session,d);
   bool okTF=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_TF_%d_%d",cls,15,5)),"TF M15/M5",e);
   bool okNews=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_NEWS_%d",cls,news)),news?"NEAR-HIGH-IMPACT":"NO-NEAR-HIGH-IMPACT",f);
   allows=(okDir && okVol && okSes && okTF && okNews);
   return "Context evidence: "+a+" | "+b+" | "+d+" | "+e+" | "+f;
}

void RSegmentStats(double &arr[],int from,int to,double &avg,double &pf)
{
   avg=0; pf=0;
   if(from<0) from=0;
   if(to>ArraySize(arr)) to=ArraySize(arr);
   int n=to-from; if(n<=0) return;
   double pos=0,neg=0,sum=0;
   for(int i=from;i<to;i++)
   {
      double r=arr[i]; sum+=r;
      if(r>0) pos+=r; else if(r<0) neg+=-r;
   }
   avg=sum/n;
   pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
}

bool StrategyWalkForwardEvidence(StrategyClass c,string &detail)
{
   detail="Walk-forward: disabled.";
   if(!InpUseWalkForwardValidation || c==STRATEGY_NO_TRADE) return true;
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)){ detail="Walk-forward: history unavailable; neutral."; return true; }

   ulong pids[]; datetime closes[];
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_OUT_BY && en!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      datetime tm=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      int at=-1;
      for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ at=j; break; }
      if(at<0)
      {
         int n=ArraySize(pids); ArrayResize(pids,n+1); ArrayResize(closes,n+1);
         pids[n]=pid; closes[n]=tm;
      }
      else if(tm>closes[at]) closes[at]=tm;
   }

   double rs[]; datetime ts[];
   for(int i=0;i<ArraySize(pids);i++)
   {
      double risk=GVRead(PosKey(pids[i],"RISK"),0); if(risk<=0) continue;
      double r=StrategyPositionRealized(pids[i])/risk;
      int n=ArraySize(rs); ArrayResize(rs,n+1); ArrayResize(ts,n+1);
      rs[n]=r; ts[n]=closes[i];
   }
   int n=ArraySize(rs);
   if(n<InpWalkForwardMinTrades)
   {
      detail=StringFormat("Walk-forward: N %d below minimum %d; developing sample, not proof of edge.",n,InpWalkForwardMinTrades);
      return true;
   }

   for(int i=0;i<n-1;i++) for(int j=i+1;j<n;j++) if(ts[j]<ts[i])
   {
      datetime tt=ts[i]; ts[i]=ts[j]; ts[j]=tt;
      double rr=rs[i]; rs[i]=rs[j]; rs[j]=rr;
   }
   double frac=MathMax(0.20,MathMin(0.50,InpWalkForwardRecentFraction));
   int recentN=(int)MathRound(n*frac); if(recentN<3) recentN=3; if(recentN>=n) recentN=n-1;
   int split=n-recentN;
   double trainAvg=0,trainPF=0,recentAvg=0,recentPF=0;
   RSegmentStats(rs,0,split,trainAvg,trainPF);
   RSegmentStats(rs,split,n,recentAvg,recentPF);
   bool recentOK=(recentAvg>=InpWalkForwardMinRecentAverageR && recentPF>=InpWalkForwardMinRecentPF);
   bool drift=(trainAvg>0 && trainPF>=1.0 && (recentAvg<0 || recentPF<1.0));
   detail=StringFormat("Walk-forward N %d | train N %d avg %.2fR PF %.2f | recent N %d avg %.2fR PF %.2f | drift %s",
                       n,split,trainAvg,trainPF,recentN,recentAvg,recentPF,drift?"YES":"NO");
   if(InpBlockNegativeWalkForward && !recentOK)
   {
      detail+=" | BLOCK: recent out-of-sample segment below configured thresholds.";
      return false;
   }
   detail+=" | PASS; historical results remain non-guaranteed evidence.";
   return true;
}

bool RecentMoveImpulsiveAgainstTrend(const StrategySnapshot &x,double &netATR,double &bodyATR,int &directionalBars)
{
   netATR=0; bodyATR=0; directionalBars=0;
   if(x.atr<=0) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(x.symbol,PERIOD_M15,1,4,r)<3) return false;
   double start=r[2].open,end=r[0].close;
   netATR=MathAbs(end-start)/x.atr;
   for(int i=0;i<3;i++)
   {
      bodyATR+=MathAbs(r[i].close-r[i].open)/x.atr;
      bool against=(x.dominantBull?r[i].close<r[i].open:r[i].close>r[i].open);
      if(against) directionalBars++;
   }
   bool directionAgainst=(x.dominantBull?end<start:end>start);
   return (directionAgainst && netATR>=1.10 && bodyATR>=1.35 && directionalBars>=2 && x.volumeRatio>=1.05);
}

void ConsiderRetracementDestination(const StrategySnapshot &x,double v,const string label,double &best,string &bestLabel)
{
   if(v<=0 || x.atr<=0) return;
   if(x.dominantBull)
   {
      if(v>x.mid+0.10*x.atr) return;
      if(best<=0 || v>best){ best=v; bestLabel=label; }
   }
   else
   {
      if(v<x.mid-0.10*x.atr) return;
      if(best<=0 || v<best){ best=v; bestLabel=label; }
   }
}

string RetracementDestinationText(const StrategySnapshot &x)
{
   double best=0; string label="";
   double w=x.priorHigh-x.priorLow;
   double f382=0,f618=0;
   if(w>0)
   {
      f382=(x.dominantBull?x.priorHigh-0.382*w:x.priorLow+0.382*w);
      f618=(x.dominantBull?x.priorHigh-0.618*w:x.priorLow+0.618*w);
   }
   ConsiderRetracementDestination(x,x.ema20,"EMA20 / dynamic value",best,label);
   ConsiderRetracementDestination(x,x.ema50,"EMA50 / deep value",best,label);
   ConsiderRetracementDestination(x,IntradayVWAP(x.symbol),"rolling VWAP",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.priorLow:x.priorHigh,"prior swing structure",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.previousDayLow:x.previousDayHigh,"previous-day structure",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.asianLow:x.asianHigh,"Asian-session liquidity",best,label);
   ConsiderRetracementDestination(x,f382,"38.2% retracement",best,label);
   ConsiderRetracementDestination(x,f618,"61.8% retracement",best,label);
   if(best<=0) return "Likely retracement destination: no clean nearby value level; wait for structure rather than guessing.";
   return StringFormat("Likely retracement destination: %s around %.*f, subject to fresh structure/liquidity confirmation.",label,DigitsFor(x.symbol),best);
}

bool ChaseRiskDetected(const StrategySnapshot &x)
{
   bool stretched=(MathAbs(x.overextensionATR)>=InpChaseOverextensionATR);
   bool stretchedWithTrend=(x.dominantBull?x.overextensionATR>0:x.overextensionATR<0);
   return stretched && stretchedWithTrend &&
          (x.state==STATE_TREND_CONTINUATION || x.state==STATE_MOMENTUM_CONTINUATION || x.state==STATE_BREAKOUT || x.state==STATE_RANGE_EXPANSION);
}

string RetracementIntelligenceText(const StrategySnapshot &x)
{
   double net=0,bodies=0; int bars=0;
   bool impulsive=RecentMoveImpulsiveAgainstTrend(x,net,bodies,bars);
   bool intact=!x.trendFailure;
   int ct=CounterTrendScore(x,!x.dominantBull);
   string reversal=(x.dominantBull?
      StringFormat("A genuine bearish reversal requires acceptance below key swing support near %.*f plus sustained opposite M15/M5 structure/CHOCH.",DigitsFor(x.symbol),x.priorLow):
      StringFormat("A genuine bullish reversal requires acceptance above key swing resistance near %.*f plus sustained opposite M15/M5 structure/CHOCH.",DigitsFor(x.symbol),x.priorHigh));
   string counter=(ct>=InpMinCounterTrendScore?"A short-term counter-trend opportunity is conditionally present, but still requires the strict sweep + BOS/CHOCH + rejection trigger.":"Counter-trend evidence is below the strict threshold; do not trade the correction merely because it moves against trend.");
   return StringFormat("Retracement intelligence: current against-trend move is %s (net %.2f ATR, bodies %.2f ATR, directional bars %d/3); HTF thesis intact=%s. %s Chase risk=%s. Waiting for value generally improves structural R:R when chase risk is present. %s %s",
      impulsive?"IMPULSIVE / possible trend-failure pressure":"CORRECTIVE / non-impulsive",net,bodies,bars,intact?"YES":"NO",
      RetracementDestinationText(x),ChaseRiskDetected(x)?"YES":"NO",counter,reversal);
}

bool ExtremeRegimeDetected(const StrategySnapshot &x,string &why)
{
   why="";
   if(!InpBlockExtremeRegimes) return false;
   if(x.atrRatio>=InpExtremeATRRatioHigh)
      why=StringFormat("ATR regime %.2fx exceeds extreme high threshold %.2fx.",x.atrRatio,InpExtremeATRRatioHigh);
   else if(x.atrRatio<=InpExtremeATRRatioLow)
      why=StringFormat("ATR regime %.2fx is below extreme low threshold %.2fx.",x.atrRatio,InpExtremeATRRatioLow);
   else if(x.openingRangeRatio>=InpExtremeOpeningRangeRatio)
      why=StringFormat("Opening range %.2fx ATR exceeds extreme threshold %.2fx.",x.openingRangeRatio,InpExtremeOpeningRangeRatio);
   return (why!="");
}

bool StrategyResearchEvidenceAllows(const string sym,StrategyClass c,bool bull,string &detail)
{
   string aggregate=""; bool baseOK=StrategyEvidenceAllows(c,aggregate);
   bool contextOK=true; string context=CurrentStrategyContextEvidence(sym,c,bull,contextOK);
   string wf=""; bool wfOK=StrategyWalkForwardEvidence(c,wf);
   detail=aggregate+" | "+context+" | "+wf;
   return (baseOK && contextOK && wfOK);
}

void SelectDynamicStrategyResearch(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyComplete(sym,pb,br,d);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   d.rationale+=" | "+RetracementIntelligenceText(x);

   string extreme="";
   if(ExtremeRegimeDetected(x,extreme))
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Extreme/out-of-distribution regime guard BLOCK: "+extreme;
   }

   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      string research="";
      bool researchOK=StrategyResearchEvidenceAllows(sym,d.strategy,d.setup.bullish,research);
      d.evidence=research;
      if(!researchOK)
      {
         d.action=STRATEGY_ACTION_NO_TRADE;
         d.setup.valid=false;
         d.rationale+=" | Research validation gate BLOCKED the strategy in its current evidence/context segment.";
      }
      else if(ChaseRiskDetected(x) &&
              (d.strategy==STRATEGY_TREND_CONTINUATION || d.strategy==STRATEGY_BREAKOUT) &&
              d.action==STRATEGY_ACTION_HIGH_CONFIDENCE)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=" | Chase filter: trend direction may remain valid, but entry is overextended. WAIT for retracement/retest rather than chase.";
      }
   }
   PersistStrategyCandidate(sym,d);
}
