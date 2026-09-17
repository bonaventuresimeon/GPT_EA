// ============================================================================
// GPT_EA Part 32 - Champion/challenger shadow validation and counterfactuals
// ============================================================================

input bool   InpUseChampionChallenger             = true;
input bool   InpAutoPromoteChallenger             = false; // conservative default: research recommendation only
input int    InpChampionChallengerMinSamples      = 30;
input double InpChallengerMinAvgRAdvantage        = 0.10;
input double InpChallengerMinPFAdvantage          = 0.15;
input double InpChallengerMaxExtraDrawdownR       = 0.25;
input double InpChallengerMaxInstabilityR         = 1.50;
input bool   InpUsePromotionSignificance          = true;
input double InpPromotionSignificanceZ            = 1.64; // conservative one-sided ~95% lower bound
input double InpPromotionMinLowerAdvantageR       = 0.02;
input bool   InpUsePromotionProbationRollback     = true;
input int    InpPromotionProbationTrades          = 15;
input int    InpPromotionRollbackMinTrades        = 5;
input double InpPromotionRollbackMinAvgR          = 0.00;
input double InpPromotionRollbackMinPF            = 1.00;
input double InpPromotionRollbackMaxExtraDDR      = 0.50;
input int    InpRollbackRequalifyNewSamples       = 20;
input int    InpShadowMaxExpiryM15                = 12;
input string InpShadowValidationFile              = "GPT_EA_ShadowValidation.csv";
input bool   InpTrackRejectedCounterfactuals      = true;

enum ShadowVariant
{
   SHADOW_CHAMPION=0,
   SHADOW_PULLBACK=1,
   SHADOW_BREAKOUT_RETEST=2,
   SHADOW_REJECTED_COUNTERFACTUAL=3
};

string ShadowVariantName(int v)
{
   if(v==SHADOW_PULLBACK) return "CHALLENGER_PULLBACK";
   if(v==SHADOW_BREAKOUT_RETEST) return "CHALLENGER_BREAKOUT_RETEST";
   if(v==SHADOW_REJECTED_COUNTERFACTUAL) return "REJECTED_COUNTERFACTUAL";
   return "CHAMPION";
}

string ShadowKey(const string sym,int variant,const string suffix)
{
   return SymKey(sym,StringFormat("SHADOW_V%d_%s",variant,suffix));
}

string ShadowStatsKey(StrategyClass c,int variant)
{
   return SysKey(StringFormat("CC_STRAT_%d_V%d",(int)c,variant));
}

bool ShadowGeometryUsable(const TradeSetup &s)
{
   if(s.symbol=="" || s.preferred<=0 || s.sl<=0) return false;
   if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1)) return false;
   if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1)) return false;
   return true;
}

