// ============================================================================
// GPT_EA Part 33 - Trade lifecycle, GPT disagreement/integrity and replay snapshots
// ============================================================================

input bool   InpUseLifecycleStateMachine          = true;
input string InpLifecycleJournalFile              = "GPT_EA_Lifecycle.csv";
input bool   InpWriteDecisionSnapshots            = true;
input string InpDecisionSnapshotFile              = "GPT_EA_DecisionSnapshots.csv";
input int    InpDecisionSnapshotMaxText            = 1600;
input bool   InpUseGPTDisagreementGate            = true;
input int    InpGPTStrongDisagreementScore        = 2;
input bool   InpUseModelOutputIntegrity            = true;
input int    InpMinimumGPTReviewChars              = 20;
input int    InpStoredAIReviewMaxAgeSeconds        = 180;

enum TradeLifecycleState
{
   LIFE_NONE=0,
   LIFE_CANDIDATE=1,
   LIFE_WAIT_CONFIRMATION=2,
   LIFE_APPROVED=3,
   LIFE_SENT=4,
   LIFE_FILLED=5,
   LIFE_TP1_PARTIAL=6,
   LIFE_PROTECTED=7,
   LIFE_RUNNER=8,
   LIFE_CLOSED=9,
   LIFE_REJECTED=10,
   LIFE_INVALIDATED=11
};

string LifecycleStateName(int s)
{
   switch(s)
   {
      case LIFE_CANDIDATE: return "CANDIDATE";
      case LIFE_WAIT_CONFIRMATION: return "WAIT_CONFIRMATION";
      case LIFE_APPROVED: return "APPROVED";
      case LIFE_SENT: return "SENT";
      case LIFE_FILLED: return "FILLED";
      case LIFE_TP1_PARTIAL: return "TP1_PARTIAL";
      case LIFE_PROTECTED: return "PROTECTED";
      case LIFE_RUNNER: return "RUNNER";
      case LIFE_CLOSED: return "CLOSED";
      case LIFE_REJECTED: return "REJECTED";
      case LIFE_INVALIDATED: return "INVALIDATED";
      default: return "NONE";
   }
}

bool LifecycleTransitionAllowed(int from,int to)
{
   if(from==to) return true;
   if(from==LIFE_NONE) return (to==LIFE_CANDIDATE || to==LIFE_FILLED || to==LIFE_CLOSED);
   if(from==LIFE_CANDIDATE) return (to==LIFE_WAIT_CONFIRMATION || to==LIFE_APPROVED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_WAIT_CONFIRMATION) return (to==LIFE_APPROVED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_APPROVED) return (to==LIFE_SENT || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_SENT) return (to==LIFE_FILLED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_FILLED) return (to==LIFE_TP1_PARTIAL || to==LIFE_PROTECTED || to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_TP1_PARTIAL) return (to==LIFE_PROTECTED || to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_PROTECTED) return (to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_RUNNER) return (to==LIFE_CLOSED);
   if(from==LIFE_REJECTED || from==LIFE_INVALIDATED || from==LIFE_CLOSED) return (to==LIFE_CANDIDATE || to==LIFE_CLOSED);
   return false;
}

