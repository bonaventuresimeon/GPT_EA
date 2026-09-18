// ============================================================================
// GPT_EA Part 27 - Reachable first-class breakout / counter-trend strategy paths
// ============================================================================

input bool   InpAllowDirectBreakoutExecution = true;
input double InpDirectBreakoutMinVolumeRatio = 1.15;
input double InpDirectBreakoutMinADX         = 22.0;
input double InpDirectBreakoutZoneATR        = 0.18;
input double InpDirectBreakoutInsideStopATR  = 0.45;

TradeSetup BuildDirectBreakoutCandidate(const StrategySnapshot &x,int score)
{
   bool bull=(x.breakoutUp && !x.breakoutDown ? true :
              (!x.breakoutUp && x.breakoutDown ? false : x.dominantBull));
   TradeSetup s; InitSetup(s,x.symbol,SETUP_BREAKOUT,bull);
   if(x.atr<=0) return s;

   double level=(bull?x.priorHigh:x.priorLow);
   if(level<=0) return s;
   double width=MathMax(0.05,InpDirectBreakoutZoneATR)*x.atr;
   s.name="BREAKOUT";
   if(bull)
   {
      s.zoneLow=NormPrice(x.symbol,level+0.02*x.atr);
      s.zoneHigh=NormPrice(x.symbol,level+width);
      s.preferred=NormPrice(x.symbol,level+0.07*x.atr);
      s.sl=NormPrice(x.symbol,level-MathMax(0.25,InpDirectBreakoutInsideStopATR)*x.atr);
   }
   else
   {
      s.zoneLow=NormPrice(x.symbol,level-width);
      s.zoneHigh=NormPrice(x.symbol,level-0.02*x.atr);
      s.preferred=NormPrice(x.symbol,level-0.07*x.atr);
      s.sl=NormPrice(x.symbol,level+MathMax(0.25,InpDirectBreakoutInsideStopATR)*x.atr);
   }

   SetConservativeTargets(s,1.0,2.0,3.0);
   RefineTargetsToStructure(s);
   s.confidence=(score>95?95:score);
   s.expiryM15=StrategyAdaptiveExpiry(x.symbol,STRATEGY_BREAKOUT);
   RealisticRRReport rr=RealisticRiskReward(s);
   bool breakout=(bull?x.breakoutUp:x.breakoutDown);
   bool fake=(bull?x.falseBreakUp:x.falseBreakDown);
   bool quality=(x.expansion && x.volumeRatio>=InpDirectBreakoutMinVolumeRatio && x.adx>=InpDirectBreakoutMinADX);
   s.valid=(InpAllowDirectBreakoutExecution && breakout && !fake && quality && !ChaseRiskDetected(x) && rr.rr>=InpMinEffectiveRR);
   s.reason=StringFormat("Direct breakout through %.5f | expansion %s | ADX %.1f | volume %.2fx | chase %s | realistic weighted R:R %.2f.",
                         level,x.expansion?"YES":"NO",x.adx,x.volumeRatio,ChaseRiskDetected(x)?"YES":"NO",rr.rr);
   s.invalidation=(bull?
      "M15 acceptance back below the broken resistance/old range invalidates the breakout thesis.":
      "M15 acceptance back above the broken support/old range invalidates the breakdown thesis.");
   s.failurePattern="Failure: displacement cannot hold outside the old range, momentum collapses, or price returns through the breakout level as a false break/liquidity sweep.";
   s.executionRule="Direct breakout execution requires fresh expansion, volume/ADX support, price inside the shallow post-break zone, M5 trigger and EMA impulse. Do not chase beyond the breakout zone; otherwise WAIT for retest.";
   return s;
}

bool OverrideResearchAllows(const string sym,StrategyDecision &d,string &detail)
{
   string research="";
   bool ok=StrategyResearchEvidenceAllows(sym,d.strategy,d.setup.bullish,research);
   string ses="";
   bool sesOK=AccurateSessionEvidenceAllows(sym,d.strategy,ses);
   detail=research+" | "+ses;
   return (ok && sesOK);
}