void EnsureShadowValidationHeader()
{
   if(!InpUseChampionChallenger) return;
   bool exists=FileIsExist(InpShadowValidationFile,FILE_COMMON);
   int h=FileOpen(InpShadowValidationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","symbol","strategy","variant","side","entry","sl","tp2","expiry_m15","outcome_r","mae_r","mfe_r","reason");
   FileClose(h);
}

void WriteShadowRow(const string eventName,const string sym,StrategyClass c,int variant,bool bull,double entry,double sl,double tp2,int expiry,double outcome,double mae,double mfe,const string reason)
{
   if(!InpUseChampionChallenger) return;
   EnsureShadowValidationHeader();
   int h=FileOpen(InpShadowValidationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"shadow_validation_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,sym,StrategyClassName(c),ShadowVariantName(variant),bull?"BUY":"SELL",
      DoubleToString(entry,DigitsFor(sym)),DoubleToString(sl,DigitsFor(sym)),DoubleToString(tp2,DigitsFor(sym)),expiry,
      DoubleToString(outcome,3),DoubleToString(mae,3),DoubleToString(mfe,3),reason);
   FileFlush(h); FileClose(h);
}

bool ShadowVariantActive(const string sym,int variant)
{
   return GVRead(ShadowKey(sym,variant,"ACTIVE"),0)>0.5;
}

void RegisterShadowTrade(const TradeSetup &s,StrategyClass c,int variant,const string reason)
{
   if(!InpUseChampionChallenger || !ShadowGeometryUsable(s) || c==STRATEGY_NO_TRADE) return;
   if(ShadowVariantActive(s.symbol,variant)) return;
   double R=MathAbs(s.preferred-s.sl); if(R<=PointFor(s.symbol)) return;
   GVWrite(ShadowKey(s.symbol,variant,"ACTIVE"),1);
   GVWrite(ShadowKey(s.symbol,variant,"STRATEGY"),(int)c);
   GVWrite(ShadowKey(s.symbol,variant,"BULL"),s.bullish?1:0);
   GVWrite(ShadowKey(s.symbol,variant,"ENTRY"),s.preferred);
   GVWrite(ShadowKey(s.symbol,variant,"SL"),s.sl);
   GVWrite(ShadowKey(s.symbol,variant,"TP1"),s.tp1);
   GVWrite(ShadowKey(s.symbol,variant,"TP2"),s.tp2);
   GVWrite(ShadowKey(s.symbol,variant,"TP3"),s.tp3);
   GVWrite(ShadowKey(s.symbol,variant,"START"),(double)TimeTradeServer());
   GVWrite(ShadowKey(s.symbol,variant,"EXP"),MathMax(1,MathMin(InpShadowMaxExpiryM15,s.expiryM15)));
   GVWrite(ShadowKey(s.symbol,variant,"MAE"),0);
   GVWrite(ShadowKey(s.symbol,variant,"MFE"),0);
   GVWrite(ShadowKey(s.symbol,variant,"LASTBAR"),0);
   WriteShadowRow("OPEN",s.symbol,c,variant,s.bullish,s.preferred,s.sl,s.tp2,s.expiryM15,0,0,0,reason);
}

void UpdateShadowStability(const string key,double outcome)
{
   double ew=GVRead(key+"_EWMA",0);
   double newE=EWMA(ew,outcome,0.20);
   double dev=MathAbs(outcome-newE);
   GVWrite(key+"_EWMA",newE);
   GVWrite(key+"_DEV",EWMA(GVRead(key+"_DEV",0),dev,0.20));
}

void FinalizeShadowTrade(const string sym,int variant,double outcome,const string reason)
{
   if(!ShadowVariantActive(sym,variant)) return;
   StrategyClass c=(StrategyClass)(int)GVRead(ShadowKey(sym,variant,"STRATEGY"),0);
   bool bull=GVRead(ShadowKey(sym,variant,"BULL"),0)>0.5;
   double entry=GVRead(ShadowKey(sym,variant,"ENTRY"),0),sl=GVRead(ShadowKey(sym,variant,"SL"),0),tp2=GVRead(ShadowKey(sym,variant,"TP2"),0);
   int exp=(int)GVRead(ShadowKey(sym,variant,"EXP"),0);
   double mae=GVRead(ShadowKey(sym,variant,"MAE"),0),mfe=GVRead(ShadowKey(sym,variant,"MFE"),0);
   string key=ShadowStatsKey(c,variant);
   UpdateStrategyBucket(key,outcome);
   UpdateShadowStability(key,outcome);
   WriteShadowRow("CLOSED",sym,c,variant,bull,entry,sl,tp2,exp,outcome,mae,mfe,reason);
   GVWrite(ShadowKey(sym,variant,"ACTIVE"),0);
}

void UpdateOneShadowTrade(const string sym,int variant)
{
   if(!ShadowVariantActive(sym,variant) || !EnsureSymbol(sym)) return;
   bool bull=GVRead(ShadowKey(sym,variant,"BULL"),0)>0.5;
   double entry=GVRead(ShadowKey(sym,variant,"ENTRY"),0),sl=GVRead(ShadowKey(sym,variant,"SL"),0),tp2=GVRead(ShadowKey(sym,variant,"TP2"),0);
   datetime start=(datetime)GVRead(ShadowKey(sym,variant,"START"),0);
   int expiry=(int)GVRead(ShadowKey(sym,variant,"EXP"),4);
   double R=MathAbs(entry-sl); if(R<=0){ FinalizeShadowTrade(sym,variant,0,"invalid shadow geometry"); return; }

   MqlTick t={}; if(!GetTickSafe(sym,t)) return;
   double px=(bull?t.bid:t.ask);
   double rNow=(bull?px-entry:entry-px)/R;
   if(rNow>GVRead(ShadowKey(sym,variant,"MFE"),0)) GVWrite(ShadowKey(sym,variant,"MFE"),rNow);
   double mae=MathMax(0.0,-rNow); if(mae>GVRead(ShadowKey(sym,variant,"MAE"),0)) GVWrite(ShadowKey(sym,variant,"MAE"),mae);

   // Use the most recently closed M5 bar to catch target/stop touches between timer cycles.
   MqlRates b[]; ArraySetAsSeries(b,true);
   bool stopHit=false,targetHit=false;
   if(CopyRates(sym,PERIOD_M5,1,1,b)>=1)
   {
      stopHit=(bull?b[0].low<=sl:b[0].high>=sl);
      targetHit=(bull?b[0].high>=tp2:b[0].low<=tp2);
   }
   if(stopHit && targetHit)
   {
      // Conservative ambiguity rule prevents optimistic shadow statistics.
      FinalizeShadowTrade(sym,variant,-1.0,"same-bar stop/TP2 ambiguity; conservative stop outcome");
      return;
   }
   if(stopHit || (bull?px<=sl:px>=sl)){ FinalizeShadowTrade(sym,variant,-1.0,"shadow stop reached"); return; }
   if(targetHit || (bull?px>=tp2:px<=tp2))
   {
      double targetR=MathAbs(tp2-entry)/R;
      FinalizeShadowTrade(sym,variant,targetR,"shadow TP2 reached"); return;
   }
   if(start>0 && BarsSince(sym,PERIOD_M15,start)>=expiry)
   {
      FinalizeShadowTrade(sym,variant,MathMax(-1.0,MathMin(2.5,rNow)),"shadow candle expiry mark-to-market");
      return;
   }
}

void ChampionChallengerMetrics(StrategyClass c,int variant,double &n,double &avg,double &pf,double &dd,double &dev)
{
   double wr=0,ml=0; string k=ShadowStatsKey(c,variant);
   StrategyBucketMetrics(k,n,wr,avg,pf,dd,ml);
   dev=GVRead(k+"_DEV",0);
}

bool ChallengerRollbackCooldownAllows(StrategyClass c,int variant,string &why)
{
   double rollbackN=GVRead(SysKey(StringFormat("CC_ROLLBACK_N_%d_V%d",(int)c,variant)),0);
   if(rollbackN<=0){ why="no rollback cooldown"; return true; }
   double n=0,a=0,pf=0,dd=0,dev=0;
   ChampionChallengerMetrics(c,variant,n,a,pf,dd,dev);
   double added=n-rollbackN;
   if(added<MathMax(1,InpRollbackRequalifyNewSamples))
   {
      why=StringFormat("rollback cooldown: %.0f/%d new shadow samples",added,InpRollbackRequalifyNewSamples);
      return false;
   }
   why=StringFormat("rollback cooldown cleared after %.0f new samples",added);
   return true;
}

bool ChallengerSignificanceAllows(StrategyClass c,int variant,string &why)
{
   why="";
   if(!InpUsePromotionSignificance){ why="statistical significance gate disabled"; return true; }
   double cn=0,ca=0,cp=0,cdd=0,cdev=0,nn=0,na=0,np=0,ndd=0,ndev=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cdev);
   ChampionChallengerMetrics(c,variant,nn,na,np,ndd,ndev);
   if(cn<2 || nn<2){ why="insufficient sample for significance"; return false; }

   // DEV is an EWMA absolute deviation. Multiplying by 1.253 approximates
   // sigma from mean absolute deviation and intentionally errs conservatively.
   double cs=MathMax(0.05,cdev*1.253);
   double ns=MathMax(0.05,ndev*1.253);
   double se=MathSqrt(cs*cs/cn+ns*ns/nn);
   double advantage=na-ca;
   double lower=advantage-MathMax(0.0,InpPromotionSignificanceZ)*se;
   why=StringFormat("promotion significance: advantage %.3fR | SE %.3f | lower bound %.3fR vs %.3fR",
                    advantage,se,lower,InpPromotionMinLowerAdvantageR);
   return lower>=InpPromotionMinLowerAdvantageR;
}