void EnsureLifecycleHeader()
{
   if(!InpUseLifecycleStateMachine) return;
   bool exists=FileIsExist(InpLifecycleJournalFile,FILE_COMMON);
   int h=FileOpen(InpLifecycleJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","symbol","position_id","from_state","to_state","strategy","reason");
   FileClose(h);
}

void WriteLifecycleEvent(const string sym,ulong pid,int from,int to,StrategyClass c,const string reason)
{
   if(!InpUseLifecycleStateMachine) return;
   EnsureLifecycleHeader();
   int h=FileOpen(InpLifecycleJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"lifecycle_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),sym,(string)pid,
      LifecycleStateName(from),LifecycleStateName(to),StrategyClassName(c),reason);
   FileFlush(h); FileClose(h);
}

bool SetSymbolLifecycle(const string sym,int to,const string reason)
{
   if(!InpUseLifecycleStateMachine) return true;
   string k=SymKey(sym,"LIFECYCLE_STATE");
   int from=(int)GVRead(k,LIFE_NONE);
   if(!LifecycleTransitionAllowed(from,to))
   {
      PrintFormat("%s lifecycle transition BLOCKED: %s -> %s | %s",sym,LifecycleStateName(from),LifecycleStateName(to),reason);
      return false;
   }
   StrategyClass c=CandidateStrategyForSymbol(sym);
   GVWrite(k,to); GVWrite(SymKey(sym,"LIFECYCLE_TIME"),(double)TimeTradeServer());
   WriteLifecycleEvent(sym,0,from,to,c,reason);
   return true;
}

bool SetPositionLifecycle(ulong ticket,int to,const string reason)
{
   if(!InpUseLifecycleStateMachine) return true;
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   int from=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_NONE);
   if(!LifecycleTransitionAllowed(from,to))
   {
      // Recovery may discover a broker-filled position before the pre-trade state was persisted.
      if(from==LIFE_NONE && (to==LIFE_FILLED || to==LIFE_PROTECTED || to==LIFE_RUNNER)) from=LIFE_FILLED;
      else
      {
         PrintFormat("%s position lifecycle transition BLOCKED: %s -> %s | %s",sym,LifecycleStateName(from),LifecycleStateName(to),reason);
         return false;
      }
   }
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),CandidateStrategyForSymbol(sym));
   GVWrite(PosKey(pid,"LIFECYCLE_STATE"),to); GVWrite(PosKey(pid,"LIFECYCLE_TIME"),(double)TimeTradeServer());
   WriteLifecycleEvent(sym,pid,from,to,c,reason);
   return true;
}

void AttachLifecycleToNewestPosition(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(GVRead(PosKey(pid,"LIFECYCLE_STATE"),0)<=0)
      GVWrite(PosKey(pid,"LIFECYCLE_STATE"),LIFE_SENT);
   SetPositionLifecycle(ticket,LIFE_FILLED,reason);
}

void RefreshOpenPositionLifecycles()
{
   if(!InpUseLifecycleStateMachine) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int current=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_NONE);
      if(current==LIFE_NONE) SetPositionLifecycle(tk,LIFE_FILLED,"restart/recovery lifecycle reconstruction");
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      bool tp2=PositionFlag(pid,tk,"TP2PARTIAL");
      if(partial && !done) SetPositionLifecycle(tk,LIFE_TP1_PARTIAL,"TP1 partial complete; protection pending");
      else if(done && tp2) SetPositionLifecycle(tk,LIFE_RUNNER,"TP2 scale-out complete; runner active");
      else if(done) SetPositionLifecycle(tk,LIFE_PROTECTED,"TP1 and required protection complete");
   }
}

void FinalizeClosedLifecycles()
{
   datetime now=TimeTradeServer(),from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-600);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"LIFE_FINAL"),0)>0.5) continue;
      string sym=HistoryDealGetString(d,DEAL_SYMBOL);
      int fromState=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_FILLED);
      StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
      GVWrite(PosKey(pid,"LIFECYCLE_STATE"),LIFE_CLOSED);
      GVWrite(PosKey(pid,"LIFECYCLE_TIME"),(double)HistoryDealGetInteger(d,DEAL_TIME));
      GVWrite(PosKey(pid,"LIFE_FINAL"),1);
      WriteLifecycleEvent(sym,pid,fromState,LIFE_CLOSED,c,"position no longer open; history finalized");
   }
}

int TextChecksum(const string s)
{
   long h=2166136261;
   int n=StringLen(s);
   for(int i=0;i<n;i++) h=(h ^ StringGetCharacter(s,i))*16777619;
   if(h<0) h=-h;
   return (int)(h%2147483647);
}

bool DeterministicSetupIntegrity(const TradeSetup &s,string &why)
{
   if(s.symbol=="" || s.preferred<=0 || s.sl<=0 || s.tp1<=0 || s.tp2<=0 || s.tp3<=0)
   { why="setup has missing symbol/price geometry"; return false; }
   if(s.zoneLow>s.zoneHigh){ why="entry zone low exceeds zone high"; return false; }
   if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1 && s.tp3>s.tp2))
   { why="bullish setup has contradictory SL/TP geometry"; return false; }
   if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1 && s.tp3<s.tp2))
   { why="bearish setup has contradictory SL/TP geometry"; return false; }
   datetime ct=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   if(ct>0 && TimeTradeServer()-ct>900){ why="candidate strategy identity is stale"; return false; }
   why="deterministic setup geometry and candidate freshness PASS";
   return true;
}

