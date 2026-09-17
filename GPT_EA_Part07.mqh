// ============================================================================
// GPT_EA Part 07 - Approval workflow, advanced scanner and MT5 event hooks
// ============================================================================

void DeletePending(const int idx,const string reason)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   string sym=g_pending[idx].setup.symbol;
   g_pending[idx].active=false;
   PrintFormat("%s pending setup deleted: %s",sym,reason);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
      SendNotification(StringFormat("%s pending setup deleted: %s",sym,reason));
   RenderApprovalPrompt();
   StyleApprovalUI();
}

void QueueForApproval(const TradeSetup &s,const string card,const string scanReason)
{
   if(!s.valid) return;
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
   RenderApprovalPrompt();
   StyleApprovalUI();

   string msg=StringFormat("GPT_EA approval required: %s %s. APPROVE or DENY within %d seconds.",s.symbol,Arrow(s.bullish),timeout);
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

bool FreshApprovalValidation(const TradeSetup &s,string &why)
{
   why="";
   if(!s.valid){ why="Stored setup is no longer marked valid."; return false; }
   if(!PriceInsideZone(s)){ why="Price left the approved entry zone."; return false; }
   if(!M5Trigger(s)){ why="M5 execution trigger is no longer present."; return false; }

   ConfluenceReport fresh=EvaluateConfluence(s);
   if(InpUseAdvancedConfluence && !fresh.valid)
   {
      why=StringFormat("Advanced confluence fell to %d/100.",fresh.score);
      return false;
   }

   double liveRR=EffectiveRR(s.symbol,s.bullish,s.preferred,s.sl,s.tp2);
   if(liveRR<InpMinEffectiveRR)
   {
      why=StringFormat("Effective R:R deteriorated to %.2f below minimum %.2f.",liveRR,InpMinEffectiveRR);
      return false;
   }

   double atr=0; ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr);
   string sessionText="";
   if(SessionConditionInvalidates(s.symbol,s.preferred,atr,sessionText))
   {
      why=sessionText;
      return false;
   }
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
   g_pending[idx].active=false; // one-shot authorization; never leave dormant authorization
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
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": APPROVED - trade executed.");
   }
   else
   {
      Print(s.symbol,": APPROVED but broker/filter revalidation failed. No order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approved, but final broker/filter validation failed; no trade opened.");
   }
}

string FilterStateText(bool newsBlock,bool yieldBlock,bool spreadOk,bool sessionBlock,bool aiAllows)
{
   return StringFormat("Filters: News %s | Yield %s | Spread %s | Session %s | AI %s",
      newsBlock?"BLOCK":"OK",yieldBlock?"BLOCK":"OK",spreadOk?"OK":"BLOCK",sessionBlock?"BLOCK":"OK",aiAllows?"OK":"VETO");
}