void CapturePromotionProbationBaseline(StrategyClass c,int variant)
{
   string k=ShadowStatsKey(c,variant);
   string p=SysKey(StringFormat("CC_PROB_%d_V%d",(int)c,variant));
   GVWrite(p+"_N",GVRead(k+"_N",0));
   GVWrite(p+"_SUMR",GVRead(k+"_SUMR",0));
   GVWrite(p+"_POSR",GVRead(k+"_POSR",0));
   GVWrite(p+"_NEGR",GVRead(k+"_NEGR",0));
   GVWrite(p+"_MAXDD",GVRead(k+"_MAXDD",0));
   GVWrite(p+"_TIME",(double)TimeTradeServer());
   GVWrite(p+"_PASSED",0);
}

bool PromotionProbationShouldRollback(StrategyClass c,int variant,string &why)
{
   why="";
   if(!InpUsePromotionProbationRollback || variant==SHADOW_CHAMPION) return false;
   string k=ShadowStatsKey(c,variant);
   string p=SysKey(StringFormat("CC_PROB_%d_V%d",(int)c,variant));
   double baseN=GVRead(p+"_N",-1);
   if(baseN<0){ CapturePromotionProbationBaseline(c,variant); why="probation baseline initialized"; return false; }

   double n=GVRead(k+"_N",0);
   double postN=n-baseN;
   if(postN<MathMax(1,InpPromotionRollbackMinTrades))
   {
      why=StringFormat("promotion probation %.0f/%d minimum review trades",postN,InpPromotionRollbackMinTrades);
      return false;
   }

   double sum=GVRead(k+"_SUMR",0)-GVRead(p+"_SUMR",0);
   double pos=GVRead(k+"_POSR",0)-GVRead(p+"_POSR",0);
   double neg=GVRead(k+"_NEGR",0)-GVRead(p+"_NEGR",0);
   double avg=(postN>0?sum/postN:0);
   double pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
   double ddNow=GVRead(k+"_MAXDD",0),ddBase=GVRead(p+"_MAXDD",0);
   bool bad=(avg<InpPromotionRollbackMinAvgR ||
             pf<InpPromotionRollbackMinPF ||
             ddNow>ddBase+InpPromotionRollbackMaxExtraDDR);
   why=StringFormat("promotion probation N %.0f | avg %.2fR | PF %.2f | DD %.2f vs base %.2f",
                    postN,avg,pf,ddNow,ddBase);
   if(bad) return true;
   if(postN>=MathMax(InpPromotionRollbackMinTrades,InpPromotionProbationTrades))
      GVWrite(p+"_PASSED",1);
   return false;
}

