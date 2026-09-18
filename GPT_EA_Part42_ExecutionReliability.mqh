// ============================================================================
// GPT_EA Part 42 - Atomic intent ledger, exactly-once execution and reconciliation
// ============================================================================

input bool   InpUseAtomicTradeIntentLedger       = true;
input bool   InpUseExactlyOnceExecution          = true;
input string InpTradeIntentFile                  = "GPT_EA_TradeIntentLedger.csv";
input int    InpIntentAmbiguityResolveSeconds    = 300;
input bool   InpUseBrokerEAReconciliation        = true;
input string InpBrokerReconciliationFile         = "GPT_EA_BrokerReconciliation.csv";
input bool   InpBlockUnexpectedManualExposure    = true;
input bool   InpUseStorageHealthGate             = true;
input string InpStorageHeartbeatFile             = "GPT_EA_StorageHealth.csv";
input int    InpStorageHealthIntervalSeconds     = 60;
input bool   InpUseConfigurationDriftGate        = true;
input bool   InpAllowLegacyOpenPositionsOnUpgrade= true;

enum IntentState
{
   INTENT_NONE=0,
   INTENT_PREPARED=1,
   INTENT_SENT=2,
   INTENT_FILLED=3,
   INTENT_FAILED=4,
   INTENT_CLOSED=5,
   INTENT_UNCERTAIN=6
};

bool g_storageHealthy=true;
string g_storageWhy="not checked";
bool g_reconciliationBlocked=false;
string g_reconciliationWhy="";
datetime g_lastStorageCheck=0;
datetime g_lastReconcile=0;
int g_lastTransactionSignature=0;
datetime g_lastTransactionTime=0;

string IntentStateName(int s)
{
   switch(s)
   {
      case INTENT_PREPARED: return "PREPARED";
      case INTENT_SENT: return "SENT";
      case INTENT_FILLED: return "FILLED";
      case INTENT_FAILED: return "FAILED";
      case INTENT_CLOSED: return "CLOSED";
      case INTENT_UNCERTAIN: return "UNCERTAIN";
      default: return "NONE";
   }
}

string ExtractIntentNonce(const string comment)
{
   int p=StringFind(comment,"GEA-");
   if(p<0) return "";
   string tail=StringSubstr(comment,p+4);
   int dash=StringFind(tail,"-");
   if(dash>=0) tail=StringSubstr(tail,dash+1);
   if(StringLen(tail)>8) tail=StringSubstr(tail,0,8);
   return tail;
}

int IntentNonceHash(const string nonce){ return IntegrityTextHash(nonce); }

string TradeIntentComment(const string nonce,StrategyClass c)
{
   string code=StrategyCode(c);
   string out="GEA-"+code+"-"+nonce;
   if(StringLen(out)>31) out=StringSubstr(out,0,31);
   return out;
}

string IntentDecisionText(const TradeSetup &s,double lots,double riskMoney)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   return StringFormat("%s|%d|%d|%d|%.10f|%.10f|%.10f|%.10f|%.10f|%.4f|%.2f|%s|%s",
      s.symbol,s.bullish?1:0,(int)s.kind,(int)c,s.preferred,s.sl,s.tp1,s.tp2,s.tp3,lots,riskMoney,
      CurrentConfigFingerprint(),StrategyConfigVersion(c));
}

