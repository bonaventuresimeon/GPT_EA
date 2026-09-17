// ============================================================================
// GPT_EA Part 23 - Full intelligence decision observability
// ============================================================================

input bool   InpWriteIntelligenceJournal = true;
input string InpIntelligenceJournalFile  = "GPT_EA_Intelligence.csv";
input int    InpIntelligenceCardMaxChars = 30000;

string CardLineValue(const string card,const string prefix)
{
   int p=StringFind(card,prefix); if(p<0) return "";
   p+=StringLen(prefix);
   int e=StringFind(card,"\n",p); if(e<0) e=StringLen(card);
   string out=StringSubstr(card,p,e-p);
   StringTrimLeft(out); StringTrimRight(out);
   return out;
}

void PersistLastIntelligenceDecision(const string card)
{
   string asset=CardLineValue(card,"Asset:");
   if(asset=="") return;
   GVWrite(SymKey(asset,"INTEL_LAST_TIME"),(double)TimeTradeServer());
   string finalDecision=CardLineValue(card,"FINAL DECISION:");
   int code=(StringFind(finalDecision,"HIGH-CONFIDENCE")>=0?2:(StringFind(finalDecision,"WAIT")>=0?1:0));
   GVWrite(SymKey(asset,"INTEL_LAST_DECISION"),code);
}

void WriteIntelligenceDecisionJournal(const string card)
{
   if(!InpWriteIntelligenceJournal || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpIntelligenceJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE)
   {
      Print("Intelligence journal open failed: ",GetLastError());
      return;
   }
   if(FileSize(h)==0)
      FileWrite(h,"server_time","asset","classification","market_state","strategy_decision","final_decision","full_card");
   FileSeek(h,0,SEEK_END);
   string payload=StringSubstr(card,0,MathMax(1000,InpIntelligenceCardMaxChars));
   FileWrite(h,
      TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
      CardLineValue(card,"Asset:"),
      CardLineValue(card,"Classification:"),
      CardLineValue(card,"Market state:"),
      CardLineValue(card,"Decision:"),
      CardLineValue(card,"FINAL DECISION:"),
      payload);
   FileFlush(h); FileClose(h);
}

void NotifyCardObserved(const string card)
{
   PersistLastIntelligenceDecision(card);
   WriteIntelligenceDecisionJournal(card);
   NotifyCard(card);
}