void EvaluateChampionRollback(StrategyClass c)
{
   if(!InpUseChampionChallenger || !InpAutoPromoteChallenger || !InpUsePromotionProbationRollback) return;
   string promotedKey=SysKey(StringFormat("CC_PROMOTED_%d",(int)c));
   int current=(int)GVRead(promotedKey,SHADOW_CHAMPION);
   if(current==SHADOW_CHAMPION) return;
   string why="";
   if(PromotionProbationShouldRollback(c,current,why))
   {
      double n=0,a=0,pf=0,dd=0,dev=0;
      ChampionChallengerMetrics(c,current,n,a,pf,dd,dev);
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_N_%d_V%d",(int)c,current)),n);
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_TIME_%d",(int)c)),(double)TimeTradeServer());
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_VARIANT_%d",(int)c)),current);
      GVWrite(promotedKey,SHADOW_CHAMPION);
      Print("GPT_EA champion rollback: ",StrategyClassName(c)," ",ShadowVariantName(current)," -> CHAMPION | ",why);
   }
}

bool ChallengerEligibleForPromotion(StrategyClass c,int variant,string &why)
{
   why="";
   if(variant!=SHADOW_PULLBACK && variant!=SHADOW_BREAKOUT_RETEST) return false;
   string cooldown="";
   if(!ChallengerRollbackCooldownAllows(c,variant,cooldown)){ why=cooldown; return false; }
   double cn=0,ca=0,cp=0,cdd=0,cdev=0,nn=0,na=0,np=0,ndd=0,ndev=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cdev);
   ChampionChallengerMetrics(c,variant,nn,na,np,ndd,ndev);
   if(cn<InpChampionChallengerMinSamples || nn<InpChampionChallengerMinSamples)
   {
      why=StringFormat("developing shadow sample champion %.0f / challenger %.0f; minimum %d",cn,nn,InpChampionChallengerMinSamples);
      return false;
   }
   bool avgOK=(na>=ca+InpChallengerMinAvgRAdvantage);
   bool pfOK=(np>=cp+InpChallengerMinPFAdvantage);
   bool ddOK=(ndd<=cdd+InpChallengerMaxExtraDrawdownR);
   bool stable=(ndev<=InpChallengerMaxInstabilityR);
   string sig="";
   bool significant=ChallengerSignificanceAllows(c,variant,sig);
   why=StringFormat("champ avg %.2f PF %.2f DD %.2f dev %.2f | challenger %s avg %.2f PF %.2f DD %.2f dev %.2f | %s | %s",
      ca,cp,cdd,cdev,ShadowVariantName(variant),na,np,ndd,ndev,sig,cooldown);
   return avgOK && pfOK && ddOK && stable && significant;
}