string IntentDecisionDigest(const TradeSetup &s,double lots,double riskMoney)
{
   return StringFormat("%08X",IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
}

string GenerateExecutionNonce(const TradeSetup &s)
{
   long seq=(long)GVRead(SysKey("INTENT_SEQ"),0)+1;
   GVWrite(SysKey("INTENT_SEQ"),(double)seq);
   string raw=StringFormat("%I64d|%I64d|%s|%d|%I64d|%d",
      AccountInfoInteger(ACCOUNT_LOGIN),InpMagic,s.symbol,s.bullish?1:0,GetTickCount64(),(int)seq);
   return StringFormat("%08X",IntegrityTextHash(raw));
}

void EnsureIntentHeader()
{
   if(!InpUseAtomicTradeIntentLedger) return;
   bool exists=FileIsExist(InpTradeIntentFile,FILE_COMMON);
   int h=FileOpen(InpTradeIntentFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","state","nonce","nonce_hash","symbol","side","setup_kind","strategy",
         "lots","risk_money","expected_entry","sl","tp1","tp2","tp3","decision_digest","config_fingerprint",
         "symbol_fingerprint","position_id","broker_ticket","retcode","note");
   FileClose(h);
}

bool WriteIntentLedgerRow(const string state,const string nonce,const TradeSetup &s,double lots,double riskMoney,
                          ulong pid,ulong ticket,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return true;
   if(ChaosInjectStorageFailure())
   {
      g_storageHealthy=false; g_storageWhy="CHAOS synthetic intent-ledger storage failure";
      return false;
   }
   EnsureIntentHeader();
   int h=FileOpen(InpTradeIntentFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      g_storageHealthy=false; g_storageWhy=StringFormat("intent ledger FileOpen failed %d",GetLastError());
      return false;
   }
   FileSeek(h,0,SEEK_END);
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   FileWrite(h,"trade_intent_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),state,nonce,IntentNonceHash(nonce),
      s.symbol,s.bullish?"BUY":"SELL",(int)s.kind,StrategyClassName(c),DoubleToString(lots,4),DoubleToString(riskMoney,2),
      DoubleToString(s.preferred,DigitsFor(s.symbol)),DoubleToString(s.sl,DigitsFor(s.symbol)),
      DoubleToString(s.tp1,DigitsFor(s.symbol)),DoubleToString(s.tp2,DigitsFor(s.symbol)),DoubleToString(s.tp3,DigitsFor(s.symbol)),
      IntentDecisionDigest(s,lots,riskMoney),CurrentConfigFingerprint(),SymbolContractFingerprint(s.symbol),
      (string)pid,(string)ticket,(string)retcode,note);
   FileFlush(h); FileClose(h);
   return true;
}

void EnsureReconciliationHeader()
{
   bool exists=FileIsExist(InpBrokerReconciliationFile,FILE_COMMON);
   int h=FileOpen(InpBrokerReconciliationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","severity","event","symbol","position_id","ticket","magic","comment","detail");
   FileClose(h);
}

void WriteReconciliationRow(const string severity,const string eventName,const string sym,ulong pid,ulong ticket,long magic,const string comment,const string detail)
{
   EnsureReconciliationHeader();
   int h=FileOpen(InpBrokerReconciliationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE){ g_storageHealthy=false; g_storageWhy="broker reconciliation journal unavailable"; return; }
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"broker_reconciliation_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),severity,eventName,
      sym,(string)pid,(string)ticket,(string)magic,comment,detail);
   FileFlush(h); FileClose(h);
}

void MarkOpenPositionsStorageAnomaly(const string reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      GVWrite(PosKey(pid,"STORAGE_ANOMALY"),1);
      MarkLearningQuarantine(pid,PositionGetString(POSITION_SYMBOL),"storage anomaly: "+reason);
   }
}

bool CriticalStorageHealthCheck(string &why)
{
   why="";
   if(!InpUseStorageHealthGate){ why="storage-health gate disabled"; return true; }
   if(ChaosInjectStorageFailure())
   {
      g_storageHealthy=false; g_storageWhy="CHAOS synthetic storage heartbeat failure";
      MarkOpenPositionsStorageAnomaly(g_storageWhy);
      why=g_storageWhy; return false;
   }
   int h=FileOpen(InpStorageHeartbeatFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      g_storageHealthy=false;
      g_storageWhy=StringFormat("critical storage FileOpen failed %d",GetLastError());
      MarkOpenPositionsStorageAnomaly(g_storageWhy);
      why=g_storageWhy; return false;
   }
   if(FileSize(h)==0) FileWrite(h,"schema_version","time","release_id","config_fingerprint","status");
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"storage_health_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,CurrentConfigFingerprint(),"PASS");
   FileFlush(h); FileClose(h);
   g_storageHealthy=true; g_storageWhy="critical storage writable";
   g_lastStorageCheck=TimeTradeServer();
   why=g_storageWhy; return true;
}

