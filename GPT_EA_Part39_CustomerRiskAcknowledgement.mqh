// ============================================================================
// GPT_EA Part 39 - Customer-facing risk acknowledgement gate
// ============================================================================
// Adds explicit, versioned risk acknowledgements on top of R8 legal acceptance.
// REAL accounts must affirm each material risk statement before new entries.
// Existing positions remain managed even when acknowledgement is incomplete.

const string GPT_EA_RISK_ACK_SCHEMA_VERSION = "GPT_EA_RISK_ACK_V1";

input bool   InpAcknowledgeNoProfitGuarantee        = false;
input bool   InpAcknowledgePossibleTotalLoss        = false;
input bool   InpAcknowledgeAILimitations            = false;
input bool   InpAcknowledgeBrokerThirdPartyRisk     = false;
input bool   InpAcknowledgePersonalResponsibility   = false;
input bool   InpAcknowledgeDemoFirst                = false;
input string InpCustomerJurisdiction                = "";
input bool   InpWriteRiskAcknowledgementLog         = true;
input string InpRiskAcknowledgementLogFile          = "GPT_EA_RiskAcknowledgements.csv";

string RiskAckTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

string RiskAckMaskLicense(const string value)
{
   string v=RiskAckTrim(value);
   int n=StringLen(v);
   if(n<=4) return "****";
   return "****"+StringSubstr(v,n-4,4);
}

bool GPTCustomerRiskAcknowledgementAllows(string &why)
{
   why="";

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: customer risk acknowledgement is informational only.";
      return true;
   }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest: customer risk acknowledgement is informational until REAL arming.";
      return true;
   }

   if(!InpAcknowledgeNoProfitGuarantee)
   {
      why="REAL account blocked: no-profit/no-wealth guarantee acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgePossibleTotalLoss)
   {
      why="REAL account blocked: possible substantial/total trading-loss acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeAILimitations)
   {
      why="REAL account blocked: AI/automation limitations acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeBrokerThirdPartyRisk)
   {
      why="REAL account blocked: broker/third-party execution risk acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgePersonalResponsibility)
   {
      why="REAL account blocked: personal trading responsibility acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeDemoFirst)
   {
      why="REAL account blocked: demo-first testing acknowledgement is missing.";
      return false;
   }

   string jurisdiction=RiskAckTrim(InpCustomerJurisdiction);
   if(StringLen(jurisdiction)<2)
   {
      why="REAL account blocked: customer jurisdiction code is required.";
      return false;
   }

   why="Customer risk acknowledgement PASS | schema="+GPT_EA_RISK_ACK_SCHEMA_VERSION+" | jurisdiction="+jurisdiction;
   return true;
}

void WriteRiskAcknowledgementEvent(const bool passed,const string reason)
{
   if(!InpWriteRiskAcknowledgementLog || (bool)MQLInfoInteger(MQL_TESTER)) return;

   int h=FileOpen(InpRiskAcknowledgementLogFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;

   if(FileSize(h)==0)
      FileWrite(h,"time","terms_version","ack_schema","jurisdiction","license_ref_masked","broker","server","state","reason");

   FileSeek(h,0,SEEK_END);
   FileWrite(h,
      TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
      GPT_EA_LEGAL_TERMS_VERSION,
      GPT_EA_RISK_ACK_SCHEMA_VERSION,
      RiskAckTrim(InpCustomerJurisdiction),
      RiskAckMaskLicense(InpCustomerLicenseReference),
      AccountInfoString(ACCOUNT_COMPANY),
      AccountInfoString(ACCOUNT_SERVER),
      passed?"PASS":"BLOCK",
      reason
   );
   FileFlush(h);
   FileClose(h);
}

bool ReleaseSafetyAllowsR9CustomerAck(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR8Legal(sym,base))
   {
      why=base;
      return false;
   }

   string risk="";
   if(!GPTCustomerRiskAcknowledgementAllows(risk))
   {
      why=risk;
      return false;
   }

   why=base+(base!=""?" | ":"")+risk;
   return true;
}

void RefreshR9CustomerAckReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR9CustomerAck("",why);

   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R9 customer-acknowledgement/API/release gates pass.":why);

   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
   {
      Print("GPT_EA R9 CUSTOMER ACK RELEASE BLOCK: ",g_releaseBlockReason);
      WriteRiskAcknowledgementEvent(false,g_releaseBlockReason);
   }
   else if(!g_releaseBlocked && oldBlocked)
   {
      Print("GPT_EA R9 CUSTOMER ACK RELEASE GATE CLEARED.");
      WriteRiskAcknowledgementEvent(true,why);
   }
}

string ReleaseGateSummaryR9CustomerAck()
{
   string why="";
   return ReleaseSafetyAllowsR9CustomerAck("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR9CustomerAck()
{
   AdvancedSafetyInitR8Legal();
   RefreshR9CustomerAckReleaseState();
}

void AdvancedSafetyTimerR9CustomerAck()
{
   AdvancedSafetyTimerR8Legal();
   RefreshR9CustomerAckReleaseState();
}

void StopFailureObservabilityInitR9CustomerAck()
{
   StopFailureObservabilityInitR8Legal();
   RefreshR9CustomerAckReleaseState();
}