int PromotedChallengerVariant(StrategyClass c)
{
   return (int)GVRead(SysKey(StringFormat("CC_PROMOTED_%d",(int)c)),SHADOW_CHAMPION);
}

void RefreshChampionChallengerPromotion()
{
   if(!InpUseChampionChallenger) return;
   for(int ci=1;ci<=9;ci++)
   {
      StrategyClass c=(StrategyClass)ci;
      EvaluateChampionRollback(c);
      int current=(int)GVRead(SysKey(StringFormat("CC_PROMOTED_%d",ci)),SHADOW_CHAMPION);
      string p="",b="";
      bool pb=ChallengerEligibleForPromotion(c,SHADOW_PULLBACK,p);
      bool br=ChallengerEligibleForPromotion(c,SHADOW_BREAKOUT_RETEST,b);
      int chosen=SHADOW_CHAMPION;
      if(pb && br)
      {
         double n1=0,a1=0,pf1=0,d1=0,v1=0,n2=0,a2=0,pf2=0,d2=0,v2=0;
         ChampionChallengerMetrics(c,SHADOW_PULLBACK,n1,a1,pf1,d1,v1);
         ChampionChallengerMetrics(c,SHADOW_BREAKOUT_RETEST,n2,a2,pf2,d2,v2);
         chosen=(a2>a1?SHADOW_BREAKOUT_RETEST:SHADOW_PULLBACK);
      }
      else if(pb) chosen=SHADOW_PULLBACK;
      else if(br) chosen=SHADOW_BREAKOUT_RETEST;
      if(!InpAutoPromoteChallenger) chosen=SHADOW_CHAMPION;
      if(chosen!=current && chosen!=SHADOW_CHAMPION)
      {
         CapturePromotionProbationBaseline(c,chosen);
         GVWrite(SysKey(StringFormat("CC_PREVIOUS_%d",ci)),current);
         GVWrite(SysKey(StringFormat("CC_PROMOTION_TIME_%d",ci)),(double)TimeTradeServer());
      }
      // A rollback performed above is not immediately undone unless the
      // challenger has cleared its requalification sample cooldown.
      GVWrite(SysKey(StringFormat("CC_PROMOTED_%d",ci)),chosen);
      GVWrite(SysKey(StringFormat("CC_PB_ELIGIBLE_%d",ci)),pb?1:0);
      GVWrite(SysKey(StringFormat("CC_BRT_ELIGIBLE_%d",ci)),br?1:0);
   }
}

