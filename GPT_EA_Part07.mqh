// ============================================================================
// GPT_EA Part 07 - Approval workflow, full intelligence scanner and MT5 hooks
// ============================================================================

void DeletePending(const int idx,const string reason)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   string sym=g_pending[idx].setup.symbol;
   g_pending[idx].active=false;
   if(StringFind(reason,"denied")>=0 || StringFind(reason,"timeout")>=0)
      MarkSignalCooldown(sym);
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   PrintFormat("%s pending setup deleted: %s",sym,reason);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
      SendNotification(StringFormat("%s pending setup deleted: %s",sym,reason));
   RenderApprovalPrompt();
   StyleApprovalUI();
}

void QueueForApproval(const TradeSetup &s,const string card,const string scanReason)
{
   if(!s.valid) return;
   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   {
      Print(s.symbol,": approval prompt suppressed by release gate - ",releaseWhy);
      return;
   }
   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   {
      Print(s.symbol,": approval prompt suppressed by partial-protection/stop gate - ",stopWhy);
      return;
   }

   datetime now=TimeTradeServer();
   int timeout=MathMax(10,InpApprovalTimeoutSeconds);
   int idx=ActivePendingForSymbol(s.symbol);
   if(idx<0)
   {
      idx=ArraySize(g_pending);
      ArrayResize(g_pending,idx+1);
   }
   g_pending[idx].active=true;
   g_pending[idx].setup=s;
   g_pending[idx].card=card;
   g_pending[idx].scanReason=scanReason;
   g_pending[idx].createdAt=now;
   g_pending[idx].expiresAt=now+timeout;
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   RenderApprovalPrompt();
   StyleApprovalUI();

   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   string msg=StringFormat("GPT_EA approval required: %s %s %s. APPROVE or DENY within %d seconds.",s.symbol,StrategyClassName(cls),Arrow(s.bullish),timeout);
   Print(msg);
   if(InpApprovalAlert && InpEnableAlerts) Alert(msg);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(msg);
}

void ProcessApprovalTimeouts()
{
   datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && now>=g_pending[i].expiresAt)
         DeletePending(i,"approval timeout - no user response");
   RenderApprovalPrompt();
   StyleApprovalUI();
}

bool StrategyAwareConfluenceGate(TradeSetup &s,ConfluenceReport &r,StrategyClass cls,string &why)
{
   why="";
   bool nonTrend=(cls==STRATEGY_COUNTER_TREND_SCALP || cls==STRATEGY_COUNTER_TREND_SWING || cls==STRATEGY_POTENTIAL_REVERSAL ||
                  cls==STRATEGY_RANGE_TRADE || cls==STRATEGY_MEAN_REVERSION);
   if(!nonTrend)
   {
      ApplyAdvancedConfluence(s,r);
      if(InpUseAdvancedConfluence && !r.valid){ why=StringFormat("standard confluence invalid at %d/100",r.score); return false; }
   }
   else
   {
      // Counter-trend/range strategies are intentionally allowed to disagree with HTF direction,
      // but must still pass spread/proximity/strategy-specific confirmation and a demanding score.
      int required=(cls==STRATEGY_COUNTER_TREND_SCALP || cls==STRATEGY_COUNTER_TREND_SWING || cls==STRATEGY_POTENTIAL_REVERSAL)?InpMinCounterTrendScore:InpMinStrategyScore;
      s.confidence=(int)MathRound(0.65*s.confidence+0.35*r.score);
      if(!r.spreadOK || s.confidence<MathMin(99,required-5))
      { s.valid=false; why=StringFormat("non-trend confluence insufficient: score %d confidence %d",r.score,s.confidence); return false; }
      r.valid=true;
   }
   why=StringFormat("strategy-aware confluence PASS %d/100",r.score);
   return true;
}