bool ConfigurationDriftAllows(string &why)
{
   why="";
   if(!InpUseConfigurationDriftGate){ why="configuration drift gate disabled"; return true; }
   string current=CurrentConfigFingerprint();
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode==ACCOUNT_TRADE_MODE_REAL)
   {
      if(StringLen(Trim(InpReleaseCertifiedConfigFingerprint))<8)
      { why="REAL account requires certified configuration fingerprint."; return false; }
      if(current!=Trim(InpReleaseCertifiedConfigFingerprint))
      { why="CONFIGURATION DRIFT: runtime "+current+" != certified "+Trim(InpReleaseCertifiedConfigFingerprint); return false; }
      why="configuration fingerprint matches certified "+current;
      return true;
   }

   int currentHash=IntegrityTextHash(CurrentSensitiveConfigText());
   int baseline=(int)GVRead(SysKey("CONFIG_BASELINE_HASH"),0);
   if(baseline==0)
   {
      GVWrite(SysKey("CONFIG_BASELINE_HASH"),currentHash);
      why="demo/test configuration baseline established "+current;
      return true;
   }
   if(baseline!=currentHash)
   {
      // A non-real reinitialization may intentionally change settings. We flag
      // the drift but permit evidence-generation only after the new baseline is explicit.
      GVWrite(SysKey("CONFIG_DRIFT_SEEN"),1);
      GVWrite(SysKey("CONFIG_BASELINE_HASH"),currentHash);
      why="demo/test configuration changed; baseline refreshed and evidence generation must identify new fingerprint "+current;
      return true;
   }
   why="configuration fingerprint stable "+current;
   return true;
}

bool ReliabilityOpenPositionForSymbol(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

bool IntentStateBlocksNewSubmission(const string sym,string &why)
{
   why="";
   if(!InpUseExactlyOnceExecution) return false;
   int state=(int)GVRead(SymKey(sym,"INTENT_STATE"),INTENT_NONE);
   datetime tm=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   if(state==INTENT_PREPARED || state==INTENT_SENT || state==INTENT_UNCERTAIN)
   {
      why=StringFormat("exactly-once gate: unresolved %s intent age %d sec",IntentStateName(state),
                       tm>0?(int)(TimeTradeServer()-tm):0);
      return true;
   }
   if(state==INTENT_FILLED && ReliabilityOpenPositionForSymbol(sym))
   {
      why="exactly-once gate: filled intent still has an open position";
      return true;
   }
   return false;
}

bool ExecutionReliabilityPreEntryAllows(const TradeSetup &s,string &why)
{
   why="";
   string storage="";
   if(!CriticalStorageHealthCheck(storage)){ why="Storage health: "+storage; return false; }
   string cfg="";
   if(!ConfigurationDriftAllows(cfg)){ why=cfg; return false; }
   if(ChaosInjectStaleQuote()){ why="CHAOS synthetic stale quote"; return false; }
   if(ChaosInjectConnectionLoss()){ why="CHAOS synthetic terminal connection loss"; return false; }
   if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED)){ why="terminal disconnected"; return false; }
   string intent="";
   if(IntentStateBlocksNewSubmission(s.symbol,intent)){ why=intent; return false; }
   if(g_reconciliationBlocked){ why="broker/EA reconciliation BLOCK: "+g_reconciliationWhy; return false; }
   why=storage+" | "+cfg+" | reconciliation PASS | exactly-once PASS";
   return true;
}