int GPTDisagreementScore(const TradeSetup &s,const string answer,bool available,string &detail)
{
   detail="GPT review unavailable or not requested.";
   if(!available || answer=="") return 0;
   string u=answer; StringToUpper(u);
   int score=0; string why="";
   bool opposite=(s.bullish?(StringFind(u,"BEARISH")>=0 || StringFind(u,"SHORT")>=0):
                            (StringFind(u,"BULLISH")>=0 || StringFind(u,"LONG")>=0));
   if(opposite){ score+=2; why+="explicit opposite direction; "; }
   if(StringFind(u,"BLOCK")>=0 || StringFind(u,"NO TRADE")>=0 || StringFind(u,"VETO")>=0){ score+=2; why+="explicit veto/no-trade; "; }
   else if(StringFind(u,"WAIT")>=0 || StringFind(u,"REANALYZE")>=0){ score+=1; why+="wait/reanalyze; "; }
   if(StringFind(u,"INVALID")>=0 && StringFind(u,"VALID")<0){ score+=1; why+="invalidity language; "; }
   detail=StringFormat("GPT disagreement score %d | %s",score,why);
   return score;
}

bool GPTReviewIntegrityAllows(const string sym,const TradeSetup &s,const string answer,bool available,bool requested,string &why)
{
   string det=""; if(!DeterministicSetupIntegrity(s,det)){ why="Deterministic integrity BLOCK: "+det; return false; }
   if(!InpUseModelOutputIntegrity){ why=det+" | model-output integrity disabled."; return true; }
   if(!requested){ why=det+" | GPT review not requested."; return true; }
   if(!available){ why=det+" | GPT unavailable; availability policy handled separately."; return true; }
   if(StringLen(answer)<InpMinimumGPTReviewChars){ why="GPT integrity BLOCK: response too short/malformed."; return false; }
   string u=answer; StringToUpper(u);
   if(StringFind(u,"API KEY")>=0 || StringFind(u,"AUTHORIZATION: BEARER")>=0)
   { why="GPT integrity BLOCK: response unexpectedly contains credential-like text."; return false; }
   if(StringFind(u,"OPENAI RESPONSE RECEIVED, BUT TEXT COULD NOT BE PARSED")>=0)
   { why="GPT integrity BLOCK: parser fallback text detected."; return false; }
   why=det+StringFormat(" | GPT review integrity PASS len %d checksum %d",StringLen(answer),TextChecksum(answer));
   return true;
}

bool GPTDisagreementAllowsHighConfidence(const TradeSetup &s,const string answer,bool available,string &why)
{
   if(!InpUseGPTDisagreementGate){ why="GPT disagreement gate disabled."; return true; }
   int d=GPTDisagreementScore(s,answer,available,why);
   if(d>=InpGPTStrongDisagreementScore)
   {
      why+=" | DOWNGRADE: deterministic setup retained, but high-confidence execution is withheld.";
      return false;
   }
   why+=" | no strong disagreement.";
   return true;
}

void PersistAIIntegrityDecision(const string sym,bool integrityOK,bool disagreementOK,bool requested,bool available,const string answer)
{
   GVWrite(SymKey(sym,"AI_INTEGRITY_OK"),integrityOK?1:0);
   GVWrite(SymKey(sym,"AI_DISAGREE_OK"),disagreementOK?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_REQUESTED"),requested?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_AVAILABLE"),available?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(sym,"AI_REVIEW_CHECKSUM"),TextChecksum(answer));
}

