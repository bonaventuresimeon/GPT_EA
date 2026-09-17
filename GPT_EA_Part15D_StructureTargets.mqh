// ============================================================================
// GPT_EA Part 15D - Structure/liquidity-aware target refinement
// ============================================================================

void AddObjective(double &arr[],double v,double entry,bool bull)
{
   if(v<=0) return;
   if((bull && v<=entry) || (!bull && v>=entry)) return;
   for(int i=0;i<ArraySize(arr);i++) if(MathAbs(arr[i]-v)<=PointFor(_Symbol)*2.0) return;
   int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=v;
}

void SortObjectives(double &arr[],bool bull)
{
   int n=ArraySize(arr);
   for(int i=0;i<n-1;i++) for(int j=i+1;j<n;j++)
   {
      bool swap=(bull?arr[j]<arr[i]:arr[j]>arr[i]);
      if(swap){ double t=arr[i]; arr[i]=arr[j]; arr[j]=t; }
   }
}

void RefineTargetsToStructure(TradeSetup &s)
{
   if(s.preferred<=0 || s.sl<=0) return;
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   double R=MathAbs(s.preferred-s.sl); if(R<=0) return;
   double objs[];
   AddObjective(objs,x.priorHigh,s.preferred,s.bullish);
   AddObjective(objs,x.priorLow,s.preferred,s.bullish);
   AddObjective(objs,x.previousDayHigh,s.preferred,s.bullish);
   AddObjective(objs,x.previousDayLow,s.preferred,s.bullish);
   AddObjective(objs,x.asianHigh,s.preferred,s.bullish);
   AddObjective(objs,x.asianLow,s.preferred,s.bullish);
   SortObjectives(objs,s.bullish);

   double fallback1=(s.bullish?s.preferred+R:s.preferred-R);
   double fallback2=(s.bullish?s.preferred+2.0*R:s.preferred-2.0*R);
   double fallback3=(s.bullish?s.preferred+3.0*R:s.preferred-3.0*R);
   double chosen1=0,chosen2=0,chosen3=0;
   for(int i=0;i<ArraySize(objs);i++)
   {
      double rr=MathAbs(objs[i]-s.preferred)/R;
      if(chosen1==0 && rr>=0.70) { chosen1=objs[i]; continue; }
      if(chosen2==0 && rr>=1.25 && MathAbs(objs[i]-chosen1)>0.20*R) { chosen2=objs[i]; continue; }
      if(chosen3==0 && rr>=1.80 && MathAbs(objs[i]-(chosen2>0?chosen2:chosen1))>0.20*R) { chosen3=objs[i]; break; }
   }
   if(chosen1==0) chosen1=fallback1;
   if(chosen2==0) chosen2=fallback2;
   if(chosen3==0) chosen3=fallback3;

   // Counter-trend candidates keep their intentionally conservative targets if structure objectives lie farther away.
   bool counter=(StringFind(s.name,"COUNTER-TREND")>=0 || StringFind(s.name,"POTENTIAL REVERSAL")>=0);
   if(counter)
   {
      if(s.bullish){ chosen1=MathMin(chosen1,s.tp1); chosen2=MathMin(chosen2,s.tp2); chosen3=MathMin(chosen3,s.tp3); }
      else { chosen1=MathMax(chosen1,s.tp1); chosen2=MathMax(chosen2,s.tp2); chosen3=MathMax(chosen3,s.tp3); }
   }

   s.tp1=NormalizePriceToTick(s.symbol,chosen1);
   s.tp2=NormalizePriceToTick(s.symbol,chosen2);
   s.tp3=NormalizePriceToTick(s.symbol,chosen3);
   s.nominalRR1=MathAbs(s.tp1-s.preferred)/R;
   s.effectiveRR1=EffectiveRRDynamic(s);
   s.reason+=StringFormat(" | Structure/liquidity targets refined to TP1 %.5f, TP2 %.5f, TP3 %.5f from swing/previous-day/Asian objectives with measured-R fallback.",s.tp1,s.tp2,s.tp3);
}

void SelectDynamicStrategyComplete(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyEnriched(sym,pb,br,d);
   if(d.strategy!=STRATEGY_NO_TRADE && d.setup.preferred>0)
   {
      RefineTargetsToStructure(d.setup);
      string ev="";
      if(!StrategyEvidenceAllows(d.strategy,ev)){ d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false; }
      d.evidence=ev;
   }
   PersistStrategyCandidate(sym,d);
}