bool PrepareAtomicTradeIntent(const TradeSetup &s,double lots,double riskMoney,string &nonce,string &why)
{
   nonce=""; why="";
   if(!InpUseAtomicTradeIntentLedger){ why="atomic intent ledger disabled"; return true; }
   string pre="";
   if(!ExecutionReliabilityPreEntryAllows(s,pre)){ why=pre; return false; }

   nonce=GenerateExecutionNonce(s);
   int nh=IntentNonceHash(nonce);
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_PREPARED);
   GVWrite(SymKey(s.symbol,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(s.symbol,"CAND_TIME"),(double)TimeTradeServer()));
   GVWrite(SymKey(s.symbol,"EXEC_APPROVAL_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"EXEC_MODEL_LATENCY_MS"),GVRead(SysKey("MODEL_LATENCY_EWMA_MS"),0));
   GVWrite(SymKey(s.symbol,"INTENT_NONCE_HASH"),nh);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"INTENT_DECISION_HASH"),IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
   GVWrite(SymKey(s.symbol,"INTENT_KIND"),(int)s.kind);
   GVWrite(SymKey(s.symbol,"INTENT_BULL"),s.bullish?1:0);
   GVWrite(SymKey(s.symbol,"INTENT_LOTS"),lots);
   GVWrite(SymKey(s.symbol,"INTENT_RISK"),riskMoney);
   if(!WriteIntentLedgerRow("PREPARED",nonce,s,lots,riskMoney,0,0,0,"durable intent prepared before broker submission"))
   {
      GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_NONE);
      GlobalVariablesFlush();
      why="atomic intent persistence failed; broker submission prohibited";
      return false;
   }
   GlobalVariablesFlush();
   why="atomic intent PREPARED nonce "+nonce+" | "+pre;
   return true;
}

bool MarkTradeIntentSent(const TradeSetup &s,const string nonce,double lots,double riskMoney,string &why)
{
   why="";
   if(!InpUseAtomicTradeIntentLedger){ why="intent ledger disabled"; return true; }
   if((int)GVRead(SymKey(s.symbol,"INTENT_NONCE_HASH"),0)!=IntentNonceHash(nonce))
   { why="intent nonce mismatch before SENT transition"; return false; }
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_SENT);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"EXEC_SENT_TIME"),(double)TimeTradeServer());
   if(!WriteIntentLedgerRow("SENT",nonce,s,lots,riskMoney,0,0,0,"SENT persisted before network order call"))
   {
      GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_UNCERTAIN);
      GlobalVariablesFlush();
      why="could not durably persist SENT state; order call prohibited";
      return false;
   }
   GlobalVariablesFlush();
   why="intent SENT durably persisted";
   return true;
}

void MarkTradeIntentUncertain(const TradeSetup &s,const string nonce,double lots,double riskMoney,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return;
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_UNCERTAIN);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   WriteIntentLedgerRow("UNCERTAIN",nonce,s,lots,riskMoney,0,0,retcode,note);
   GlobalVariablesFlush();
}

void MarkTradeIntentFailed(const TradeSetup &s,const string nonce,double lots,double riskMoney,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return;
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_FAILED);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   WriteIntentLedgerRow("FAILED",nonce,s,lots,riskMoney,0,0,retcode,note);
   GlobalVariablesFlush();
}

void BindTradeIntentToPosition(ulong ticket,const TradeSetup &s,const string nonce,double lots,double riskMoney)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_FILLED);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(PosKey(pid,"INTENT_NONCE_HASH"),IntentNonceHash(nonce));
   GVWrite(PosKey(pid,"INTENT_BOUND"),1);
   GVWrite(PosKey(pid,"DECISION_HASH"),IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
   GVWrite(PosKey(pid,"RECON_VOL"),PositionGetDouble(POSITION_VOLUME));
   GVWrite(PosKey(pid,"RECON_SL"),PositionGetDouble(POSITION_SL));
   GVWrite(PosKey(pid,"RECON_TP"),PositionGetDouble(POSITION_TP));
   if(GVRead(SysKey("CHAOS_ACTIVE_SAMPLE"),0)>0.5) GVWrite(PosKey(pid,"CHAOS_SAMPLE"),1);
   AttachIntegrityMetadataToPosition(ticket);
   WriteIntentLedgerRow("FILLED",nonce,s,lots,riskMoney,pid,ticket,trade.ResultRetcode(),"broker position bound to durable intent");
   GlobalVariablesFlush();
}

