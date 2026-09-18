// ============================================================================
// GPT_EA Part 35 - Adaptive stack integration wrappers
// ============================================================================
// These wrappers preserve the proven legacy paths and insert Parts 30-36 at
// selector, authorization, AI-veto, telemetry and runtime lifecycle boundaries.

TradeSetup       g_r5Primary;
TradeSetup       g_r5Pullback;
TradeSetup       g_r5BreakoutRetest;
StrategyDecision g_r5Decision;
string           g_r5SelectionNote="";
string           g_r5CalibrationNote="";
string           g_r5ExpiryNote="";
string           g_r5AIAnswer="";
bool             g_r5ContextReady=false;

bool AdaptiveOpenPositionForSymbol(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

void SelectDynamicStrategyR5(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   string pbCal="",brCal="";
   CalibratedConfidenceValue(pb.confidence,pbCal);
   CalibratedConfidenceValue(br.confidence,brCal);

   SelectDynamicStrategyUltimate(sym,pb,br,d);
   TradeSetup primary=d.setup;
   if(primary.symbol=="") primary=(pb.confidence>=br.confidence?pb:br);

   string cc="";
   ApplyChampionChallengerSelection(primary,pb,br,d,cc);

   string selectedCal="";
   ApplyConfidenceCalibration(primary,selectedCal);
   if(d.strategy!=STRATEGY_NO_TRADE && d.action==STRATEGY_ACTION_HIGH_CONFIDENCE && !primary.valid)
      d.action=STRATEGY_ACTION_WAIT;
   d.setup=primary;

   string expiry="";
   int learned=LearnedStrategyExpiryM15(d.strategy,MathMax(1,primary.expiryM15),expiry);
   d.setup.expiryM15=learned;
   primary.expiryM15=learned;

   g_r5Primary=primary;
   g_r5Pullback=pb;
   g_r5BreakoutRetest=br;
   g_r5Decision=d;
   g_r5SelectionNote=cc;
   g_r5CalibrationNote=pbCal+" | "+brCal+" | selected: "+selectedCal;
   g_r5ExpiryNote=expiry;
   g_r5AIAnswer="";
   g_r5ContextReady=true;

   PersistStrategyCandidate(sym,d);
}

bool AdaptivePreAuthorizationRiskAllowsR5(const TradeSetup &s,string &why)
{
   string kill="";
   if(RiskKillSwitchActive(kill)){ why=kill; return false; }
   string cd="";
   if(CooldownActive(s.symbol,cd)){ why=cd; return false; }

   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string emergencyAI="";
   bool deterministicOnly=DeterministicEmergencyExecutionActive(s.symbol,c,emergencyAI);
   bool storedRequested=GVRead(SymKey(s.symbol,"AI_REVIEW_REQUESTED"),0)>0.5;
   bool storedAvailable=GVRead(SymKey(s.symbol,"AI_REVIEW_AVAILABLE"),0)>0.5;
   string ai="";
   if(deterministicOnly && (!storedRequested || !storedAvailable))
      ai="DETERMINISTIC_ONLY: unavailable stored GPT review bypassed; "+emergencyAI;
   else if(!StoredAIIntegrityAllows(s.symbol,ai))
   { why="GPT integrity/disagreement: "+ai; return false; }

   string learn="";
   if(!AdaptiveExecutionLearningAllows(s,learn)){ why="Execution learning: "+learn; return false; }

   double rm=0,ol=0;
   double lots=AdaptiveLotSizeForRiskFinal(s,rm,ol);
   if(lots<=0){ why="Adaptive final lot-size calculation returned zero."; return false; }

   string adaptive="";
   if(!AdaptivePreEntryAllows(s,lots,adaptive)){ why=adaptive; return false; }
   why=StringFormat("%s | %s | %s | final lots %.3f risk %.2f | %s",
                    kill,ai,learn,lots,rm,FinalAdaptiveSizingText(s));
   return true;
}

int AdaptiveExecutionSlippagePointsR5(const string sym)
{
   StrategyClass c=CandidateStrategyForSymbol(sym);
   string detail="";
   double forecast=ExecutionSlippageForecastPoints(sym,c,detail);
   int pts=(int)MathCeil(MathMax((double)DynamicSlippagePoints(sym),forecast));
   return MathMax(1,MathMin(InpMaxDynamicSlippagePoints,pts));
}

bool AIReviewAllowsExecutionR5(const string aiText,bool aiAvailable,string &why)
{
   g_r5AIAnswer=aiText;
   if(g_r5ContextReady)
   {
      string emergency="";
      if(!aiAvailable && DeterministicEmergencyExecutionActive(g_r5Primary.symbol,g_r5Decision.strategy,emergency))
      {
         string det="";
         bool detOK=DeterministicSetupIntegrity(g_r5Primary,det);
         PersistAIIntegrityDecision(g_r5Primary.symbol,detOK,true,false,false,"");
         why="DETERMINISTIC_ONLY: unavailable GPT transport bypassed by emergency policy | "+emergency+" | "+det;
         return detOK;
      }
   }

   string legacy="";
   bool legacyOK=AIReviewAllowsExecution(aiText,aiAvailable,legacy);
   if(!g_r5ContextReady)
   {
      why=legacy+" | adaptive scan context unavailable.";
      return legacyOK;
   }

   bool requested=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || g_r5Decision.score>=InpMinStrategyScore));
   string integrity="",disagreement="";
   bool integrityOK=GPTReviewIntegrityAllows(g_r5Primary.symbol,g_r5Primary,aiText,aiAvailable,requested,integrity);
   bool disagreementOK=GPTDisagreementAllowsHighConfidence(g_r5Primary,aiText,aiAvailable,disagreement);
   PersistAIIntegrityDecision(g_r5Primary.symbol,integrityOK,disagreementOK,requested,aiAvailable,aiText);
   why=legacy+" | "+integrity+" | "+disagreement;
   return legacyOK && integrityOK && disagreementOK;
}