void ApplyChampionChallengerSelection(TradeSetup &primary,const TradeSetup &pb,const TradeSetup &br,StrategyDecision &d,string &note)
{
   note="Champion selector retained.";
   if(!InpUseChampionChallenger || !InpAutoPromoteChallenger || d.strategy==STRATEGY_NO_TRADE) return;
   int v=PromotedChallengerVariant(d.strategy);
   if(v==SHADOW_PULLBACK && ShadowGeometryUsable(pb) && pb.valid)
   {
      primary=pb; d.setup=pb; note="Promoted pullback challenger selected after shadow validation."; return;
   }
   if(v==SHADOW_BREAKOUT_RETEST && ShadowGeometryUsable(br) && br.valid)
   {
      primary=br; d.setup=br; note="Promoted breakout-retest challenger selected after shadow validation."; return;
   }
}

void ChampionChallengerScanHook(const TradeSetup &primary,const TradeSetup &pb,const TradeSetup &br,const StrategyDecision &d,bool liveReady,const string reason)
{
   if(!InpUseChampionChallenger || d.strategy==STRATEGY_NO_TRADE) return;
   if(ShadowGeometryUsable(primary)) RegisterShadowTrade(primary,d.strategy,SHADOW_CHAMPION,"selected strategy shadow benchmark");
   if(ShadowGeometryUsable(pb)) RegisterShadowTrade(pb,d.strategy,SHADOW_PULLBACK,"alternative pullback execution path");
   if(ShadowGeometryUsable(br)) RegisterShadowTrade(br,d.strategy,SHADOW_BREAKOUT_RETEST,"alternative breakout-retest execution path");
   if(InpTrackRejectedCounterfactuals && !liveReady && ShadowGeometryUsable(primary))
      RegisterShadowTrade(primary,d.strategy,SHADOW_REJECTED_COUNTERFACTUAL,"rejected/no-trade counterfactual: "+reason);
}

string ChampionChallengerSummary(StrategyClass c)
{
   if(!InpUseChampionChallenger || c==STRATEGY_NO_TRADE) return "Champion/challenger disabled or no strategy.";
   double cn=0,ca=0,cp=0,cdd=0,cd=0,pn=0,pa=0,pp=0,pdd=0,pd=0,bn=0,ba=0,bp=0,bdd=0,bd=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cd);
   ChampionChallengerMetrics(c,SHADOW_PULLBACK,pn,pa,pp,pdd,pd);
   ChampionChallengerMetrics(c,SHADOW_BREAKOUT_RETEST,bn,ba,bp,bdd,bd);
   string pwhy="",bwhy=""; bool pe=ChallengerEligibleForPromotion(c,SHADOW_PULLBACK,pwhy),be=ChallengerEligibleForPromotion(c,SHADOW_BREAKOUT_RETEST,bwhy);
   return StringFormat("Champion/challenger %s | champion N %.0f avg %.2f PF %.2f DD %.2f | PB N %.0f avg %.2f PF %.2f eligible %s | BRT N %.0f avg %.2f PF %.2f eligible %s | promoted %s",
      StrategyClassName(c),cn,ca,cp,cdd,pn,pa,pp,pe?"YES":"NO",bn,ba,bp,be?"YES":"NO",ShadowVariantName(PromotedChallengerVariant(c)));
}

void ChampionChallengerInit()
{
   EnsureShadowValidationHeader();
   RefreshChampionChallengerPromotion();
   Print("GPT_EA champion/challenger shadow engine initialized. Auto-promotion=",InpAutoPromoteChallenger?"ON":"OFF");
}

void ChampionChallengerTimer()
{
   if(!InpUseChampionChallenger) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      for(int v=0;v<=3;v++) UpdateOneShadowTrade(sym,v);
   }
   RefreshChampionChallengerPromotion();
}