bool FreshApprovalValidation(const TradeSetup &s,string &why)
{
   why="";
   if(!s.valid){ why="Stored setup is no longer marked valid."; return false; }

   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   { why="Release safety gate failed: "+releaseWhy; return false; }

   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   { why="Partial-protection/stop gate failed: "+stopWhy; return false; }

   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(cls==STRATEGY_NO_TRADE){ why="No valid strategy classification remains."; return false; }
   if(!PriceInsideZone(s)){ why="Price left the approved entry zone."; return false; }
   if(!StrategyExecutionTrigger(s,cls)){ why="Strategy-specific M5 execution trigger is no longer present."; return false; }

   TradeSetup live=s;
   live.sl=NormalizePriceToTick(live.symbol,live.sl);
   live.tp1=NormalizePriceToTick(live.symbol,live.tp1);
   live.tp2=NormalizePriceToTick(live.symbol,live.tp2);
   live.tp3=NormalizePriceToTick(live.symbol,live.tp3);

   ConfluenceReport fresh=EvaluateConfluence(live);
   string confWhy="";
   if(!StrategyAwareConfluenceGate(live,fresh,cls,confWhy))
   { why="Confluence revalidation failed: "+confWhy; return false; }

   string institutional="";
   EnhanceSetupWithInstitutionalFilters(live,fresh,institutional);
   if(!live.valid && cls!=STRATEGY_COUNTER_TREND_SCALP && cls!=STRATEGY_COUNTER_TREND_SWING && cls!=STRATEGY_POTENTIAL_REVERSAL)
   { why="Institutional/regime validation failed: "+institutional; return false; }

   string intelWhy="";
   if(!PreEntryIntelligenceRevalidation(live,intelWhy))
   { why="Deep pre-entry intelligence failed: "+intelWhy; return false; }

   double liveRR=EffectiveRRDynamic(live);
   double rrFloor=(cls==STRATEGY_COUNTER_TREND_SCALP?MathMax(1.10,InpMinEffectiveRR-0.30):InpMinEffectiveRR);
   if(liveRR<rrFloor)
   { why=StringFormat("Effective R:R deteriorated to %.2f below %.2f strategy floor.",liveRR,rrFloor); return false; }

   double atr=0; ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr);
   string sessionText="";
   if(SessionConditionInvalidates(s.symbol,s.preferred,atr,sessionText))
   { why=sessionText; return false; }

   string riskWhy="";
   if(!PreAuthorizationRiskAllows(live,riskWhy))
   { why="Risk authorization failed: "+riskWhy; return false; }

   double rm=0,ol=0;
   double lots=LotSizeForRisk(live,rm,ol);
   string brokerWhy="";
   if(lots<=0 || !BrokerExecutionAllows(live,lots,brokerWhy))
   { why="Broker execution validation failed: "+brokerWhy; return false; }

   string serverWhy="";
   if(!ServerOrderCheckAllows(live,lots,DynamicSlippagePoints(live.symbol),serverWhy))
   { why="Server OrderCheck failed: "+serverWhy; return false; }
   why="Fresh strategy + news + intermarket + confluence + risk + broker validation PASS.";
   return true;
}

void ApprovePending(const int idx)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   if(TimeTradeServer()>=g_pending[idx].expiresAt)
   {
      DeletePending(idx,"approval arrived after timeout");
      return;
   }

   TradeSetup s=g_pending[idx].setup;
   g_pending[idx].active=false;
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   RenderApprovalPrompt();
   StyleApprovalUI();

   string why="";
   if(!FreshApprovalValidation(s,why))
   {
      Print(s.symbol,": APPROVED but final validation failed: ",why," No order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approval rejected by fresh validation - "+why);
      return;
   }

   if(ApprovedPlaceTrade(s))
   {
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(s.symbol+": APPROVED - trade executed.");
   }
   else
   {
      Print(s.symbol,": APPROVED but final strategy/news/release/broker/risk validation failed. No order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approved, but final execution validation failed; no trade opened.");
   }
}

string FilterStateText(bool newsBlock,bool yieldBlock,bool spreadOk,bool sessionBlock,bool aiAllows)
{
   return StringFormat("Filters: Calendar %s | Yield %s | Spread %s | Session %s | AI %s",
      newsBlock?"BLOCK":"OK",yieldBlock?"BLOCK":"OK",spreadOk?"OK":"BLOCK",sessionBlock?"BLOCK":"OK",aiAllows?"OK":"VETO");
}