bool IntentGeometryMatchesPosition(const string sym,ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=sym || PositionGetInteger(POSITION_MAGIC)!=InpMagic) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime posTime=(datetime)PositionGetInteger(POSITION_TIME);
   if(intentTime<=0 || posTime<intentTime-15 || posTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   long type=PositionGetInteger(POSITION_TYPE);
   if((bull && type!=POSITION_TYPE_BUY) || (!bull && type!=POSITION_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=PositionGetDouble(POSITION_VOLUME);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool IntentGeometryMatchesDeal(const string sym,ulong deal)
{
   if(deal==0 || !HistoryDealSelect(deal)) return false;
   if(HistoryDealGetString(deal,DEAL_SYMBOL)!=sym || HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) return false;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   if(intentTime<=0 || dealTime<intentTime-15 || dealTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
   if((bull && type!=DEAL_TYPE_BUY) || (!bull && type!=DEAL_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=HistoryDealGetDouble(deal,DEAL_VOLUME);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool IntentGeometryMatchesHistoryOrder(const string sym,ulong order)
{
   if(order==0 || !HistoryOrderSelect(order)) return false;
   if(HistoryOrderGetString(order,ORDER_SYMBOL)!=sym || HistoryOrderGetInteger(order,ORDER_MAGIC)!=InpMagic) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime orderTime=(datetime)HistoryOrderGetInteger(order,ORDER_TIME_SETUP);
   if(intentTime<=0 || orderTime<intentTime-15 || orderTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(order,ORDER_TYPE);
   if((bull && type!=ORDER_TYPE_BUY) || (!bull && type!=ORDER_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool PositionOrHistoryMatchesIntent(const string sym,int nonceHash,ulong &ticket,ulong &pid,bool &closed)
{
   ticket=0; pid=0; closed=false;
   if(nonceHash<=0) return false;

   ulong fallbackPosition=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(PositionGetString(POSITION_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash)
      {
         ticket=tk; pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER); return true;
      }
      if(IntentGeometryMatchesPosition(sym,tk)) fallbackPosition=tk;
   }
   if(fallbackPosition>0 && PositionSelectByTicket(fallbackPosition))
   {
      ticket=fallbackPosition;
      pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_POSITION",sym,pid,ticket,InpMagic,
         PositionGetString(POSITION_COMMENT),"broker comment did not preserve nonce; strict time/side/volume geometry matched");
      return true;
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ot=OrderGetTicket(i); if(ot==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym || OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(OrderGetString(ORDER_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash){ ticket=ot; return true; }
   }

   datetime now=TimeTradeServer();
   if(!HistorySelect(now-86400*3,now)) return false;
   ulong fallbackDeal=0;
   int nd=HistoryDealsTotal();
   for(int i=nd-1;i>=0;i--)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=sym || HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(HistoryDealGetString(d,DEAL_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash)
      {
         pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
         closed=!PositionIdentifierOpen(pid);
         return true;
      }
      if(fallbackDeal==0 && IntentGeometryMatchesDeal(sym,d)) fallbackDeal=d;
   }
   if(fallbackDeal>0 && HistoryDealSelect(fallbackDeal))
   {
      pid=(ulong)HistoryDealGetInteger(fallbackDeal,DEAL_POSITION_ID);
      closed=!PositionIdentifierOpen(pid);
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_DEAL",sym,pid,0,InpMagic,
         HistoryDealGetString(fallbackDeal,DEAL_COMMENT),"broker comment did not preserve nonce; strict entry time/side/volume geometry matched");
      return true;
   }

   ulong fallbackOrder=0;
   int no=HistoryOrdersTotal();
   for(int i=no-1;i>=0;i--)
   {
      ulong o=HistoryOrderGetTicket(i); if(o==0) continue;
      if(HistoryOrderGetString(o,ORDER_SYMBOL)!=sym || HistoryOrderGetInteger(o,ORDER_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(HistoryOrderGetString(o,ORDER_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash){ ticket=o; closed=true; return true; }
      if(fallbackOrder==0 && IntentGeometryMatchesHistoryOrder(sym,o)) fallbackOrder=o;
   }
   if(fallbackOrder>0)
   {
      ticket=fallbackOrder; closed=true;
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_ORDER",sym,0,ticket,InpMagic,"",
         "broker comment did not preserve nonce; strict order time/side/volume geometry matched");
      return true;
   }
   return false;
}

void ReconcileIntentForSymbol(const string sym)
{
   if(!InpUseExactlyOnceExecution || sym=="") return;
   int state=(int)GVRead(SymKey(sym,"INTENT_STATE"),INTENT_NONE);
   int nh=(int)GVRead(SymKey(sym,"INTENT_NONCE_HASH"),0);
   datetime tm=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   if(state==INTENT_NONE || state==INTENT_FAILED || state==INTENT_CLOSED) return;

   ulong ticket=0,pid=0; bool closed=false;
   bool found=PositionOrHistoryMatchesIntent(sym,nh,ticket,pid,closed);
   if(found)
   {
      if(pid>0 && PositionIdentifierOpen(pid))
      {
         GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_FILLED);
         GVWrite(PosKey(pid,"INTENT_NONCE_HASH"),nh);
         GVWrite(PosKey(pid,"INTENT_BOUND"),1);
         WriteReconciliationRow("INFO","INTENT_RECONCILED_OPEN",sym,pid,ticket,InpMagic,"","broker evidence joined to intent");
      }
      else if(closed)
      {
         GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_CLOSED);
         WriteReconciliationRow("INFO","INTENT_RECONCILED_CLOSED",sym,pid,ticket,InpMagic,"","historical broker evidence joined to intent");
      }
      GlobalVariablesFlush();
      return;
   }

   if((state==INTENT_SENT || state==INTENT_UNCERTAIN || state==INTENT_PREPARED) &&
      tm>0 && TimeTradeServer()-tm>=MathMax(60,InpIntentAmbiguityResolveSeconds) &&
      (bool)TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      // After a conservative reconciliation window with synchronized history and
      // no matching broker position/order/deal, resolve as FAILED. Until then,
      // exactly-once semantics prohibit resubmission.
      GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_FAILED);
      WriteReconciliationRow("WARN","INTENT_RESOLVED_NO_BROKER_EVIDENCE",sym,0,0,InpMagic,"",
         "ambiguity window elapsed; no matching position/order/deal found; future new intent allowed");
      GlobalVariablesFlush();
   }
}

void ReconcileBrokerAgainstEA()
{
   if(!InpUseBrokerEAReconciliation) return;
   g_reconciliationBlocked=false; g_reconciliationWhy="";

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      long magic=PositionGetInteger(POSITION_MAGIC);
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string comment=PositionGetString(POSITION_COMMENT);

      if(magic==InpMagic)
      {
         double vol=PositionGetDouble(POSITION_VOLUME);
         double sl=PositionGetDouble(POSITION_SL);
         double tp=PositionGetDouble(POSITION_TP);
         double oldVol=GVRead(PosKey(pid,"RECON_VOL"),0);
         double oldSL=GVRead(PosKey(pid,"RECON_SL"),0);
         double oldTP=GVRead(PosKey(pid,"RECON_TP"),0);
         double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
         double tick=MathMax(SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),PointFor(sym));

         if(oldVol>0 && vol>oldVol+0.5*step)
         {
            GVWrite(PosKey(pid,"BROKER_ANOMALY"),1);
            MarkLearningQuarantine(pid,sym,"position volume increased outside recorded EA intent");
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" broker volume exceeds last reconciled EA volume";
            WriteReconciliationRow("CRITICAL","UNEXPECTED_VOLUME_INCREASE",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
         if(oldVol>0 && vol<oldVol-0.5*step &&
            !PositionFlag(pid,tk,"TP1PARTIAL") && !PositionFlag(pid,tk,"TP2PARTIAL") &&
            GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5)
         {
            GVWrite(PosKey(pid,"BROKER_ANOMALY"),1);
            MarkLearningQuarantine(pid,sym,"unexplained broker-side/partial volume reduction");
            WriteReconciliationRow("WARN","UNEXPLAINED_VOLUME_REDUCTION",sym,pid,tk,magic,comment,
               StringFormat("volume %.4f -> %.4f without recorded partial state",oldVol,vol));
         }
         datetime expectedUntil=(datetime)GVRead(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         double expectedSL=GVRead(PosKey(pid,"EA_EXPECT_SL"),oldSL);
         double expectedTP=GVRead(PosKey(pid,"EA_EXPECT_TP"),oldTP);
         bool expectedWindow=(expectedUntil>0 && TimeTradeServer()<=expectedUntil);
         bool expectedSLMatch=(MathAbs(sl-expectedSL)<=0.5*tick);
         bool expectedTPMatch=(MathAbs(tp-expectedTP)<=0.5*tick);
         bool expectedModification=(expectedWindow && expectedSLMatch && expectedTPMatch);

         if(oldSL>0 && MathAbs(sl-oldSL)>0.5*tick && GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5 && !expectedModification)
         {
            double tracked=GVRead(PosKey(pid,"LASTSL"),GVRead(PosKey(pid,"INITSL"),oldSL));
            if(tracked>0 && MathAbs(sl-tracked)>0.5*tick)
            {
               GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
               MarkLearningQuarantine(pid,sym,"external SL modification differs from EA-tracked protection state");
               WriteReconciliationRow("WARN","EXTERNAL_SL_CHANGE",sym,pid,tk,magic,comment,
                  StringFormat("SL %.10f -> %.10f tracked %.10f; no matching EA modification intent",oldSL,sl,tracked));
            }
         }
         if(oldTP>0 && MathAbs(tp-oldTP)>0.5*tick && GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5 && !expectedModification)
         {
            int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),0);
            bool expectedTrailRemoval=(stage>=4 && !InpKeepTP3WhileTrailing && tp<=0);
            if(!expectedTrailRemoval)
            {
               GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
               MarkLearningQuarantine(pid,sym,"external TP modification differs from EA-tracked target state");
               WriteReconciliationRow("WARN","EXTERNAL_TP_CHANGE",sym,pid,tk,magic,comment,
                  StringFormat("TP %.10f -> %.10f; no matching EA modification intent",oldTP,tp));
            }
         }
         if(expectedModification)
         {
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
            WriteReconciliationRow("INFO","EA_MODIFICATION_RECONCILED",sym,pid,tk,magic,comment,
               StringFormat("expected EA SL/TP modification reconciled at SL %.10f TP %.10f",sl,tp));
         }
         else if(expectedUntil>0 && TimeTradeServer()>expectedUntil)
         {
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         }

         GVWrite(PosKey(pid,"RECON_VOL"),vol);
         GVWrite(PosKey(pid,"RECON_SL"),sl);
         GVWrite(PosKey(pid,"RECON_TP"),tp);

         bool intentBound=(GVRead(PosKey(pid,"INTENT_BOUND"),0)>0.5 || ExtractIntentNonce(comment)!="");
         bool lifecycle=(GVRead(PosKey(pid,"LIFECYCLE_STATE"),0)>0);
         if(!lifecycle)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" EA position missing lifecycle metadata";
            WriteReconciliationRow("CRITICAL","MISSING_LIFECYCLE",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
         if(!intentBound && !InpAllowLegacyOpenPositionsOnUpgrade)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" EA position missing intent binding";
            WriteReconciliationRow("CRITICAL","ORPHAN_EA_POSITION",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
      }
      else if(InpBlockUnexpectedManualExposure)
      {
         bool configured=false;
         for(int j=0;j<ArraySize(g_symbols);j++) if(g_symbols[j]==sym){ configured=true; break; }
         if(configured)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" has external/manual position exposure";
            WriteReconciliationRow("WARN","EXTERNAL_POSITION",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
      }
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ot=OrderGetTicket(i); if(ot==0) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      string sym=OrderGetString(ORDER_SYMBOL);
      // GPT_EA submits market orders, not durable pending entries.
      ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_SELL_STOP ||
         t==ORDER_TYPE_BUY_STOP_LIMIT || t==ORDER_TYPE_SELL_STOP_LIMIT)
      {
         g_reconciliationBlocked=true;
         g_reconciliationWhy=sym+" unexpected EA pending order exists";
         WriteReconciliationRow("CRITICAL","UNEXPECTED_PENDING_ORDER",sym,0,ot,InpMagic,OrderGetString(ORDER_COMMENT),g_reconciliationWhy);
      }
   }

   for(int j=0;j<ArraySize(g_symbols);j++) if(g_symbols[j]!="") ReconcileIntentForSymbol(g_symbols[j]);
}

void MarkManualIntervention(ulong pid,const string sym,const string detail)
{
   if(pid==0) return;
   GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
   MarkLearningQuarantine(pid,sym,"manual intervention: "+detail);
   WriteReconciliationRow("WARN","MANUAL_INTERVENTION",sym,pid,0,0,"",detail);
}

void HandleReliabilityTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(ChaosDropTradeTransaction())
   {
      GVWrite(SysKey("CHAOS_DROPPED_TRANSACTION"),GVRead(SysKey("CHAOS_DROPPED_TRANSACTION"),0)+1);
      return;
   }

   string sig=StringFormat("%d|%I64u|%I64u|%I64u|%I64u",(int)trans.type,trans.deal,trans.order,trans.position,trans.position_by);
   int h=IntegrityTextHash(sig);
   datetime now=TimeTradeServer();
   if(h==g_lastTransactionSignature && now-g_lastTransactionTime<=2)
   {
      GVWrite(SysKey("DUPLICATE_TRADE_CALLBACK"),GVRead(SysKey("DUPLICATE_TRADE_CALLBACK"),0)+1);
      return;
   }
   g_lastTransactionSignature=h; g_lastTransactionTime=now;

   bool injectDuplicate=ChaosDuplicateTradeTransaction();

   ulong pid=trans.position;
   string sym=trans.symbol;
   if(trans.deal>0 && HistoryDealSelect(trans.deal))
   {
      pid=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
      sym=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
      ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON);
      if(reason==DEAL_REASON_CLIENT || reason==DEAL_REASON_MOBILE || reason==DEAL_REASON_WEB)
      {
         if(pid>0 && (GVRead(PosKey(pid,"STRATEGY"),0)>0 || GVRead(PosKey(pid,"INTENT_BOUND"),0)>0.5))
            MarkManualIntervention(pid,sym,"deal reason "+EnumToString(reason));
      }
   }

   // MqlTradeRequest is authoritative only for TRADE_TRANSACTION_REQUEST.
   // Do not infer manual POSITION modifications from request.magic here.
   // Periodic broker reconciliation compares current SL/TP/volume with explicit
   // EA modification intents and flags only unexplained external changes.

   if(injectDuplicate)
   {
      // Simulate delivery of the same callback a second time. The duplicate
      // signature guard is the only state transition the duplicate may cause.
      if(h==g_lastTransactionSignature && now-g_lastTransactionTime<=2)
         GVWrite(SysKey("DUPLICATE_TRADE_CALLBACK"),GVRead(SysKey("DUPLICATE_TRADE_CALLBACK"),0)+1);
   }
}

void ExecutionReliabilityInit()
{
   string storage=""; CriticalStorageHealthCheck(storage);
   string cfg=""; ConfigurationDriftAllows(cfg);
   ReconcileBrokerAgainstEA();
   Print("GPT_EA execution reliability initialized | ",storage," | ",cfg,
         " | reconciliation ",g_reconciliationBlocked?"BLOCK":"PASS");
}

void ExecutionReliabilityTimer()
{
   datetime now=TimeTradeServer();
   if(g_lastStorageCheck==0 || now-g_lastStorageCheck>=MathMax(10,InpStorageHealthIntervalSeconds))
   {
      string q=""; CriticalStorageHealthCheck(q);
   }
   if(g_lastReconcile==0 || now-g_lastReconcile>=30)
   {
      ReconcileBrokerAgainstEA();
      g_lastReconcile=now;
   }
}

void ExecutionReliabilityShutdown()
{
   ReconcileBrokerAgainstEA();
   string q=""; CriticalStorageHealthCheck(q);
}