string AdaptiveFinalDecisionFromCard(const string card)
{
   if(StringFind(card,"FINAL DECISION: ✅ HIGH-CONFIDENCE TRADE SETUP")>=0) return "HIGH_CONFIDENCE";
   if(StringFind(card,"FINAL DECISION: ❌ NO TRADE")>=0) return "NO_TRADE";
   return "WAIT_REANALYZE";
}

void RefreshAdaptiveLifecycleFromDecision(const string decision)
{
   if(!g_r5ContextReady || g_r5Primary.symbol=="" || AdaptiveOpenPositionForSymbol(g_r5Primary.symbol)) return;
   string sym=g_r5Primary.symbol;
   int cur=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
   if(cur==LIFE_REJECTED || cur==LIFE_INVALIDATED || cur==LIFE_CLOSED || cur==LIFE_NONE)
      SetSymbolLifecycle(sym,LIFE_CANDIDATE,"fresh adaptive scan candidate");

   if(decision=="HIGH_CONFIDENCE" && InpRequireApproval)
   {
      if(SetSymbolLifecycle(sym,LIFE_WAIT_CONFIRMATION,"high-confidence setup awaiting human approval"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_HUMAN_APPROVAL);
   }
   else if(decision=="WAIT_REANALYZE")
   {
      if(SetSymbolLifecycle(sym,LIFE_WAIT_CONFIRMATION,"strategy valid but market confirmation/reanalysis still required"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_MARKET_CONFIRMATION);
   }
   else if(decision=="NO_TRADE")
   {
      if(SetSymbolLifecycle(sym,LIFE_INVALIDATED,"fresh scan classified NO TRADE"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
   }
}

void NotifyCardR5(const string card)
{
   if(!g_r5ContextReady)
   {
      ObserveDemoSoakScanCard(card);
      NotifyCardObserved(card);
      return;
   }
   string decision=AdaptiveFinalDecisionFromCard(card);
   bool liveReady=(decision=="HIGH_CONFIDENCE");
   string enriched=card+AdaptiveCardAddendum(g_r5Primary,g_r5Decision);
   enriched+="Champion/challenger selection: "+g_r5SelectionNote+"\n";
   enriched+="Confidence calibration: "+g_r5CalibrationNote+"\n";
   enriched+="Learned candle expiry: "+g_r5ExpiryNote+"\n";
   enriched+="Final sizing: "+FinalAdaptiveSizingText(g_r5Primary)+"\n";
   if(InpEnableDemoSoakEvidence) enriched+=DemoSoakEvidenceSummary()+"\n";

   ChampionChallengerScanHook(g_r5Primary,g_r5Pullback,g_r5BreakoutRetest,g_r5Decision,liveReady,decision);
   WriteDecisionSnapshot(g_r5Primary,g_r5Decision,decision,"scanner hard filters and news/web state are retained in the emitted card","",g_r5AIAnswer,decision);
   RefreshAdaptiveLifecycleFromDecision(decision);
   ObserveDemoSoakScanCard(card);
   NotifyCardObserved(enriched);
}

void MarkSignalCooldownR5(const string sym)
{
   MarkSignalCooldown(sym);
   if(!AdaptiveOpenPositionForSymbol(sym))
   {
      SetSymbolLifecycle(sym,LIFE_INVALIDATED,"approval denied/expired; cooldown activated");
      GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
   }
}

void NewsIntermarketInitR5()
{
   NewsIntermarketInit();
   ChaosInit();
   ModelClockTrustInit();
   AdaptiveRiskSupervisorInit();
   DataIntegrityInit();
   ExecutionLearningInitR5();
   ChampionChallengerInit();
   LifecycleIntegrityInit();
   ExecutionReliabilityInit();
   CausalAttributionInit();
   DemoSoakEvidenceInit();
   StrategyHealthDashboardInit();
}

void NewsIntermarketTimerR5()
{
   NewsIntermarketTimer();
   ModelClockTrustTimer();
   AdaptiveRiskSupervisorTimer();
   DataIntegrityTimer();
   ExecutionLearningTimerR5();
   ChampionChallengerTimer();
   LifecycleIntegrityTimer();
   ExecutionReliabilityTimer();
   CausalAttributionTimer();
   DemoSoakEvidenceTimer();
   StrategyHealthDashboardTimer();
}

void DeleteAdvancedDashboardR5()
{
   ExecutionReliabilityShutdown();
   DataIntegrityShutdown();
   DemoSoakEvidenceShutdown();
   DeleteAdvancedDashboard();
   DeleteStrategyHealthDashboard();
}