void CompleteOverrideDecision(const string sym,StrategyDecision &d)
{
   RefreshFrameworkForAccurateSession(sym,d);
   d.setup.expiryM15=StrategyAdaptiveExpiry(sym,d.strategy);
   string evidence="";
   bool evidenceOK=OverrideResearchAllows(sym,d,evidence);
   d.evidence=evidence;
   if(!evidenceOK)
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Override strategy rejected by research/context evidence.";
      return;
   }
   if(d.score<InpMinStrategyScore || !d.setup.valid) d.action=STRATEGY_ACTION_WAIT;
   else d.action=STRATEGY_ACTION_HIGH_CONFIDENCE;
}

void SelectDynamicStrategyUltimate(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyFinal(sym,pb,br,d);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string extreme="";
   if(ExtremeRegimeDetected(x,extreme))
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Ultimate strategy guard retains extreme-regime BLOCK: "+extreme;
      PersistStrategyCandidate(sym,d);
      return;
   }

   // Trend failure is not yet a completed reversal. Always keep this state classified
   // as Counter-Trend Swing; if its stricter score/trigger is insufficient the result is WAIT.
   if(x.state==STATE_TREND_FAILURE && InpAllowCounterTrendSwing)
   {
      bool counterBull=!x.dominantBull;
      int ct=CounterTrendScore(x,counterBull);
      int reversalScore=StrategyBaseScore(x,STRATEGY_POTENTIAL_REVERSAL);
      d.strategy=STRATEGY_COUNTER_TREND_SWING;
      d.counterTrend=true;
      d.counterTrendScore=ct;
      d.score=(ct>reversalScore?ct:reversalScore);
      d.state=STATE_TREND_FAILURE;
      d.stateText=MarketStateName(d.state);
      d.setup=BuildCounterTrendCandidate(x,counterBull,ct,true);
      d.strategyName=StrategyClassName(d.strategy);
      d.rationale+=" | Trend failure is classified as COUNTER-TREND SWING until full reversal acceptance is established.";
      d.confirmation="COUNTER-TREND TRADE: require major-level/sweep rejection plus M5 BOS/CHOCH and rejection; targets remain conservative until reversal structure proves durable.";
      CompleteOverrideDecision(sym,d);
      if(ct<InpMinCounterTrendScore)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=StringFormat(" | Counter-trend swing score %d/100 is below strict threshold %d; WAIT, do not relabel as reversal.",ct,InpMinCounterTrendScore);
      }
   }

   // A completed structural reversal remains Potential Reversal rather than being diluted
   // into the counter-trend swing class.
   if(x.state==STATE_REVERSAL && d.strategy!=STRATEGY_NO_TRADE)
   {
      d.state=STATE_REVERSAL;
      d.stateText=MarketStateName(d.state);
   }

   // Make BREAKOUT a true executable class when displacement quality is high and the
   // price is still in a shallow post-break zone. Overextended breaks remain WAIT/retest.
   if(d.strategy==STRATEGY_BREAKOUT && InpAllowDirectBreakoutExecution)
   {
      TradeSetup direct=BuildDirectBreakoutCandidate(x,d.score);
      d.setup=direct;
      d.strategyName=StrategyClassName(d.strategy);
      d.rationale+=" | Direct breakout execution path evaluated. "+direct.reason;
      d.confirmation=direct.executionRule;
      CompleteOverrideDecision(sym,d);
   }

   if(d.strategy==STRATEGY_BREAKOUT_RETEST)
   {
      d.state=STATE_BREAKOUT_RETEST;
      d.stateText=MarketStateName(d.state);
   }

   // Mean reversion has its own enable switch; do not accidentally depend on the range-trade toggle.
   if(d.strategy==STRATEGY_MEAN_REVERSION && InpAllowMeanReversion && !d.setup.valid && d.setup.preferred>0)
   {
      RealisticRRReport rr=RealisticRiskReward(d.setup);
      if(d.setup.confidence>=InpMinStrategyScore && rr.rr>=1.05)
      {
         d.setup.valid=true;
         d.rationale+=" | Mean-reversion validity repaired using its dedicated enable switch and realistic R:R gate.";
         CompleteOverrideDecision(sym,d);
      }
   }

   PersistStrategyCandidate(sym,d);
}