// ----------------------------- Scanner ----------------------------
void ScanSymbol(const string sym,const string scanReason)
{
   if(!EnsureSymbol(sym)){ Print("Symbol unavailable: ",sym); return; }

   string trend="";
   bool alignedBull=false,alignedBear=false;
   int mtfScore=MultiTFScore(sym,trend,alignedBull,alignedBear);
   bool baseBull=(mtfScore>=0);
   if(alignedBear) baseBull=false; else if(alignedBull) baseBull=true;
   int base=BaseConfidenceFromScore(mtfScore,alignedBull,alignedBear,baseBull);

   TradeSetup pb=BuildPullback(sym,baseBull,base,trend);
   TradeSetup br=BuildBreakoutRetest(sym,baseBull,base,trend);

   // First classify the market and choose the strategy; never force pullback/breakout on every chart.
   StrategyDecision decision;
   SelectDynamicStrategy(sym,pb,br,decision);
   TradeSetup primary=decision.setup;
   if(primary.symbol=="") primary=(pb.confidence>=br.confidence?pb:br);

   ConfluenceReport pbReport=EvaluateConfluence(pb),brReport=EvaluateConfluence(br),primaryReport=EvaluateConfluence(primary);
   ApplyAdvancedConfluence(pb,pbReport); ApplyAdvancedConfluence(br,brReport);
   string pbInstitutional="",brInstitutional="";
   EnhanceSetupWithInstitutionalFilters(pb,pbReport,pbInstitutional);
   EnhanceSetupWithInstitutionalFilters(br,brReport,brInstitutional);

   string strategyConfWhy="";
   bool strategyConfluence=StrategyAwareConfluenceGate(primary,primaryReport,decision.strategy,strategyConfWhy);
   string primaryInstitutional="";
   bool institutionalOK=EnhanceSetupWithInstitutionalFilters(primary,primaryReport,primaryInstitutional);
   if(decision.counterTrend && strategyConfluence)
   {
      // HTF opposition is expected for a valid counter-trend setup. Institutional filters remain informative,
      // while counter-trend score/trigger and hard risk/news gates carry the stricter authorization burden.
      primary.valid=(primary.valid && primary.effectiveRR1>=MathMax(1.10,InpMinEffectiveRR-0.30));
      institutionalOK=primary.valid;
   }

   string newsText="",yieldText="",spreadText="",sessionText="";
   bool newsBlock=CalendarBlock(sym,newsText);
   bool yieldBlock=YieldShock(yieldText);
   bool spreadOk=SpreadOK(sym,spreadText);
   double atr=0; ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr);
   bool sessionBlock=SessionConditionInvalidates(sym,primary.preferred,atr,sessionText);

   IntermarketReport intermarket=AssessIntermarket(sym,primary.bullish);
   string webText="",webError=""; bool webBlock=false,webWatch=false;
   bool webAvailable=GetLiveWebIntel(sym,primary,decision,false,webText,webBlock,webWatch,webError);
   string emergencyWebWhy="";
   bool emergencyWebBypass=(!webAvailable && g_lastWebIntelFailureClass=="UNAVAILABLE" &&
                            DeterministicEmergencyExecutionActive(sym,decision.strategy,emergencyWebWhy));
   if(!webAvailable && InpBlockIfWebIntelUnavailable && !emergencyWebBypass) webBlock=true;
   if(emergencyWebBypass)
   {
      webBlock=false; webWatch=true;
      webText="DETERMINISTIC_ONLY external-intelligence transport outage bypass | "+emergencyWebWhy+" | "+webText;
   }

   bool readyNow=(primary.valid && decision.action==STRATEGY_ACTION_HIGH_CONFIDENCE && StrategyExecutionTrigger(primary,decision.strategy));
   string upcoming=UpcomingEventSummary(sym);

   string card=StrategyDecisionHeader(decision);
   card+=BuildCard(primary,pb,br,scanReason,newsBlock,newsText,spreadText,spreadOk,yieldBlock,yieldText,sessionBlock,sessionText);
   card+=ConfluenceCardBlock(primaryReport,upcoming,readyNow);
   card+=StringFormat("Pullback confluence: %d/100 | Breakout-retest confluence: %d/100 | Selected strategy confluence: %d/100\n",pbReport.score,brReport.score,primaryReport.score);
   card+="Strategy rationale: "+decision.rationale+"\n";
   card+="Strategy confirmation: "+decision.confirmation+"\n";
   card+="Counterargument: "+decision.counterargument+"\n";
   card+="Institutional validation: "+primaryInstitutional+"\n";
   card+="Pullback institutional: "+pbInstitutional+"\n";
   card+="Breakout institutional: "+brInstitutional+"\n";
   card+="Intermarket: "+intermarket.detail+"\n";
   card+="Live web/news intelligence: "+webText+"\n";
   card+="Broker environment: "+BrokerEnvironmentSummary()+"\n";
   card+="Broker symbol profile: "+SymbolProfileSummary(sym)+"\n";

   string thesis=BuildMandatory25PointThesis(sym,primary,pb,br,decision,primaryReport,newsText,webText,intermarket,spreadText,sessionText);
   card+=thesis;

   bool aiAvailable=false; string aiAnswer="",aiError="";
   bool requestAI=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || decision.score>=InpMinStrategyScore));
   if(requestAI)
   {
      aiAvailable=CallOpenAI(BuildDeepGPTPrompt(sym,card,thesis,webText,decision),aiAnswer,aiError);
      if(aiAvailable) card+="\n━━━━━━━━━━━━━━━━━━━━\n🤖 GPT ADVERSARIAL VALIDATION\n━━━━━━━━━━━━━━━━━━━━\n"+aiAnswer+"\n";
      else card+="\nGPT secondary validation unavailable: "+aiError+"\n";
   }

   string aiGateWhy="";
   bool aiAllows=AIReviewAllowsExecution(aiAnswer,aiAvailable,aiGateWhy);
   if(!requestAI && InpAICanVetoTrade){ aiAllows=true; aiGateWhy="AI review not requested for this candidate."; }

   string releaseWhy=""; bool releaseAllows=ReleaseSafetyAllows(sym,releaseWhy);
   string stopObsWhy=""; bool stopObsAllows=StopObservabilityAllowsNewEntries(stopObsWhy);
   string evidenceText=""; bool evidenceAllows=StrategyEvidenceAllows(decision.strategy,evidenceText);

   string riskWhy=""; bool riskAllows=PreAuthorizationRiskAllows(primary,riskWhy);
   double previewRisk=0,previewOneLot=0;
   double previewLots=LotSizeForRisk(primary,previewRisk,previewOneLot);
   string brokerWhy=""; bool brokerAllows=(previewLots>0 && BrokerExecutionAllows(primary,previewLots,brokerWhy));
   if(previewLots<=0) brokerWhy="Preview lot calculation returned zero.";

   string serverWhy=""; bool serverAllows=false;
   if(brokerAllows) serverAllows=ServerOrderCheckAllows(primary,previewLots,DynamicSlippagePoints(sym),serverWhy);
   else serverWhy="Skipped because broker execution gate did not pass.";

   double rrFloor=(decision.strategy==STRATEGY_COUNTER_TREND_SCALP?MathMax(1.10,InpMinEffectiveRR-0.30):InpMinEffectiveRR);
   bool strategyActionOK=(decision.action==STRATEGY_ACTION_HIGH_CONFIDENCE);
   bool hardValid=(strategyActionOK && primary.valid && strategyConfluence && institutionalOK && evidenceAllows &&
                   !newsBlock && !yieldBlock && !sessionBlock && spreadOk && EffectiveRRDynamic(primary)>=rrFloor &&
                   !intermarket.severeConflict && !(InpBlockOnWebIntelVerdictBLOCK && webBlock) && aiAllows &&
                   releaseAllows && stopObsAllows && riskAllows && brokerAllows && serverAllows);
   bool approvalReady=(hardValid && readyNow);

   string filterState=FilterStateText(newsBlock,yieldBlock,spreadOk,sessionBlock,aiAllows);
   filterState+=" | Web "+(webBlock?"BLOCK":webWatch?"WATCH":"OK");
   filterState+=" | Intermarket "+(intermarket.severeConflict?"BLOCK":"OK");
   filterState+=" | Release "+(releaseAllows?"OK":"BLOCK");
   filterState+=" | StopRisk "+(stopObsAllows?"OK":"BLOCK");
   card+="\n"+filterState+"\n";
   card+="Strategy decision: "+(strategyActionOK?"HIGH-CONFIDENCE":"WAIT/NO TRADE")+" | "+strategyConfWhy+"\n";
   card+="Historical strategy evidence gate: "+evidenceText+"\n";
   card+="GPT execution gate: "+aiGateWhy+"\n";
   card+="Release safety gate: "+(releaseAllows?"PASS":"BLOCK - "+releaseWhy)+"\n";
   card+="Partial-protection/stop gate: "+stopObsWhy+"\n";
   card+="Portfolio/risk gate: "+riskWhy+"\n";
   card+="Broker execution gate: "+brokerWhy+"\n";
   card+="MT5 OrderCheck gate: "+serverWhy+"\n";
   card+=StringFormat("Portfolio risk %.2f%% | daily loss %.2f%% | drawdown %.2f%% | consecutive losses %d\n",
                      CurrentPortfolioRiskPercent(),DailyLossPercent(),EquityDrawdownPercent(),ConsecutiveLosses());
   card+=StringFormat("Dynamic slippage ceiling %d points | dynamic effective R:R %.2f\n",DynamicSlippagePoints(sym),EffectiveRRDynamic(primary));
   card+=StringFormat("FINAL DECISION: %s\n",approvalReady?"✅ HIGH-CONFIDENCE TRADE SETUP — APPROVE / DENY ACTIVE":
                     decision.action==STRATEGY_ACTION_NO_TRADE?"❌ NO TRADE":"⏳ WAIT FOR CONFIRMATION / REANALYZE");

   NotifyCard(card);
   RenderAdvancedDashboard(primary,primaryReport,filterState,readyNow);
   UpdateRiskAnalyticsPanel();

   int existing=ActivePendingForSymbol(sym);
   if(approvalReady)
   {
      PersistStrategyCandidate(sym,decision);
      if(InpRequireApproval) QueueForApproval(primary,card,scanReason);
      else
      {
         string freshWhy="";
         if(FreshApprovalValidation(primary,freshWhy)) ApprovedPlaceTrade(primary);
         else Print(sym,": execution skipped after final validation: ",freshWhy);
      }
   }
   else if(existing>=0)
   {
      DeletePending(existing,"fresh scan no longer meets complete intelligence/entry conditions");
   }
}