// ----------------------------- Scanner ----------------------------
void ScanSymbol(const string sym,const string scanReason)
{
   if(!EnsureSymbol(sym)){ Print("Symbol unavailable: ",sym); return; }

   string trend="";
   bool alignedBull=false,alignedBear=false;
   int score=MultiTFScore(sym,trend,alignedBull,alignedBear);
   bool bull=(score>=0);
   if(alignedBear) bull=false;
   else if(alignedBull) bull=true;
   int base=BaseConfidenceFromScore(score,alignedBull,alignedBear,bull);

   TradeSetup pb=BuildPullback(sym,bull,base,trend);
   TradeSetup br=BuildBreakoutRetest(sym,bull,base,trend);

   ConfluenceReport pbReport=EvaluateConfluence(pb);
   ConfluenceReport brReport=EvaluateConfluence(br);
   ApplyAdvancedConfluence(pb,pbReport);
   ApplyAdvancedConfluence(br,brReport);

   TradeSetup primary=ChoosePrimary(pb,br);
   ConfluenceReport primaryReport;
   if(primary.kind==SETUP_BREAKOUT_RETEST) primaryReport=brReport;
   else primaryReport=pbReport;

   string newsText="",yieldText="",spreadText="",sessionText="";
   bool newsBlock=CalendarBlock(sym,newsText);
   bool yieldBlock=YieldShock(yieldText);
   bool spreadOk=SpreadOK(sym,spreadText);
   double atr=0; ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr);
   bool sessionBlock=SessionConditionInvalidates(sym,primary.preferred,atr,sessionText);

   bool readyNow=(primary.valid && PriceInsideZone(primary) && M5Trigger(primary));
   string upcoming=UpcomingEventSummary(sym);

   string card=BuildCard(primary,pb,br,scanReason,newsBlock,newsText,spreadText,spreadOk,yieldBlock,yieldText,sessionBlock,sessionText);
   card+=ConfluenceCardBlock(primaryReport,upcoming,readyNow);
   card+=StringFormat("Pullback confluence: %d/100 | Breakout-retest confluence: %d/100\n",pbReport.score,brReport.score);

   bool aiAvailable=false;
   string aiAnswer="",aiError="";
   bool requestAI=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || primary.confidence>=InpMinConfidence));
   if(requestAI)
   {
      aiAvailable=CallOpenAI(BuildOpenAIPrompt(sym,card),aiAnswer,aiError);
      if(aiAvailable)
         card += "\n━━━━━━━━━━━━━━━━━━━━\n🤖 OPENAI SECONDARY REVIEW\n━━━━━━━━━━━━━━━━━━━━\n"+aiAnswer+"\n";
      else
         card += "\nOpenAI review unavailable: "+aiError+"\n";
   }

   string aiGateWhy="";
   bool aiAllows=AIReviewAllowsExecution(aiAnswer,aiAvailable,aiGateWhy);
   if(!requestAI && InpAICanVetoTrade)
   {
      aiAllows=true;
      aiGateWhy="AI review not requested for this scan.";
   }

   bool confluencePass=(!InpUseAdvancedConfluence || primaryReport.valid);
   bool hardValid=(primary.valid && confluencePass && !newsBlock && !yieldBlock && !sessionBlock &&
                   spreadOk && primary.effectiveRR1>=InpMinEffectiveRR && aiAllows);
   bool approvalReady=(hardValid && readyNow);

   string filterState=FilterStateText(newsBlock,yieldBlock,spreadOk,sessionBlock,aiAllows);
   card+="\n"+filterState+"\n";
   card+="AI execution gate: "+aiGateWhy+"\n";
   card+=StringFormat("Approval status: %s\n",approvalReady?"✅ READY - APPROVE / DENY PROMPT ACTIVE":"⏳ NOT READY - NO ORDER AUTHORIZATION");

   NotifyCard(card);
   RenderAdvancedDashboard(primary,primaryReport,filterState,readyNow);

   int existing=ActivePendingForSymbol(sym);
   if(approvalReady)
   {
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
      DeletePending(existing,"fresh scan no longer meets high-confluence entry conditions");
   }
}

void ScanAll(const string reason)
{
   for(int i=0;i<ArraySize(g_symbols);i++)
      if(g_symbols[i]!="") ScanSymbol(g_symbols[i],reason);
}

// -------------------------- MT5 event hooks -----------------------
int OnInit()
{
   if(SplitSymbols()<=0)
   {
      Print("No symbols configured.");
      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   ApplyChartPolish();
   EventSetTimer(MathMax(1,InpTimerSeconds));

   Print("GPT_EA Advanced initialized. Approval=",InpRequireApproval?"REQUIRED":"DISABLED",
         ", Timeout=",InpApprovalTimeoutSeconds,"s",
         ", Min confluence=",InpMinAdvancedConfluence,
         ", ApprovedExecution=",InpEnableApprovedExecution?"ON":"OFF");

   if(InpUseOpenAI && StringLen(Trim(InpOpenAIAPIKey))<20)
      Print("OpenAI enabled but API key is blank. Enter it locally in EA Inputs. Never commit the key.");
   if(InpUseOpenAI)
      Print("MT5 WebRequest allow-list must include: https://api.openai.com");

   ScanAll("EA startup scan");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteApprovalObjects();
   DeleteAdvancedDashboard();
   Comment("");
}

void OnTimer()
{
   ManagePositions();
   ProcessApprovalTimeouts();
   StyleApprovalUI();

   string why="";
   if(ScheduledScanDue(why)) ScanAll(why);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(sparam==BTN_SCAN_NOW)
   {
      ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_STATE,false);
      ScanAll("Manual SCAN NOW");
      return;
   }

   if(g_displayPending<0) return;
   if(sparam==BTN_APPROVE)
   {
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_STATE,false);
      ApprovePending(g_displayPending);
   }
   else if(sparam==BTN_DENY)
   {
      ObjectSetInteger(0,BTN_DENY,OBJPROP_STATE,false);
      DeletePending(g_displayPending,"user denied trade");
   }
}

void OnTick()
{
   // Multi-symbol scanning, approval expiry and position management are timer-driven.
}