bool StoredAIIntegrityAllows(const string sym,string &why)
{
   bool requested=GVRead(SymKey(sym,"AI_REVIEW_REQUESTED"),0)>0.5;
   if(!requested){ why="No GPT review was required for stored candidate."; return true; }
   datetime tm=(datetime)GVRead(SymKey(sym,"AI_REVIEW_TIME"),0);
   if(tm<=0 || TimeTradeServer()-tm>InpStoredAIReviewMaxAgeSeconds)
   { why="Stored GPT integrity decision is stale; reanalysis required."; return false; }
   if(GVRead(SymKey(sym,"AI_INTEGRITY_OK"),0)<0.5){ why="Stored GPT output integrity failed."; return false; }
   if(GVRead(SymKey(sym,"AI_DISAGREE_OK"),0)<0.5){ why="Stored GPT/deterministic disagreement requires WAIT/REANALYZE."; return false; }
   why="Stored GPT integrity/disagreement state PASS.";
   return true;
}

void EnsureDecisionSnapshotHeader()
{
   if(!InpWriteDecisionSnapshots) return;
   bool exists=FileIsExist(InpDecisionSnapshotFile,FILE_COMMON);
   int h=FileOpen(InpDecisionSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","symbol","strategy","market_state","decision","side","entry","zone_low","zone_high","sl","tp1","tp2","tp3",
         "confidence","strategy_score","atr_ratio","opening_range_ratio","adx","rsi15","overextension_atr","volume_ratio","realistic_rr","risk_multiplier",
         "broker_health","strategy_mode","regime_transition","filters","web_summary","gpt_checksum","gpt_excerpt","reason");
   FileClose(h);
}

string SnapshotText(string s)
{
   int maxLen=MathMax(100,InpDecisionSnapshotMaxText);
   if(StringLen(s)>maxLen) s=StringSubstr(s,0,maxLen);
   StringReplace(s,"\r"," "); StringReplace(s,"\n"," ");
   return s;
}

void WriteDecisionSnapshot(const TradeSetup &s,const StrategyDecision &d,const string finalDecision,const string filters,const string webText,const string aiAnswer,const string reason)
{
   if(!InpWriteDecisionSnapshots || s.symbol=="") return;
   EnsureDecisionSnapshotHeader();
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   string rm="",bh=""; double mult=AdaptiveRiskMultiplier(s,rm),health=BrokerHealthScore(s.symbol,bh);
   int h=FileOpen(InpDecisionSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"decision_snapshot_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),s.symbol,StrategyClassName(d.strategy),MarketStateName(d.state),finalDecision,
      s.bullish?"BUY":"SELL",DoubleToString(s.preferred,DigitsFor(s.symbol)),DoubleToString(s.zoneLow,DigitsFor(s.symbol)),DoubleToString(s.zoneHigh,DigitsFor(s.symbol)),
      DoubleToString(s.sl,DigitsFor(s.symbol)),DoubleToString(s.tp1,DigitsFor(s.symbol)),DoubleToString(s.tp2,DigitsFor(s.symbol)),DoubleToString(s.tp3,DigitsFor(s.symbol)),
      s.confidence,d.score,DoubleToString(x.atrRatio,3),DoubleToString(x.openingRangeRatio,3),DoubleToString(x.adx,2),DoubleToString(x.rsi15,2),
      DoubleToString(x.overextensionATR,3),DoubleToString(x.volumeRatio,3),DoubleToString(RealisticRiskReward(s).rr,3),DoubleToString(mult,3),DoubleToString(health,1),
      AdaptiveStrategyModeName(StrategyHealthMode(d.strategy)),SnapshotText(RegimeTransitionText(s.symbol)),SnapshotText(filters),SnapshotText(webText),
      TextChecksum(aiAnswer),SnapshotText(aiAnswer),SnapshotText(reason+" | "+rm+" | "+bh));
   FileFlush(h); FileClose(h);
}

string LifecycleIntegritySummary(const string sym)
{
   int life=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
   string ai=""; bool ok=StoredAIIntegrityAllows(sym,ai);
   return "Lifecycle "+LifecycleStateName(life)+" | stored AI integrity "+(ok?"PASS":"BLOCK")+" | "+ai;
}

void LifecycleIntegrityInit()
{
   EnsureLifecycleHeader(); EnsureDecisionSnapshotHeader();
   RefreshOpenPositionLifecycles(); FinalizeClosedLifecycles();
   Print("GPT_EA lifecycle/integrity/replay engine initialized.");
}

void LifecycleIntegrityTimer()
{
   RefreshOpenPositionLifecycles(); FinalizeClosedLifecycles();
}