void ScanAll(const string reason)
{
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") ScanSymbol(g_symbols[i],reason);
}

// -------------------------- MT5 event hooks -----------------------
int OnInit()
{
   if(SplitSymbols()<=0){ Print("No symbols configured."); return INIT_PARAMETERS_INCORRECT; }
   if(!ResolveConfiguredSymbolsUniversal())
   { Print("No configured symbols could be resolved on this broker."); return INIT_PARAMETERS_INCORRECT; }

   PrintResolvedBrokerProfiles();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   ApplyChartPolish();
   EventSetTimer(MathMax(1,InpTimerSeconds));
   RiskRecoveryInit();
   PrepareRecoveryCheckpointFallback();
   UniversalRecoveryInit();
   RecoverySafetyAudit();
   SafeUniversalCheckpointNow();
   AdvancedSafetyInit();
   StopFailurePolicyInit();
   StopFailureObservabilityInit();
   StrategyIntelligenceInit();
   NewsIntermarketInit();

   Print("GPT_EA Full Intelligence initialized. Approval=",InpRequireApproval?"REQUIRED":"DISABLED",
         ", Timeout=",InpApprovalTimeoutSeconds,"s",
         ", Min strategy=",InpMinStrategyScore,
         ", Min confluence=",InpMinAdvancedConfluence,
         ", Portfolio cap=",DoubleToString(InpMaxPortfolioRiskPercent,2),"%",
         ", Live web intel=",InpUseLiveWebIntelligence?"ON":"OFF",
         ", ReleaseGate=",ReleaseGateSummary());

   if(InpUseOpenAI && StringLen(Trim(InpOpenAIAPIKey))<20)
      Print("OpenAI enabled but API key is blank. Enter it locally in EA Inputs. Never commit the key.");
   if(InpUseOpenAI || InpUseLiveWebIntelligence)
      Print("MT5 WebRequest allow-list must include: https://api.openai.com");

   ScanAll("EA startup / restart recovery full-intelligence scan");
   RenderApprovalPrompt(); StyleApprovalUI(); UpdateRiskAnalyticsPanel(); SafeUniversalCheckpointNow();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   UniversalRecoveryShutdown();
   BackupRecoveryCheckpointIfValid();
   RiskRecoveryShutdown();
   DeleteApprovalObjects();
   DeleteAdvancedDashboard();
   Comment("");
}

