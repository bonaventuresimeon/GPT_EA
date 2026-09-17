   ObjectSetInteger(0,BTN_DENY,OBJPROP_XDISTANCE,155);
   ObjectSetInteger(0,BTN_DENY,OBJPROP_YDISTANCE,78);
   ObjectSetInteger(0,BTN_DENY,OBJPROP_XSIZE,125);
   ObjectSetInteger(0,BTN_DENY,OBJPROP_YSIZE,30);
   ObjectSetString(0,BTN_DENY,OBJPROP_TEXT,"DENY / DELETE");
   ChartRedraw();
}

void DeletePending(const int idx,const string reason)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   string sym=g_pending[idx].setup.symbol;
   g_pending[idx].active=false;
   PrintFormat("%s pending setup deleted: %s",sym,reason);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
      SendNotification(StringFormat("%s pending setup deleted: %s",sym,reason));
   RenderApprovalPrompt();
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

   string msg=StringFormat("Approval required: %s %s. APPROVE or DENY within %d seconds.",s.symbol,Arrow(s.bullish),timeout);
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
   g_pending[idx].active=false; // one-shot authorization
   RenderApprovalPrompt();
   if(ApprovedPlaceTrade(s))
   {
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": APPROVED - trade executed.");
   }
   else
   {
      Print(s.symbol,": APPROVED but fresh validation failed. Pending setup deleted; no order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approved, but setup became invalid; no trade opened.");
   }
}

// ----------------------------- Scanner ----------------------------
void ScanSymbol(const string sym,const string scanReason)
{
   if(!EnsureSymbol(sym)){ Print("Symbol unavailable: ",sym); return; }
   string trend=""; bool alignedBull=false,alignedBear=false;
   int score=MultiTFScore(sym,trend,alignedBull,alignedBear);
   bool bull=(score>=0);
   if(alignedBear) bull=false; else if(alignedBull) bull=true;
   int base=BaseConfidenceFromScore(score,alignedBull,alignedBear,bull);

   TradeSetup pb=BuildPullback(sym,bull,base,trend);
   TradeSetup br=BuildBreakoutRetest(sym,bull,base,trend);
   TradeSetup primary=ChoosePrimary(pb,br);

   string newsText,yieldText,spreadText,sessionText;
   bool newsBlock=CalendarBlock(sym,newsText);
   bool yieldBlock=YieldShock(yieldText);
   bool spreadOk=SpreadOK(sym,spreadText);
   double atr=0; ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr);
   bool sessionBlock=SessionConditionInvalidates(sym,primary.preferred,atr,sessionText);

   string card=BuildCard(primary,pb,br,scanReason,newsBlock,newsText,spreadText,spreadOk,yieldBlock,yieldText,sessionBlock,sessionText);

   bool requestAI=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || primary.confidence>=InpMinConfidence));
   if(requestAI)
   {
      string aiAnswer,aiError;
      if(CallOpenAI(BuildOpenAIPrompt(sym,card),aiAnswer,aiError))
         card += "\n\n━━━━━━━━━━━━━━━━━━━━\n🤖 OPENAI SECONDARY REVIEW\n━━━━━━━━━━━━━━━━━━━━\n"+aiAnswer;
      else
         card += "\n\nOpenAI review unavailable: "+aiError;
   }
   NotifyCard(card);

   bool allOK=(primary.valid && !newsBlock && !yieldBlock && !sessionBlock && spreadOk && primary.effectiveRR1>=InpMinEffectiveRR);
   if(allOK)
   {
      if(InpRequireApproval) QueueForApproval(primary,card,scanReason);
      else ApprovedPlaceTrade(primary);
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
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   EventSetTimer(MathMax(1,InpTimerSeconds));
   Print("GPT EA initialized. Approval=",InpRequireApproval?"REQUIRED":"DISABLED",
         ", Timeout=",InpApprovalTimeoutSeconds,"s",
         ", ApprovedExecution=",InpEnableApprovedExecution?"ON":"OFF");
   if(InpUseOpenAI && StringLen(Trim(InpOpenAIAPIKey))<20)
      Print("OpenAI enabled but API key is blank. Enter it locally in EA Inputs. Never commit the key.");
   if(InpUseOpenAI) Print("MT5 WebRequest allow-list must include: https://api.openai.com");
   ScanAll("EA startup scan");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteApprovalObjects();
   Comment("");
}

void OnTimer()
{
   ManagePositions();
   ProcessApprovalTimeouts();
   string why="";
   if(ScheduledScanDue(why)) ScanAll(why);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK || g_displayPending<0) return;
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
   // Multi-symbol scanning, prompt expiry and trade management are timer-driven.
}