void OnTimer()
{
   // Existing positions remain managed even if new-entry intelligence or release gates are blocked.
   ManagePositionsAdvanced();
   ProcessApprovalTimeouts();
   RiskRecoveryTimer();
   SafeUniversalRecoveryTimer();
   AdvancedSafetyTimer();
   StopFailurePolicyTimer();
   StopFailureObservabilityTimer();
   StrategyIntelligenceTimer();
   NewsIntermarketTimer();
   StyleApprovalUI();

   string why="";
   if(ScheduledScanDue(why)) ScanAll(why);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   HandleReliabilityTradeTransaction(trans,request,result);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(sparam==BTN_SCAN_NOW)
   {
      ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_STATE,false);
      ScanAll("Manual SCAN NOW"); return;
   }
   if(sparam==BTN_PAUSE)
   {
      ObjectSetInteger(0,BTN_PAUSE,OBJPROP_STATE,false);
      ToggleTradingPause(); SafeUniversalCheckpointNow(); UpdateRiskAnalyticsPanel();
      if(g_manualPaused) for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) DeletePending(i,"manual trading pause");
      return;
   }
   if(g_displayPending<0) return;
   if(sparam==BTN_APPROVE){ ObjectSetInteger(0,BTN_APPROVE,OBJPROP_STATE,false); ApprovePending(g_displayPending); }
   else if(sparam==BTN_DENY){ ObjectSetInteger(0,BTN_DENY,OBJPROP_STATE,false); DeletePending(g_displayPending,"user denied trade"); }
}

void OnTick()
{
   // Multi-symbol intelligence scans, approval expiry, recovery and position management are timer-driven.
}
